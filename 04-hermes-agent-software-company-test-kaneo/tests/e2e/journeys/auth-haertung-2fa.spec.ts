import { expect, type Page, test } from "@playwright/test";
import db, { schema } from "../../../apps/api/src/database";
import { generateTotp } from "../../../apps/api/src/utils/totp";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";

/**
 * Journey J-08 — Auth-Härtung: Zwei-Faktor-Authentifizierung (TOTP)
 *
 * Erweiterung der Eingangsaufgabe J-01 (Konto anlegen). Roundtrip, der die
 * Aussperr-Befreiung als Akzeptanzkriterium mitträgt: Nach dem Einrichten wird
 * mit einem berechneten TOTP-Code, dann mit einem Backup-Code, dann mit einem
 * absichtlich falschen 6-Steller angemeldet — und am Ende wieder deaktiviert,
 * sodass die Anmeldung ohne 2FA durchkommt (Opt-in-Nicht-Regression).
 *
 * Schritte: 11 · Eigentümer: esf-qa-release
 */

/** Die eindeutige Identität der Journey — in der Beschreibung sichtbar. */
const ich = neueIdentitaet("j08");

async function oeffneSicherheit(page: Page) {
  await page.goto("/dashboard/settings/account/security");
  await expect(page.getByText("Two-factor authentication").first()).toBeVisible(
    { timeout: 30_000 },
  );
}

/** Anmelden (Schritt 7 ff.): nutzt den sichtbaren Anmeldeweg. */
async function anmelden(page: Page, email: string, passwort: string) {
  await page.goto("/auth/sign-in");
  await page.getByLabel("Email").fill(email);
  await page.locator('input[name="password"]').fill(passwort);
  await page.getByRole("button", { name: "Sign In" }).click();
}

/**
 * Abmelden über das Nutzer-Menü (AppSidebar der Arbeitsbereichsseite — auf
 * den Konto-Einstellungen gibt es keine solche Leiste). Von der
 * Einstellungsseite aus als Erstes auf das Dashboard wechseln, das den Nutzer
 * zurück in die App-Bar mit dem Avatar führt.
 */
async function abmelden(page: Page) {
  await page.goto("/dashboard");
  await page.getByLabel("Open user menu").click();
  await page.getByRole("menuitem", { name: "Log out" }).click();
  await expect(page).toHaveURL(/\/auth\/sign-in/, { timeout: 20_000 });
}

/** Aus den 10 einmalig angezeigten Codes einen zurückbehalten. */
async function liesBackupCodes(page: Page): Promise<string[]> {
  const codes = await page.locator("code").allTextContents();
  return codes.map((c) => c.trim()).filter(Boolean);
}

/**
 * Schritt 2–5 der Journey gemeinsam machen: 2FA für das aktuelle Konto
 * aktivieren (Passwort → Secret erfassen → berechneten Code verifizieren) und
 * die einmalig angezeigten Backup-Codes zurückbehalten.
 */
async function aktiviereZweiFaktor(page: Page, passwort: string) {
  await oeffneSicherheit(page);
  await page.getByPlaceholder("Enter your password").fill(passwort);
  await page.getByRole("button", { name: "Enable" }).click();

  // Der erste Client-Aufruf endet mit dem Setup-Screen. Danach erscheint der
  // otpauth://-Text und die Backup-Codes werden einmalig angezeigt.
  await expect(page.getByLabel("Secret (otpauth URI)")).toBeVisible({
    timeout: 20_000,
  });

  // Schritt 3 — Secret erfassen: die otpauth://-URI aus der UI lesen.
  const secretInput = page.getByLabel("Secret (otpauth URI)");
  const totpUri = await secretInput.inputValue();
  const secretMatch = totpUri.match(/secret=([A-Z2-7]+)/i);
  if (!secretMatch) {
    throw new Error(`Keine zu erwartende otpauth://-URI gelesen: ${totpUri}`);
  }
  const secret = secretMatch[1];

  // Schritt 3b — Backup-Codes werden einmalig angezeigt; sie vor der
  // Bestätigung entgegennehmen (Schritt 8 nutzt einen davon).
  const backupCodes = await liesBackupCodes(page);
  expect(backupCodes.length).toBe(10);

  // Schritt 4 — Code im Test berechnen: RFC 6238 (SHA-1, 6 Ziffern, 30 s).
  const code = generateTotp(secret);

  // Schritt 5 — Verifizieren: Der berechnete Code aktiviert das Konto.
  await page.getByLabel("Verification code").fill(code);
  await page.getByRole("button", { name: "Verify and enable" }).click();

  // Nach der Verifikation verschwindet der Setup-Screen; Status „Enabled“.
  await expect(page.getByText("Enabled").first()).toBeVisible({
    timeout: 20_000,
  });

  // Der Einmalig-Nachweis (Akzeptanzkriterium 9): Die Backup-Codes sind
  // nach der Aktivierung nicht mehr aus der UI lesbar.
  await expect(page.getByText("Shown once").first()).toHaveCount(0);

  return { secret, backupCodes };
}

