interface Env {
  OURA_CLIENT_ID: string;
  OURA_CLIENT_SECRET: string;
  ALLOWED_REDIRECT_URI: string;
}

type ExchangeBody = { code?: string; redirect_uri?: string };
type RefreshBody = { refresh_token?: string };

const OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") return response({ error: "method_not_allowed" }, 405);

    const url = new URL(request.url);
    if (url.pathname === "/v1/oauth/oura/exchange") {
      const body = await safeJSON<ExchangeBody>(request);
      if (!body?.code || body.redirect_uri !== env.ALLOWED_REDIRECT_URI) {
        return response({ error: "invalid_request" }, 400);
      }
      return exchangeWithOura({
        grant_type: "authorization_code",
        code: body.code,
        redirect_uri: body.redirect_uri,
      }, env);
    }

    if (url.pathname === "/v1/oauth/oura/refresh") {
      const body = await safeJSON<RefreshBody>(request);
      if (!body?.refresh_token) return response({ error: "invalid_request" }, 400);
      return exchangeWithOura({ grant_type: "refresh_token", refresh_token: body.refresh_token }, env);
    }

    return response({ error: "not_found" }, 404);
  },
};

async function exchangeWithOura(fields: Record<string, string>, env: Env): Promise<Response> {
  if (!isConfigured(env)) return response({ error: "broker_not_configured" }, 503);
  const form = new URLSearchParams({
    ...fields,
    client_id: env.OURA_CLIENT_ID,
    client_secret: env.OURA_CLIENT_SECRET,
  });
  const upstream = await fetch(OURA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json" },
    body: form,
  });
  const payload = await upstream.json<unknown>();
  return response(payload, upstream.ok ? 200 : upstream.status);
}

function isConfigured(env: Env): boolean {
  return Boolean(env.OURA_CLIENT_ID && env.OURA_CLIENT_SECRET &&
    !env.OURA_CLIENT_ID.startsWith("YOUR_") && !env.OURA_CLIENT_SECRET.startsWith("YOUR_"));
}

async function safeJSON<T>(request: Request): Promise<T | null> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) return null;
  try { return await request.json<T>(); } catch { return null; }
}

function response(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Pragma": "no-cache",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
