# VitalSync Oura token broker

This minimal Cloudflare Worker keeps the Oura client secret off the iOS device. It accepts an authorization code or rotating refresh token over HTTPS, forwards it to Oura, and returns the token response with `no-store` headers. It deliberately performs no request or response logging.

## Configure and deploy

1. Replace the placeholder `OURA_CLIENT_ID` and `ALLOWED_REDIRECT_URI` in `wrangler.toml`.
2. Store the secret outside source control with `npx wrangler secret put OURA_CLIENT_SECRET`.
3. Run `npm install`, `npm run typecheck`, then `npm run deploy`.
4. Configure the exact same redirect URI in the Oura developer application and the iOS app.

For production, add app attestation, request-rate limiting, abuse monitoring that never logs token bodies, and one-time authorization-code replay protection at the edge. Rotate the Oura client secret if it is ever exposed.
