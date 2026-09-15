#!/usr/bin/env python3
"""Apply a reviewer's corrections from the vocabulary CSV back into the ARBs.

The CSV produced for review carries, per row, the English string, the machine
translation per locale, and an empty `corrected_<locale>` column. A reviewer
fills in only the cells that were wrong. This reads those cells and writes them
into `app_<locale>.arb`, leaving every other key untouched.

Dry run by default. Nothing is written until you pass --apply, and nothing is
written at all if any check fails, so a half-applied file is not a state this
can leave behind.

Checks, and why each exists:
  * the key must already exist in app_en.arb -- a typo in the key column would
    otherwise add a string no screen ever reads;
  * placeholders must match the English -- a translator who rewords `{count}`
    turns a display bug into a runtime format exception;
  * a correction identical to the English is refused, because that is almost
    always a cell filled in by mistake rather than a decision that English is
    right (pass --allow-english for the genuine cases, such as product names);
  * if a locale column was edited but its `corrected_` cell left empty, that is
    reported rather than silently ignored -- it means the reviewer typed into
    the wrong column, and staying quiet would lose their work.

Usage:
  python scripts/import_reviewed_arb.py                      # dry run, all locales
  python scripts/import_reviewed_arb.py --locales hi bn      # dry run, two locales
  python scripts/import_reviewed_arb.py --apply              # write
"""
import argparse
import csv
import io
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_CSV = REPO / "BLUSHY_CYCLE_VOCAB_REVIEW.csv"
DEFAULT_L10N = REPO / "BLUSHY_MAINAPP" / "lib" / "l10n"
LOCALES = ["hi", "bn", "mr", "kn", "ta", "te"]

# Values the extractor writes when there is nothing to show. They are not
# translations and must never be imported as one.
SENTINELS = {"(not translated yet)", "(still English)", ""}

PLACEHOLDER_RE = re.compile(r"\{\s*[^}]+\s*\}")


def placeholders(text):
    """The set of ICU placeholders in a string, normalised for whitespace."""
    return {re.sub(r"\s+", "", p) for p in PLACEHOLDER_RE.findall(text)}


def load_arb(path):
    with io.open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_arb(path, data):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", default=str(DEFAULT_CSV),
                        help="reviewed CSV (default: %(default)s)")
    parser.add_argument("--l10n-dir", default=str(DEFAULT_L10N),
                        help="directory holding app_<locale>.arb")
    parser.add_argument("--locales", nargs="*", default=LOCALES,
                        help="locales to import (default: all)")
    parser.add_argument("--apply", action="store_true",
                        help="write the files; without this nothing changes")
    parser.add_argument("--allow-english", action="store_true",
                        help="permit a correction identical to the English source")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    l10n = Path(args.l10n_dir)
    if not csv_path.exists():
        print("no such CSV: %s" % csv_path, file=sys.stderr)
        return 2

    english = load_arb(l10n / "app_en.arb")

    with io.open(csv_path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))

    problems = []
    # locale -> {key: value}
    pending = {loc: {} for loc in args.locales}
    misplaced = []

    for line, row in enumerate(rows, start=2):
        key = (row.get("key") or "").strip()
        if not key:
            continue
        if key not in english:
            problems.append("line %d: key %r is not in app_en.arb" % (line, key))
            continue

        source = english[key]
        want = placeholders(source)

        for loc in args.locales:
            corrected = (row.get("corrected_" + loc) or "").strip()
            shown = (row.get(loc) or "").strip()

            if not corrected:
                # The reviewer may have typed over the machine translation
                # instead of the corrected column. Say so rather than lose it.
                if shown and shown not in SENTINELS:
                    current = load_arb(l10n / ("app_%s.arb" % loc)).get(key)
                    if current is not None and shown != current:
                        misplaced.append((line, loc, key, shown))
                continue

            if corrected in SENTINELS:
                problems.append("line %d [%s]: %r is a placeholder, not a translation"
                                % (line, loc, corrected))
                continue

            if corrected == source and not args.allow_english:
                problems.append(
                    "line %d [%s]: correction for %r is identical to the English. "
                    "Pass --allow-english if that is deliberate." % (line, loc, key))
                continue

            got = placeholders(corrected)
            if got != want:
                problems.append(
                    "line %d [%s]: placeholders differ for %r -- English has %s, "
                    "correction has %s" % (line, loc, key,
                                           sorted(want) or "none", sorted(got) or "none"))
                continue

            pending[loc][key] = corrected

    for line, loc, key, shown in misplaced:
        problems.append(
            "line %d [%s]: the %s column was edited for %r but corrected_%s is empty. "
            "Corrections go in corrected_%s." % (line, loc, loc, key, loc, loc))

    total = sum(len(v) for v in pending.values())
    for loc in args.locales:
        if pending[loc]:
            print("%s: %d correction(s)" % (loc, len(pending[loc])))
            for key, value in list(pending[loc].items())[:5]:
                print("    %-30s %s" % (key, value))
            if len(pending[loc]) > 5:
                print("    ... and %d more" % (len(pending[loc]) - 5))

    if problems:
        print("\n%d problem(s) -- nothing was written:" % len(problems), file=sys.stderr)
        for p in problems:
            print("  %s" % p, file=sys.stderr)
        return 1

    if total == 0:
        print("no corrections found in %s" % csv_path.name)
        return 0

    if not args.apply:
        print("\ndry run: %d correction(s) ready. Re-run with --apply to write." % total)
        return 0

    for loc in args.locales:
        if not pending[loc]:
            continue
        path = l10n / ("app_%s.arb" % loc)
        data = load_arb(path)
        data.update(pending[loc])          # existing keys keep their position
        save_arb(path, data)
        print("wrote %s" % path.name)

    print("\napplied %d correction(s). Now run:" % total)
    print("  cd BLUSHY_MAINAPP && flutter gen-l10n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
