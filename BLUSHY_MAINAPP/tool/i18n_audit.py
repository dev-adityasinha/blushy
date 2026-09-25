# -*- coding: utf-8 -*-
"""
i18n audit: lists hardcoded user-facing strings that are NOT going through
AppLocalizations, so they will not translate when the language changes.

Usage:  python tool/i18n_audit.py [path]   (default: lib)

Advisory only: it cannot distinguish chrome (should be translated) from
clinical copy (deliberately kept English per the ARB safety policy), so review
the results. See CLAUDE.md > Localization.
"""
import re, os, sys, collections

ROOT = sys.argv[1] if len(sys.argv) > 1 else 'lib'
# Text('..'), and common string-arg constructors that render to the user.
PAT = re.compile(
    r'''(?:Text\(\s*|text:\s*|label:\s*|labelText:\s*|hintText:\s*|helperText:\s*|title:\s*|subtitle:\s*|tooltip:\s*)'''
    r'''(['"])((?:(?!\1).){2,}?)\1''')

def is_userfacing(lit: str) -> bool:
    if not re.search('[A-Za-z]', lit):
        return False
    if '$' in lit:            # interpolated — needs placeholder handling, report separately if desired
        return False
    if 'http' in lit or lit.endswith('.dart') or '/' in lit:
        return False
    return True

counts = collections.Counter()
total = 0
for base, _, files in os.walk(ROOT):
    if 'l10n' in base:
        continue
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(base, fn)
        c = 0
        try:
            for line in open(p, encoding='utf-8'):
                if 'AppLocalizations' in line:   # line already localized
                    continue
                for m in PAT.finditer(line):
                    if is_userfacing(m.group(2)):
                        c += 1
        except Exception:
            continue
        if c:
            counts[p] = c
            total += c

print('Hardcoded user-facing (non-interpolated) strings not using AppLocalizations:', total)
print('Top files:')
for p, c in counts.most_common(30):
    print('%5d  %s' % (c, p))
