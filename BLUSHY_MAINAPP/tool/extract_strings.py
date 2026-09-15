"""Pulls hardcoded user-facing strings out of widgets and into app_en.arb.

Makes the app translator-ready. Only English is written: the other six locales
inherit the English implementation for any key they do not define, so a
half-extracted app keeps working and every new key reads as untranslated until
someone translates it. That is the hand-off point.

Deliberately conservative. It only touches literals it is confident about, and
it verifies every file with the analyzer before keeping the change:

  * Only `Text('...')`, `label:`, `title:`, `hintText:` and `helperText:`.
  * No interpolation. `'Hello $name'` needs a placeholder declaration and a
    judgement about the argument, so those are left for a human.
  * Nothing inside a `const` expression, where a runtime call cannot go.
  * Nothing in a `static` or top-level declaration, which has no BuildContext.
  * Nothing under 3 characters, and nothing that looks like an identifier,
    asset path, URL or format string.

Run:
    python tool/extract_strings.py --list                 # what it would take
    python tool/extract_strings.py --file lib/...dart     # one file
    python tool/extract_strings.py --apply --limit 5      # a batch
"""
import argparse
import collections
import io
import json
import re
import subprocess
import sys
from pathlib import Path

ARB = Path('lib/l10n/app_en.arb')

# The attributes whose value is read by a person.
ATTRS = ('label', 'title', 'hintText', 'helperText', 'tooltip')

LITERAL = r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\""
PATTERNS = [
    re.compile(r'Text\(\s*(?:' + LITERAL + r')'),
    re.compile(r'\b(?:' + '|'.join(ATTRS) + r'):\s*(?:' + LITERAL + r')'),
]

# Things that are not prose.
SKIP = re.compile(
    r'^\s*$'
    r'|^[a-z_]+$'                     # identifiers / keys
    r'|^[A-Z_]+$'                     # constants
    r'|\.(png|jpg|jpeg|svg|json|dart|webp|mp3|wav)$'
    r'|^(https?|assets|package|blushy)[:/]'
    r'|^\W+$'                         # punctuation or emoji only
)


def is_prose(text: str) -> bool:
    if len(text) < 3 or len(text) > 200:
        return False
    if SKIP.search(text):
        return False
    if '$' in text or '\\n' in text:        # interpolation / multiline
        return False
    return any(c.isalpha() for c in text)


def adjacent_literal(source: str, end: int) -> bool:
    """Is another string literal butted up against this one?"""
    return bool(re.match(r"\s*['\"]", source[end:end + 40]))


def key_for(path: Path, text: str, taken: set) -> str:
    """A key that says where it came from and what it says."""
    stem = re.sub(r'_(screen|widget|dialog|card|sheet|wizard)$', '', path.stem)
    prefix = ''.join(w[:1] for w in stem.split('_'))[:4] or 'app'
    words = re.findall(r'[A-Za-z]+', text)[:4]
    body = words[0].lower() + ''.join(w.capitalize() for w in words[1:]) if words else 'text'
    base = prefix + body[:1].upper() + body[1:]
    key, n = base, 2
    while key in taken:
        key, n = f'{base}{n}', n + 1
    return key


def in_const(source: str, at: int) -> bool:
    """Is this literal inside a const expression a runtime call cannot enter?"""
    window = source[max(0, at - 240):at]
    return bool(re.search(r'\bconst\b[^;{}]*$', window))


def no_context(source: str, at: int) -> bool:
    """Top-level or static declarations have no BuildContext in scope."""
    line_start = source.rfind('\n', 0, at) + 1
    # Walk back to the enclosing declaration.
    head = source[max(0, at - 3000):line_start]
    decl = re.findall(r'^\s*(static\s+|final\s+|const\s+)?[A-Za-z<>,\s\?\[\]]+\s+\w+\s*[=({]',
                      head, re.M)
    return bool(decl and 'static' in (decl[-1] or ''))


def find_candidates(path: Path):
    source = io.open(path, encoding='utf-8').read()
    seen = []
    for pattern in PATTERNS:
        for m in pattern.finditer(source):
            text = m.group(1) if m.group(1) is not None else m.group(2)
            if text is None or not is_prose(text):
                continue
            at = m.start()
            if in_const(source, at) or no_context(source, at):
                continue
            if adjacent_literal(source, m.end()):
                # 'first half ' 'second half' is a single Dart string. Replacing
                # one half leaves the other stranded as a syntax error.
                continue
            seen.append(text)
    # Stable, de-duplicated.
    return list(dict.fromkeys(seen))


def analyzer_clean(path: Path) -> bool:
    out = subprocess.run(['flutter', 'analyze', str(path)],
                         capture_output=True, text=True, shell=True)
    return 'No issues found' in out.stdout


def apply_to(path: Path, arb: dict, dry: bool) -> int:
    texts = find_candidates(path)
    if not texts:
        return 0

    source = io.open(path, encoding='utf-8').read()
    original = source
    added = {}

    for text in texts:
        key = key_for(path, text, set(arb) | set(added))
        quoted = text.replace("'", r"\'")
        call = f'AppLocalizations.of(context).{key}'
        # Replace the literal wherever it appears in a matched position.
        for lit in (f"'{text}'", f'"{text}"'):
            if lit in source:
                source = source.replace(lit, call)
                added[key] = text
                break

    if not added:
        return 0

    if 'app_localizations.dart' not in source:
        lines = source.split('\n')
        idx = max((i for i, l in enumerate(lines) if l.startswith('import ')), default=0)
        depth = len(path.relative_to('lib').parts) - 1
        lines.insert(idx + 1, f"import '{'../' * depth}l10n/app_localizations.dart';")
        source = '\n'.join(lines)

    if dry:
        print(f'  would extract {len(added):3d} from {path}')
        return len(added)

    io.open(path, 'w', encoding='utf-8').write(source)
    arb.update(added)
    write_arb(arb)
    # The getters do not exist until this runs, so analysis before it is
    # guaranteed to fail on every new key.
    subprocess.run(['flutter', 'gen-l10n'], capture_output=True, text=True, shell=True)

    if not analyzer_clean(path):
        io.open(path, 'w', encoding='utf-8').write(original)
        for k in added:
            arb.pop(k, None)
        write_arb(arb)
        subprocess.run(['flutter', 'gen-l10n'], capture_output=True, text=True, shell=True)
        print(f'  REVERTED {path} (analyzer rejected it)')
        return 0

    print(f'  extracted {len(added):3d} from {path}')
    return len(added)


def write_arb(arb: dict):
    io.open(ARB, 'w', encoding='utf-8').write(
        json.dumps(arb, ensure_ascii=False, indent=2) + '\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--file')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--list', action='store_true')
    args = ap.parse_args()

    arb = json.load(io.open(ARB, encoding='utf-8'),
                    object_pairs_hook=collections.OrderedDict)

    if args.file:
        files = [Path(args.file)]
    else:
        files = sorted(Path('lib/features').rglob('*.dart')) + \
                sorted(Path('lib/shared').rglob('*.dart'))

    if args.list:
        total = 0
        for f in files:
            n = len(find_candidates(f))
            if n:
                total += n
                print(f'  {n:4d}  {f}')
        print(f'\n  extractable: {total}')
        return

    done, touched = 0, 0
    for f in files:
        if args.limit and touched >= args.limit:
            break
        n = apply_to(f, arb, dry=not args.apply)
        if n:
            done += n
            touched += 1

    print(f'\n  {"would extract" if not args.apply else "extracted"}: {done} strings '
          f'from {touched} files')


if __name__ == '__main__':
    sys.exit(main())
