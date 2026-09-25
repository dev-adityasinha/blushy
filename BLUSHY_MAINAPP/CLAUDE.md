# Blushy app — coding conventions

## Localization (i18n) — user-facing strings MUST be translatable

The app supports 7 languages (en, hi, bn, ta, te, mr, kn) and switches **live**
(no restart): `MaterialApp.locale` is driven by `LanguagePreference.current`
(a `ValueNotifier`) via a `ValueListenableBuilder` above `MaterialApp` in
`lib/main.dart`. Changing the language instantly rebuilds every string that
comes from `AppLocalizations`.

**The rule that was historically missed:** every **user-facing chrome string
must come from `AppLocalizations`, not be hardcoded** in the widget. i.e.

```dart
// WRONG — hardcoded, never translates when the language changes
Text('Cycle Length')
_settingsRow(label: 'Log your period')

// RIGHT — flips live with the language
Text(AppLocalizations.of(context).setCycleLength)
```

"Chrome" = buttons, labels, nav, section headers, empty states, prompts,
snackbars, hints, dialog titles.

### The one deliberate exception: clinical copy stays English
Health/medical **guidance and instructions** (symptom explanations, "when to
see a doctor", protocol/lab names like TSH, Fasting Insulin, condition
descriptions) are intentionally **kept in English** — see the `@_NOTE` at the
top of `lib/l10n/app_en.arb`. A mistranslated medical instruction is a safety
problem; that copy is served/reviewed separately, never machine-translated
into the ARB. When in doubt whether a string is chrome or clinical, treat it
as clinical (leave English).

### How to add a translatable string
1. Add the key to **all 7** files `lib/l10n/app_<lang>.arb` (chrome →
   translated; if you only have English, still add the key to every file so
   `gen-l10n` doesn't drop it — it falls back to English).
   - Note: some ARB files use **CRLF** and historically lacked an `@@locale`
     line — insert new keys right after the opening `{`, keep the file valid
     JSON, and keep the line endings consistent.
2. Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations*.dart`.
3. Use it: `AppLocalizations.of(context).yourKey`. For placeholders
   (`"{count} days"`) the generated method takes an arg: `t.setDaysValue(n)`.

### Structural traps (no `context` available)
`AppLocalizations.of(context)` needs a `BuildContext`, so it **cannot** be used
in `static const` lists, class field initializers, or function default
parameter values. Those need a display-time lookup (resolve the key where the
value is rendered, not where it's declared) — or leave them English. Also,
removing a hardcoded string from inside a `const` widget tree means dropping
the `const` on that subtree (a runtime `AppLocalizations` call is not const).

### Audit
Run `python tool/i18n_audit.py` to list remaining hardcoded user-facing
strings per file (advisory — it can't tell chrome from clinical, so review the
results).

### Build-time guard (prevents regressions)
`tool/i18n_guard.py` fails when a change **adds** a hardcoded user-facing
string in `lib/` that bypasses `AppLocalizations`. It only inspects *added*
lines, so the existing baseline never blocks you; append `// i18n-ignore` to a
line that is deliberately English (reviewed clinical copy / internal key).

- **Pre-commit hook** (blocks the bad commit locally). Enable once from the
  repo root: `git config core.hooksPath BLUSHY_MAINAPP/tool/hooks`
- **CI**: `.github/workflows/i18n-guard.yml` runs the same check on every push
  to `main` and on PRs.
