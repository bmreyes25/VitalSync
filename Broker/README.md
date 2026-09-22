# VitalSync Oura token broker

This minimal Cloudflare Worker keeps the Oura client secret off the iOS device. It accepts an authorization code or rotating refresh token over HTTPS, forwards it to Oura, and returns the token response with `no-store` headers. It deliberately performs no request or response logging.

## Configure and deploy

1. Sign in to Cloudflare with `npx wrangler login`.
2. Enter the Client ID through Cloudflare's protected prompt with `npx wrangler secret put OURA_CLIENT_ID`.
3. Enter the replacement Client Secret through the protected prompt with `npx wrangler secret put OURA_CLIENT_SECRET`.
4. Run `npm install`, `npm run typecheck`, then `npm run deploy`.
5. Configure the exact same redirect URI in the Oura developer application and the iOS app.

For local Worker development only, copy `.env.example` to `.dev.vars`. That file is ignored by Git. Never paste a real Client Secret into source, GitHub settings, Xcode, an issue, a commit, or chat.

For production, add app attestation, request-rate limiting, abuse monitoring that never logs token bodies, and one-time authorization-code replay protection at the edge. Rotate the Oura client secret if it is ever exposed.
