"""Appends translated strings to every ARB file.

Translating a screen means touching seven files in step. Doing that by hand is
how a language quietly ends up missing a key and silently falling back to
English, which looks like it worked.

Usage: feed it a JSON file of {key: {locale: text}} and it merges each locale
into its ARB, leaving existing entries alone.

    python tool/add_translations.py batch.json
"""
import io
import json
import sys
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / 'lib' / 'l10n'
LOCALES = ['en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn']


def load(locale):
    path = L10N / f'app_{locale}.arb'
    return path, json.loads(io.open(path, encoding='utf-8').read())


def main(batch_path):
    batch = json.loads(io.open(batch_path, encoding='utf-8').read())

    missing = []
    for key, byLocale in batch.items():
        for locale in LOCALES:
            if locale not in byLocale:
                missing.append(f'{key}:{locale}')
    if missing:
        # Refuse rather than write a partial set: a key present in some
        # languages and not others is the exact failure this tool exists to
        # prevent.
        print('Refusing to write. Missing translations:')
        for m in missing:
            print('  ' + m)
        return 1

    for locale in LOCALES:
        path, data = load(locale)
        added = 0
        for key, byLocale in batch.items():
            if key in data:
                continue
            data[key] = byLocale[locale]
            added += 1
        io.open(path, 'w', encoding='utf-8').write(
            json.dumps(data, ensure_ascii=False, indent=2) + '\n'
        )
        print(f'{locale}: +{added}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
