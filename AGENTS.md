# VitalSync Engineering Requirements

## Mission

Build VitalSync as a production-quality, App Store-ready native iOS app that lets a user privately import authorized Oura API v2 data, retain a faithful local record, and write only semantically valid samples to Apple Health.

The functional sync core takes priority over visual polish. Continue iteratively toward a working app; do not stop at scaffolding.

## Non-negotiable privacy and security

- Never request, read, print, commit, transmit to an AI model, or otherwise expose real Oura client secrets, OAuth tokens, user health records, or exported HealthKit data.
- Use fabricated, clearly synthetic fixtures in source, tests, previews, logs, and debugging.
- The iOS app must never contain an Oura client secret. OAuth code exchange and refresh go through a deployable server-side token broker.
- Use `ASWebAuthenticationSession` for authorization and a callback URL owned by VitalSync.
- Store mobile credentials only in Keychain with an appropriate accessibility class; never in `UserDefaults`, SwiftData, source, or logs.
- Redact tokens, authorization codes, URLs containing sensitive query parameters, identifiers, and health values from production logs.
- Collect no analytics, advertising identifiers, tracking data, or third-party telemetry.
- Provide privacy controls for connection state, per-category import/export choices, local-data deletion, HealthKit authorization guidance, and account disconnection.
- Request only needed Oura scopes. Email is not required. Supported authorized data scopes are Personal, Daily, Heartrate, Tag, Workout, Session, SpO2, Ring Configuration, Stress, and Heart Health.

## Architecture

- Native Swift and SwiftUI, with Apple-quality platform conventions and a minimum deployment target suitable for SwiftData and modern Observation.
- Separate app/UI, domain, persistence, HealthKit, Oura transport/authentication, and sync orchestration concerns. Keep services injectable and business logic testable without live services.
- Use structured concurrency and actors for mutable service state.
- Implement an actor-based single-flight token refresh coordinator. Multiple callers encountering expiry must await one refresh operation. Treat Oura refresh tokens as rotating: persist the replacement atomically and never reuse the old token after success.
- Use SwiftData for local persistence, including raw/unmappable normalized metrics, sync cursors, authorization/account metadata that is not secret, and an idempotent sync ledger.
- Keep secrets behind a Keychain abstraction.
- Use protocol-driven clocks, networking, persistence boundaries, HealthKit writing, and credential storage where determinism or testing benefits.
- Avoid global singletons. Construct the production dependency graph once at the app root and inject dependencies explicitly or through typed SwiftUI environment values.

## Oura API v2

- Support decoding and pagination for every endpoint needed by all authorized scopes, including personal info, daily activity, readiness, sleep, cardiovascular age, resilience, stress, sleep time, heartrate, tags, workouts, sessions, SpO2, ring configuration, and heart-health-related data available to the application.
- Models must preserve source identity, timestamps/time zones, units, source endpoint, and fields needed for reconciliation. Use tolerant decoding for forward-compatible optional fields without silently changing meaning.
- Centralize HTTP behavior: authorization, status validation, pagination, cancellation, bounded exponential backoff with jitter, `Retry-After` handling for HTTP 429, and retry only for safe/transient failures.
- Support historical backfill in bounded date windows and incremental foreground/manual/background sync.
- The token broker contract must be documented and versioned. The broker template must be minimally deployable, validate redirect/state inputs, use placeholder environment variables, avoid logging secrets, and contain no real credentials.

## HealthKit semantics

- HealthKit access must degrade gracefully when only some types are authorized. Never assume read authorization can be inferred from HealthKit APIs.
- Maintain an explicit reviewed mapping table with source metric, destination HealthKit identifier, unit conversion, aggregation semantics, timestamp rules, metadata, and unsupported rationale.
- Write only measurements with equivalent physiological meaning and compatible aggregation. Preserve Oura source IDs in metadata for reconciliation and duplicate detection.
- Oura RMSSD must never be written or labeled as HealthKit heart-rate variability SDNN.
- Provide `HRVTranslationEngine` and `SDNNCalculator` domain components ready to calculate true SDNN only when legitimate beat-to-beat RR/NN intervals become available. Do not estimate SDNN from RMSSD or summary heart-rate values.
- Metrics without a semantically correct HealthKit destination stay available locally.
- HealthKit saves must be idempotent, reconcile existing VitalSync samples, and tolerate partial batch failures without duplicating successful writes.

## Sync correctness

- Use a deterministic ledger key based on source, endpoint/category, stable source record ID, source revision/fingerprint, and destination.
- Re-running any sync range must be safe and idempotent.
- Detect exact duplicates, source updates, local conflicts, deleted/invalidated records where supported, and partially completed exports. Reconcile rather than blindly append.
- Commit cursors only after corresponding normalized records and ledger outcomes are durably recorded.
- Make pagination loop-safe and test repeated/empty pages, next-token cycles, cancellation, malformed responses, and resumability.
- Expose meaningful sync progress and an auditable, privacy-safe local history of outcome counts and errors.
- Schedule background work using supported iOS background mechanisms while keeping manual and foreground sync fully functional when background execution is unavailable.

## UI and accessibility

- SwiftUI UI should feel native and calm, with a small functional surface: connection/onboarding, sync dashboard, locally retained metrics/history, and privacy/settings.
- Use system typography, semantic colors, symbols, controls, navigation, sheets, and feedback. Support light/dark mode.
- Support Dynamic Type without clipping, VoiceOver labels/hints/traits, sufficient contrast, comfortable hit targets, keyboard/switch accessibility where applicable, and reduced-motion alternatives.
- Every async screen needs explicit loading, empty, success, partial-permission, offline, and recoverable error states.
- Never display a secret or full sensitive payload in diagnostics.

## Testing and fixtures

- Use only fabricated synthetic fixtures with impossible/test identifiers and documented provenance.
- Add extensive unit coverage for model decoding, pagination, retry and `Retry-After`, authentication errors, single-flight refresh, rotating-token persistence, Keychain abstraction behavior, date/time-zone and unit conversions, mapping eligibility, RMSSD exclusion, true SDNN math, ledger idempotency, duplicate reconciliation, backfill windows, partial permissions, cancellation, and redacted logging.
- Add integration tests using in-memory persistence, fake Oura transport/token broker, and fake HealthKit writer. No tests may contact Oura or read the simulator/device Health database.
- Add UI/accessibility tests for key states when the functional core is stable.

## Build and delivery discipline

- Build and test after every major milestone. Fix errors and warnings at their cause; do not suppress them.
- Inspect the diff before each checkpoint. Make small, coherent Git commits with messages that explain the completed milestone.
- Never commit derived data, local signing material, `.env` files, secrets, tokens, private health exports, or generated credentials.
- Keep the project buildable for the iOS Simulator without requiring live Oura credentials or HealthKit data.
- Prefer Apple frameworks and a minimal dependency footprint.
- Keep user-facing configuration examples limited to placeholders such as `YOUR_OURA_CLIENT_ID` and `https://auth.example.com`.

## Initial delivery sequence

1. Repository, Xcode project, secure configuration placeholders, domain models, mapping policy, and core algorithms.
2. Oura client, broker-backed OAuth, Keychain store, pagination/retry, and single-flight refresh.
3. SwiftData persistence, deterministic ledger, reconciliation, backfill, and sync orchestration.
4. HealthKit authorization/writer and background scheduling.
5. Functional SwiftUI flows, privacy controls, and accessibility.
6. Synthetic fixtures, comprehensive tests, broker deployment documentation, visual polish, and release checks.
