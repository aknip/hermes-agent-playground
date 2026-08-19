import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
} from "../support/journey";
import { paletteOeffnen } from "../support/tastatur";

/**
 * Journey J-02 — Erstes Projekt anlegen
 *
 * Im angelegten Arbeitsbereich setzt der Anwender sein erstes Projekt auf und
 * landet direkt im Board. Die Vorbedingung Konto + Arbeitsbereich ist der
 * gemeinsame Einstieg; die Projekt-Schritte sind diese Journey.
 *
 * Schrittfolge wird um den Tastaturweg erweitert (F-R1-3): derselbe Weg,
 * ganz ohne Maus, über die Command-Palette.
 *
 * Schritte: 5 · Eigentümer: esf-qa-release
 */
test.describe("J-02 Erstes Projekt anlegen", () => {
  test("Ein Anwender legt im Arbeitsbereich sein erstes Projekt an", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j02");

    // Vorbedingung (J-00/J-01): Konto und Arbeitsbereich einrichten.
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);

    // Schritt 1 — Die leere Projektliste zeigt den Weg „Create project"
    // (im Kopf und im Leerzustand, beide identisch beschriftet).
    await expect(
      page.getByRole("button", { name: "Create project", exact: true }).first(),
    ).toBeVisible();

    // Schritt 2 — Der Anwender öffnet das Anlegeformular.
    await page
      .getByRole("button", { name: "Create project", exact: true })
      .first()
      .click();

    // Schritte 3-4 — Nur der Projektname ist Pflicht; der Schlüssel wird
    // automatisch erzeugt, danach wird das Projekt angelegt.
    const projektName = `Q3 Launch ${Date.now()}`;
    await page.getByPlaceholder("Project name").fill(projektName);
    await page
      .getByRole("button", { name: "Create Project", exact: true })
      .click();

    // Schritt 5 — Man landet im Board mit den Standard-Spalten.
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });
    await expect(page.getByText("To Do")).toBeVisible();
    await expect(page.getByText("In Progress")).toBeVisible();
    await expect(page.getByText("Done")).toBeVisible();
  });

  test("Ein Anwender legt sein erstes Projekt rein über die Tastatur an", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j02k");

    // Vorbedingung: Konto + Arbeitsbereich (wie im Mausweg).
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);

    // Schritt 1 — Die Palette öffnet sich per ⌘K/Ctrl+K (keine Maus).
    await paletteOeffnen(page);

    // Schritt 2 — „Projekt anlegen" per Tastatur wählen: das Suchfeld filtert
    // die Befehle, „create project" + Enter öffnet das Anlegeformular. Die
    // Kürzel-Sequenz „pc" löst in einem Textfeld (Suchfeld) bewusst nichts aus
    // (Befund R1-c: Suchtexteingabe darf nie eine Aktion auslösen).
    const suchfeld = page.getByPlaceholder("Search for apps and commands...");
    await expect(suchfeld).toBeFocused();
    await suchfeld.type("create project");
    await page.keyboard.press("Enter");
    await expect(page.getByPlaceholder("Project name")).toBeVisible();

    // Schritt 3 — Nur der Name eintippen und mit Enter absenden.
    const projektName = `Q3 Tastatur ${Date.now()}`;
    await page.keyboard.type(projektName);
    await page.keyboard.press("Enter");

    // Schritt 4 — Man landet im Board mit den Standard-Spalten.
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });
    await expect(page.getByText("To Do")).toBeVisible();
    await expect(page.getByText("In Progress")).toBeVisible();
    await expect(page.getByText("Done")).toBeVisible();
  });
});
