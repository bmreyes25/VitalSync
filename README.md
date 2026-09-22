# VitalSync

VitalSync is a native iOS app for private, semantically correct synchronization of authorized Oura API v2 measurements into Apple Health.

## Repository layout

- `VitalSync/App` — application entry point, root navigation, and shared app state
- `VitalSync/Features` — user-facing Sync, Data, and Privacy features
- `VitalSync/Domain` — platform-independent health semantics and redacted logging
- `VitalSync/Oura` — OAuth, Keychain credentials, token broker client, models, and API transport
- `VitalSync/HealthKit` — reviewed mappings, permission requests, and reconciled writes
- `VitalSync/Persistence` — SwiftData records and deterministic sync ledger
- `VitalSync/Sync` — backfill, background scheduling, and orchestration
- `VitalSync/Security` — privacy shielding and health-data transfer policy
- `VitalSync/Configuration` — placeholder-only local configuration template
- `VitalSyncTests` — synthetic-fixture unit and integration tests
- `Broker` — server-side Oura OAuth token broker template
- `docs` — static GitHub Pages product, privacy, terms, and support site
- `Documentation` — architecture and security guidance

Run `xcodegen generate` after adding or moving source files, then open `VitalSync.xcodeproj`.

No real Oura secret, OAuth credential, or health record belongs in this repository, an issue, a test fixture, or an AI conversation.
