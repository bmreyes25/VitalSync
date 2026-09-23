# VitalSync App Store release checklist

## Build identity

- Product name: `VitalSync`
- Bundle identifier: `com.bmreyes25.VitalSync`
- Minimum version: iOS and iPadOS 27.0
- Marketing version: `1.0.0`
- Build number: `1`
- Category recommendation: Health & Fitness
- No analytics, advertising, tracking, or third-party telemetry

## Public URLs

- Marketing: `https://bmreyes25.github.io/VitalSync/`
- Support: `https://bmreyes25.github.io/VitalSync/support.html`
- Privacy policy: `https://bmreyes25.github.io/VitalSync/privacy.html`
- Terms: `https://bmreyes25.github.io/VitalSync/terms.html`

## Suggested listing

- Subtitle: `Traceable Oura sleep metrics`
- Promotional text: `Keep recent Oura heart rate, sleep SpO₂ average, HRV, and temperature change in a private local record.`
- Keywords: `oura,health,wellness,privacy,heart,rate,import`

### Description

VitalSync lets you manually import the last seven days of authorized Oura heart rate, sleep SpO₂ average, sleep HRV, and readiness temperature deviation. Review each measurement's source, timing precision, and local import history on your iPhone. VitalSync does not duplicate samples that Oura can already send to Apple Health.

VitalSync never sees your Oura password or passkey. OAuth credentials are protected in the iOS Keychain. Imported metrics remain local in this build. Health records are not used for advertising or tracking. Oura RMSSD is never mislabeled as HealthKit SDNN.

## Account-owner steps before submission

1. Join the Apple Developer Program and select the development team in Xcode.
2. Register `com.bmreyes25.VitalSync` in Certificates, Identifiers & Profiles. Enable HealthKit only for a version with a tested, eligible export. If a different permanent identifier is preferred, change it before creating the App Store record.
3. Create the App Store Connect app record, complete agreements, tax, banking, export-compliance, age-rating, and content-rights questions.
4. Add the privacy-policy and support URLs above. Review the App Privacy answer against the final broker and app behavior; the current design does not retain health or identity data on developer-controlled servers.
5. Obtain production approval for the Oura application and verify `heartrate`, `daily`, and `spo2` scopes. Limit requested scopes to those used by the submitted build.
6. Add App Attest validation, edge rate limiting, and authorization-code replay protection to the token broker before external distribution.
7. Capture one to ten accurate screenshots using fabricated records only. The debug-only `-SyntheticStoreScreenshots` launch argument permits capture without weakening release privacy. Never upload real health information in store media; avoid representing a synthetic preview control as a release feature.
8. Run a signed Archive validation and TestFlight review on physical iPhone and iPad hardware.
9. Exercise a real Oura account end-to-end on device without sharing credentials or health records with the development assistant. Supply App Review with a usable account or an approved review path if login is required.

## Current release status

The simulator build and tests are development checks, not an App Store approval. Manual seven-day import covers heart rate, sleep HRV, daily sleep SpO₂ average, and readiness temperature deviation. Other Oura endpoint models and background-sync infrastructure are not yet release functionality. Do not advertise them or submit until completed and tested. App Review Guideline 4.2 emphasizes real utility; the best response to a previous rejection is a complete, working app and accurate metadata, not an unsupported promise about how the app was made.

Oura's own iOS app already exports heart rate and other common measurements to Apple Health. Therefore VitalSync does not export them in this build. Prioritize the auditable local record plus semantically safe, genuinely missing exports before submission. Daily SpO₂ has only a day and daily average in Oura's public schema; VO₂ max lacks a calculation-method field. Do not invent an interval or exercise-test provenance to force either into HealthKit. Cross-app HealthKit duplicate detection needs explicit read permission and a reviewed design; do not claim it exists now.

Reviewer note, once the on-device flow is verified: "VitalSync is a native health-data utility. It does not provide a generative-AI feature or send health records to an AI service. Sign in through Oura's system-browser flow, grant heart rate, daily, and SpO₂ access, use Import last 7 days, and review records in Data. Sleep HRV remains labeled RMSSD and temperature remains labeled as deviation from baseline. This version keeps imports local." Supply review credentials or an Apple-accepted review method separately; never put them in source, screenshots, or a model conversation.

## Guideline 4.3(a) distinctiveness check

- Do not reuse a purchased app template, other developers' source, generic screenshot set, or another app's icon. VitalSync's visual assets and source should have clear provenance.
- Show the actual Oura-to-local workflow, per-record provenance, duplicate reconciliation, and RMSSD/SDNN safeguard in accurate screenshots and reviewer notes. Do not depict an Apple Health export until a missing, equivalent data type is implemented.
- Search the live App Store for close Oura import utilities before submission and compare the final feature set and metadata honestly. No change can guarantee App Review approval.
- If Apple raises 4.3(a), respond in App Store Connect with concrete feature and code/asset provenance evidence, and ask which similarity remains. Do not claim that AI assistance was prohibited or that its absence guarantees approval.

## Release gates

- `PrivacyInfo.xcprivacy` declares no tracking, collected data, or required-reason API use. Re-audit whenever dependencies or system API usage changes.
- App icon is an original 1024×1024 opaque asset without pre-rounded corners.
- HealthKit purpose strings and entitlement remain in the development project for a future reviewed export; remove unused HealthKit capability from the submitted build if no eligible export is ready.
- Release builds hide synthetic preview controls.
- No secret, token, health export, `.env`, signing file, or provisioning profile may be committed.
