# Partner Data Visibility, Notifications & AI Suggestions

## How To Use This File

This is the execution checklist for the partner data feature. The deliverable has two mandatory products: **the app** and **the website**. An agent must follow the phases in order and must not mark a task complete until its acceptance checks pass for both products.

- `[ ]` not started
- `[-]` in progress or blocked; record the reason beside the item
- `[x]` implemented and verified
- Treat `BLUSHY_MAINAPP` as the app target and identify the website target during Phase 0. Do not silently implement only one product.
- Preserve existing user changes. Read the target file before editing it.
- Before editing, identify the current owner of the behavior and its nearest test.
- After every code edit, run the narrowest relevant test or type check immediately.
- Do not invent endpoint names, response fields, permissions, or database columns. Keep backend, Flutter, and any mirror implementation on the same contract.
- Do not log health data, notification content, tokens, passwords, or AI prompts containing personal data.
- Every completed phase must include a short verification note in the commit/PR description or issue tracker.

## Scope And Success Criteria

The feature lets an authenticated connected partner see only data explicitly shared by the other person, receive useful notifications about permitted updates, mark data as viewed/read, and request contextual AI suggestions.

The feature is complete only when all of the following are true:

- A user cannot read another user's data by changing a `connectionId`, `userId`, or notification id.
- Revoked, expired, pending, and disconnected relationships return no protected shared data.
- Every shared category follows the connection's current permission settings.
- Empty, loading, error, offline, and unauthorized states are handled in the UI.
- Duplicate notification creation is prevented or intentionally deduplicated.
- AI suggestions use only authorized, current context and fail gracefully when unavailable.
- The app build and the website build compile and their focused backend/frontend tests pass.
- App and website use the same API contract, authorization rules, privacy behavior, and user-visible states.
- A missing or unclear website source is a blocker to completion, not permission to mark the website phase complete.

## Architecture Change Plan From PDF

These tasks come from `Blushy Architecture Change Comparison (1).pdf`. The percentages in the PDF are estimates, not acceptance criteria. Implement the items in order, validate each one, and keep app and website behavior aligned.

### Security First

- [x] Protect every admin route with mandatory authentication and an explicit `admin` role guard. Implemented in `BLUSHY_MAINAPP/backend/src/middleware/requireAuth.js` and `BLUSHY_MAINAPP/backend/src/routes/adminRoutes.js`.
- [ ] Keep permanent AI provider credentials on the backend; remove any provider key from client responses and use an ephemeral token or backend proxy for voice.
- [ ] Replace optional authentication on private routes with mandatory authentication, starting with health-data, partner, AI, journal, and account routes. Preserve optional auth only for intentionally public endpoints.
- [ ] Remove full transcriptions, AI prompts, health values, attachment names, and personal identifiers from logs. Keep request id, operation, status, and duration only.
- [ ] Make production startup fail when `JWT_SECRET` is missing, weak, or still using a known fallback. Keep local development setup explicit and documented.
- [ ] Harden uploads with allowlisted MIME types and file signatures, size limits, per-user quotas, safe filenames, and malware scanning or an explicitly documented deployment control.

### Data Reliability

- [ ] Verify `withTransaction()` uses a real MongoDB session transaction wherever multiple writes must succeed together.
- [ ] Make required-index creation fail startup or make readiness unhealthy; do not continue as healthy after a required index failure.
- [ ] Centralize woman/man collection selection in one tested resolver or unified identity model.
- [ ] Add ownership predicates and cross-user isolation tests to every medical and health-data read/write path.

### Runtime And Scaling

- [ ] Add one shared client interceptor for token refresh: refresh once, retry the original request once, then log out only when refresh fails.
- [ ] Standardize base URL, auth headers, timeout, refresh, and error mapping behind one client abstraction for both app and website.
- [ ] Replace URL JWTs for WebSocket authentication with a short-lived ticket or authenticated upgrade flow.
- [ ] Add shared Redis Pub/Sub or an equivalent broker before claiming multi-instance WebSocket support.
- [ ] Move scheduled jobs to a worker or protect them with a distributed lock so multiple web instances cannot duplicate work.
- [ ] Document and enforce shared Redis requirements for production rate limits and realtime events.

### Maintainability And Delivery

- [ ] Refactor large Flutter screens so views render state, controllers/view models orchestrate, and repositories own data access.
- [ ] Add an explicit startup loading state before authenticated routing reads local session state.
- [ ] Select and document one versioned API convention, then update backend, app, website, tests, and documentation consistently.
- [ ] Add a repeatable isolated backend test command; do not rely on an undocumented live database.
- [ ] Add automated authorization tests for anonymous, non-admin, cross-user, expired-token, invalid-upload, WebSocket, refresh, and privacy cases.
- [ ] Add safe structured logs, request IDs, liveness, and readiness checks.

