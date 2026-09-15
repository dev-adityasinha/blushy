# Blushy Design System & Visual Guidelines
## Stage 1: First Period Not Started Dashboard

This document establishes the official visual hierarchy, typography rules, color palette tokens, card vs. unboxed component layouts, and dynamic engine rules used in the **First Period Not Started** stage. Use this guide as the single source of truth to maintain visual consistency across all stages and future features.

---

### 1. Canvas & Surface Hierarchy

| Component | Token / Style | Value / Hex | Usage Rules |
| :--- | :--- | :--- | :--- |
| **Page Canvas Background** | `surfaceBackground` | `Color(0xFFFAF7F2)` | Warm cream neutral canvas. Never stark white or grey. |
| **Structural Cards** | `cardBg` | `Color(0xFFFFFFFF)` (`Colors.white`) | All main cards use pure white. **Never** flood cards with solid colors. |
| **Card Borders** | `cardBorderColor` | `Color(0xFFEFE8E0)` | `Border.all(color: Color(0xFFEFE8E0), width: 1.0)`. Unified across all cards. |
| **Card Border Radius** | `cardRadius` | `BorderRadius.circular(18)` to `20` | Soft, modern rounded corners. |
| **Dividers & Lines** | `dividerColor` | `Color(0xFFF3EEE9)` | Extremely soft, non-intrusive separators. |

---

### 2. Typography Hierarchy

| Role | Font Family | Size / Weight / Style | Color | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Category Eyebrow** | `GoogleFonts.manrope` | `10.5px`, `w800`, `letterSpacing: 1.1` | **Crimson Red (`#DD0D22`)** | UPPERCASE section headers (`YOUR JOURNEY`, `PUBERTY GUIDE`, `FEEL PREPARED`, `CHECK IN`). |
| **Editorial Greeting** | `GoogleFonts.cormorantGaramond` | `28px`, `w600` | Charcoal (`#221510`) + User name in **Italic Crimson (`#DD0D22`)** | Unboxed warm greeting at top of dashboard. |
| **Section & Card Headings** | `GoogleFonts.cormorantGaramond` | `20px` - `24px`, `w600` or `w700` | Dark Charcoal (`#221510`) | Main titles inside cards and above unboxed rows. |
| **Body & Explanations** | `GoogleFonts.manrope` | `11.5px` - `13px`, `w400` or `w500`, `height: 1.35-1.45` | Warm Muted Grey (`#7A6B72`) | Informative descriptions and subtitles. |
| **Buttons & Interactive Text**| `GoogleFonts.manrope` | `11.5px` - `13px`, `w700` | White (`#FFFFFF`) or Crimson (`#DD0D22`) | CTAs, links, and action buttons. |

---

### 3. Color Palette & Strategic Placement Rules

#### A. Strategic Primary Red (`#DD0D22`)
- **Category Eyebrows**: Every section category eyebrow is consistently `#DD0D22`.
- **Primary CTA Buttons**: "Log a period start", "Continue to Stage 2", "Share with Mom", "Talk →".
- **Brand Highlights**: User's italicized name in the greeting, linear progress indicators, and active badges.

#### B. Punchy, Bold Accent Colors (Icon Badges & Pills Only)
Accents are **bold, punchy, and vibrant** (never dull or pastel), paired with matching 10–12% soft tint backgrounds for circular icon badges:

| Accent Name | Solid Accent Hex | Soft Tint Hex | Semantic Category in Stage 1 |
| :--- | :--- | :--- | :--- |
| **Cobalt Blue** | `Color(0xFF2563EB)` | `Color(0xFFDBEAFE)` | 💧 Discharge & Fluid Signs / Calm State |
| **Emerald Teal** | `Color(0xFF0D9488)` | `Color(0xFFCCFBF1)` | 📈 Growth Spurts / Body Structure / Good Feeling |
| **Vivid Magenta** | `Color(0xFFF72585)` | `Color(0xFFFFE5F0)` | 🌸 Breast Buds / Puberty Milestones / Mixed Emotions |
| **Royal Purple** | `Color(0xFF7209B7)` | `Color(0xFFF3E8FF)` | ✨ Body Hair / Anatomy Changes / Tired State |
| **Warm Amber** | `Color(0xFFD97706)` | `Color(0xFFFEF3C7)` | ☀️ Mood Shifts / Emotional Swings / Nervous State |
| **Electric Coral**| `Color(0xFFFF4A00)` | `Color(0xFFFFEBE0)` | 🌿 Skin Care & Glow / Daily Comfort |
| **Brand Crimson**| `Color(0xFFDD0D22)` | `Color(0xFFFFECEB)` | 🌙 Sleep & Cellular Rest / Emergency Preparedness |

> [!IMPORTANT]
> **Strict Rule**: Accent colors are only used for 52–56px circular icon badges, small tag pills, and active highlights. **NEVER** apply these colors as full card backgrounds or rainbow borders.

---

### 4. Card vs. Unboxed Component Layout Rules

To maintain visual rhythm and prevent "box fatigue", alternate between unboxed elements and clean white cards:

#### 1. Unboxed Elements
- **Editorial Greeting**: Text directly on canvas background.
- **Puberty Guide ("Your body, lately")**: A horizontal row of 56px circular colored icon badges with clean 2-line centered labels underneath (zero card borders around items).
- **Daily Feeling Check-In ("Check In")**: A horizontal row of 52px circular mood icon badges with labels below.

#### 2. Clean White Structured Cards (`#FFFFFF` + `#EFE8E0` border)
- **01 Your Journey Card**: Next milestone action with "Log a period start" button.
- **02 Today with Docsy Card**: AI Daily Reflection + search-style input bar + quick prompt pills.
- **03 Feel Prepared**: First-Period Kit progress bar + 5-Step Emergency Guide.
- **04 Family & Friends**: Rotating conversation prompt + "Share with Mom" + "Next question".
- **05 Keep Exploring**: Rotating article cards with reading time and topic badges.

---

### 5. Dynamic Engine & Real-Time Rules

1. **Zero Hardcoded Stagnation**: Content changes dynamically every day using date-seeded rotation (`_dayOfYear % list.length`).
2. **Real-Time AI Sync**: Dynamically queries backend health insights via `ApiSiaService().getHealthInsights()`.
3. **Real Docsy AI Integration**: All question chips and prompts invoke `openDocsyWith(context, prompt)` to launch `BlushySiaScreen`.
4. **Native Sharing & Clipboard**: "Share with Mom" copies the discussion text to the clipboard and opens native OS sharing (`Share.share()`).
