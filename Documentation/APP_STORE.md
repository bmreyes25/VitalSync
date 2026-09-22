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

- Subtitle: `Private Oura heart rate import`
- Promotional text: `Import seven days of Oura heart rate records to your iPhone, with an optional Apple Health write.`
- Keywords: `oura,health,wellness,privacy,heart,rate,import`

### Description

VitalSync lets you manually import the last seven days of authorized Oura heart rate measurements. Review imported records on your iPhone and choose whether to write heart rate to Apple Health. Apple Health export is off by default.

VitalSync never sees your Oura password or passkey. OAuth credentials are protected in the iOS Keychain. Imported metrics remain local unless you enable Apple Health export. Health records are not used for advertising or tracking. Oura RMSSD is never mislabeled as HealthKit SDNN.

## Account-owner steps before submission

1. Join the Apple Developer Program and select the development team in Xcode.
2. Register `com.bmreyes25.VitalSync` in Certificates, Identifiers & Profiles with HealthKit enabled. If a different permanent identifier is preferred, change it before creating the App Store record.
3. Create the App Store Connect app record, complete agreements, tax, banking, export-compliance, age-rating, and content-rights questions.
4. Add the privacy-policy and support URLs above. Review the App Privacy answer against the final broker and app behavior; the current design does not retain health or identity data on developer-controlled servers.
5. Obtain production approval for the Oura application and verify the heart-rate scope. Limit requested scopes to those used by the submitted build.
6. Add App Attest validation, edge rate limiting, and authorization-code replay protection to the token broker before external distribution.
7. Capture one to ten accurate screenshots using fabricated records only. The debug-only `-SyntheticStoreScreenshots` launch argument permits capture without weakening release privacy. Never upload real health information in store media; avoid representing a synthetic preview control as a release feature.
8. Run a signed Archive validation and TestFlight review on physical iPhone and iPad hardware.
9. Exercise a real Oura account end-to-end on device without sharing credentials or health records with the development assistant. Supply App Review with a usable account or an approved review path if login is required.

## Current release status

The simulator build and tests are development checks, not an App Store approval. Manual seven-day heart-rate import is the only live sync path. Other Oura endpoint models and background-sync infrastructure are not yet release functionality. Do not advertise them or submit until completed and tested. App Review Guideline 4.2 emphasizes real utility; the best response to a previous rejection is a complete, working app and accurate metadata, not an unsupported promise about how the app was made.

Reviewer note, once the on-device flow is verified: "VitalSync is a native health-data utility. It does not provide a generative-AI feature or send health records to an AI service. Sign in through Oura's system-browser flow, use Import last 7 days, review records in Data, and optionally enable heart-rate writing to Apple Health in Privacy." Supply review credentials or an Apple-accepted review method separately; never put them in source, screenshots, or a model conversation.

## Release gates

- `PrivacyInfo.xcprivacy` declares no tracking, collected data, or required-reason API use. Re-audit whenever dependencies or system API usage changes.
- App icon is an original 1024×1024 opaque asset without pre-rounded corners.
- HealthKit purpose strings are included and must continue to match actual behavior.
- Release builds hide synthetic preview controls.
- No secret, token, health export, `.env`, signing file, or provisioning profile may be committed.
