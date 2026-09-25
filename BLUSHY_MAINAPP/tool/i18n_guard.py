# -*- coding: utf-8 -*-
"""
i18n build-time guard.

Fails (exit 1) when a commit/diff ADDS a hardcoded user-facing string in a
lib/ Dart file instead of routing it through AppLocalizations. Only inspects
*added* lines, so the existing baseline never blocks you.

Escape hatch: end the line with  // i18n-ignore  for a string that is
deliberately English (e.g. reviewed clinical/medical copy, an internal key,
or a debug string). See CLAUDE.md > Localization.

Modes:
  python tool/i18n_guard.py                      # staged changes (pre-commit)
  python tool/i18n_guard.py --staged
  python tool/i18n_guard.py --range A..B         # a commit range (CI)
"""
import re, subprocess, sys

PAT = re.compile(
    r'''(?:Text\(\s*|text:\s*|label:\s*|labelText:\s*|hintText:\s*|helperText:\s*|title:\s*|subtitle:\s*|tooltip:\s*)'''
    r'''(['"])((?:(?!\1).){2,}?)\1''')

def is_userfacing(lit: str) -> bool:
    if not re.search('[A-Za-z]', lit):
        return False
    if '$' in lit or 'http' in lit or lit.endswith('.dart') or '/' in lit:
        return False
    return True

def diff_args():
    a = sys.argv[1:]
    if a and a[0] == '--range' and len(a) > 1:
        return [a[1], '-U0']
    return ['--cached', '-U0']  # staged (pre-commit default)

def main():
    try:
        out = subprocess.run(
            ['git', 'diff'] + diff_args() + ['--', '*.dart'],
            capture_output=True, text=True, encoding='utf-8', errors='replace',
        ).stdout
    except Exception:
        return 0  # never break the build on a git hiccup

    path = None
    newln = 0
    violations = []
    for line in out.split('\n'):
        if line.startswith('+++ b/'):
            path = line[6:]
            continue
        if line.startswith('@@'):
            m = re.search(r'\+(\d+)', line)
            newln = int(m.group(1)) if m else 0
            continue
        if not line.startswith('+') or line.startswith('+++'):
            continue
        content = line[1:]
        cur, newln = newln, newln + 1
        if path is None:
            continue
        # Only lib/ Dart UI, never generated l10n or tests.
        if '/lib/' not in ('/' + path) and not path.startswith('lib/'):
            continue
        if '/l10n/' in path or '/test/' in path:
            continue
        if 'AppLocalizations' in content or '// i18n-ignore' in content or 'ignore: ' in content:
            continue
        for mm in PAT.finditer(content):
            if is_userfacing(mm.group(2)):
                violations.append((path, cur, mm.group(2)))

    if violations:
        print('i18n guard: %d newly hardcoded user-facing string(s) found.' % len(violations))
        print('Route them through AppLocalizations, or add  // i18n-ignore  if the')
        print('string is deliberately English (reviewed clinical copy / internal key).')
        print('')
        for p, ln, lit in violations:
            s = lit if len(lit) <= 60 else lit[:57] + '...'
            print('  %s:%d  "%s"' % (p, ln, s))
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
