Translation workflow (local)

1. Create a virtual environment and install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\Activate.ps1 on Windows PowerShell
pip install -r scripts/requirements-translate.txt
```

2. Generate translations (example):

```bash
python scripts/translate_jsons.py --src "website blushy/lib/l10n/en.json" --out "website blushy/lib/l10n/" --langs hi bn ta te mr
```

- If `website blushy/lib/l10n/en.json` is missing, the script will fall back to `app blushy/lib/l10n/en.json`.
- Review generated files in `website blushy/lib/l10n/` before committing.

3. QA checks to run after generation:
- Ensure placeholders like `{name}` exist in the translation.
- Check ICU/plural forms and HTML/markdown markup.
- Open a PR per language and use Weblate or manual review for final edits.

4. CI suggestion:
- Add a job that detects new/changed keys in `en.json` and runs the script to create a PR with translations.

Contact: translation engineers or your localization reviewer for final sign-off.
