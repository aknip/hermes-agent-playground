import { expect, test } from "@playwright/test";
import { einladungAnnehmen, gastKontoAnlegen } from "../support/einladung";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";

/**
 * Journey J-05 — Ein Teammitglied per Einladungslink aufnehmen
 *
 * Ohne SMTP ist der Einladungslink der einzige Zustellkanal: Das Modal bleibt
 * nach dem Absenden offen und zeigt den Link. J-05 ist die einzige Journey
 * mit zwei eingeloggten Nutzern — der Einladende (Eigentümer) und der
 * Eingeladene, ein eigenes Konto in einem zweiten Browser-Kontext. Nach dem
 * Annehmen steht der Kollege in der Mitgliederliste, ohne „pending"-Badge.
 *
 * Schritte: 7 · Eigentümer: esf-qa-release
 */
test.describe("J-05 Teammitglied einladen", () => {
  test("Ein Anwender lädt ein Teammitglied ein und der Eingeladene nimmt an", async ({
    browser,
    page,
  }) => {
    const einladend = neueIdentitaet("j05-einladend");
    const gast = neueIdentitaet("j05-gast");

    // Vorbedingung (J-00 bis J-01): Konto und Arbeitsbereich einrichten.
    await kontoAnlegen(page, einladend);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);

    // Schritt 1 — Der Einladende öffnet die Mitglieder-Seite des Arbeitsbereichs.
    await expect(page).toHaveURL(/\/dashboard\/workspace\/[^/]+/, {
      timeout: 30_000,
    });
    const workspaceId = page
      .url()
      .match(/\/dashboard\/workspace\/([^/?#]+)/)?.[1];
    await expect(workspaceId).toBeDefined();
    const mitgliederUrl = `/dashboard/workspace/${workspaceId}/members`;
    await page.goto(mitgliederUrl);
    await expect(page).toHaveURL(/\/members/);

    // Schritt 2 — „Invite member" öffnet das Einladeformular.
    await page
      .getByRole("button", { name: "Invite member", exact: true })
      .click();
    const emailFeld = page.getByPlaceholder("colleague@company.com");
    await expect(emailFeld).toBeVisible();

    // Schritt 3 — Der Einladende trägt die E-Mail des Gasts ein.
    await emailFeld.fill(gast.email);

    // Schritt 4 — „Send Invitation" stößt die Einladung an; die Mutation gelingt.
    await page
      .getByRole("button", { name: "Send Invitation", exact: true })
      .click();
    await expect(page.getByText("Invitation sent successfully")).toBeVisible();

    // Schritt 5 — Ohne SMTP bleibt das Modal offen und zeigt den Einladungslink.
    const linkFeld = page.getByLabel("Invitation link");
    await expect(linkFeld).toBeVisible();
    const link = await linkFeld.inputValue();
    expect(link).toMatch(/\/invitation\/accept\/[^/]+$/);

    // Schritt 6 — Der Gast (zweiter Kontext) öffnet den Link und nimmt an.
    const gastKontext = await gastKontoAnlegen(browser, gast);
    await einladungAnnehmen(gastKontext.seite, link);

    // Schritt 7 — Der Kollege steht jetzt als Mitglied in der Liste
    // (der Eigenname erscheint nur in der Mitgliedszeile) — ohne „pending"-Badge.
    await page.goto(mitgliederUrl);
    await expect(page.getByText(gast.name, { exact: true })).toBeVisible();
    await expect(page.getByText("pending", { exact: true })).not.toBeVisible();
  });
});
