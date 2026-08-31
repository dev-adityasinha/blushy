# Requested changes

Source: `Untitled document (1).docx` (38 bullets), received 2026-08-31.

This document restates each request in full sentences, records what I found in the code when I checked, and flags the ones that cannot be started until a decision is made. Each item carries its own status — see the decisions log immediately below for what has been built so far.

Where a claim has a number against it, I measured it. Where I am guessing at intent, I say so.

---

## Decisions log

Answers given since the first draft. These override anything below them.

### 2026-08-31 — three decisions

| # | Decision | Effect | Status |
|---|---|---|---|
| 1 | **Remove the Discover section** | Resolves the #9 / #11 contradiction — #11 wins. See C1. | **Implemented** |
| 2 | **Rename Sia to Dr. Docsy** | See D1. Name only; persona question still open. | **Implemented** |
| 3 | **"Boutique" becomes "Bouquet"** | See F1. | **Implemented** |
| 4 | **Continue down the list** | Community off home (#10, #12), logout confirmation (#24), greeting card (#3), period chart refresh (#7). See C2, G3b, B3, B2. | **Implemented** |

**Progress: 20 of 38 done, 2 more started** (#5, #18/#37). Complete: #1 (extraction), #3, #7, #10, #11, #12, #13, #14, #15, #17, #23, #24, #25, #26, #28, #31, #38, part of #33. Verified at each step: `flutter analyze` clean, **228 Flutter tests**, **440 backend tests**. **339** translation keys; 165 translated in all six locales, the rest awaiting a translator.

**Waiting on you:** how to handle medical vocabulary in translation (A1), which languages to add (#2), the persona question (D1), and the two incomplete requests (#21, #27). The clinical approval is deferred at your request — see 0.1.

**On the rename specifically:** `Sia` no longer appears as a word anywhere in `lib/` or `backend/src/`, and the stored permission key `sia_conversations` is untouched.

Problems found while doing this work, and fixed at the same time, are recorded under "Found along the way" below and inside the individual items.

**Still open on the rename:** I asked whether the *persona* changes with the name. That was not answered, so I am changing **the name only** and leaving the character as written — a warm companion that never names medications and defers to a doctor. This is the conservative reading: "Dr." implies clinical authority, and giving the AI that authority is a product and safety decision, not a find-and-replace. Say the word if you want the persona reworked too.

**Typography:** rendering it as **"Dr. Docsy"** (space after the period), which is conventional. The source wrote "Dr.Docsy". Tell me if you want it closed up.

**Brand name in the six non-English locales — needs a second opinion.** Each locale previously transliterated the name into its own script (Hindi सिया, Bengali সিয়া, Tamil சியா, and so on). I replaced all of them with **"Dr. Docsy" in Latin script** rather than inventing six transliterations of a brand name, partly because "Dr." is an abbreviation and transliterating abbreviations reads badly. Latin-script brand names are normal in Indian apps, so this is defensible — but it does break the convention the app already had, and a native speaker should confirm it before release. Transliterating instead is a small change if you prefer.

### Found along the way

Two defects surfaced while making these changes. Both are fixed.

1. **The bottom navigation label was never translated.** `_buildSiaItem` took a `siaLabel` argument but used it *only* for the screen-reader `Semantics` label — the visible `Text` was a hardcoded literal. So screen-reader users heard the translated name and everyone looking at the screen saw English, in every locale. Now uses the localised string. This is a concrete instance of item #1.
2. **No overflow handling on that label.** `maxLines: 1` with no `overflow`, in a fifth of the screen width at 10pt. "Sia" always fit; "Dr. Docsy" is three times longer and would have clipped on narrow devices. Now ellipsises.

---

**Status legend**

| Mark | Meaning |
|---|---|
| BLOCKED | Cannot start; waiting on a decision or an input only you can give |
| DONE? | Already built this session — needs verifying on the current APK, not rebuilding |
| CLEAR | Understood well enough to start |
| UNCLEAR | Ambiguous or contradicts another item; needs a sentence from you |

---

## 0. Read this first — three things change the shape of the list

### 0.1 Roughly a fifth of the list is one blocked decision, not separate bugs

Every piece of content in the app sits behind a clinical review gate, and **nothing has been approved**:

```
status=clinical_review  audience=female_user  121
status=clinical_review  audience=partner       38

by content_type:  article 141 · recovery_session 5 · safety 13
```

The API returns `{"data":[],"state":"empty"}` and the screens correctly render their empty states. So these reported items share one cause:

- "Discover section doesn't have content" (#9)
- "Recovery has no sessions available" (#19)
- Any other screen that looks empty of articles

The gate is deliberate: `setContentStatus` refuses to approve without a named reviewer, and writes that name and date into the content audit trail. That record is the entire point of the gate — it separates "a clinician read this" from "nobody did". I will not put an invented name in it.

**Deferred 2026-08-31 at your request — skipping the clinical approval for now.** These screens stay empty until it happens; that is the expected behaviour, not a bug to chase.

Two things found while preparing it, worth keeping for whenever you come back to it:

**The 159 are not one batch.** 52 carry a real citation — NICE NG201, NICE NG23, WHO antenatal and postnatal recommendations, RCOG Green-top — and a reviewer could check those against the source. The other **107 carry a placeholder that says, in the source field itself**, "Blushy editorial copy. Awaiting clinical review and sourcing." Approving those would stamp a reviewer's name on text whose own record says it has not been sourced.

**All 5 recovery sessions are in the sourced group**, so approving only those 52 would have cleared #19 outright.

`src/scripts/approveSourcedContent.mjs` is written and dry-run tested for exactly that split — it approves the 52 and refuses to touch the 107. It needs only `--reviewer "Name, credentials"` whenever you want it.

### 0.2 Some items may already be fixed — check before I touch them

These were built during this session. If you tested on an APK built before **01:37 today**, you would still see the old behaviour:

| Reported | Status |
|---|---|
| "Successful account creation message isn't shown, doesn't redirect to login" (#4) | DONE? — success dialog + redirect to the login tab, email pre-filled |
| "Voice reflection isn't working" (#8) | DONE? — reflections persist via `journal_quick_entry.dart` |
| Recovery session player missing (#19) | DONE? — player exists; the *content* is what's blocked (0.1) |
| Home page blank while loading | DONE? — sync banner added |

Please confirm against the current APK before I spend time re-fixing these. If they still fail on the new build, that is a different bug and I want to know.

### 0.3 Two requests contradicted each other — RESOLVED

- **#9:** "Discover section doesn't have content"
- **#11:** "Discover — to be removed"

**Resolved 2026-08-31: remove it.** #11 supersedes #9.

Two further items are incomplete in the source document:

- **#21:** *"Time capsules are supposed to be sent over email. Open it in should be a calendar date- and it"* — the sentence stops mid-thought.
- **#27:** *"Activity,"* — a single word with no request attached.

---

## A. Localisation

### A1 — Translation isn't applied across the app (#1) · EXTRACTION DONE, translation handed off

**The translation pipeline itself is healthy.** All **156** keys are defined and genuinely translated in every one of the six locales — I checked, and only the brand name is identical to English. So this is not a broken pipeline; it is a coverage problem. Only about **10 of 129** feature files call `AppLocalizations` at all.

Where the untranslated text lives:

| Strings | File |
|---|---|
| 105 | `everyday_wellness_dashboard.dart` |
| 68 | `journal_screen.dart` |
| 52 | `stage_questionnaire_dialog.dart` |
| 47 | `onboarding_wizard.dart` |
| 38 | `partner_screen.dart` |

**Done so far — 17 strings across two screens, in all seven locales:**

- **Onboarding wizard chrome** — Continue, Back, "I don't remember", the chapter headings, the four loading messages. The wizard is the first thing a new user meets, so English there costs the most.
- **Journal feedback and actions** — Cancel, Share, Delete, and the transcription and sharing messages ("Could not transcribe that recording", "Nothing was recognised in that recording. You can type it instead", "No longer shared").

Decorative vocabulary in the journal — colour, sticker, paper and font names like "Coral Tape", "Cream Paper", "Brush Script" — is deliberately left in English. Each names a visual thing being picked from a swatch, and translating it adds nothing.

### Bulk extraction — done (option 1, chosen 2026-08-31)

Hand-translating 581 strings screen by screen was going to take days and still need a native speaker at the end. So the mechanical half was automated instead, and the translation half handed off properly.

**`tool/extract_strings.py`** pulls hardcoded strings out of widgets into `app_en.arb` and wires `AppLocalizations`. It is deliberately conservative, and it **verifies every file with the analyzer, reverting anything that does not compile**:

- Skips `const` expressions, where a runtime call cannot go
- Skips `static` and top-level declarations, which have no `BuildContext`
- Skips interpolated strings, which need a placeholder declaration and a judgement call
- Skips adjacent string concatenation — `'first half ' 'second half'` is one Dart string, and replacing half of it is a syntax error

Those last two were found by testing the tool on a single small file before letting it near the codebase. It also ran `flutter analyze` before `gen-l10n`, so every new getter was undefined and every file was rejected — fixed the same way.

**Result: 171 strings extracted from 33 files.** Eleven files were reverted by the analyzer check rather than broken. English keys went from 165 to **338**.

**One thing the analyzer could not catch.** Extraction made `recovery_session_player.dart` depend on localizations, and its existing widget test built it in a bare `MaterialApp` with no delegates — so the lookup returned null and the widget threw at runtime while analysis stayed clean. The test suite caught it; the harness now supplies the delegates the real app does.

**`tool/translation_status.py`** writes `TRANSLATION_TODO.md` — the hand-off. It separates the two kinds of work rather than dumping 338 rows on one person:

```
LOCALE  TRANSLATED  REMAINING
bn/hi/kn/mr/ta/te      165        173

of which clinical vocabulary: 5
```

The 5 clinical keys — hormonal contraception, hormonal conditions, luteal recovery — are listed under their own heading, to be routed to a clinician or medical translator rather than a general one.

**Nothing regressed for users.** A key a locale does not define inherits the English implementation, so the app works throughout and each untranslated string simply reads as English until someone translates it. The coverage guard was rewritten to match: it now forbids a locale carrying an English string *as though it were translated*, forbids orphan keys, and requires the six locales to stay in step with each other — while allowing the deliberate backlog.

**107 strings remain extractable.** These are the ones the tool would not touch: const contexts, static declarations, interpolation. They need hands, and the tool lists them with `--list`.

Added a coverage guard (`test/localization_coverage_test.dart`) that fails if any locale is missing a key or is quietly repeating the English string. A missing key falls back to English silently, so an incomplete translation looks fine in testing and untranslated to the person using it.

**The decision this needs.** Extracting the rest is mechanical, but a large share of the remaining strings are **medical vocabulary**, not interface copy. The onboarding wizard alone carries:

> "Adenomyosis" · "Cervical mucus" · "Basal body temperature" · "Brain fog" · "Bone health"

I have deliberately not translated those, and will not without a decision. It contradicts the rule already governing this app — clinical text goes through the reviewed pipeline with a named reviewer *because* a mistranslated symptom or condition name is a safety problem rather than a cosmetic one. Inventing six translations of "adenomyosis" is exactly the thing that rule exists to prevent, and neither of us could spot a wrong one by reading it.

So the remaining work splits in two:

- **Interface copy** — buttons, headings, empty states, navigation. I can extract and translate this, at the same quality as what is already shipped.
- **Medical vocabulary** — condition names, symptom names, tracking methods. Needs either a clinician or a medical translator, and probably belongs in the reviewed content pipeline alongside the articles rather than in the ARB files.

Tell me how you want the second half handled and I will keep going on the first regardless.

### A2 — Add more prominent languages (#2) · UNCLEAR

**Currently shipped (7):** English, Hindi, Bengali, Tamil, Telugu, Marathi, Kannada.

**Not covered, by speaker count:** Gujarati, Punjabi, Malayalam, Odia, Urdu, Assamese.

**Needs your call:** which to add. I would suggest Gujarati, Punjabi and Malayalam first.

Note this multiplies with A1 — each new language is another full pass over ~300 strings. Worth finishing A1 first and adding languages once, rather than the reverse.

---

## B. Home page and first-run experience

### B1 — Onboarding answers don't shape the home page (#5, #6) · PARTLY DONE

**What was actually wrong: more than one onboarding flow has written this data, and they disagree on both key names and value shapes. The home page only understood one dialect.**

Measured against the live database (81 women with onboarding answers):

| The app read | Users with it | What the other flow wrote instead | Users with that |
|---|---|---|---|
| `goals` (a list) | 21 | `selected_goals` — **a comma-separated string** | 32 |
| — | — | `goal_*` — **the strings `"yes"`/`"no"`, not booleans** | 32 |

Two traps here, and I fell into both on the first attempt:

- `selected_goals` is stored as `"get_pregnant,track_period,nutrition"` — one line, not a list. Read as a single answer it becomes one nonsense goal containing every choice.
- `goal_track_period` holds `"yes"`, not `true`. Of 213 such values in the live data, 53 are `"yes"` and a check for `true` matches **none** of them.

My first implementation handled lists and booleans, measured **zero** users improved, and was only worth keeping once I looked at the actual stored values. Reads now go through `OnboardingAnswers`, which accepts every shape the data actually has.

**Measured effect on the live database:**

```
had usable goals BEFORE : 16 of 81
have usable goals AFTER : 42 of 81
users whose goals were being ignored : 26
total goals recovered   : 53
```

Symptoms and conditions get the same treatment (`period_pms_symptoms`, `checkin_symptoms`, `medical_conditions`, `diagnosed_conditions`).

**Still open under this item.** Recovering the answers is the prerequisite, not the whole job — the home page now *has* goals for 42 women instead of 16, but what it does with them is a separate piece of work. The cycle half of #6 reads correctly already: `last_period` is present for 54 of 81 and the read path accepts six spellings of it.

I did **not** migrate the stored data. Rows carry both shapes and a migration would have to guess intent; a read that tolerates history costs nothing and cannot corrupt anything.

### B2 — Period chart doesn't update dynamically (#7) · DONE

There are two ways to log a period and they behaved differently.

Logging **from the dashboard** works: `_logPeriodRange` calls `setState` and updates `PersonalContext`, so the chart redraws.

Logging **from Dr. Docsy** did not. The reason is subtler than a missing `setState`: the dashboard keeps its own copy of the cycle fetched from the server, and updating `PersonalContext` does not invalidate it. The only thing that reloads it is `refreshNotifier`.

Home *did* bump that notifier — but only in the `.then()` after Dr. Docsy is **popped as a route from the home floating button**. Dr. Docsy is also a bottom-navigation tab, and switching tabs pops nothing. So a period logged from the tab left the chart on the previous cycle until something unrelated happened to reload it.

Fixed by making the write itself invalidate the dashboard (`markDashboardDirty()`) rather than depending on how the user happened to navigate.

**Second bug in the same block.** The write was wrapped in `catch (_) {}` and the success message shown regardless — so a failed save still told her "Period start date recorded." It now reports the failure instead. Same shape as the "Failed to publish post" problem: a silent catch turning an error into a false confirmation.

### B3 — First card is too wordy (#3) · DONE

Every life stage opened with its own hero card carrying the cycle day, the phase name and a line of guidance about energy. **All of which the very next card already showed** — I checked `_buildLivingTodayCycle()` before removing anything, and it renders phase, cycle day, energy and mood. So the first thing anyone saw was a dense block duplicating the block beneath it.

Replaced by a single `GreetingCard`: a time-aware greeting and one short line. **28 call sites** across **10 stage-specific hero builders**, all now one widget — there is nothing stage-specific about saying hello, and ten copies is how those heroes drifted apart in tone and layout to begin with.

**Localised properly.** Four new keys across all seven locales, so the greeting is translated rather than English-with-a-translated-screen-reader-label (the bug found in the bottom navigation). The greeting follows the local hour: a health app gets opened at odd times, and "Good morning" at 11pm reads as a machine talking.

**The six non-English greetings need a native check.** They are the standard everyday forms, not literal renderings — same caveat as the brand name.

Together with C1 and C2, the dashboard file went from **13,190 to 11,893 lines**.

### B4 — Nothing is optimised for first-time users (#18, #37) · STARTED

A brand-new account has no logs, so every data-driven card on the home page renders its empty state. The app already has a good component for this — `ApiStateCard`, which distinguishes *empty*, *not enough data yet* and *restricted*, and takes an **`emptyActionLabel` + `onEmptyAction`** so the card can offer a way forward.

**Of nine usages across the app, zero supplied an action.** So the first thing a new user saw was a column of cards reporting absence, with no next step from any of them:

> "Dr. Docsy has not noticed anything in your logs yet."
> "Nothing stands out in your logs yet."
> "Nothing logged yet. What you record will appear here."

Wired the three home cards that a check-in would fill (both patterns cards and the timeline) to offer **"Log your first check-in"**, which scrolls to the check-in card via the `_scrollToCheckIn()` helper that already existed. Localised across all seven locales.

The action also shows for *not enough data yet*, not only *empty* — she has logged something, just not enough for the app to say anything honest, and that state leaves her waiting too.

**Also wired: the partner's home.** "Nothing shared yet." was a dead end — he cannot share anything himself, and nothing told him he could ask. It now offers **"Ask what she'd like to share"**, which opens the privacy screen where the per-signal request buttons live. He still cannot grant himself anything: every request goes to her to approve or refuse, which is the point.

**Three cards were deliberately left without an action**, because inventing one would be worse than none: *partner learn* ("No reviewed articles here yet") is the content gate from 0.1 and no user action clears it; *partner sharing* ("This connection is no longer active") has nothing to offer; and the care plan's "Nothing to suggest right now. That is a good sign." is reassurance, not a dead end — a call to action there would turn good news into a chore. *Conditions* is waiting on an add-condition entry point that does not exist yet.

**Not finished.** Screens that do not use `ApiStateCard` at all — journal, M Studio, community — have not been looked at yet. The two cards I left alone were deliberate: *conditions* needs an add-condition entry point that does not exist yet, and the care plan's empty message ("Nothing to suggest right now. That is a good sign.") is genuinely reassuring rather than a dead end.

### B5 — Welcome and greeting pages (#36) · UNCLEAR

Reads as "build welcome/greeting screens", but may mean reworking existing ones. Which screens, and what should they say?

### B6 — No hardcoded data anywhere (#38) · DONE

The earlier sweep had removed most of it — fabricated cycle statistics, invented community posts, a made-up efficacy claim, a fabricated journal dashboard. A fresh audit found four more, three of them live.

**1. Progress the user never made.** `_completedLessons` was seeded with `{"Understanding My Body"}`, and the server load calls `addAll` rather than replacing — so the seed never cleared. **Every new account was told it had already finished a lesson it had never opened.** Now starts empty.

**2. Sharing that never happened.** `_sharedLessons` was seeded the same way, and is never persisted anywhere — so it claimed a lesson had been shared with a parent who never received it. Now starts empty.

**3. A reading time derived from list position.** `"${3 + (index * 2)} min read"` — item one claimed three minutes, item two five, and so on. There is no duration behind those lessons; they are title strings. Removed rather than replaced with a different invented number.

**4. A gallery of other people's bouquets that was a hardcoded list.** The tab read "Community" and the copy said *"A peek at some of the bouquets people have made!"* over `_communityBouquets`, a static list commented "Pre-made". There is no public bouquet endpoint — only `listMyBouquets`, behind auth — and the entire database holds two bouquets. Relabelled to **"Ideas"** with *"Ready-made bouquets to start from."*

I did not build a real community gallery: bouquets are private gifts between partners, and making them browsable is a product and privacy decision, not a bug fix.

**Two more were found but do not ship.** `lib/presentation/explore.dart` carries `'6 min read • Verified by Dr. Aris'` — a fabricated clinical endorsement by an invented person — and `parent_screen.dart` has a hardcoded article list. Neither file is imported anywhere, so neither reaches a user. They are in the dead `lib/presentation/` tree noted elsewhere. Worth deleting when that tree is cleaned up; the endorsement is the kind of string that must never become reachable.

Guarded by `test/no_fabricated_data_test.dart`: progress state cannot start pre-populated, nothing displayed may be derived from a list index, and the bouquet gallery cannot describe itself as other users' work.

---

## C. Community and Discover

### C1 — Remove Discover (#11) · DONE

Removed in two passes, because the first one missed the part that mattered.

**Pass 1 — the unused files.** Deleted `discover_service.dart`, `discover_section_widget.dart` and `test/discover_test.dart`. Nothing imported them, so this was dead-code removal with no user-visible effect.

**Pass 2 — the section people actually saw.** I initially reported Discover as "already orphaned dead code". **That was wrong.** A `_buildLivingDiscover()` method inside the 13,000-line `everyday_wellness_dashboard.dart` renders a section headed `"DISCOVER"` on the home page, and I had missed it — the two Discover implementations share a name but nothing else. Removed: 2 builder methods, 7 call sites, and the topic-picker state behind them.

`"Learn & Discover"` — the heading of the **partner learn page** — is a separate feature and is untouched.

### C2 — Move community off the home page (#10, #12) · DONE

Home carried **six** community builders across the stage dashboards (living, hormonal, postpartum, perimenopause, menopause, wellness) at **19 call sites**. All removed, along with the tab state and saved-article sets that only they used.

Removing the two features together took **~950 lines** out of that dashboard file.

The community page itself is untouched and still on nav tab 1 — the request was to move community off home, not to remove it from the app.

**Guarded by tests** (`test/home_sections_removed_test.dart`): no Discover or community builders in the dashboard, no `"DISCOVER"` heading, and the community screen still routed from the shell. Asserted against the source, because a widget test here would need a signed-in user, a life stage and a live backend to build a stage dashboard at all.

### G3b — Logout confirmation (#24) · DONE

The **partner** profile screen already asked before signing out. The main account screen did not — it signed out on a single tap, from a button sitting directly under "clear symptom logs".

Rather than write a second dialog, both now call one shared `confirmSignOut()` (`lib/shared/confirm_sign_out.dart`). That also closes a small instance of #33: the two sides had drifted, and a shared helper stops them drifting again.

### C3 — Community interactions are slow (#13) · DONE

Named: commenting, posting, upvotes and downvotes.

**Measured, and partly fixed already:** the feed was doing **116 database round trips to render 20 posts (2374ms)** — a query per post for votes and authors. Batched, that is now **5 calls (83ms)**. Missing indexes on `post_votes` were added.

**Votes, measured and fixed.** A single upvote cost **643ms across 16 database calls**. It fetched the post to check it existed, fetched the existing vote, wrote the vote, incremented the score, then fetched the same post *again* to return it — five sequential round trips, two of them for the same document.

The two lookups do not depend on each other, and the increment can return the updated document itself:

| | Before | After |
|---|---|---|
| Upvote | 643ms | **190ms** |
| Clear a vote | 801ms | **134ms** |

The existence check was kept rather than optimised away — without it, voting on a deleted post leaves an orphan row in `post_votes` that nothing cleans up. Verified after the change: a deleted post still returns null and writes nothing.

**Comments were already fine** — listing them is a single query at 43ms. No change made, which is worth stating rather than "optimising" something that was not slow.

Also relevant: posting was failing outright with "Failed to publish post" due to a rate limit, now raised — see H2.

---

## D. Sia / Dr. Docsy

### D1 — Rename Sia to Dr. Docsy (#15) · DECIDED — IN PROGRESS

**Measured scope.** 508 occurrences of "Sia" in Dart, which split into two very different groups:

| Kind | Count | Changing? |
|---|---|---|
| Inside quotes — what users read | **195** | **Yes** |
| Code identifiers — class, variable and file names | **310** | **No** |

Plus **three backend system prompts** that open "You are Sia…" (`aiChatService.js` ×2, `partnerDecoderService.js`), and the values in the ARB translation files.

**Why identifiers are staying.** `BlushySiaScreen`, `sia_screen.dart` and the rest are internal names no user ever sees. Renaming 310 of them is a large mechanical refactor across imports and file paths, carrying real regression risk for zero user-visible benefit. The ARB **keys** (`siaAsk`, `siaThinking`) stay for the same reason; their **values** change. If you want the internal naming brought in line later, that is a clean standalone task — best done on its own, not folded into a user-facing change.

**Included in the rename.** The legal text in the privacy policy and account-deletion copy names Sia explicitly ("Sia AI Companion & Automated Response Notice", "…Sia chat history…"). Those get the new name too, since they describe what the user is actually using.

**Persona: unchanged, deliberately.** See the decisions log. The character stays a warm companion that never names medications and defers to a doctor; only the name changes.

**Existing chat history** keeps whatever was stored at the time — I am not rewriting past messages. Nothing in the database stores the assistant name as data, so this is only about what appears going forward.

### D2 — Remove cards from the Dr. Docsy page (#14) · DONE

Removed all three named cards: **"Pattern You've Been Building"**, **"Journal Prompt"** and **"Voice Reflection"**, plus everything only they used — two description builders, the analytics modal one of them opened, and its meter-row helper. About **290 lines**; `sia_screen.dart` is down to 2,881.

**"Community Discussion" was left in place.** It sits in the same list and is the same kind of card, but it is not one of the three named, and #12 asks for community off *home* — this is the Dr. Docsy page. Say if you want it gone too.

**On the apparent conflict with #8** ("voice reflection isn't working"): I read the two together as *keep the feature, remove this entry point*, and verified rather than assumed — voice reflection is still reachable from four places on the dashboard, so removing the card did not remove the feature.

### D3 — Remove AI reflections (#20) · UNCLEAR

Which feature exactly? There are several reflection surfaces (journal reflections, Sia reflections, the daily reflection card). Naming the screen would save a wrong deletion.

---

## E. M Studio / journal

### E1 — Complete rework of the journal (#16) · DONE except the artwork

The request names three things. Two are buildable now; one genuinely needs an illustrator.

**1. "Icons and all aren't same" — DONE.**

Measured across the journal and M Studio: **84 distinct icons use the `_rounded` family, 13 do not.**

```
Icons.auto_awesome        Icons.check       Icons.close      Icons.copy
Icons.mic                 Icons.pause       Icons.play_arrow
Icons.broken_image_outlined   Icons.color_lens_outlined   Icons.edit_outlined
Icons.mark_email_unread_outlined   Icons.palette_outlined   Icons.photo_outlined
```

Thirteen of ninety-seven, so the convention was clear and the exceptions were accidents. **All now standardised — the journal and M Studio are 100% `_rounded`**, and a test fails if a stray one appears.

**Not swept app-wide, deliberately.** Across all of `lib/` it is 167 rounded to 119 not — that is a mixed codebase, not a convention with exceptions, and `_outlined` is frequently a deliberate inactive state paired with a filled active one. Converting those would change design decisions rather than fix accidents. Worth doing as a design pass, not a find-and-replace.

**2. "Templates should be worked" — DONE.**

**Templates did nothing.** Selecting "Gratitude" created an entry whose title and `templateName` were "Gratitude", carrying the same blank "Tap to start writing your reflection..." as every other one. The stage config already varied the list by life stage, so the app knew which template suited her — and then discarded the answer.

A template now places its prompts on the page, spaced so there is room to write under each. Choosing "Cycle Reflection" opens a page that already asks.

**Matched on keywords rather than exact names.** The config carries variants — "Gratitude", "Gratitude Log", "Gratitude Journal" — and new ones get added over time. Exact matching would drop the variants to blank silently, which is how the feature came to do nothing in the first place. A test walks every name in `stage_config.dart` and fails if any falls through to the generic prompt; all **25** currently resolve.

**These are reflective prompts, not health guidance.** Nothing in them tells anyone what to do about a symptom. Clinical content is served from the reviewed pipeline with a named reviewer, and a journal prompt is not a way to route advice around that.

**The pregnancy set is deliberately open** — "How are you today?", not "How is the bump?" A prompt assuming a due date or a growing bump lands badly on someone whose pregnancy has ended, and the app already carries a `pregnancyContentBlocked` flag because someone thought about that. A test asserts those assumptions stay out.

Draft prompts are in `lib/features/journal/journal_templates.dart` and are yours to rewrite — the wording is a voice decision, and the structure holds whatever you put in it.

**3. "Stickers aren't realistic, they look emoji" — the seam is built; the art is still yours.**

The stickers are Material `IconData` — `Icons.local_florist_rounded` for Flower, `Icons.flutter_dash_rounded` for Butterfly. They are flat single-colour glyphs by design. **No amount of code makes a Material icon look painted**; that needs an illustrator or a licensed sticker set.

Both buildable parts are done:

- **The delivery mechanism.** A sticker may now carry `'asset': 'assets/stickers/flower.png'`. The renderer prefers the image, falls back to the glyph if the file is missing, and the asset travels with the saved entry so a page keeps the sticker it was made with even if the set changes later. **Adding artwork is now a data change, not a rewrite.**
- **The naming.** Emoji prefixes removed. Eight of ten had one and two did not, and since the complaint is that they *read* as emoji, emoji in the names worked against it.

**The rename is backwards compatible, which was worth checking rather than assuming.** Saved stickers are resolved by name on load, and old entries hold `'🦋 Butterfly'`. `resolveIcon` matches on the word rather than the whole string, so those still render — and a test now pins that, because switching it to exact matching would silently blank every sticker saved before the rename.

**What is left:** the artwork itself. Send an asset set, or say the word and I will specify format and sizes for a licensed one. Everything around it is ready.

### E2 — Import photos from the gallery (#17) · DONE

**The feature was declared, measured, and never implemented.** `ScrapbookItem` has carried a `'photo'` type from the start, and the journal counts photos for its statistics — but nothing anywhere created one. The "Photo Frames" tray offered *"Add Polaroid Frame"*, and tapping it inserted a **text item reading `📸 [Polaroid Memory]`**: a placeholder standing in for a picture. So the photo count was always zero while the page looked like it held photos. That belongs to #38 as much as to this item.

Now it picks a real image, reusing the `pickFileFromDevice` helper that already handles web and native for chat attachments.

**Photos are downscaled to 1280px before being embedded.** They travel inside the entry as a data URI, the same way voice notes do, so they persist through the existing JSON without new infrastructure — but a phone photo is several megabytes and base64 adds a third again. Embedding originals would bloat every entry and its sync. Smaller images are left alone rather than upscaled into a bigger file for no gain.

Rendered with the polaroid border the tray used to only pretend to add, with a fallback tile if the data cannot be decoded.

**Not done here:** an existing entry's photos are counted correctly by the statistics screen, but there is no way yet to reorder or crop a photo once placed — it behaves like any other scrapbook item.

---

## F. Partner features

### F1 — Bouquet, not boutique (#28) · DECIDED — IN PROGRESS

**Measured:** 297 occurrences of "bouquet" and **20** of "boutique". The code mostly has it right already; 20 places are wrong.

They break into three kinds, and only the first is purely cosmetic:

- **Displayed text** (`'Boutique'`, `'About Boutique'`, `'Open Boutique & Garden'`, `'Boutique (B&W)'`) — straight rename.
- **Tab identifiers** — `case 'Boutique':` appears at four sites, matched against a tab label string. These must all change together or the partner screen's tab routing silently breaks. Handled as one edit, not four.
- **One backend deep link**, `blushy://partner/boutique` in `bouquetController.js`. **Left alone.** Any invitation or notification already sent carries the old path; changing it would dead-end those links. Renaming it needs the app to accept both paths for a transition period — a separate, deliberate change.

The exported image filename `my_boutique.png` is also renamed, since users see it when they share.

### F2 — Sharing to a partner is unavailable (#31) · DONE

Sending was never the problem. **Receiving was.**

The backend has carried both halves for a while: `sendMyBouquet` writes a row for the recipient, and `GET /bouquets?received=true` lists it. The client fetched that list on every account sync and exposed it as `receivedBouquets`. **No screen ever read the property.** So a bouquet arrived, was stored, was loaded into memory, and was never shown to the person it was sent to — which is what "share it to the partner isn't available" looks like from their side.

Added a **"💌 For Me"** tab to the garden that renders it.

**And the tab row itself was hidden from exactly the people who needed it.** It only appeared `if (hasSaved)` — that is, once *you* had made a bouquet. Someone who had never made one but had been sent one saw no tabs at all, so even a rendered list would have been unreachable. Now `if (hasSaved || hasReceived)`.

**Two more invented figures found here** (they belong to #38 as well):

- The "Most liked" sort ranked by a number parsed out of the id — `comm_1` scored 21, `comm_2` scored 35. It now sorts by what she actually liked, which is real.
- The same computation was **printed on every card as a like count**, so the gallery showed other people's likes for bouquets nobody had ever seen. I missed this one on the first pass; the test I had just written caught it. The card now shows the heart alone.

Guarded by `test/bouquet_sharing_test.dart`.

### F3 — Messaging is slow (#25) · IMPROVED, with an honest ceiling

Indexes on `partner_chat_messages` were added earlier — it had none while being the fastest-growing collection, so every read scanned it. **Reading a conversation is now one query at 46ms.**

Sending was the slow half. `sendMessageToConnection` wrapped five operations in a transaction. Measured:

| | Time |
|---|---|
| Send, in a transaction | 209–1076ms |
| A plain insert, for comparison | 46–129ms |
| **Send, after the change** | **182–1090ms** |

**Being straight about this: the transaction was not the bottleneck.** Removing it bought about 13% on the best case and left the variance untouched. The cost is five sequential round trips to a free shared Atlas tier, and that tier's jitter is what "message is slow" actually feels like. Nothing in the application code fixes that.

**The change was still worth making, for correctness rather than speed.** The notification sat inside the transaction with the message — so a failed notification **rolled back a message the sender had already been told was sent.** That is backwards: the message is the thing that must survive, and the badge can be rebuilt from it. The notification is now written after the message, best-effort, and its two reads overlap instead of running one after the other.

### F3b — Partner disconnected suddenly (#26) · DONE

**The realtime socket had no keepalive.** No ping, no pong, no liveness check anywhere in the hub.

Proxies and load balancers — Render's included — close connections idle for around a minute, and a partner chat is idle most of the time. So the socket was dropped from under a conversation that was still open. That is the disconnect.

Added a 25-second ping with pong tracking, terminating sockets that miss one, stopped on shutdown alongside the schedulers.

**It fixes a second problem too.** A socket whose peer has vanished stays readable indefinitely, so without a liveness check `isUserOnline` reported people as online for ever — and messages were published to a connection nobody was listening to. That also fed a wrong "is she online" state into the partner surface.

Guarded by `tests/realtimeHeartbeat.test.js`, including that the interval stays under the idle timeout it exists to stay ahead of.

### F4 — Time capsules by email (#21) · BLOCKED — incomplete requirement

Understood so far: capsules should be delivered by email, and the "open on" input should be a calendar date picker rather than whatever it is now. The sentence ends "and it" — the rest is missing.

Email delivery itself is ready: Brevo is wired and verified working, and a capsule delivery scheduler already exists.

### F5 — Icons and UI/UX (#29, #30) · UNCLEAR

"Icons have to be changed" and "Ui ux of it" — for which screen, and changed to what? Needs either a reference design or a conversation.

---

## G. Settings and account

### G1 — Switch and auto-switch user type (#32) · MANUAL FIXED; automatic deliberately not built

**The manual toggle already existed** in settings — but it was not doing what it appeared to.

The backend carries a real state machine for this, and it is carefully built. Sensitive moves are marked `requiresConfirmation` — into pregnancy, into menopause, pregnancy to postpartum — with a comment saying the spec requires they *never be inferred silently*. There is a separate guard that refuses to re-enter pregnancy after a loss without explicit confirmation.

**The settings switcher bypassed all of it.** It consulted a client-side conflict engine, wrote the new stage into `user_profile.json`, and **never called `/life-stage/transition`** — that endpoint was reached only from onboarding. Three consequences:

- The transition rules did not apply, including the ones that exist to avoid inferring a pregnancy or a birth.
- The pregnancy-loss guard did not apply.
- **The server never learned.** It carried on serving content, safety rules and dashboards for the stage she had just left, while the screen showed the new one — and the change lived on a single device.

Both branches of the selector now go through the server first, ask for confirmation when the server says the move needs it, repeat the call with that confirmation, and only write local state once the account has actually moved.

**On the "automatic change of user type" half — I have not built it, and I would push back on building it as described.**

The app's own design says these transitions must not be inferred, and the reasoning holds. A due date passing does not mean a baby arrived; moving someone to postpartum automatically after a stillbirth or a loss would be a serious harm, and the code already carries a `pregnancyContentBlocked` flag written by someone who thought about exactly that.

What is safe, and what I would build instead: **prompt at the right moment.** When the due date passes, ask. When twelve months pass without a period, ask. The confirmation contract for this already exists end to end now — the question is only where to raise the prompts, which is a product decision about tone and timing rather than an engineering one.

Say which moments you want prompts at and I will add them.

### G2 — Both partners' settings should match (#33) · R&D DONE; two defects fixed

The document asked for R&D on this, so here is the comparison rather than a guess. **Her settings carry about 21 controls; the partner's carry 4.**

**Most of that gap is correct and should stay.** Cycle length, period length, last period date, cycle pattern, due date, life stage, symptom focus, diagnoses, medications, health goals — these are *her* health data. A partner has none of it, and giving them the same screen would be nonsense at best.

**Genuinely missing from the partner, and not role-specific:**

| Control | Why it belongs to both |
|---|---|
| **Preferred name** | The partner has no way to set their own name anywhere. Dr. Docsy addresses them by it and she sees it on her side. |
| **Reset AI recommendations** | The partner uses Dr. Docsy — `partner_sia.dart` — so the controls over what it remembers apply to them too. |
| **Logout confirmation** | Already fixed; see G3b. |

**Two defects found while comparing, both in her "Manage My Data" section.**

**"Reset AI Recommendations" did nothing.** Its entire body was a snackbar reading "Personalized recommendations reset." No API call, no state change, nothing. It now clears the cached observations, patterns and recommendations, which is a real action, and says what it did.

**"Clear Symptom History" and "Restart Cycle Learning" only change local state.** There is no endpoint anywhere that deletes stored logs, and `updateWellbeingState` writes to local storage — so the account keeps its copy and the next sync brings it back, after the user has been told it was cleared. The wording now describes what actually happens: cleared from this view, saved logs unchanged.

This is the section where someone goes to exercise control over their own data, which makes it the worst place in the app to overstate what happened.

**What this needs from you.** There is no server-side deletion of health logs at all. That is a data-rights gap rather than a copy problem, and building it means deciding what "delete my symptom history" should mean — the logs, the derived patterns, the AI's memory of them, the partner's cached view. Say what it should cover and I will build it; a test will fail the moment a delete endpoint appears, as a reminder to rewire these controls to it.

### G4 — No back option (#22) · UNCLEAR

Which screen? Almost certainly a specific one rather than the whole app.

---

## H. Performance

### H1 — Generate and copy link is slow (#23) · DONE

Measured against the live backend before touching anything: **2.3–3.6 seconds** warm. Then measured a baseline to find out where it went:

| | Time |
|---|---|
| `/health` — no database, no auth | 0.4–0.95s |
| A simple authenticated read | 1.22s |
| **Generate invite link** | **2.3–3.6s** |

So roughly half a second is network and platform floor, and the rest is the handler doing four sequential Atlas round trips. Two of those were waste.

**The rate limiter had no index and never deleted anything.** `checkDistributedRateLimit` counts recent events for a key — and `partner_rate_limit_events` carried only its `_id` index, so every invite scanned the whole collection. Worse, **nothing ever removed the rows**: events from 21 August were still being scanned to answer a question about the last ten minutes. Added a `{key, created_at}` index and a **TTL that expires rows after an hour** (the longest window in use is 600s). Verified the query now plans an `IXSCAN` with no `COLLSCAN`.

**Every authenticated request read the user twice.** Both auth middlewares load the record and check the token version against it. Every controller then called its own `requireAuthUser` helper, which loaded the same record again — and `getUserById` is itself two queries, since a user may be in either collection. The middlewares now mark the request and the helpers reuse it.

`partnerController`'s helper is the exception and was left alone: it returns the whole record rather than an id and role, so its lookup is doing real work. The reason is recorded above the function.

**A correctness bug fell out of this.** `optionalAuth` fetched `dbUser`, then set `req.user = decoded` — discarding the record it had just read and leaving the role to come from the token, where it stays stale after a role change. The same shape of bug was fixed in `requireAuth` earlier in this session. It now uses the record's role.

Guarded by `tests/authLookupReuse.test.js`: both middlewares must mark the request, `optionalAuth` must use the database role, and no controller helper may repeat the lookup.

**What this does not fix.** Roughly 0.5s of every request is network and platform floor — the free Render instance and the distance to it. Fewer round trips helps proportionally, but the floor stays until the hosting does.

### H2 — General slowness · Partly addressed

Already measured and fixed this session, for context:

| Path | Before | After |
|---|---|---|
| Community feed (20 posts) | 116 db calls / 2374ms | 5 calls / 83ms |
| Upvote a post | 643ms | 190ms |
| Sia reply | ~4900ms | ~1600ms |
| Single user lookup | 84ms | 43ms |
| Dashboard sync | 7 sequential requests | 3 rounds |

Also fixed: posting failed with "Failed to publish post" because the production IP rate limit was 60 requests per 5 minutes — one dashboard load costs 7. Raised to 600.

---

## Open questions, collected

These block or reshape work. Answering them is the fastest way to unblock the list.

1. **Reviewer name and credentials** for the 159 clinical items. Unblocks recovery sessions and every article screen.
2. ~~Discover: fill it or delete it?~~ **Answered 2026-08-31: delete.** Follow-up: if you still see a Discover section after the deletion, which screen is it? (See C1 — the files were already dead code.)
3. **Which languages** to add beyond the current seven.
4. **Dr. Docsy: persona too, or name only?** Proceeding with **name only** unless told otherwise.
5. **Time capsules (#21):** the requirement sentence is cut off.
6. **"Activity," (#27):** no request attached.
7. **Which screen** for: back button (#22), icons/UI-UX (#29, #30), AI reflections to remove (#20), welcome/greeting pages (#36).
8. **Have you tested the 01:37 APK?** Four items may already be fixed (0.2).

---

## Suggested order

Grouped by what unblocks the most for the least effort.

**First — cheap and unblocking**
- Approve the content (one command, once you give a name) → clears #9, #19
- Verify the four DONE? items on the current APK → may clear #4, #8
- Logout confirmation (#24), bouquet rename (#28)

**Second — high impact, well understood**
- Onboarding data actually driving the home page (#5, #6)
- First-run empty states across primary screens (#18, #37)
- Move community off home, remove Discover (#10, #11, #12)
- Period chart live updates (#7)

**Third — large but mechanical**
- Finish localisation (#1), then add languages (#2)
- Dr. Docsy rename (#15) once the persona question is settled

**Fourth — needs design or research input**
- Journal rework: icons, stickers, templates (#16)
- Life-stage switching (#32), partner settings parity (#33)
- Anything in F5

**Ongoing**
- Hardcoded-data audit (#38)
- Performance, as each slow path is reported and measured

---

## Onboarding: the branch questions that were asked and never read

Two separate faults, found while adding the stage-specific questions.

**The gating read two keys out of all of them.** `_isMetricSelected` decides
which of the home page's 44 card gates switch on. It assembled its list of the
user's answers from `symptoms` and `goals` only. Every branch question stored
its answer under its own key — `ttc_tracking_method`, `postpartum_feeding` —
and those keys were written, synced, and never consulted. So TTC asked whether
she uses ovulation strips, basal body temperature or cervical mucus, and the
cards keyed to `opk`, `bbt` and `thermometer` could not switch on however she
answered. The gating now reads every answer, taken generically rather than key
by key, so a question added later counts without anyone remembering this list
exists. **41 → 44 of 44 card gates reachable.**

**Only one branch ever asked about symptoms.** `_buildReproductiveStep8` was
added for reproductive years. TTC and postpartum had no equivalent: TTC asked
duration, tracking method and treatment; postpartum asked birth date, feeding
and goals. Neither asked what her body was doing, so anyone arriving through
them finished onboarding with an empty symptom list and a home page with the
symptom-keyed cards switched off — not because she tracks nothing, because she
was never asked. Postpartum in particular could not hear about recovery at all:
no question covered lochia, stitches, an incision or perineal healing.

Added `_buildTtcStep7` and `_buildPostpartumStep7`, both required like the
symptom steps in the other branches. Clinical words are paired with plain ones
("Bleeding (lochia)") because she may know either. These ask what she notices;
they do not tell her what it means, which stays with the reviewed content.

| stage | card gates reachable before | after |
|---|---|---|
| trying to conceive | 3 of 44 | 22 of 44 |
| postpartum | 20 of 44 | 30 of 44 |

**The guard was only watching one step.** The test that caught "Breast
tenderness" — an option that unlocked no card — checked
`_buildReproductiveStep8` by name and would have said nothing about the same
mistake in the branches where new options actually get added. It now runs over
all three symptom steps. Verified by injecting an orphan option into the TTC
step and confirming the failure names it.

Also fixed while here: the step counter read `"0${index + 1} / 0$total"` with a
literal zero. Harmless at eight steps, `"010"` at ten — and adding steps to a
branch is exactly the routine change that would reach it. It pads now.

### Correction: the generic fix above was too generic

Reading *every* answer was wrong, and I caught it only by tracing the data path
instead of trusting it. The stored answers map is not the questionnaire: it also
carries her name, her weight, her date of birth and today's check-in sliders,
because `saveOnboardingAnswers` sends the profile fields alongside the answers
and the home page merges the whole remote response into the same map.

Feeding all of that into the matcher was unsafe, because the matcher accepted a
substring in either direction. `daily_energy: "Low"` would have switched on the
period-flow card — `"flow"` contains `"low"` — for anyone reporting low energy,
on any life stage. Her name would have done the same: "Forrest" contains "rest".

Both halves now live in `lib/core/metric_gating.dart`, out of the 13,000-line
widget and under test:

* `isNonQuestionAnswerKey` excludes profile fields, `daily_*` check-in state and
  anything ending `_date`/`_at`. The daily ones especially — those are what she
  logged this morning, not what she wants tracked, and letting them gate the
  layout would rearrange her home page day to day.
* `metricMatches` keeps substring matching in the direction that needs it
  ("Breastfeeding" → `feeding`, "Walking" → `walk`) and requires a **word
  boundary** in the reverse direction, so "Acne" still matches `hormonal acne`
  while "Low" no longer matches `flow`.

Nine tests in `test/metric_gating_test.dart`. Their keyword lists are copied
verbatim from the dashboard gates they guard: an earlier draft invented
`['ovulation test', 'opk']` and failed, because the real gate carries `strip`
too — the test was wrong, not the code.

**Known gap.** `stage_questionnaire_dialog.dart`, the path for changing your
answers later, mirrors the old branch structure and does not ask about symptoms
for TTC, postpartum or reproductive years. New signups get the questions; an
existing user re-answering through settings does not.

### The change-your-answers-later dialog now asks the same things

`stage_questionnaire_dialog.dart` is how an existing user changes her answers,
and it mirrored the old branch structure: reproductive years, TTC and
postpartum collected goals and a treatment choice and never asked about
symptoms. So the onboarding fix would have reached new signups only — anyone
already using the app had no way to supply the answers the home page needs.

A symptoms step was added to all three, written in the dialog's more clinical
register ("Ovulation test strips (LH)" rather than "Ovulation strips") and
required like the equivalent steps in the branches that already had one. All 35
options were checked against the live gate keywords before being written: zero
orphans. `_selectedSymptoms` already saved to `finalAnswers['symptoms']`, so no
plumbing was needed.

The title reuses the existing `sqWhichSymptomsAffectYou` key rather than adding
a new string, so these arrive translated in all seven locales instead of
falling back to English.

**Pregnancy still does not ask.** Neither does the wizard, so the two surfaces
agree. The gates it would feed — `braxton hicks`, `fetal movement`, `kicks`,
`contractions` — are the ones where a wrong question is a safety problem rather
than an awkward one, so it is left for the reviewed pipeline.

### Found while extending the guard: 13 symptom options no card responds to

Widening the coverage test to the dialog immediately failed on options nobody
had added in this pass — "Hair thinning / Loss", "Excess facial or body hair",
"Weight fluctuations" in the PCOS branch, and weight, vaginal dryness, bone
density and cardiovascular options across perimenopause and menopause.

These are the same defect as "Breast tenderness": asked, stored, and unable to
change anything on the home page. They are **not** deleted, because unlike that
one they are real symptoms of the conditions the branch exists to serve — the
fix is a card that responds to them, which needs design and reviewed content.
They are recorded as a named exception in the test, so a *new* orphan still
fails while the existing debt stays visible rather than being silently allowed.

## Cards for the 13 unbacked symptoms — and the reason none of them would have worked

Six cards were added, covering the thirteen option strings across both
surfaces: **hair thinning**, **facial & body hair**, **weight change** (PCOS);
**weight & metabolism**, **vaginal dryness** (perimenopause); **vaginal
dryness**, **bone & joint comfort**, **heart & circulation** (menopause).

They are trackers, not guidance. Each records a value on a neutral scale —
"None / Mild / Noticeable", or "Same / Up / Down" where a direction matters and
neither direction is better. What a change in bone comfort or circulation
*means* is exactly the sort of claim that belongs to the reviewed pipeline with
a named reviewer, and a card is not the place to smuggle it in.

The coverage test's exception list is gone: every symptom option in both the
wizard and the dialog now backs a card, and the wizard guard **discovers**
symptom steps instead of checking three by name — a named list only covers what
someone remembered to add to it, which is why the PCOS, perimenopause and
menopause steps carried orphans undetected. It now covers six steps.

### The trackers never saved anything

Adding cards to that path meant first finding out the path was broken. There is
exactly one writer, and it stored:

```dart
{ 'metric': label, 'value': opt, 'date': ... }   // under e.g. 'peri_log'
```

while every loader read `answers['peri_log']['hot_flashes']`. The two shapes had
never agreed. It could not have worked regardless, because
`saveMyOnboarding` stores a non-string answer as `JSON.stringify(value)` — so
the map came back a **String**, the `is Map` check guarding every loader was
false every time, and the value was silently dropped.

So all ~34 existing trackers — hot flashes, BBT, cervical mucus, feeding,
bleeding, joint stiffness — recorded into widget state and lost it on reload.
Six more cards on that path would have been six more of the same.

`lib/core/tracker_log.dart` now derives one flat, string-valued key per metric,
and the **writer and the reader call the same function**, so they cannot drift
apart again. `trackerLogKey('peri', 'HOT FLASHES')` is `log_peri_hot_flashes`
on both sides. Flat strings are what the endpoint can actually round-trip.

Existing stored `*_log` values are unreadable JSON strings that nothing ever
loaded, so nothing is lost.

**A tracker's own record cannot switch its card back on.** The trackers write
into the same answers map the gating reads, so `log_*` keys are excluded there —
otherwise logging "HOT FLASHES" once would have held that card open regardless
of what she asked to track. The old `*_log` keys are excluded too, since that
JSON string contains the card labels.

## Six reported issues

**1 · Check-in selections changed when switching tabs.** *(Extended — the
first fix covered one of three paths.)* Every tab change fires
`syncAllDashboardsFromBackend`, and the hydration that follows re-applied the
stored value over whatever she had just picked. The `daily_*` answers carry no
date, so the value it restored could be from a previous day. Selections she has
made this session are now recorded in `_userEditedMetrics` and are not
overwritten by a sync.

**2 · Request timeouts on Dr. Docsy insights and cycle patterns.** Two causes.
The AI routes: the server aborts its own model call at 30s and then still has to
write a response, while the client gave up at 25s — so a slow-but-successful
generation was reported as a timeout. Those routes now allow 50s.

The larger cause was infrastructure, found by measuring the live host: the first
request after an idle spell hung past 90 seconds and the next answered in 18.3s,
against about 1s warm. That is the instance cold-starting, and it blew past the
20s contract-client timeout — which is what cycle patterns uses, a rule-based
endpoint that has no business being slow. Two changes: a timed-out request is
retried once with 45s, since the failed attempt is what wakes the instance; and
`ApiWarmup` pings the API at launch so the wait is spent on the splash screen
rather than under a card. **A paid instance would remove the cold start
entirely — this makes it survivable, not absent.**

**3 · AI reflections removed from Studio**, along with the letters state, the
loader, the empty state and three imports left unused by the removal.

**4 · Bouquet.** "Send to Partner" was rendered only when an active connection
existed, so with no partner the option appeared not to exist — while
`_sendBouquetToPartner` already explains a missing connection perfectly well. It
is always shown now. A **Done** button was added: it saves once (not twice, if
she already saved) and returns. The finish step previously had no exit at all —
every action either stayed put or pushed another screen on top, so the only way
out was Back, which reads as abandoning the bouquet rather than finishing it.

**5 · July shown to someone who was not here in July.** The monthly card reports
the last *completed* calendar month, so through August it reports July, and a
newer account was shown a list of things it had "not logged" in a month it never
existed for. That is a statement about the app, not about her. A month ending
before the account was created is now `not_yet_joined`, and the card is not
rendered. Someone who *was* here and logged nothing still sees the empty-month
summary — that is a real gap, and hiding it would hide her own data.

The join-date comparison lives in `src/utils/monthWindow.js` rather than in the
service. The service opens a database connection on import, so a test that only
wanted to compare two dates held the process open for two minutes waiting on a
connection it never used — it hung the whole suite.

**6 · The app now analyses her answers when she finishes onboarding.**
`onboardingAnalysisService` turns what she answered into the focus areas the
home page is arranged around, and one sentence saying so, shown above Dr. Docsy
insights.

Two hard limits, because this runs unattended over health answers. **The model
may only choose, never invent:** its output is intersected with the focus areas
the rules already derived from her answers, so it reprioritises and cannot add a
focus she gave no basis for. **It may not give guidance:** the sentence says
what the app will show her, never what a symptom means — that is reviewed
content and not the model's to write. If the model is unavailable, malformed or
off-list, the rule-based derivation stands on its own; it is the floor, not a
degraded mode.

Triggered server-side in `saveMyOnboarding` so closing the app on the last step
cannot skip it, not awaited so onboarding never waits on a model, and only on
the save that carries a life stage — every tracker write comes through the same
endpoint and would otherwise spend a model call per tap. Its conclusions are
written back into her answers, and `analysis_*` keys are excluded from the card
gating so the analysis cannot widen its own input on the next run.

## Likes did not move until the feed was reloaded

The vote request was never the problem: the server records it and returns the
new score. But `votePost` turns *any* failure into `null` — a timeout included —
and `null` left the UI untouched, so the tap counted and showed nothing for it.
Reloading then revealed the vote that had been there all along.

The API sleeps when idle and the first request after that can take 20 seconds or
more, against a 25s receive timeout on the community client. That is how a vote
went through while the screen showed nothing.

Both the feed and the post detail now apply the vote immediately and reconcile
when the server answers. `score` is a **net** total, so switching a downvote to
an upvote moves it by two, not one — that arithmetic is covered by six tests in
`test/community_vote_test.dart`.

If the server never answers, the prediction stands rather than being reverted:
the vote was almost certainly recorded, and undoing a tap she just made is the
more confusing of the two failures.

## Keeping the API awake

Measured against the live host, three requests in a row after ~10 minutes idle:

| attempt | time to first byte |
|---|---|
| 1 | **22.9s** |
| 2 | 0.90s |
| 3 | 0.65s |

`GET /health` already exists and **touches no database** — it returns a literal
JSON object, so pinging it costs nothing in Atlas reads or storage.

Pinging it every 10 minutes (inside the 15-minute idle window) keeps the
instance up. Two caveats worth knowing before relying on it:

* Render's free plan has a monthly instance-hours allowance. Keeping one service
  awake for a 31-day month is ~744 hours, so it fits only just, and only for a
  single service. Check the figure against the current plan.
* A self-ping from inside the app cannot wake a sleeping instance — once it is
  down its timers are not running. It can only prevent sleep, never recover
  from it, so the pinger has to be external.

The supported fix is a paid instance, which does not sleep and has no hours cap.
The client-side work — the retry on timeout and `ApiWarmup` — makes the cold
start survivable rather than absent, and stays worth having either way.

## Why the check-in still reverted locally

The first fix guarded the wrong path for local running. Switching tabs makes the
shell call `syncAllDashboardsFromBackend`, which fires `refreshNotifier`, which
calls `_onSiaRefresh` and reloads the dashboard — and **three** separate paths
write the check-in fields on that reload:

1. **the remote hydration**, from `daily_*` answers carrying no date, so the
   value restored could be from a previous day — this is the one that was
   guarded;
2. **the device restore** in `_loadOnboardingData`, from `daily_checkin.json`,
   which was not guarded at all;
3. **`_loadTodayCheckins`**, whose request can have left before her tap reached
   the server, so it carries the previous value.

Locally, with no backend answering, (1) never runs — so (2) was the only thing
writing to those fields, and it won every time. That is why it kept happening
after the first fix.

There was a second half to it. The generic selector wrote a tap to the
**server only**, never to `daily_checkin.json`, so the file that path (2) reads
still held the older value and put it straight back. Five daily metrics — pain,
sleep, stress, water, exercise — now pass a `checkinKey`, which both records the
edit and updates the device copy, so the file the restore reads agrees with what
she just tapped.

All three paths are now guarded consistently. Covered by
`test/checkin_selection_test.dart`, asserted against the source since the paths
sit in a 13,000-line stateful widget behind a backend, a sync service and device
storage. Verified by deleting the device-restore guard and confirming the test
names it.

## Correction: the check-in explanations were wrong

Two explanations were given for the check-in reverting on a tab change. Both
were reasoned from reading the code, and **both are wrong**. Each was disproved
by testing it rather than by further reading.

**Wrong #1 — "the sync banner destroys the dashboard."** `isSyncing` inserts a
banner above the dashboard in an unkeyed `Column`, which looked like it would
shift the dashboard from slot 0 to slot 1 and rebuild its State, wiping every
selection. A widget test of exactly that shape shows the State is **preserved**:
Flutter's multi-child reconciliation matches trailing children bottom-up, so the
last child survives an insertion above it. The speculative fix was reverted.

**Wrong #2 — "the device file held a stale value because the selector only
wrote to the server."** Several of those call sites already write
`daily_checkin.json` in their own `onSelected`. Adding `checkinKey` was
redundant, and `test/checkin_tab_switch_test.dart` passes with that write
removed — so it is not what makes the value stick.

**What is actually established**, each verified rather than argued:

* The dashboard's State survives a tab change, so `_userEditedMetrics` is not
  being reset.
* A tap already persisted to `daily_checkin.json` before any change here.
* End to end, in `test/checkin_tab_switch_test.dart`: seed the stored answer,
  tap a different one, destroy and rebuild the whole screen — and the summary
  shows the new answer, not the old one.

So **the bug does not reproduce without a live backend.** That points at the two
paths a widget test cannot drive: `_loadTodayCheckins()`, which reads today's
events back from the server, and the profile sync that follows a tab change.
Both are now guarded against overwriting a fresh edit, but guarding is not the
same as having reproduced the fault, and it should not be described as a fix
until it has been.

The three guards and the `checkinKey` write are left in place: they are correct
in themselves and harmless. Neither is claimed to be the cause.

## The check-in bug, found

A debug trace from a real device settled it. Four paths assign these fields;
the trace printed what each one carried:

| metric | device | today's events | `daily_*` answers |
|---|---|---|---|
| mood | Happy | Happy | **Cramps** |
| energy | High | High | **Medium** |
| sleep | 6-8h | 6-8h | **<6h** |
| water | 3L | 3L | **1L** |
| flow | Heavy | Heavy | **Light** |

The device and today's events agreed with each other and with what she had
picked. Only the `daily_*` onboarding answers disagreed — and they were applied
last, unconditionally, on a sync that a tab change triggers.

That mirror is **partial**: only some selectors write it, nothing clears it, and
it carries no per-metric date, so each key sits at whatever was last written to
it, which can be days old. It is now a fallback: it fills in a metric the device
has nothing for — a fresh install, or an answer given on another device — and
otherwise defers. The rule is `lib/core/checkin_merge.dart`, tested in
`test/checkin_merge_test.dart` against the exact values above.

The session guard did not save it because the trace shows why: it reads
`edited-this-session: false` for mood, energy, sleep and water. Those had been
tapped on an *earlier* run, so nothing marked them, and the stale mirror was
free to replace them. The guard only ever protected a metric tapped since the
screen was opened.

**The flow selector was also never marked.** `TAP FLOW LEVEL = Heavy` printed
the label rather than `flow`, because it takes a localised title and the earlier
edit matched on the literal `"FLOW LEVEL"`. It passes `checkinKey: 'flow'` now,
and sends `daily_logged_at` like the others so its mirror entry is dated.

### What was wrong before this

Three earlier explanations, all reasoned from reading and all disproved by
testing:

* **the sync banner rebuilding the dashboard** — the State survives; verified
  against the real `BlushyHomeScreen` by comparing the State object across a
  sync;
* **the device file holding a stale value** — those call sites already wrote it;
* **the `daily_checkin` blob restore** — the trace confirms it arrives as a
  `String`, so that block never runs at all.

The lesson is in the trace: four paths write these fields, and the answer came
from printing what each one carried, not from reading them.

## Logging a period start before today reported Day 1

Reproduced by calling the function directly, before changing anything:

| input (today = 31 Aug) | before | after |
|---|---|---|
| logged Aug 24, nothing else on file | Day 8 | Day 8 |
| logged Aug 24, answer holds Aug 30 | **Day 2** | Day 8 |
| logged Aug 24, answer holds Aug 31 | **Day 1** | Day 8 |
| logged Aug 20, month-1 answer holds Aug 29 | **Day 3** | Day 12 |

`buildCycleInfo` collected the logged start together with five onboarding
answers, sorted them, and took **the most recent**. Those answers are a one-time
seed that is never updated, so one sitting later in the calendar than the period
she had just logged silently replaced it — and the date she entered appeared to
have been ignored.

A logged period is a deliberate statement about her own cycle; a signup answer
is not. The logged start now decides, and the answers fill in only when nothing
is logged. Cycle length is derived only from starts at or before the anchor, so
a seed dated after it cannot produce a nonsense gap.

**Found while testing it: a future start date reported a negative day.** A
mistyped year gave `Day -9`, and that number goes into Dr Docsy's prompt as "on
Day -9 of her menstrual cycle". The client calculator has always clamped at 1;
this did not. It does now.

Five tests in `tests/cycleStartPrecedence.test.js`, built from the measured
numbers above.

### The same precedence, on the client

`buildCycleInfo` feeds Dr Docsy's chat context and the partner view. The **Day**
on the card comes from the client's `lastPeriodStart`, which had the same fault
one layer up: the onboarding answers were applied *over* the canonical date from
the profile, and the entries fallback took a logged entry only when it fell
later than what was already held. A seed dated ahead of a real entry won both
times.

Both now treat the answers as a fallback, matching what
`periodPredictionService` already did correctly — it uses them only when there
are no logged entries. This matters when the prediction call fails, which on a
sleeping instance it does.

Unlike the server change, the client one is **not covered by a test**: it sits
inside `syncStateWithBackend`, behind six network calls.

## The period date reverting to today, found

The trace showed the value alternating on a real device after logging 26 Aug:

```
[period] PUSHING BACK -> 2026-08-26     <- her pick
[period] PUSHING BACK -> 2026-08-31     <- put back
[period] PUSHING BACK -> 2026-08-26
[period] PUSHING BACK -> 2026-08-31
```

Two writers, and no `prediction` or `profile` lines between them — so this was
not the backend disagreeing, and not the sync. It was the dashboard.

In `_loadOnboardingData`, on every refresh — so on every tab change:

```dart
DateTime? pStart = cur.lastPeriodStart;
if (remoteAnswers.containsKey('period_last_start_date')) {
  pStart = DateTime.tryParse(remoteAnswers['period_last_start_date'].toString());
}
```

`period_last_start_date` is written once at signup and never updated: logging a
period writes `last_period`, `cycle_start_date` and `last_period_date`, never
this key. Applying it unconditionally replaced the date she had just logged with
the signup answer — and `updatePersonalContext` then **pushed that back to the
server**, so the stale date was written in as though she had chosen it. Hence
Day 1, and hence the date appearing not to have been accepted.

It is a fallback now, used only when nothing is known.

**Also fixed: the picker claimed a save it never checked.**

```dart
await ApiPeriodService().logPeriodEntry(...);
saved = true;
```

`logPeriodEntry` returns `null` for any non-2xx rather than throwing, so a
refused write still told her the date was recorded. `saved` now depends on the
result, and the failure logs its status instead of passing silently.

`test/period_seed_precedence_test.dart` guards the shape in all three client
places, verified by reintroducing the bug and confirming the failure names it.

### Wrong turns, for the record

* **the client's period URLs miss `/api`** — they do, but `app.js` mounts every
  router twice, with and without the prefix, so the calls were fine. Checked
  before changing anything.
* **the onboarding date picker restricts the range** — it allows a year back.

Both were plausible from reading and wrong. The trace settled it in one run.

## "Today's context" showed a score instead of the option she picked

Energy read `Level 2/10` and mood `Level 4/10` on the Dr. Docsy tab. Neither is
a thing the app ever asked her. The check-in offers words — High/Medium/Low, and
Happy/Okay/Cramps/Tired/Irritable — and stores the label next to a score kept
for charting:

```json
{"energy": "High", "energy_score": 7, "mood": "Cramps", "mood_score": 4}
```

These two cards were built from the score alone:

```dart
final String energyText = (wb.energy != null && wb.energy! > 0)
    ? "Level ${wb.energy}/10"
    : "Not Logged";
```

So a number she was never shown, on a scale she was never given, stood in for
the answer she gave. The home page had always preferred the label — this screen
was the odd one out, and it now reads the same `daily_checkin.json`, keeping the
score only as a fallback for entries that carry no label.

**The mood face was stuck too.** The emoji was matched against `moodText`, which
was `"Level 4/10"`, so none of the cases could ever fire and every mood drew the
same face. It matches the labels the picker actually offers now, including the
ones it never covered: happy, okay and cramps.

Four tests in `test/sia_context_labels_test.dart`, verified by reverting the
card to the score and confirming the failure names it.

## Day 1 again: logging a start added a cycle instead of correcting one

The trace settled what the earlier fixes could not:

```
[period] entries on server: 9 -> [2026-08-31, 2026-08-28, 2026-08-27, 2026-08-26,
                                  2026-08-25, 2026-08-24, 2026-08-18, 2026-08-11, 2026-08-04]
[period] prediction -> 2026-08-31
```

The date **was** being saved every time. The current cycle start is the most
recent confirmed start, so with an entry on the 31st present, Day 1 was
arithmetically right — on data that should never have existed.

`createOrUpdatePeriodEntry` upserted on an **exact date match**:

```js
{ user_id: cleanUserId, period_start_date: startDateStr }
```

so every correction appended a row. Trying to fix a start date built a cluster —
24th, 25th, 26th, 27th, 28th, 31st — and since the newest wins, an earlier
correction could never take effect. Six stored dates, none of them usable.

Starts closer together than a cycle can be are the same period; the interval
maths already assumes exactly that when computing cycle length. A new start now
supersedes any existing start inside `minCycleLengthDays`, and anything older is
a different cycle and is left alone. Measured against the nine real entries:

| | entries | current start | day |
|---|---|---|---|
| before | all nine | 2026-08-31 | **1** |
| after logging the 26th | `2026-08-26, 2026-08-04` | 2026-08-26 | **6** |

The 4th survives — 22 days earlier, a genuinely separate cycle, and cycle
history is what every prediction is built from.

Four tests in `tests/periodCorrection.test.js`, including that two real cycles
28 days apart are both kept and that logging the same date twice stays
idempotent.

**A harness note worth keeping:** the file hung for the full timeout after its
tests passed, because the database connection is opened on import and holds the
process open. `closeDb()` in a final teardown fixes it. The same trap cost a
suite-wide stall earlier in this work.

## Driving the insight pipeline with generated data

637 randomised events over 90 days (mood, energy, sleep, pain, stress,
hydration, symptoms) plus three cycles 28 days apart, through a seeded
generator so any surprise is reproducible.

**What worked.** Every event was accepted — 637 written, 0 rejected — so the
validation contracts and the client's payload shapes agree. Predictions came
back with a day, a phase and a `medium_high` confidence. Patterns produced 8
insights, including a cycle-anchored one ("Acne around cycle day 23"), which
means the cycle-day resolver is wired and the branch capability gate is open for
reproductive years.

**What did not.** The monthly reflection reported **0 check-ins** against those
637 events, and then described it as progress:

> In July, you began building your daily wellness rhythm with 0 logged
> check-ins.

Two faults behind it.

**The count read a table nothing writes.** `distinctCheckinDates` came from
`user_daily_logs_*`. The app records check-ins as **health events**;
`ApiCheckinService`, the only client for the daily-log route, is called from
nowhere in the app. So the monthly reflection reported zero for every real user,
forever, however diligently they logged. It now counts both sources by distinct
date, so a day logged in both is still one day. Same run afterwards: **31
check-ins, 100% consistency, `sufficient_data`**.

**And zero read as progress.** With a period logged and no check-ins, the state
fell through to `learning_state`, whose summary congratulates her for the
nothing she logged. Zero is now `no_data`.

Four tests in `tests/monthlyCheckinSources.test.js`, including that several
events on one morning count as one check-in.

## Every life stage, driven with generated data

546 events over 90 days per stage — one of each type through the real writer so
the validation contracts are exercised, the rest bulk-inserted — plus three
cycles 28 days apart. All ten stages.

| stage | cycle language | prediction | patterns | monthly |
|---|---|---|---|---|
| first_period | yes | day 29 | 8 | 31 check-ins |
| cycle_tracking | yes | day 29 | 7 | 31 |
| hormonal_health | yes | day 29 | 7 | 31 |
| ttc | yes | day 29 | 7 | 31 |
| pregnancy | no | **suppressed** | 6 | 31 |
| postpartum | no | **suppressed** | 7 | 31 |
| perimenopause | yes | day 29 | 7 | 31 |
| menopause | no | **suppressed** | 7 | 31 |
| everyday_wellness | no | suppressed¹ | 7 | 31 |
| exploring | no | suppressed¹ | 7 | 31 |

¹ after the fix below. Nothing threw, nothing was rejected, and every stage
produced insights.

**Checked deliberately: no cycle wording leaks.** Pregnancy, postpartum,
menopause and everyday_wellness returned only stage-neutral findings ("Fatigue
is recurring"). None received the cycle-anchored kind ("Acne around cycle day
23") that reproductive years gets. The `allowCycleInsights` gate holds, which is
the one that matters — a countdown or a cycle-day claim shown to someone
pregnant or post-menopausal would be worse than showing nothing.

**Found: suppression did not match the capability table.** The rule was a
hardcoded list of four stage names compared against the raw string, and it
disagreed with `BRANCH_CAPABILITIES` in both directions:

* `everyday_wellness` and `exploring` declare `cycleTracking: false` and were
  given a full countdown — someone who opted out of cycle tracking was shown
  "Day 29, Late / Overdue Cycle";
* the comparison was on the raw string, so an account stored as
  `firstPeriodNotStarted` was suppressed while the same stage stored canonically
  as `first_period` was not.

It now derives from the declaration. "Periods not started" stays a separate
check, because the aliases fold it and `firstPeriodStarted` into one stage.

**A correction inside the correction.** Deriving straight from
`getBranchCapabilities` broke 17 existing tests: it falls back to
everyday_wellness for anything unrecognised, so every account with no stage set
was suppressed. Absent is not the same as opted out. Only a *recognised* stage
suppresses now.

Four tests in `tests/cycleSuppressionByStage.test.js`, including that the app's
own enum spellings (`reproductiveYears`, `tryingToConceive`) resolve correctly —
those are what real accounts hold.

**Not a finding, checked anyway:** the Flutter enum names are covered by
`LEGACY_STAGE_ALIASES`, so the domain layer does understand what the app sends.

## The partner surface, driven end to end

Two accounts, a real connection, and traffic through the repository the
controllers use.

**Working, verified:** invitation and connection creation; the connection
visible to both sides as `active`; messages sent both ways and both readable by
both; a non-member reading the thread gets nothing; shared-data read; permission
update; shared activities listed (5) and updated; the partner notified when a
message arrives. The Flutter client is wired to all of it —
`partner_screen.dart` calls both `getMessages` and `sendMessage`.

**Privacy default is right:** every share flag is off until she turns it on, and
the fallback added below does not bypass that.

### The partner could never see her mood

With sharing fully enabled, `latestMood` and `latestSleep` both came back
**null** while `cycleInfo` and `suggestions` were real.

`getSharedData` reads `user_daily_moods` and the sleep table. **Nothing in the
app writes either.** `saveDailyMood` and `saveSleepLog` exist in
`api_auth_service.dart` and are called from no screen; the check-in records
health events instead. So the feature the partner side exists for — seeing how
she is doing today — showed nothing for every couple, however faithfully she
logged.

Third instance of this exact shape in this pass: a consumer reading a table the
app stopped writing. `checkinEventFallback.js` recovers today's mood and sleep
from the events, and is used only when the dedicated tables are empty, since
chat extraction does still write them. Verified on the same fixture:
`latestMood {mood: low, energyLevel: 2}`, `latestSleep {hours: 5}`.

### Her account id was shown to her partner

`dynamicNeeds` read `partnerUser.display_name` off a **mapped** row whose key is
`displayName`. Always undefined, so it fell through to the email local-part, and
the copy the partner reads became:

> probe_sw_1788192975908 doesn't need anything right now

Her name now, and the email fallback is gone — an address is not a name, and not
something to show another person.

Five tests in `tests/partnerSharedData.test.js`, including that the fallback
respects her permission and that a user id never appears in partner copy.

**One test of mine was wrong, not the code.** I asserted the partner sees the
label she picked ("Tired"); `mood_logged` deliberately stores a canonical value
and drops `reportedAs`, because the coded set is what the pattern rules match
on. The expectation was corrected rather than the behaviour.

## The community surface, driven end to end

Two accounts, real posts, votes, comments and reports through the repositories
the controllers use.

**Working, verified:** post creation; another user reading it with the author
name resolved; upvote, switch to downvote (the score moves by **two**, which is
the easy one to get wrong), clearing a vote, and voting the same way twice
without double-counting; comment creation and threaded replies; comment voting;
the feed carrying the post with a comment count matching the thread; reporting;
an author deleting their own comment; and a non-author being refused.

The vote arithmetic matching the client-side prediction added earlier matters:
both sides now agree that switching sides is a two-point move.

### Anonymity would have shipped the author

`buildPostView` returned `anonymous` to the client and sent `authorId` and
`authorName` **alongside it regardless**, so a post marked anonymous still
carried the poster's name and account id to every reader.

Nothing sets the flag today — the app offers no such toggle, and `createPost`
does not even accept the field — so this was not a live leak. It is closed
anyway, because the flag is read, returned, and one UI toggle away from being
set: the leak was already written and waiting. An anonymous post now carries
`authorName: 'Anonymous'` and `authorId: null`, through the single post read and
through the feed.

Five tests in `tests/communitySurface.test.js`, including that a named post
still shows its name — the failure mode of over-correcting here is hiding
everyone.

## Health settings: two of the three checkbox groups never saved

The page edits three groups — conditions, goals and symptoms — through one
`_saveField`, which calls `updatePersonalContext`. That builds the payload sent
to the server, and the payload carried `medical_conditions` and `medications`
and **neither `symptoms` nor `goals`**.

So ticking a goal or a symptom updated local state, played the "saved" tick, and
was wiped by the next sync, which rebuilds the context from what the server
holds. Those two are also exactly what the home page gates its cards on, so a
tick appeared to work, visibly changed the cards, and then quietly undid both.

Answering the three questions directly:

* **Saving answers?** Conditions yes. Goals and symptoms no — now fixed.
* **Changing recommendations?** Yes, until the next sync, which reverted both
  the answer and the cards.
* **Checkboxes selecting?** They ticked and reported saved. The tick was
  honest about the local write and silent about the one that mattered.

The read-back already tolerated what the server stores: `saveMyOnboarding`
stringifies a list, and `OnboardingAnswers` parses both that and a real list, so
the round trip works now that the write exists.

### "Allow Dr. Docsy to learn from your interactions" did not

The same page's memory switch wrote to device storage and nothing else. It
survived a restart, so it looked like it worked, and:

* it never reached the server, so it did not follow her to another device;
* **nothing server-side consulted it**, so the learning continued after she
  turned it off.

A privacy control has to be known where the data is actually processed. It is
sent as `sia_memory_enabled`, restored on sync, and
`extractAndStoreProfileMemory` now stores nothing when it is off and says why
rather than reporting a write it did not make.

**Caught while wiring it:** the synced value was being read into a local that
the rebuilt context then ignored — it read `_personalContext.preferences` back
instead. Set and discarded, which is the same shape as several bugs already
fixed in this file. The test asserts the local is used.

Six tests in `test/settings_health_sync_test.dart`, verified by removing
`symptoms` from the payload and confirming the failure names it.

## Journal and M Studio, driven end to end

**Time capsules — correct, including the parts that matter.** A capsule is a
promise about *when* something may be read, and every edge held: a sealed
capsule reports `sealed: true` and its body is absent from the listing; opening
early is refused with `reason: 'sealed'` and leaks nothing; a capsule past its
date opens and stays readable on a second read; another account cannot read,
open **or delete** it; deletion works for the owner.

**Journal storage — correct.** A day upserts rather than duplicating: saving the
same date twice leaves one row and keeps the added entry. Entries survive the
round trip, journals are scoped to their owner, and day-level sharing writes.
Both halves are wired in the app — `saveJournalForDate` on write,
`getJournals` on read.

**Journal templates are genuinely consumed.** `_createNewEntry` calls
`JournalTemplates.promptsFor(templateName)` and lays the prompts down the page,
so choosing a template changes what the entry opens with. Worth checking rather
than assuming, since this is the file where a template list existed for a long
time as names with nothing behind them.

**Recovery is empty, and correctly so.** Five sessions exist; **none are
approved**, so the tab shows nothing. That is the deferred content approval, not
a broken query — and the empty state says so rather than inventing sessions to
fill the space: "They appear here once they have been reviewed." The test
asserts the gate can only narrow and that no draft reaches a reader, because
"empty" and "broken" look identical from the outside.

Five tests in `tests/studioSurface.test.js`.

**Two probe errors, mine not the product's.** I read `openCapsule` as returning
the capsule directly when it returns `{ok, capsule}`, and reported a false
failure on a due capsule before checking the shape. Same class of mistake as the
partner probe. The signature is worth reading before the result is believed.
