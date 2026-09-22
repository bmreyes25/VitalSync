# VitalSync public website

GitHub Pages publishes this directory. Before the first public deployment:

1. Create or connect the repository at `https://github.com/bmreyes25/VitalSync`.
2. In the GitHub repository, open **Settings → Pages** and select **GitHub Actions** as the source.
3. Push `main`. The workflow publishes the site at `https://bmreyes25.github.io/VitalSync/`.
4. Use these URLs in the Oura developer application:
   - Website: the published home page
   - Privacy policy: `/privacy.html`
   - Terms of service: `/terms.html`
   - Support: `/support.html`

Do not use a GitHub Pages URL as the OAuth redirect. GitHub Pages is static and must not receive OAuth authorization codes. Use the HTTPS token-broker callback URL configured for the app and Oura developer application.