**Architecture acceptance:** no recommendation is marked complete without a focused test or executable validation, and no estimated percentage is presented as measured performance. A full rewrite is out of scope unless a later validated blocker requires it.

## Phase 0: Before Starting

- [ ] Confirm the app target is `BLUSHY_MAINAPP`.
- [ ] Confirm the website target directory, entry point, backend, package manager, and deployment command. Current candidates include `BlushyBeta`; do not assume it is the website without verification.
- [ ] Record the app target and website target paths in the Verification Log before implementation begins.
- [ ] Do not edit `blushy_flutter_ui 6` unless it is explicitly confirmed as one of the two deliverables.
- [ ] Inspect the working tree with `git status --short`; do not revert unrelated changes.
- [ ] Read `BLUSHY_MAINAPP/README.md`, `BLUSHY_MAINAPP/pubspec.yaml`, and `BLUSHY_MAINAPP/backend/package.json`.
- [ ] Confirm environment variables and database connection details from existing `.env` conventions. Never add secrets to source control.
- [ ] Locate the current auth middleware and verify the authenticated id is `req.user.userId` or the repository's established equivalent.
- [ ] Locate the existing partner permission model and list its allowed categories before changing schemas or APIs.
- [ ] Locate the current backend test setup. If no test script exists, run existing test files directly and add the smallest missing test harness needed.
- [ ] Write down the API contract before implementation: method, path, auth requirement, request fields, success response, empty response, and each error status.

## Phase 1: Database Schema

**Owner:** `BLUSHY_MAINAPP/backend/src/utils/initDatabase.js`

- [x] Add the `partner_data_views` table using the existing database initialization and migration style.
- [x] Add the `partner_notifications` table using the existing database initialization and migration style.
- [ ] Confirm every table has required relationship/user identifiers, timestamps, indexes, and uniqueness constraints.
- [ ] Confirm foreign keys or equivalent cleanup behavior when a connection is removed.
- [ ] Confirm timestamps are stored and compared consistently in UTC.
- [ ] Confirm initialization is idempotent and safe to run against an existing database.
- [ ] Add or update a schema smoke test that initializes a clean database twice without failure.
- [ ] Verify indexes support list queries for connection, recipient, unread state, and newest-first ordering.

**Acceptance:** clean and existing databases initialize successfully; queries cannot return records for an unrelated user; repeated initialization creates no duplicate schema objects.

## Phase 2: Partner Repository

**Owner:** `BLUSHY_MAINAPP/backend/src/repositories/partnerRepository.js`

- [x] Add `getSharedData()`.
- [x] Add `markDataViewed()`.
- [x] Add notification create/list/read operations.
- [ ] Make every read begin with an authorized active connection lookup owned by the requesting user.
- [ ] Apply permissions in the repository query or one clearly enforced repository boundary, not only in the controller.
- [ ] Return a stable shape for missing optional data: use `null`, empty arrays, or omitted fields consistently.
- [ ] Enforce ownership for notification listing and read updates using the authenticated recipient id.
- [ ] Make mark-viewed and mark-read operations idempotent.
- [ ] Add duplicate/deduplication behavior for repeated mood and sleep updates.
- [ ] Keep private categories out of results even when a caller requests them explicitly.
- [ ] Add repository tests for owner, connected partner, unrelated user, revoked permission, missing connection, and empty data.

**Acceptance:** repository methods are safe when called directly with hostile ids and return deterministic results without leaking private records.

## Phase 3: Partner Controller And Routes

**Owners:** `BLUSHY_MAINAPP/backend/src/controllers/partnerController.js`, `BLUSHY_MAINAPP/backend/src/routes/partnerRoutes.js`

- [x] Add `getPartnerSharedData()`.
- [x] Add `markPartnerDataViewed()`.
- [x] Add `listPartnerNotifications()`.
- [x] Wire new routes under the existing `/partner` prefix.
- [ ] Confirm all routes use existing auth middleware and rate limiter.
- [ ] Validate path parameters and request bodies before calling the repository.
- [ ] Use the established status-code and error-response format.
- [ ] Do not accept a caller-supplied viewer/user id when the value is available from auth.
- [ ] Define behavior for no active connection, no permission, stale connection, and malformed ids.
- [ ] Add route/controller tests for success, 400, 401, 403, 404, 429, and repository failure paths.
- [ ] Confirm response payloads contain no database-only fields, tokens, or internal error messages.

**Acceptance:** an authenticated partner can fetch only permitted data and can view/read it; unauthorized requests fail without exposing whether another user's record exists.

## Phase 4: Notification Hooks

**Owner:** `BLUSHY_MAINAPP/backend/src/controllers/authController.js`

