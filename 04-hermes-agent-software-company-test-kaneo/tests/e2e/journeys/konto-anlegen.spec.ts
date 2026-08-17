import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";

/**
 * Journey J-01 — Konto anlegen und ersten Arbeitsbereich einrichten
 *
 * Die Eingangsaufgabe: Ein neuer Anwender legt sich ein Konto an und richtet
 * seinen ersten Arbeitsbereich ein. Jede weitere Journey setzt darauf auf.
 *
 * Schritte: 7 · Eigentümer: esf-qa-release
 */
test.describe("J-01 Konto anlegen", () => {
  test("Ein neuer Anwender legt ein Konto an und richtet seinen Arbeitsbereich ein", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j01");

    // Schritte 1-4 — Registrierungsformular ausfüllen und absenden.
    await kontoAnlegen(page, ich);

    // Schritt 5 — Ein frisches Konto hat noch keinen Arbeitsbereich.
    await expect(page.getByText("Create workspace").first()).toBeVisible();

    // Schritte 6-7 — Arbeitsbereich benennen und anlegen.
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await expect(page).not.toHaveURL(/\/onboarding/);
  });

  test("Ein zu kurzes Passwort wird sichtbar abgewiesen", async ({ page }) => {
    const ich = neueIdentitaet("j01-kurz");

    // Schritt 1 — Der Anwender öffnet die Registrierung.
    await page.goto("/auth/sign-up");

    // Schritte 2-4 — Er trägt ein offensichtlich zu kurzes Passwort ein.
    await page.getByLabel("Full Name").fill(ich.name);
    await page.getByLabel("Email").fill(ich.email);
    await page.locator('input[name="password"]').fill("abc");
    await page.getByRole("button", { name: "Create Account" }).click();

    // Schritt 5 — Er bleibt im Formular und sieht, woran es lag.
    await expect(page).toHaveURL(/\/auth\/sign-up/);
    await expect(page.getByText(/password/i).last()).toBeVisible();
  });
});
