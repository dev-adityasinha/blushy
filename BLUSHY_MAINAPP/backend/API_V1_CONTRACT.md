# Blushy API v1 — spec-aligned surface

Implements the Blushy Backend & AI Feature Specification (14 Aug). Every route
below returns the standard response contract (spec §27):

```json
{
  "data": null,
  "state": "ready | empty | insufficient_data | restricted | error",
  "lastUpdated": "2026-08-29T10:00:00.000Z",
  "source": "manual | rule | ai | medical_reference | device | imported",
  "version": "calculation, content or model version",
  "permissions": null,
  "errorCode": "MACHINE_READABLE_CODE"
}
```

All routes require `Authorization: Bearer <jwt>` unless marked **public**.
Existing routes (`/auth`, `/partner`, `/community`, `/posts`, `/ai`, …) are
unchanged; this is an additive surface.

---

## Life stage — `/api/v1/life-stage`

| Method | Path | Purpose |
|---|---|---|
| GET | `/journeys` | **public** — the 10 life journeys, each with only its own branch questions (§3) |
| GET | `/journeys/:stage/questions` | **public** — branch initialization questions |
| GET | `/` | Current branch, capabilities, ordered Home modules, allowed transitions |
| POST | `/transition` | Guarded transition. `409 CONFIRMATION_REQUIRED` for sensitive moves, `422 MISSING_BRANCH_CONTEXT` when the target branch needs an answer first (§23) |
| PUT | `/context` | Merge branch context |
| POST | `/pregnancy/end` | Pregnancy exit/loss. Requires `confirmed: true`; permanently blocks pregnancy content (§15) |
| GET | `/history` | Transition history — historical data is never deleted |
| PUT | `/ttc-opt-in` | Fertility stays separate from cycle tracking until opted in (§5) |

## Home, cycle, patterns, care plan — `/api/v1`

| Method | Path | Purpose |
|---|---|---|
| GET | `/home` | Home read model: ordered modules, each with its own contract state (§5) |
| GET | `/cycle` | Cycle Hero. `restricted` for menopause/pregnancy, `insufficient_data` rather than false precision (§6) |
| POST | `/cycle/periods` | Log/correct a period; returns the recalculated cycle in the same response (§28). Accepts `Idempotency-Key` |
| GET | `/cycle/periods` | Period history |
| DELETE | `/cycle/periods/:entryId` | Delete; recalculates every dependent card |
| GET | `/patterns` | Structured insights with `sourceEventIds`, `confidence`, `engineVersion` (§8) |
| POST | `/patterns/refresh` | Recompute without creating duplicates |
| POST | `/patterns/:insightId/dismiss` · `/feedback` · `/view` | Dismiss, helpful/not-helpful, viewed |
| GET | `/care-plan` | Action objects. `restricted` while a safety escalation is active (§10) |
| POST | `/care-plan/:actionId/complete` · `/dismiss` | Completion state |
| GET | `/pregnancy` · `/postpartum` · `/fertility` | Branch modules (§13, §15, §16) |
| GET | `/reflections/current` · PUT `/reflections` · GET `/reflections` | Data-driven prompts, private by default (§12) |

## Health events — `/api/v1/events`

| Method | Path | Purpose |
|---|---|---|
| GET | `/schema` | **public** — event types and what each invalidates |
| POST | `/` | Log a check-in. Returns the canonical record; `Idempotency-Key` / `clientEventId` prevents duplicates (§7, §25) |
| GET | `/` | Query by type and date range |
| GET/PATCH/DELETE | `/:eventId` | Read, edit, soft delete. Edit and delete recalculate dependent insights and cancel linked reminders (§6) |
| GET | `/timeline` | Chronological history, paginated. Menopause excludes cycle records (§11) |
| POST | `/sync` | Offline queue flush, up to 100 events, per-item accept/reject |

## Safety, screening, doctor companion — `/api/v1/safety`

