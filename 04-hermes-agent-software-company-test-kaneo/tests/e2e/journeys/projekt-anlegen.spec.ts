import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";

/**
 * Journey J-02 — Projekt anlegen
 *
 * Die erste Aufgabe für ein Team: einen gemeinsamen Raum für ein Vorhaben
 * schaffen. Ein neues Projekt ist die Voraussetzung jeder projektbezogenen
 * Arbeit (J-03, J-04, …). Der Weg geht über die Sidebar „Add project" ins
 * Modal CreateProjectModal → Name → „Create Project".
 *
 * Schritte: 10 · Eigentümer: esf-qa-release
 */
test.describe("J-02 Projekt anlegen", () => {
  test("Ein Anwender legt ein Projekt für die Teamarbeit an", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j02");
    const projektName = `Projekt ${Date.now()}`;

    // Schritte 1-4 — Registrierungsformular ausfüllen und Konto anlegen.
    await kontoAnlegen(page, ich);

    // Schritt 5 — den ersten Arbeitsbereich einrichten.
    await arbeitsbereichAnlegen(page, `Projekt-WS ${Date.now()}`);

    // Schritt 6 — im Sidebar den Einstieg „Add project" öffnen.
    await page.getByRole("button", { name: "Add project" }).click();

    // Schritt 7 — der Dialog erscheint mit einem Namensfeld.
    await expect(page.getByPlaceholder("Project name")).toBeVisible();

    // Schritt 8 — Projektname eintragen; das Kürzel für Ticket-IDs wird
    // automatisch daraus abgeleitet.
    await page.getByPlaceholder("Project name").fill(projektName);

    // Schritt 9 — das Projekt anlegen.
    await page.getByRole("button", { name: "Create Project" }).click();

    // Schritt 10 — das neue Projekt öffnet sich im Board.
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });
    await expect(page.getByTitle("Add task").first()).toBeVisible();
  });
});
