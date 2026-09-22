# VitalSync security model

## Authentication

- Oura login uses `ASWebAuthenticationSession` with the shared browser session. Password AutoFill, iCloud Keychain verification codes, existing Oura sessions, and Oura-supported passkeys remain inside Apple’s protected browser authentication experience.
- VitalSync never receives an Oura password, verification code, or passkey private key.
- The iOS app contains no Oura client secret. Authorization-code exchange and refresh occur through the HTTPS token broker.
- OAuth `state` is generated with `SecRandomCopyBytes` and validated using an exact match.
- Access and rotating refresh tokens are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, are not synchronized to iCloud Keychain, and are never logged.
- Concurrent refresh callers share one actor-owned refresh task. A successful response atomically replaces the old refresh token in Keychain.

## Health data

- HealthKit permission is requested separately for every supported type. Denied read access is treated as no data, consistent with HealthKit privacy behavior.
- The mapping policy permits only measurements with equivalent meaning, units, and aggregation. Oura RMSSD is retained locally and never written as HealthKit SDNN.
- HealthKit writes include stable sync metadata, query and remove an earlier VitalSync revision, and record durable ledger outcomes to prevent duplicates.
- App content is marked privacy-sensitive and covered when the scene becomes inactive or backgrounded, reducing disclosure in app-switcher snapshots.
- Local transfer operations require the device to be unlocked, the app to be active, and fresh explicit consent for the specific operation.
- Imported files must use the VitalSync file type, be regular files, and remain within a bounded size. Temporary exports receive complete file protection and are excluded from backup.
- Operational logs contain event names and stable error codes only—not tokens, authorization codes, source identifiers, URLs with queries, or health values.

## Network and server

- The mobile broker client requires HTTPS outside local debug development.
- Broker responses use `Cache-Control: no-store`; the template never logs request or response bodies.
- The static GitHub Pages site never receives OAuth callbacks, tokens, or health data.
- Before production launch, add App Attest validation, broker rate limiting, authorization-code replay protection, and a short-lived broker session binding the callback to the originating device.

## Credential setup

- The Oura client ID and broker URL may be supplied through a local ignored configuration file.
- Store `OURA_CLIENT_SECRET` only through the deployment platform’s encrypted secret facility, such as `wrangler secret put OURA_CLIENT_SECRET`.
- Never send the client secret in chat, email, screenshots, issues, build logs, `.xcconfig`, `.plist`, or source control.

## Incident response

If any OAuth secret or token is exposed, revoke affected access, rotate the Oura client secret, invalidate broker sessions, remove the exposed material from reachable systems, and review redacted operational events for abuse. Do not copy exposed values into a bug report.