/**
 * Legt einen Sign-in-OTP direkt in der `verification`-Tabelle an. Das
 * email-otp-Plugin speichert den Code `storeOTP: "plain"` als
 * `${otp}:<attempts>` unter dem Identifier `sign-in-otp-<email>`. Der Test
 * trägt den Code so ein, wie die E-Mail ihn geliefert hätte — der echte
 * Codeversand über SMTP würde in der Testumgebung (ohne erreichbaren
 * Mailserver) den Request in die Länge ziehen. Der Browser-Weg, der hier
 * geprüft wird, ist das Eintippen und die Abweisung, nicht der Mailversand.
 */
async function legeSignInOtpAn(email: string, otp = "135790"): Promise<string> {
  const now = new Date();
  await db.insert(schema.verificationTable).values({
    identifier: `sign-in-otp-${email}`,
    value: `${otp}:0`,
    expiresAt: new Date(now.getTime() + 5 * 60 * 1000),
    createdAt: now,
    updatedAt: now,
  });
  return otp;
}

test.describe("J-08 Auth-Härtung: Zwei-Faktor-Authentifizierung", () => {
  test("Roundtrip: aktivieren, authenthizieren, deaktivieren", async ({
    page,
  }) => {
    // Schritt 1 — Vorbereitung: Jungfern-Konto anlegen (wie J-01).
    await kontoAnlegen(page, ich);

    // Schritt 1b — Arbeitsbereich anlegen, um in die Einstellungen zu kommen.
    await arbeitsbereichAnlegen(page, `ESF 2FA ${Date.now()}`);

    // Schritt 2–5 — 2FA aktivieren: Secret erfassen, berechneten Code
    // verifizieren, Backup-Codes einmalig entgegennehmen (gemeinsamer Helper).
    const { secret, backupCodes } = await aktiviereZweiFaktor(
      page,
      ich.passwort,
    );

    // Schritt 6 — Abmelden: über das Nutzer-Menü.
    await abmelden(page);

    // Schritt 7 — Anmelden mit 2FA: nach der Anmeldung landet der Nutzer auf
    // dem 2FA-Code-Bildschirm, nicht im Dashboard.
    await anmelden(page, ich.email, ich.passwort);
    await expect(page).toHaveURL(/\/auth\/two-factor/, { timeout: 30_000 });

    // Schritt 7b — berechneten Code eingeben → Session, Landung im Dashboard.
    const code2 = generateTotp(secret);
    await page.locator('input[name="two-factor-code"]').fill(code2);
    await expect(page).not.toHaveURL(/\/auth\/two-factor/, {
      timeout: 30_000,
    });

    // Schritt 8 — Aussperr-Befreiung über den Backup-Code: abmelden, anmelden,
    // einen der einmalig angezeigten Backup-Codes verwenden.
    await abmelden(page);
    await anmelden(page, ich.email, ich.passwort);
    await expect(page).toHaveURL(/\/auth\/two-factor/, { timeout: 30_000 });
    await page
      .getByRole("button", { name: "Use a backup code instead" })
      .click();
    await page.getByPlaceholder("Backup code").fill(backupCodes[0]);
    await page.getByRole("button", { name: "Verify and sign in" }).click();
    await expect(page).not.toHaveURL(/\/auth\/two-factor/, {
      timeout: 30_000,
    });

    // Schritt 9 — Falscher 6-Steller wird sichtbar abgewiesen und erzeugt
    // keine Session: Der Nutzer bleibt auf dem 2FA-Bildschirm.
    await abmelden(page);
    await anmelden(page, ich.email, ich.passwort);
    await expect(page).toHaveURL(/\/auth\/two-factor/, { timeout: 30_000 });
    // Ein absichtlich falscher 6-Steller (kein Vielfaches des echten Codes).
    const falscherCode = (Number(code2) + 1) % 1_000_000;
    const falsch = String(falscherCode).padStart(6, "0");
    await page.locator('input[name="two-factor-code"]').fill(falsch);
    await page.getByRole("button", { name: "Verify and sign in" }).click();
    // Sichtbare Fehlermeldung UND: keine Session, weiterhin auf dem Code-Bild.
    await expect(page.getByText(/invalid|code|Code/i).last()).toBeVisible({
      timeout: 20_000,
    });
    await expect(page).toHaveURL(/\/auth\/two-factor/);

    // Um zur Deaktivierung zu kommen, frisch anmelden und richtig verifizieren:
    // der fehlgeschlagene Versuch hat keine Session erzeugt und den
    // Pending-2FA-Schritt verbraucht.
    await anmelden(page, ich.email, ich.passwort);
    await expect(page).toHaveURL(/\/auth\/two-factor/, { timeout: 30_000 });
    const code3 = generateTotp(secret);
    await page.locator('input[name="two-factor-code"]').fill(code3);
    await expect(page).not.toHaveURL(/\/auth\/two-factor/, {
      timeout: 30_000,
    });

    // Schritt 10 — Abschalten (Fluss C).
    await oeffneSicherheit(page);
    await page
      .getByPlaceholder("Enter your password")
      .last()
      .fill(ich.passwort);
    await page.getByRole("button", { name: "Disable" }).click();
    await expect(page.getByText("Disabled").first()).toBeVisible({
      timeout: 20_000,
    });

    // Schritt 10b — Abmelden und ohne 2FA-Code anmelden (Opt-in-Nicht-Regression).
    await abmelden(page);

    await anmelden(page, ich.email, ich.passwort);
    await expect(page).not.toHaveURL(/\/auth\/two-factor/, {
      timeout: 30_000,
    });
  });

  test("J-08b: E-Mail-OTP ist für ein 2FA-Konto gesperrt — verständliche Abweisung statt Endlos-Spinner", async ({
    page,
  }) => {
    // Schritt 1 — Konto anlegen + 2FA aktivieren (gemeinsamer Helper).
    const id = neueIdentitaet("j08b");
    await kontoAnlegen(page, id);
    await arbeitsbereichAnlegen(page, `ESF 2FA-Bypass ${Date.now()}`);
    await aktiviereZweiFaktor(page, id.passwort);
    await abmelden(page);

    // Schritt 2 — E-Mail-OTP-Bestätigung öffnen. (Das Einstiegsformular auf
    // /auth/sign-in ist ohne SMTP-Konfiguration ausgeblendet; die
    // Bestätigungsseite ist der nutzersichtbare Schritt dieses Wegs.)
    await page.goto(
      `/auth/verify-otp?email=${encodeURIComponent(id.email)}&redirect=/dashboard`,
    );
    await expect(page.getByText("Enter verification code").first()).toBeVisible(
      { timeout: 30_000 },
    );

    // Schritt 3 — den gültigen OTP direkt in der DB anlegen (wie die E-Mail ihn
    // geliefert hätte) und über die SICHTBARE UI absenden. Anders als der alte
    // Test umgeht der Test den Web-Client jetzt nicht mehr per fetch: der
    // Nutzer tippt den Code ein, und genau dieser Browser-Weg wird geprüft.
    // (Der better-auth-Web-Client hängt bei der 401-Antwort dieses Endpunkts —
    // die Seite führt den Aufruf deshalb selbst per fetch aus, siehe
    // apps/web/src/routes/auth/verify-otp.tsx.)
    const otp = await legeSignInOtpAn(id.email);
    const verifying = page.getByRole("button", { name: "Verifying..." });
    await page.locator('input[name="one-time-code"]').fill(otp);

    // Schritt 4 — der Spinner erscheint und VERSCHWINDET wieder: die Abweisung
    // bleibt nicht endlos auf „Verifying...“ hängen (Review-Frage 4, Befund 2).
    await expect(verifying).toBeVisible({ timeout: 15_000 });
    await expect(verifying).toBeHidden({ timeout: 15_000 });

    // Schritt 5 — die verständliche, handlungsleitende Abweisung ist sichtbar:
    // die Meldung, dass das Konto 2FA nutzt, mit Aufforderung zur
    // Passwort-Anmeldung. Kein rohes 401-JSON, kein Dauer-Spinner.
    await expect(
      page.getByText("Two-factor authentication required"),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.getByText(
        "This account uses two-factor authentication. Please sign in with your password.",
      ),
    ).toBeVisible();
    await expect(
      page.getByRole("link", { name: "Sign in with password" }),
    ).toBeVisible();
    await expect(
      page.getByRole("link", { name: "Sign in with password" }),
    ).toHaveAttribute("href", /\/auth\/sign-in/);

    // Schritt 6 — der zurückgewiesene Sign-in hat keine Session erzeugt:
    // get-session liefert keine angemeldete Sitzung, und der Nutzer bleibt auf
    // der OTP-Seite stehen.
    const apiUrl = process.env.E2E_API_URL ?? "http://localhost:1337";
    const session = await page.evaluate(
      async ({ baseUrl }) => {
        const response = await fetch(`${baseUrl}/api/auth/get-session`, {
          credentials: "include",
        });
        return (await response.json()) as { user: { email: string } } | null;
      },
      { baseUrl: apiUrl },
    );
    expect(session).toBeNull();
    await expect(page).toHaveURL(/\/auth\/verify-otp/);
  });
});
