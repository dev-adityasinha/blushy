#!/usr/bin/env python3
"""Quick translate en.json to a single language using a smaller Marian model.
Usage:
  python scripts/translate_quick.py --src "website blushy/lib/l10n/en.json" --out "website blushy/lib/l10n/" --lang hi
"""
import argparse
import json
from pathlib import Path

from transformers import MarianMTModel, MarianTokenizer


def load_json(path: Path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def save_json(obj, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def flatten(d, prefix=''):
    out = {}
    for k, v in d.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flatten(v, key))
        else:
            out[key] = v
    return out


def unflatten(flat):
    out = {}
    for k, v in flat.items():
        parts = k.split('.')
        cur = out
        for p in parts[:-1]:
            cur = cur.setdefault(p, {})
        cur[parts[-1]] = v
    return out


def translate_texts(texts, model_name, batch_size=32):
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    translated = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        inputs = tokenizer(batch, return_tensors='pt', padding=True, truncation=True)
        gen = model.generate(**inputs, max_length=256)
        out = tokenizer.batch_decode(gen, skip_special_tokens=True)
        translated.extend(out)
    return translated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--src', default='website blushy/lib/l10n/en.json')
    parser.add_argument('--out', default='website blushy/lib/l10n/')
    parser.add_argument('--lang', required=True)
    args = parser.parse_args()

    src_path = Path(args.src)
    if not src_path.exists():
        fallback = Path('app blushy/lib/l10n/en.json')
        if fallback.exists():
            src_path = fallback
        else:
            raise FileNotFoundError('Source en.json not found')

    src = load_json(src_path)
    flat = flatten(src)
    keys = list(flat.keys())
    texts = [flat[k] for k in keys]

    model_map = {
        'hi': 'Helsinki-NLP/opus-mt-en-hi',
        'bn': 'Helsinki-NLP/opus-mt-en-bn',
        'ta': 'Helsinki-NLP/opus-mt-en-ta',
        'te': 'Helsinki-NLP/opus-mt-en-te',
        'mr': 'Helsinki-NLP/opus-mt-en-mr',
    }
    model_name = model_map.get(args.lang)
    if not model_name:
        raise ValueError('No quick model available for this language')

    print('Using model', model_name)
    translated = translate_texts(texts, model_name)
    new_flat = {k: v for k, v in zip(keys, translated)}
    out = unflatten(new_flat)
    out_path = Path(args.out) / f"{args.lang}.json"
    save_json(out, out_path)
    print('Wrote', out_path)


if __name__ == '__main__':
    main()
