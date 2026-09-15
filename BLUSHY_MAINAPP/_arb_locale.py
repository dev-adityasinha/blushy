import io, re, glob, json

# The brand token as each locale currently transliterates it, taken from that
# file's own navSia value rather than guessed.
NEW = 'Dr. Docsy'
total = {}

for p in sorted(glob.glob('lib/l10n/app_*.arb')):
    if p.endswith('app_en.arb'):
        continue
    raw = io.open(p, encoding='utf-8').read()
    m = re.search(r'"navSia"\s*:\s*"([^"]+)"', raw)
    if not m:
        print(f'  {p}: navSia missing, skipped')
        continue
    token = m.group(1)
    if token == NEW:
        continue
    lines = raw.split('\n')
    hits = 0
    for i, line in enumerate(lines):
        mm = re.match(r'^(\s*"[^"]+"\s*:\s*)(.*)$', line)
        if not mm:
            continue
        head, tail = mm.group(1), mm.group(2)
        if token in tail:
            hits += tail.count(token)
            lines[i] = head + tail.replace(token, NEW)
    if hits:
        io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
        total[p] = (token, hits)

for p, (tok, n) in total.items():
    print(f'  {n:2d}  {p}   (was "{tok}")')
print(f'\n  locale files: {len(total)}   values renamed: {sum(n for _, n in total.values())}')
