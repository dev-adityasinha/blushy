#!/usr/bin/env python3
"""
Translate `en.json` into target languages using facebook/m2m100_418M.

Usage:
  python scripts/translate_jsons.py --src "website blushy/lib/l10n/en.json" --out "website blushy/lib/l10n/" --langs hi bn ta te mr

Notes:
 - Requires `transformers`, `sentencepiece`, and `torch`.
 - If website `en.json` is missing, the script will try to fall back to `app blushy/lib/l10n/en.json`.
 - This script performs batch translation and writes `<lang>.json` files.
 - Review translations before committing; placeholders and ICU tokens may need manual fixes.
"""
import argparse
import json
from pathlib import Path
from typing import Dict

try:
    from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer
except Exception as e:
    raise RuntimeError("Please install transformers, torch and sentencepiece: pip install transformers torch sentencepiece") from e


def load_json(path: Path) -> Dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(obj: Dict, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def flatten(d: Dict, prefix=""):
    out = {}
    for k, v in d.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flatten(v, key))
        else:
            out[key] = v
    return out


def unflatten(flat: Dict):
    out = {}
    for k, v in flat.items():
        parts = k.split('.')
        cur = out
        for p in parts[:-1]:
            cur = cur.setdefault(p, {})
        cur[parts[-1]] = v
    return out


def translate_texts(texts, tokenizer, model, src_lang, tgt_lang):
    tokenizer.src_lang = src_lang
    translated = []
    batch = []
    # simple batching by sentences
    for t in texts:
        batch.append(t)
        if len(batch) >= 16:
            enc = tokenizer(batch, return_tensors="pt", padding=True, truncation=True)
            gen = model.generate(**enc, forced_bos_token_id=tokenizer.get_lang_id(tgt_lang), max_length=256)
            out = tokenizer.batch_decode(gen, skip_special_tokens=True)
            translated.extend(out)
            batch = []
    if batch:
        enc = tokenizer(batch, return_tensors="pt", padding=True, truncation=True)
        gen = model.generate(**enc, forced_bos_token_id=tokenizer.get_lang_id(tgt_lang), max_length=256)
        out = tokenizer.batch_decode(gen, skip_special_tokens=True)
        translated.extend(out)
    return translated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default="website blushy/lib/l10n/en.json", help="Path to source en.json")
    parser.add_argument("--out", default="website blushy/lib/l10n/", help="Output l10n folder")
    parser.add_argument("--langs", nargs='+', default=["hi", "bn", "ta", "te", "mr"], help="Target language codes")
    parser.add_argument("--model", default="facebook/m2m100_418M", help="Hugging Face model to use")
    args = parser.parse_args()

    src_path = Path(args.src)
    if not src_path.exists():
        # fallback to app blushy
        fallback = Path("app blushy/lib/l10n/en.json")
        if fallback.exists():
            print(f"Source not found at {src_path}. Falling back to {fallback}.")
            src_path = fallback
        else:
            raise FileNotFoundError(f"Could not find source en.json at {args.src} or {fallback}")

    src = load_json(src_path)
    flat = flatten(src)
    keys = list(flat.keys())
    texts = [flat[k] for k in keys]

    print("Loading model", args.model)
    tokenizer = M2M100Tokenizer.from_pretrained(args.model)
    model = M2M100ForConditionalGeneration.from_pretrained(args.model)

    for lang in args.langs:
        print("Translating to", lang)
        translated = translate_texts(texts, tokenizer, model, "en", lang)
        new_flat = {k: v for k, v in zip(keys, translated)}
        out = unflatten(new_flat)
        out_path = Path(args.out) / f"{lang}.json"
        save_json(out, out_path)
        print("Wrote", out_path)


if __name__ == "__main__":
    main()
