# Oura developer application setup

After the GitHub Pages site and token broker are deployed, configure the Oura application with exact production URLs:

- Application name: `VitalSync`
- Website: `https://bmreyes25.github.io/VitalSync/`
- Privacy policy: `https://bmreyes25.github.io/VitalSync/privacy.html`
- Terms of service: `https://bmreyes25.github.io/VitalSync/terms.html`
- Support: `https://bmreyes25.github.io/VitalSync/support.html`
- Redirect URI: `vitalsync://oauth/oura/callback`

Request only the scopes used by VitalSync. Do not request email. The initial requested set is Personal, Daily, Heartrate, Tag, Workout, Session, SpO₂, Ring Configuration, Stress, and Heart Health where Oura makes those scopes available to the application.

GitHub Pages is suitable for the public website, privacy policy, terms, and support pages. It is not used for OAuth. Oura returns the short-lived authorization code to `ASWebAuthenticationSession` through VitalSync's registered callback scheme; the app validates `state` and sends the code to the HTTPS broker for exchange. The same redirect URI is included in both authorization and token-exchange requests and must match Oura's registered value exactly.

The Oura client ID is safe to configure in the app. The Oura client secret must remain exclusively in the broker’s encrypted runtime secret store.
