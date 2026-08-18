import { and, desc, eq, like } from "drizzle-orm";
import { beforeEach, describe, expect, it } from "vitest";
import db, { schema } from "../../apps/api/src/database";
import { createApp } from "../../apps/api/src/index";
import { resetTestDatabase } from "./helpers/database";

type App = ReturnType<typeof createApp>["app"];

function applyCookies(existing: string, response: Response) {
  const jar = new Map<string, string>();

  for (const pair of existing.split("; ").filter(Boolean)) {
    const [name, ...value] = pair.split("=");
    if (name) jar.set(name, value.join("="));
  }

  for (const setCookie of response.headers.getSetCookie()) {
    const [pair] = setCookie.split(";");
    const [name, ...value] = (pair ?? "").split("=");
    if (!name) continue;
    if (value.join("=") === "") {
      jar.delete(name);
      continue;
    }
    jar.set(name, value.join("="));
  }

  return [...jar].map(([name, value]) => `${name}=${value}`).join("; ");
}

function collectCookies(response: Response) {
  return applyCookies("", response);
}

async function signUp(
  app: App,
  email: string,
  name = "2FA Bypass",
): Promise<string> {
  const response = await app.request("/api/auth/sign-up/email", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      email,
      password: "correct horse battery staple",
      name,
    }),
  });
  expect(response.status).toBe(200);
  return collectCookies(response);
}

/** Aktiviert 2FA direkt in der DB (der echte Enable-Fluss ist E2E J-08 abgedeckt). */
async function enableTwoFactor(email: string): Promise<void> {
  const updated = await db
    .update(schema.userTable)
    .set({ twoFactorEnabled: true })
    .where(eq(schema.userTable.email, email));
  expect(updated.rowCount).toBe(1);
}

async function getSession(app: App, cookies: string) {
  const response = await app.request("/api/auth/get-session", {
    headers: { cookie: cookies },
  });
  return (await response.json()) as { user: { email: string } } | null;
}

/** Liest den Klartext-Sign-in-OTP aus der verification-Tabelle. */
async function readSignInOtp(email: string): Promise<string> {
  const [row] = await db
    .select({ value: schema.verificationTable.value })
    .from(schema.verificationTable)
    .where(eq(schema.verificationTable.identifier, `sign-in-otp-${email}`))
    .limit(1);
  if (!row) throw new Error(`Kein sign-in OTP für ${email} gefunden`);
  return row.value.split(":")[0];
}

/** Liest den Magic-Link-Token aus der verification-Tabelle. */
async function readMagicLinkToken(email: string): Promise<string> {
  const [row] = await db
    .select({ identifier: schema.verificationTable.identifier })
    .from(schema.verificationTable)
    .where(
      and(
        like(schema.verificationTable.value, `%${email}%`),
        eq(
          schema.verificationTable.identifier,
          schema.verificationTable.identifier,
        ),
      ),
    )
    .orderBy(desc(schema.verificationTable.createdAt))
    .limit(1);
  if (!row) throw new Error(`Kein Magic-Link-Token für ${email} gefunden`);
  return row.identifier;
}

describe("API integration: 2FA blockiert die passwortlosen Anmeldewege", () => {
  beforeEach(async () => {
    await resetTestDatabase();
  });

  it("lehnt E-Mail-OTP-Anmeldung für ein 2FA-Konto ab (keine Session)", async () => {
    const { app } = createApp();
    const email = "otp-2fa@example.com";
    await signUp(app, email);
    await enableTwoFactor(email);

    // Code anfordern und aus der DB lesen (storeOTP = plain).
    const sendRes = await app.request(
      "/api/auth/email-otp/send-verification-otp",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, type: "sign-in" }),
      },
    );
    expect(sendRes.status).toBe(200);
    const otp = await readSignInOtp(email);

    // Anmeldung mit korrektem OTP — darf KEINE Session erzeugen.
    const signInRes = await app.request("/api/auth/sign-in/email-otp", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, otp }),
    });
    expect(signInRes.status).toBe(401);

    const cookies = collectCookies(signInRes);
    expect(await getSession(app, cookies)).toBeNull();
  });

  it("lehnt Magic-Link-Anmeldung für ein 2FA-Konto ab (keine Session)", async () => {
    const { app } = createApp();
    const email = "magic-2fa@example.com";
    await signUp(app, email);
    await enableTwoFactor(email);

    const linkRes = await app.request("/api/auth/sign-in/magic-link", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email }),
    });
    expect(linkRes.status).toBe(200);
    const token = await readMagicLinkToken(email);

    const verifyRes = await app.request(
      `/api/auth/magic-link/verify?token=${encodeURIComponent(token)}&callbackURL=/dashboard`,
      { method: "GET", headers: { cookie: collectCookies(linkRes) } },
    );
    expect(verifyRes.status).toBe(401);

    const cookies = collectCookies(verifyRes);
    expect(await getSession(app, cookies)).toBeNull();
  });

  it("Nicht-Regression: ein Konto OHNE 2FA kann sich per E-Mail-OTP anmelden", async () => {
    const { app } = createApp();
    const email = "otp-no2fa@example.com";
    await signUp(app, email);

    await app.request("/api/auth/email-otp/send-verification-otp", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, type: "sign-in" }),
    });
    const otp = await readSignInOtp(email);

    const signInRes = await app.request("/api/auth/sign-in/email-otp", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, otp }),
    });
    expect(signInRes.status).toBe(200);

    const cookies = collectCookies(signInRes);
    const session = await getSession(app, cookies);
    expect(session?.user.email).toBe(email);
  });
});
