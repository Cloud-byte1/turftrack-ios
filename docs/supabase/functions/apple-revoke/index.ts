// Revokes a user's Sign in with Apple tokens before their fairLie account is deleted
// (App Store Review Guideline 5.1.1(v)).
//
// The app sends a fresh Apple authorization code. This function exchanges it for a refresh
// token and then calls Apple's revoke endpoint. Both calls need a client secret signed with
// your Sign in with Apple private key, so this must run server-side.
//
// Secrets (Dashboard -> Edge Functions -> Secrets, or `supabase secrets set`):
//   APPLE_TEAM_ID      10-character Apple Developer Team ID
//   APPLE_KEY_ID       Key ID of a key with "Sign in with Apple" enabled
//   APPLE_PRIVATE_KEY  Full contents of the downloaded AuthKey_<KEY_ID>.p8 file
//   APPLE_CLIENT_ID    Optional; defaults to the app bundle ID com.fairlie.turftrack
// SUPABASE_URL and SUPABASE_ANON_KEY are provided automatically.

const APPLE = "https://appleid.apple.com";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const user = await currentUser(req.headers.get("Authorization"));
  if (!user) return json({ error: "Sign in again, then retry." }, 401);
  const isApple = (user.identities ?? []).some((i) => i.provider === "apple") ||
    user.app_metadata?.provider === "apple";
  if (!isApple) return json({ revoked: false, reason: "Account does not use Sign in with Apple." });

  const { code } = await req.json().catch(() => ({ code: undefined }));
  if (typeof code !== "string" || code.length === 0) {
    return json({ error: "Missing Apple authorization code." }, 400);
  }

  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientId = Deno.env.get("APPLE_CLIENT_ID") ?? "com.fairlie.turftrack";
  if (!teamId || !keyId || !privateKey) {
    return json({ error: "Sign in with Apple revocation is not configured on the server." }, 500);
  }

  const clientSecret = await appleClientSecret(teamId, keyId, privateKey, clientId);

  const tokenRes = await form(`${APPLE}/auth/token`, {
    client_id: clientId,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
  });
  const tokenBody = await tokenRes.json().catch(() => ({}));
  const token: string | undefined = tokenBody.refresh_token ?? tokenBody.access_token;
  if (!tokenRes.ok || !token) {
    return json({ error: `Apple rejected the authorization code (${tokenBody.error ?? tokenRes.status}).` }, 502);
  }

  const revokeRes = await form(`${APPLE}/auth/revoke`, {
    client_id: clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: tokenBody.refresh_token ? "refresh_token" : "access_token",
  });
  if (!revokeRes.ok) {
    return json({ error: `Apple did not revoke the token (${revokeRes.status}).` }, 502);
  }
  return json({ revoked: true });
});

type AuthUser = {
  id: string;
  app_metadata?: { provider?: string };
  identities?: { provider: string }[];
};

async function currentUser(authorization: string | null): Promise<AuthUser | null> {
  if (!authorization?.startsWith("Bearer ")) return null;
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
  });
  return res.ok ? await res.json() : null;
}

// ES256 JWT Apple accepts as client_secret; valid for 5 minutes.
async function appleClientSecret(teamId: string, keyId: string, pem: string, clientId: string) {
  const der = base64Decode(
    pem.replace(/\\n/g, "\n").replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64url(JSON.stringify({
    iss: teamId,
    iat: now,
    exp: now + 300,
    aud: APPLE,
    sub: clientId,
  }));
  const signingInput = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

function form(url: string, body: Record<string, string>) {
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body),
  });
}

function base64Decode(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