- [x] Create a notification after a permitted mood update.
- [x] Create a notification after a permitted sleep update.
- [ ] Verify hooks run only after the source update succeeds.
- [ ] Verify hooks target the connected partner, never the updating user.
- [ ] Verify current sharing permission is checked at notification creation time.
- [ ] Avoid notification content that reveals a category the recipient is not allowed to see.
- [ ] Make notification failure non-destructive: record the source update successfully and report hook failure without sensitive values.
- [ ] Prevent duplicate notifications on retries or repeated requests.
- [ ] Add tests for allowed, disallowed, disconnected, repeated, and failed-notification cases.

**Acceptance:** a valid update creates exactly the intended notification, while private or failed updates create none and do not break the original request.

## Phase 5: AI Partner Suggestions

**Owners:** `BLUSHY_MAINAPP/backend/src/controllers/aiController.js`, `BLUSHY_MAINAPP/backend/src/routes/aiRoutes.js`

- [x] Add `getPartnerSuggestions()`.
- [x] Wire `/ai/partner-suggestions` through existing authenticated AI route setup.
- [ ] Build AI context from repository data that has already passed partner authorization.
- [ ] Exclude raw private notes, identifiers, credentials, and unshared health categories from prompt/context.
- [ ] Define a bounded response schema with suggestion text, category, and existing safety metadata.
- [ ] Add input validation, timeout handling, rate limiting, and provider-error handling.
- [ ] Make suggestions supportive and non-diagnostic; include the existing medical-safety fallback where required.
- [ ] Add tests proving an unauthorized category cannot reach AI context.
- [ ] Add tests for provider timeout, empty context, malformed provider output, and success.

**Acceptance:** suggestions use only authorized partner context, have a stable response shape, and degrade to a safe user-facing error without leaking prompts or provider details.

## Phase 6: Flutter Partner Service

**Owner:** `BLUSHY_MAINAPP/lib/services/api_partner_service.dart`

- [x] Add `getPartnerData()`.
- [x] Add `getNotifications()`.
- [x] Add `markNotificationsRead()`.
- [ ] Match every method to the backend method/path/request/response contract exactly.
- [ ] Use existing auth headers, base URL, timeout, and error parsing conventions.
- [ ] Parse null, empty, malformed, unauthorized, rate-limited, and offline responses safely.
- [ ] Do not cache protected partner data beyond existing app policy; clear it on logout or connection change.
- [ ] Prevent overlapping refresh calls and ignore stale responses when the screen is disposed.
- [ ] Add service tests or mock-client tests for success and each user-visible failure state.

**Acceptance:** the service can be used by the screen without raw JSON handling, uncaught exceptions, or stale data after account/connection changes.

## Phase 7: Models And Widgets

**Owners:** `BLUSHY_MAINAPP/lib/features/partner/digibouquet/models/partner_models.dart`, existing partner widget directory, and any new `partner_data_card.dart`

- [x] Add `PartnerSharedData`, `MoodEntry`, `SleepEntry`, `CycleInfo`, `HealthInsights`, and `PartnerNotification` models.
- [x] Add the partner data card widget.
- [ ] Make `fromJson` tolerant of absent optional fields and unexpected enum values.
- [ ] Keep date/time parsing timezone-aware and display dates in the user's locale.
- [ ] Ensure private categories cannot render merely because malformed JSON includes them.
- [ ] Define accessible labels, semantic reading order, contrast, text scaling, and touch targets.
- [ ] Provide explicit loading, empty, error, and retry states for each card/list.
- [ ] Avoid medical certainty or alarming language in partner-facing copy.
- [ ] Add widget/model tests for complete, partial, empty, malformed, and permission-filtered data.

**Acceptance:** cards render stable layouts on narrow and wide screens and never crash or reveal unshared fields when data is incomplete.

## Phase 8: Partner Dashboard Integration

**Owners:** existing partner dashboard screen and partner presentation widgets under `BLUSHY_MAINAPP/lib/features/partner/`

- [x] Fetch partner shared data for the partner role.
- [x] Conditionally render mood, cycle, sleep, and insight cards.
- [x] Add the notification badge in the partner section.
- [x] Add the AI partner suggestions widget.
- [x] Add periodic refresh.
- [ ] Confirm the screen fetches only after authentication and an active connection are known.
- [ ] Stop timers/subscriptions in `dispose` and avoid updates after widget disposal.
- [ ] Prevent refresh storms when returning to foreground or changing tabs.
- [ ] Refresh after marking viewed/read and update badge counts immediately.
- [ ] Add retry actions that preserve the selected partner context.
- [ ] Verify role-based navigation: data owner and receiving partner see the correct screens.
- [ ] Add widget tests for all states, permission combinations, roles, refresh, and logout.
- [ ] Manually verify mobile and web layouts at small, medium, and large widths.

**Acceptance:** the dashboard stays responsive, reflects permission changes after refresh, and has no timer, navigation, or set-state-after-dispose errors.

