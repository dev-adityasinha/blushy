#!/usr/bin/env python3
"""Fill Tamil, Kannada and Telugu ARBs using HuggingFace inference.

MyMemory's free daily quota ran out partway through these three, and its cap
makes finishing them a multi-day job. Helsinki-NLP/opus-mt-en-dra is served on
the free hf-inference tier, covers all three Dravidian targets, and uses the
HF_TOKEN already in backend/.env -- no new credential.

Two things this does that a naive port would not:

  * Sentence-cases an ALL-CAPS source before sending. The model treats caps as
    an acronym and guesses: "CYCLE OVERVIEW" came back as கதிர்வீச்சு
    (radiation) and "CHECK IN" as ಕ್ಯೂಬೆಕ್ (Quebec), while "Cycle overview" and
    "Check in" translated correctly. Indic scripts are caseless, so nothing is
    lost by lowering the input.
  * Retries a 503, which is the model cold-starting rather than a failure.

Marathi is deliberately not handled here. No Marathi-specific model is served,
and the multilingual fallback produces broken words -- "No period logged yet"
came back as "अजूनही लॉगिड व्हिंट नाही". Finish mr on MyMemory instead.
"""
import argparse
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(REPO, "BLUSHY_MAINAPP", "lib", "l10n")
ENV = os.path.join(REPO, "BLUSHY_MAINAPP", "backend", ".env")

MODEL = "Helsinki-NLP/opus-mt-en-dra"
ENDPOINT = "https://router.huggingface.co/hf-inference/models/" + MODEL

# ARB locale -> the model's target token
TARGETS = {"ta": "tam", "kn": "kan", "te": "tel"}

BRAND_ONLY = {"Docsy", "Blushy", "M Studio", "Sia", "Blushy OS"}


def read_token():
    with io.open(ENV, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("HF_TOKEN="):
                return line.split("=", 1)[1].strip()
    return None


def prepare(text):
    """Sentence-case an all-caps source; leave anything else alone."""
    letters = [c for c in text if c.isalpha()]
    if letters and not any(c.islower() for c in letters):
        return text[:1] + text[1:].lower()
    return text


def skip_reason(value):
    if "{" in value or "}" in value:
        return "icu placeholder"
    if value.strip() in BRAND_ONLY:
        return "product name"
    if not any(ch.isalpha() for ch in value):
        return "no letters"
    return None


def translate(token, text, target, attempts=3):
    body = json.dumps({"inputs": ">>%s<< %s" % (target, prepare(text))}).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT, data=body,
        headers={"Authorization": "Bearer " + token,
                 "Content-Type": "application/json"},
    )
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                payload = json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            # 503 is the model waking up, not a failure.
            if exc.code == 503 and attempt + 1 < attempts:
                time.sleep(12)
                continue
            raise RuntimeError("HTTP %s" % exc.code)

        if isinstance(payload, dict) and payload.get("error"):
            raise RuntimeError(str(payload["error"])[:80])
        if not isinstance(payload, list) or not payload:
            raise RuntimeError("unexpected response")
        out = (payload[0].get("translation_text") or "").strip()
        if not out:
            raise RuntimeError("empty translation")
        return out
    raise RuntimeError("model did not become ready")


def load(path):
    with io.open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, data):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--locales", nargs="*", default=list(TARGETS))
    ap.add_argument("--limit", type=int, default=0,
                    help="stop after N keys per locale (0 = no limit)")
    args = ap.parse_args()

    token = read_token()
    if not token:
        print("no HF_TOKEN in backend/.env", file=sys.stderr)
        return 2

    en = load(os.path.join(L10N, "app_en.arb"))
    en_strings = {k: v for k, v in en.items()
                  if not k.startswith("@") and isinstance(v, str)}

    for loc in args.locales:
        if loc not in TARGETS:
            print("%s is not covered by %s -- skipped" % (loc, MODEL))
            continue

        path = os.path.join(L10N, "app_%s.arb" % loc)
        data = load(path)
        todo = [k for k, v in en_strings.items()
                if k not in data or data.get(k) == v]
        if args.limit:
            todo = todo[:args.limit]

        done = skipped = failed = 0
        cache = {}
        for key in todo:
            source = en_strings[key]
            why = skip_reason(source)
            if why:
                data[key] = source
                skipped += 1
                continue
            try:
                if source in cache:
                    data[key] = cache[source]
                else:
                    out = translate(token, source, TARGETS[loc])
                    cache[source] = out
                    data[key] = out
                done += 1
            except Exception as exc:
                failed += 1
                print("  %s %s: %s" % (loc, key, exc))
            if done and done % 25 == 0:
                save(path, data)
                print("  %s ... %d/%d" % (loc, done, len(todo)))

        save(path, data)
        print("%s: %d translated, %d left as-is, %d failed"
              % (loc, done, skipped, failed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
