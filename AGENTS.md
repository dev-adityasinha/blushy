## Swiggy Builders Club

When writing code against Swiggy MCP (Food, Instamart, Dineout), consult the authoritative docs at:
- Index: https://mcp.swiggy.com/builders/llms.txt
- Full text: https://mcp.swiggy.com/builders/llms-full.txt
- Per-page: append `.md` to any https://mcp.swiggy.com/builders/docs/... URL

Before recommending a tool name, parameter, error code, rate limit, or auth flow, verify against these docs. The tool catalog lives under `/docs/reference/{food,instamart,dineout}`.

Rules:
1. Before recommending a tool name, parameter, error code, rate limit, or auth flow, fetch the relevant doc and verify.
2. Never invent tool names or parameters. If the docs don't cover it, say so and ask.
3. Prefer `.md` page fetches over `llms-full.txt` when you know the exact area - it's cheaper on context.

Smoke test: fetch llms.txt and tell me how many tools the Food server exposes. (Answer: 14.)

## Flutter SDK Configuration

Always use the global Flutter SDK installed via Homebrew Cask:
- PATH: `/opt/homebrew/Caskroom/flutter/3.44.6/flutter`
- Executable: `/opt/homebrew/bin/flutter` (symlinked from `/opt/homebrew/Caskroom/flutter/3.44.6/flutter/bin/flutter`)

Rules:
1. Do not download or install local copies of the Flutter SDK or other workspace-specific SDKs.
2. Do not reference `/Users/yashasnaidu/Bicbrick_Registration/flutter`.
3. If executing Flutter commands, use the global path `flutter` directly or run `/opt/homebrew/bin/flutter`.

## Git Collaboration & Branch Workflow (`nithya`)

Rules for collaborating on this repository without overwriting work:
1. **Branch Discipline**:
   - Always work on the `nithya` branch (or a dedicated feature branch). Never commit directly to `main`.
   - Never run `git push --force` unless explicitly authorized.
   - Commit in small, logical chunks with clear descriptive commit messages.

2. **Daily Syncing (Pulling Latest from `main`)**:
   - At the start of a session or before new work, sync latest changes from `main`:
     ```bash
     git fetch origin
     git merge origin/main
     ```
   - Ensure working tree is clean (committed or stashed) before merging.

3. **Pushing Work**:
   - Push commits to `origin nithya`:
     ```bash
     git push -u origin nithya  # (or `git push` once upstream is set)
     ```

4. **Merging into `main` (Pull Requests)**:
   - Always open a Pull Request on GitHub from `nithya` -> `main` for review and merging; do not merge into `main` locally.

5. **Merge Conflict Resolution**:
   - If Git reports conflicts during `git merge origin/main`, resolve conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), test and verify, stage resolved files (`git add .`), commit the merge resolution, and push to `origin nithya`.

## Blushy Design System & Visual Guidelines (Dashboard & Stages)

Consult and strictly follow the design system defined in `BLUSHY_MAINAPP/lib/features/home/presentation/stages/STAGE1_DESIGN_RULES.md`:

1. **Canvas & Surface Hierarchy**:
   - Canvas: Warm cream neutral `Color(0xFFFAF7F2)` (`surfaceBackground`). Never stark white or grey.
   - Cards: Pure white `Color(0xFFFFFFFF)` (`cardBg`). Never flood cards with solid background colors.
   - Borders: `Color(0xFFEFE8E0)` (`cardBorderColor`) with `1.0` width.
   - Radius: `BorderRadius.circular(18)` to `20` (`cardRadius`).
   - Dividers: `Color(0xFFF3EEE9)` (`dividerColor`).

2. **Typography Hierarchy**:
   - Category Eyebrow: `GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFFDD0D22))` (Uppercase).
   - Editorial Greeting: `GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF221510))` + user name in *Italic Crimson* (`Color(0xFFDD0D22)`).
   - Section/Card Headings: `GoogleFonts.cormorantGaramond(fontSize: 20-24, fontWeight: FontWeight.w600 or w700, color: Color(0xFF221510))`.
   - Body & Subtitles: `GoogleFonts.manrope(fontSize: 11.5-13, fontWeight: FontWeight.w400 or w500, height: 1.35-1.45, color: Color(0xFF7A6B72))`.
   - Buttons & Interactive Text: `GoogleFonts.manrope(fontSize: 11.5-13, fontWeight: FontWeight.w700, color: Colors.white or Color(0xFFDD0D22))`.

3. **Colors & Strategic Usage**:
   - Primary Brand Crimson: `Color(0xFFDD0D22)`. Used for eyebrows, primary CTA buttons ("Log a period start", "Continue to Stage 2", "Share with Mom"), name highlight, active badges.
   - Punchy Accent Colors (Badges/Pills ONLY, never full card backgrounds):
     - Cobalt Blue: `Color(0xFF2563EB)` / Tint: `Color(0xFFDBEAFE)` (Discharge/Calm)
     - Emerald Teal: `Color(0xFF0D9488)` / Tint: `Color(0xFFCCFBF1)` (Growth/Structure/Good)
     - Vivid Magenta: `Color(0xFFF72585)` / Tint: `Color(0xFFFFE5F0)` (Puberty milestones/Mixed emotions)
     - Royal Purple: `Color(0xFF7209B7)` / Tint: `Color(0xFFF3E8FF)` (Anatomy/Tired)
     - Warm Amber: `Color(0xFFD97706)` / Tint: `Color(0xFFFEF3C7)` (Mood/Nervous)
     - Electric Coral: `Color(0xFFFF4A00)` / Tint: `Color(0xFFFFEBE0)` (Skin Care/Comfort)
     - Brand Crimson: `Color(0xFFDD0D22)` / Tint: `Color(0xFFFFECEB)` (Sleep/Emergency)

4. **Card vs. Unboxed Component Rhythm**:
   - Alternate between unboxed elements (Editorial Greeting, horizontal rows of circular badges with labels) and clean white structured cards to prevent box fatigue.

5. **Dynamic Content & Features**:
   - Dynamic date-seeded rotation (`_dayOfYear % list.length`), no hardcoded stagnation.
   - Real-time AI sync via `ApiSiaService().getHealthInsights()`.
   - Real Docsy AI invocation via `openDocsyWith(context, prompt)`.
   - Native OS sharing via `Share.share()` + clipboard copy.
