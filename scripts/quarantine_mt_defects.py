#!/usr/bin/env python3
"""Remove machine-translation output that is broken on its face, and list it.

The opus-mt models used for Tamil, Kannada and Telugu are trained partly on
KDE/GNOME translation files, and some output carries tokens from that corpus:
values ending in "Name", "Query" or "Comment", the application name "Strigi",
and four Kannada values containing the literal "NAME OF TRANSLATORS". None of
that is in the source string.

A key removed here falls back to English, which is plainly worse than a good
translation and plainly better than showing a user a Kannada word with "Name"
welded to the end. Re-running a translator would reproduce it exactly -- these
models decode greedily -- so the fix has to come from a human, and the same
pass rebuilds the review CSV so it is on the reviewer's list.

Detection is narrow on purpose: a Latin run of three or more letters that does
not appear in the English source. Awkward-but-readable output is not detectable
this way and is left alone.

  python scripts/quarantine_mt_defects.py            # dry run
  python scripts/quarantine_mt_defects.py --apply    # remove + rebuild the CSV
"""
import argparse
import csv
import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(REPO, "BLUSHY_MAINAPP", "lib", "l10n")
CSV_OUT = os.path.join(REPO, "BLUSHY_CYCLE_VOCAB_REVIEW.csv")
LOCALES = ["hi", "bn", "mr", "kn", "ta", "te"]

LATIN = re.compile(r"[A-Za-z]{3,}")
LEAK_MARKERS = [
    "name of transl", "email of transl", "role of transl",
    "your names", "your emails", "credit_for_transl",
]

# Same vocabulary list the first review extract used, so the CSV keeps covering
# the terms a general translator renders in the wrong sense.
TERMS = {
    "menstruation": ["period", "periods", "menstrual", "menstruation", "menses",
                     "flow", "bleed", "bleeding", "spotting", "lochia", "tampon", "pad"],
    "cycle": ["cycle", "cycles", "luteal", "follicular", "ovulation", "ovulate",
              "ovulating", "phase"],
    "fertility": ["fertile", "fertility", "conceive", "conception", "implantation",
                  "lh", "bbt", "basal", "cervical", "mucus", "sperm"],
    "pregnancy": ["pregnant", "pregnancy", "trimester", "postpartum", "gestational",
                  "birth", "feeding", "latch", "nursing"],
    "menopause": ["menopause", "menopausal", "perimenopause", "postmenopause",
                  "hot flash", "hot flashes", "flush", "flushes"],
    "anatomy / clinical": ["uterus", "uterine", "vaginal", "vagina", "cervix", "breast",
                           "nipple", "pelvic", "discharge", "hormone", "hormonal",
                           "estrogen", "progesterone", "pcos", "pmdd", "pms",
                           "endometriosis", "thyroid", "cramp", "cramps", "cramping"],
}
WORD = {w: g for g, words in TERMS.items() for w in words}


def vocab_hit(value):
    low = value.lower()
    for w, group in WORD.items():
        if re.search(r"(?<![a-z])%s(?![a-z])" % re.escape(w), low):
            return w, group
    return None


def load(path):
    with io.open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, data):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def leaked_token(source, translated):
    """The first Latin run in the translation that is absent from the source."""
    if any(m in translated.lower() for m in LEAK_MARKERS):
        return "NAME OF TRANSLATORS"
    for token in LATIN.findall(translated):
        if token.lower() not in source.lower():
            return token
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    en = load(os.path.join(L10N, "app_en.arb"))
    en_strings = {k: v for k, v in en.items()
                  if not k.startswith("@") and isinstance(v, str)}

    data = {loc: load(os.path.join(L10N, "app_%s.arb" % loc)) for loc in LOCALES}

    # locale -> {key: leaked token}
    defects = {loc: {} for loc in LOCALES}
    for loc in LOCALES:
        for key, value in data[loc].items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            source = en_strings.get(key)
            if source is None or value == source:
                continue
            token = leaked_token(source, value)
            if token:
                defects[loc][key] = token

    total = sum(len(v) for v in defects.values())
    print("machine-translation defects found: %d" % total)
    for loc in LOCALES:
        if defects[loc]:
            print("  %-4s %3d" % (loc, len(defects[loc])))
    print()

    if not args.apply:
        for loc in LOCALES:
            for key, token in list(defects[loc].items())[:4]:
                print("  %s %-28s %-24s -> %s   [leaked %r]"
                      % (loc, key, en_strings[key][:24], data[loc][key][:34], token))
        print("\ndry run. Re-run with --apply to remove them and rebuild the CSV.")
        return 0

    # ── remove, so the key falls back to English ──────────────────────────────
    for loc in LOCALES:
        if not defects[loc]:
            continue
        for key in defects[loc]:
            del data[loc][key]
        save(os.path.join(L10N, "app_%s.arb" % loc), data[loc])
        print("%s: removed %d, now %d keys"
              % (loc, len(defects[loc]),
                 len([k for k in data[loc] if not k.startswith("@")])))

    # ── rebuild the review CSV over both reasons ─────────────────────────────
    rows = []
    for key, source in en_strings.items():
        hit = vocab_hit(source)
        quarantined = sorted(loc for loc in LOCALES if key in defects[loc])
        if not hit and not quarantined:
            continue

        reasons = []
        if hit:
            reasons.append(hit[1])
        if quarantined:
            reasons.append("mt defect")

        row = {
            "key": key,
            "english": source,
            "category": " + ".join(reasons),
            "flagged_term": hit[0] if hit else "",
            "removed_from": " ".join(quarantined),
            "leaked_token": " ".join(sorted({defects[loc][key] for loc in quarantined})),
        }
        for loc in LOCALES:
            got = data[loc].get(key)
            if got is None:
                row[loc] = "(not translated)"
            elif got == source:
                row[loc] = "(still English)"
            else:
                row[loc] = got
            row["corrected_" + loc] = ""
        rows.append(row)

    rows.sort(key=lambda r: (r["category"], r["key"]))
    fields = (["key", "english", "category", "flagged_term", "removed_from", "leaked_token"]
              + [c for loc in LOCALES for c in (loc, "corrected_" + loc)])

    with io.open(CSV_OUT, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    print("\nrebuilt %s with %d rows" % (os.path.basename(CSV_OUT), len(rows)))
    print("now run: cd BLUSHY_MAINAPP && flutter gen-l10n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
