import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";

/**
 * Journey J-06 — Teammitglied einladen
 *
 * Teamarbeit wachsen lassen: einen Kollegen per E-Mail in den Arbeitsbereich
 * einladen. Ohne konfiguriertes SMTP erzeugt die Einladung einen Teilen-Link,
 * und der Kollege erscheint als ausstehend in der Mitgliederliste.
 * Geprüft wird die Absender-Seite — die E-Mail-Zustellung selbst kann eine
 * isolierte Suite nicht verlässlich nachziehen.
 *
 * Schritte: 11 · Eigentümer: esf-qa-release
 */
test.describe("J-06 Teammitglied einladen", () => {
  test("Ein Anwender lädt einen Kollegen in den Arbeitsbereich ein", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j06");
    const gast = `kollege-${Date.now()}@beispiel.local`;

    // Schritte 1-4 — Konto anlegen.
    await kontoAnlegen(page, ich);
    // Schritt 5 — Arbeitsbereich einrichten.
    await arbeitsbereichAnlegen(page);

    // Schritt 6 — im Sidebar zur Mitgliederliste des Arbeitsbereichs.
    await page.getByRole("link", { name: "Members" }).click();
    await expect(page).toHaveURL(/\/members/, { timeout: 30_000 });

    // Schritt 7 — den Einstieg „Invite member" öffnen.
    await page.getByRole("button", { name: "Invite member" }).click();

    // Schritt 8 — die E-Mail-Adresse des Kollegen eintragen.
    await page.getByPlaceholder("colleague@company.com").fill(gast);

    // Schritt 9 — die Einladung absenden.
    await page.getByRole("button", { name: "Send Invitation" }).click();

    // Schritt 10 — der Dialog bestätigt die Einladung mit einem Teilen-Link.
    await expect(page.getByText("Invitation created")).toBeVisible({
      timeout: 30_000,
    });

    // Schritt 11 — der Kollege steht als ausstehend in der Mitgliederliste.
    await page.getByRole("button", { name: "Done" }).click();
    await expect(page.getByText(gast, { exact: true })).toBeVisible({
      timeout: 30_000,
    });
  });
});