## Phase 9: Website Implementation (Mandatory Second Product)

**Target:** the website directory and backend recorded in Phase 0. Do not call this a mirror-only task: the website must be independently runnable and verified.

- [ ] Confirm the website source directory and do not proceed with an unverified path.
- [ ] Create or complete the website frontend entry point, routing, authentication integration, partner service, models, cards, dashboard, notifications, AI suggestions, and all loading/error/empty/offline states.
- [ ] Create or complete the website backend entry point, database initialization, repository, controllers, routes, notification hooks, and AI endpoint.
- [ ] Use the same documented API contract as the app, while following the website's existing framework and conventions.
- [ ] Apply the same object-level authorization, sharing permissions, disconnect/revoke behavior, and privacy filtering as the app.
- [ ] Add website-specific responsive behavior for desktop, tablet, and mobile browser widths.
- [ ] Add website backend tests for schema, repository, routes, hooks, authorization, notifications, and AI context filtering.
- [ ] Add website frontend/model tests for complete, partial, loading, empty, error, unauthorized, offline, and logged-out states.
- [ ] Run the website's dependency install, lint/analyze, test, and production build commands.
- [ ] Verify the website can connect to the intended backend using configured environment variables without committed secrets.
- [ ] Compare app and website payloads and manually test the same privacy matrix against both products.

**Acceptance:** the website is a separate runnable product with its own verified frontend/backend implementation, responsive UI, tests, production build, and parity with the app's contract and privacy rules. If the website source is absent, mark this phase `[-] BLOCKED` with the exact missing path; do not mark it `[x]`.

## Phase 10: Tests And Static Validation

- [ ] From `BLUSHY_MAINAPP`, run `flutter pub get`.
- [ ] From `BLUSHY_MAINAPP`, run `flutter analyze` and resolve all new diagnostics.
- [ ] From `BLUSHY_MAINAPP`, run `flutter test` and focused partner/widget tests.
- [ ] From `BLUSHY_MAINAPP/backend`, run available backend tests; add a `test` script only if no runnable test command exists.
- [ ] Run `npm run lint:security` from `BLUSHY_MAINAPP/backend`.
- [ ] From the website target, install dependencies and run its lint/analyze, frontend tests, backend tests, and production build.
- [ ] Start both products locally and verify that app and website reach the intended backend without hard-coded local-only URLs.
- [ ] Exercise the API with a local authenticated setup: owner, connected partner, unrelated user, revoked permissions, logout, and expired connection.
- [ ] Verify repeated requests do not duplicate notifications or corrupt read/viewed state.
- [ ] Verify database initialization against empty and populated test data.
- [ ] Record commands, pass/fail results, and unrelated pre-existing failures.

## Phase 11: Security, Privacy And Release Review

- [ ] Review every endpoint for authentication, authorization, object-level access control, input validation, rate limiting, and safe errors.
- [ ] Confirm logs and analytics contain no sensitive health values or AI prompt content.
- [ ] Confirm notification previews do not reveal restricted health information on a lock screen unless product policy allows it.
- [ ] Confirm disconnect/revoke behavior immediately removes access and stops future notifications.
- [ ] Confirm logout clears in-memory partner data, timers, pending requests, and cached notifications.
- [ ] Confirm production configuration has no debug endpoints, mock data, test credentials, or permissive CORS changes.
- [ ] Update `README.md` or feature documentation if endpoint usage, setup, or privacy behavior changed.
- [ ] Review the final diff for unrelated formatting, generated files, secrets, and accidental changes to `BlushyBeta`.

## Final Definition Of Done

- [ ] All applicable checklist items are `[x]`; blocked items include a reason and owner.
- [ ] Backend schema, repository, controller, route, hook, and AI tests pass.
- [ ] Flutter analyze and tests pass.
- [ ] Security-log validation passes.
- [ ] Manual privacy matrix passes for owner, partner, unrelated user, revoked permission, disconnected state, and logout.
- [ ] Mobile and web UI states have been checked.
- [ ] The app and website are both runnable from documented commands.
- [ ] App-versus-website parity has been checked for API payloads, permissions, notifications, AI suggestions, and responsive states.
- [ ] API contract and documentation match the shipped implementation.
- [ ] Verification commands and known unrelated failures are recorded below.

## Verification Log

Record the date, command, result, and relevant output here. Never paste secrets or personal health data.

| Date | Command/check | Result | Notes |
|---|---|---|---|
| 2026-08-26 | Initial tracker review | Pending | Existing phases 1-10 were marked complete; detailed verification was not recorded. App target is `BLUSHY_MAINAPP`; website target still requires confirmation. |

## Known Blockers

- [ ] Confirm the website target path before implementation. Current checkout has `BlushyBeta` and `blushy_flutter_ui 6`, but no directory explicitly named `website blushy`.

