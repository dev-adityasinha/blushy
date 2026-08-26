import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: repair_json.py <path-to-json>")
    sys.exit(1)

p = Path(sys.argv[1])
if not p.exists():
    print("File not found:", p)
    sys.exit(1)

s = p.read_text(encoding='utf-8')
# find first balanced JSON object
balance = 0
start = None
end = None
for i, ch in enumerate(s):
    if ch == '{':
        if start is None:
            start = i
        balance += 1
    elif ch == '}':
        balance -= 1
        if balance == 0 and start is not None:
            end = i
            break

if end is None:
    print('Could not find balanced JSON object in file')
    sys.exit(1)

new = s[:end+1]
backup = p.with_suffix('.json.bak')
backup.write_text(s, encoding='utf-8')
p.write_text(new, encoding='utf-8')
print(f'Repaired {p} — original saved to {backup}')