| Method | Path | Purpose |
|---|---|---|
| GET | `/emergency-resources` | **public** — region-aware; returns `REGION_UNKNOWN` rather than guessing a number (§15) |
| GET | `/state` | Current red flag state and suppression |
| POST | `/check-text` | Screen free text before acting on it |
| GET | `/screening/instruments` | EPDS, PHQ-9, GAD-7 with instrument metadata |
| GET | `/screening/instruments/:id/items` | Returns `itemsAvailable: false` until licensed wording is loaded — never paraphrased (§16) |
| POST | `/screening/submit` | Deterministic scoring; concerning results return a professional support flow, not wellness tips |
| GET | `/screening/history` · POST `/screening/:id/handoff` | History and provider handoff |
| GET | `/screening/mood-check-in` | Rule-based check-in from repeated concerning moods |
| GET | `/doctor-summary/preview` | Draft summary over a date range, labelled user-reported vs app-generated (§18) |
| POST/GET/DELETE | `/doctor-summary[/:id]` | Save after removing entries, list, delete |
| GET | `/admin/red-flag-rules` | **admin** — versioned ruleset (§27) |

## Partner — `/api/v1/partner`

| Method | Path | Purpose |
|---|---|---|
| GET | `/permission-matrix` | **public** — all 13 permissions with labels and examples (§10) |
| GET/PATCH | `/connections/:id/sharing` | What is shared; only the person sharing can change it. Revocation takes effect on the partner's next request |
| GET | `/connections/:id/sharing/history` | Permission audit trail |
| GET | `/connections/:id/home` | Partner Home — works with nothing shared (§19) |
| GET | `/connections/:id/context` | The permission-filtered context Partner Sia receives (§9, §22) |
| GET | `/connections/:id/us` | Explicitly shared objects only (§21) |
| GET/POST | `/connections/:id/support-requests` | Support requests — partner sees the request and nothing else (§11) |
| PATCH | `/support-requests/:id` | State change; server enforces who may do what |

## Notifications and analytics — `/api/v1/notifications`

| Method | Path | Purpose |
|---|---|---|
| GET | `/categories` | **public** — categories with sensitivity flags |
| GET/PATCH | `/preferences` | Per-category control, quiet hours, lock-screen redaction. Safety notices cannot be disabled (§19) |
| GET | `/` · POST `/read` | List and mark read |
| POST | `/reminders` · DELETE `/reminders/:entityType/:entityId` | Entity-linked reminders, cancelled when their source is deleted (§24) |
| GET | `/analytics/schema` | **public** — the only accepted event names |
| POST | `/analytics/track` | Allowlisted events and properties; health text is dropped server side (§26) |
| GET | `/analytics/funnel` | **admin** — funnel counts |

## Clinical content — `/api/v1/content`

| Method | Path | Purpose |
|---|---|---|
| GET | `/` · `/:contentId` | Approved content only; audience-tagged for Partner Learn (§13, §17) |
| PUT | `/:contentId/progress` · `/bookmark` | Progress and saved state |
| GET | `/saved` · `/completed` · `/recommendations` | Library state |
| GET/POST/PATCH | `/admin[...]` | **admin** — draft → clinical_review → approved → retired, review queue, emergency retirement, audit (§27) |

---

## Running it

```bash
npm run dev:memorydb
```

Starts the real server against a throwaway in-memory MongoDB — no local `mongod`
needed. `npm run dev` uses `MONGODB_URI` as before.

```bash
npm test
```

153 tests: deterministic domain tests plus HTTP integration tests against the
real app on an in-memory database.

## Clinical content review

Seed content is written in `clinical_review` status. It is **not served** until a
named reviewer approves it, because the spec requires sourced, reviewed and
versioned clinical content. For local and CI use, set
`SEED_CONTENT_AUTO_APPROVE=true`; startup refuses that flag in production.

Validated screening instrument wording (EPDS, PHQ-9, GAD-7) is deliberately not
seeded. It is licensed clinical text and must be loaded from the licence holder;
until it is, the items endpoint reports `itemsAvailable: false` rather than
presenting an approximation.
