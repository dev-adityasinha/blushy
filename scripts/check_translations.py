#!/usr/bin/env python3
"""Check translation JSONs against source `en.json`.

Checks performed per target language:
- JSON parseable
- Same key set as source (reports missing/extra keys)
- Placeholder/token parity: braces {name}, printf %s, ICU plurals {count, plural, ...}
- All values are strings

Usage:
  python scripts/check_translations.py --src "app blushy/lib/l10n/en.json" --target_dir "website blushy/lib/l10n/" --repeat 100
"""
import argparse
import json
import re
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"{\s*[^}]+\s*}")
PRINTF_RE = re.compile(r"%s")
ICU_PLURAL_RE = re.compile(r"{\s*\w+\s*,\s*plural\s*,")


def load_json(path: Path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def extract_tokens(s: str):
    if not isinstance(s, str):
        return set()
    tokens = set(PLACEHOLDER_RE.findall(s))
    if PRINTF_RE.search(s):
        tokens.add('%s')
    if ICU_PLURAL_RE.search(s):
        tokens.add('ICU_PLURAL')
    return tokens


def flatten(d, prefix=''):
    out = {}
    for k, v in d.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flatten(v, key))
        else:
            out[key] = v
    return out


def check_once(src_path: Path, target_dir: Path):
    results = {}
    try:
        src = load_json(src_path)
    except Exception as e:
        return {'error': f'Failed to load source {src_path}: {e}'}
    flat_src = flatten(src)
    src_keys = set(flat_src.keys())

    for p in sorted(target_dir.glob('*.json')):
        lang = p.stem
        try:
            tgt = load_json(p)
            flat_tgt = flatten(tgt)
        except Exception as e:
            results[lang] = {'error': f'Failed to load {p}: {e}'}
            continue
        tgt_keys = set(flat_tgt.keys())
        missing = sorted(list(src_keys - tgt_keys))
        extra = sorted(list(tgt_keys - src_keys))

        token_mismatches = []
        for k in sorted(src_keys & tgt_keys):
            toks_src = extract_tokens(flat_src[k])
            toks_tgt = extract_tokens(flat_tgt[k])
            if toks_src != toks_tgt:
                token_mismatches.append({'key': k, 'src': sorted(toks_src), 'tgt': sorted(toks_tgt)})

        non_string_values = [k for k, v in flat_tgt.items() if not isinstance(v, str)]

        results[lang] = {
            'missing_keys': missing,
            'extra_keys': extra,
            'token_mismatches': token_mismatches,
            'non_string_values': non_string_values,
            'file': str(p)
        }
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--src', default='app blushy/lib/l10n/en.json')
    parser.add_argument('--target_dir', default='website blushy/lib/l10n/')
    parser.add_argument('--repeat', type=int, default=1)
    args = parser.parse_args()

    src_path = Path(args.src)
    target_dir = Path(args.target_dir)

    overall_ok = True
    aggregate_failures = {}
    for i in range(args.repeat):
        res = check_once(src_path, target_dir)
        if 'error' in res:
            print(f'Run {i+1}: ERROR: {res["error"]}')
            overall_ok = False
            break
        # collect any failures
        for lang, info in res.items():
            ok = True
            if info.get('missing_keys') or info.get('extra_keys') or info.get('token_mismatches') or info.get('non_string_values'):
                ok = False
                overall_ok = False
                aggregate_failures.setdefault(lang, []).append(info)
        if (i+1) % 10 == 0:
            print(f'Completed {i+1}/{args.repeat} runs')
    # Summary
    if not aggregate_failures:
        print(f'All {args.repeat} runs passed: no missing/extra keys or token mismatches found.')
    else:
        print('Failures detected:')
        for lang, items in aggregate_failures.items():
            print(f'--- {lang} ({len(items)} run(s) with issues) ---')
            # print only last failure details to avoid huge output
            last = items[-1]
            if last.get('missing_keys'):
                print(f"Missing keys ({len(last['missing_keys'])}): {last['missing_keys'][:10]}{('...' if len(last['missing_keys'])>10 else '')}")
            if last.get('extra_keys'):
                print(f"Extra keys ({len(last['extra_keys'])}): {last['extra_keys'][:10]}{('...' if len(last['extra_keys'])>10 else '')}")
            if last.get('token_mismatches'):
                print(f"Token mismatches ({len(last['token_mismatches'])}), example: {last['token_mismatches'][:2]}")
            if last.get('non_string_values'):
                print(f"Non-string values ({len(last['non_string_values'])}): {last['non_string_values'][:10]}")
    return 0 if overall_ok else 2

if __name__ == '__main__':
    import sys
    rc = main()
    sys.exit(rc)
