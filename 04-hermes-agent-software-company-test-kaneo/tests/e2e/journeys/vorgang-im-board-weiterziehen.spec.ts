import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
  vorgangAnlegen,
} from "../support/journey";

/**
 * Journey J-04 — Einen Vorgang im Board weiterziehen
 *
 * Der Anwender zieht eine Karte per Drag & Drop von „To Do" in die nächste
 * Spalte „In Progress". Die Vorbedingungen (Konto, Arbeitsbereich, Projekt,
 * Vorgang in „To Do") werden über die gemeinsamen Helfer aufgebaut; die
 * sichtbaren Schritte dieser Journey sind das Ziehen und das veränderte Board.
 *
 * Schrittfolge wird um den Tastaturweg erweitert (F-R1-3): der Statuswechsel
 * per Detail-Kürzel (s) in der Shelf, ohne Drag & Drop.
 *
 * Schritte: 3 · Eigentümer: esf-qa-release
 */
test.describe("J-04 Vorgang im Board weiterziehen", () => {
  test('Ein Anwender zieht einen Vorgang von "To Do" zu "In Progress"', async ({
    page,
  }) => {
    const ich = neueIdentitaet("j04");
    const titel = `Karte ziehen ${Date.now()}`;

    // Vorbedingungen (J-00 bis J-03): Konto, Arbeitsbereich, Projekt, Vorgang.
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);
    await vorgangAnlegen(page, titel);

    const karte = page.getByText(titel, { exact: true });
    await expect(karte).toBeVisible();

    // Schritt 1-2 — Die Karte in „To Do" wird gegriffen und in die nächste
    // Spalte gezogen. Dnd-kit aktiviert nach >8px Mausbewegung (MouseSensor);
    // deshalb eine kontrollierte Drag-Geste über Mausereignisse.
    const ziel = (await page
      .getByText("In Progress", { exact: true })
      .boundingBox())!;
    const ausgangsBBox = (await karte.boundingBox())!;
    await page.mouse.move(
      ausgangsBBox.x + ausgangsBBox.width / 2,
      ausgangsBBox.y + ausgangsBBox.height / 2,
    );
    await page.mouse.down();
    // In den Körper der Zielspalte fahren (unter die Überschrift), dann loslassen.
    await page.mouse.move(ziel.x + ziel.width / 2, ziel.y + 80, {
      steps: 24,
    });
    await page.mouse.up();

    // Schritt 3 — Die Karte steht jetzt in „In Progress"; in „To Do" ist sie weg.
    // Jede Spalte ist ein Container mit der Klasse min-w-80.
    const spalte = (name: string) =>
      page.locator('[class*="min-w-80"]').filter({
        has: page.getByText(name, { exact: true }),
      });
    await expect(
      spalte("In Progress").getByText(titel, { exact: true }),
    ).toBeVisible();
    await expect(
      spalte("To Do").getByText(titel, { exact: true }),
    ).not.toBeVisible();
  });

  test("Ein Anwender wechselt den Status per Detail-Kürzel in der Shelf", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j04k");
    const titel = `Karte Tastatur ${Date.now()}`;

    // Vorbedingungen: Konto, Arbeitsbereich, Projekt, Vorgang in „To Do".
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);
    await vorgangAnlegen(page, titel);

    const karte = page.getByText(titel, { exact: true });
    await expect(karte).toBeVisible();

    // Schritt 1 — Die Karte öffnen (die Detail-Shelf erscheint).
    await karte.click();
    const statusTrigger = page.locator('[data-shelf-action="status"]');
    await expect(statusTrigger).toBeVisible();

    // Schritt 2 — Das Status-Popover über das Detail-Kürzel „s" öffnen.
    await page.keyboard.press("s");

    // Schritt 3 — Zielstatus „In Progress" über die Schnellwahl (2) wählen.
    await page.keyboard.press("2");

    // Schritt 4 — Die Karte steht jetzt in „In Progress"; in „To Do" ist sie weg.
    const spalte = (name: string) =>
      page.locator('[class*="min-w-80"]').filter({
        has: page.getByText(name, { exact: true }),
      });
    await expect(
      spalte("In Progress").getByText(titel, { exact: true }),
    ).toBeVisible();
    await expect(
      spalte("To Do").getByText(titel, { exact: true }),
    ).not.toBeVisible();
  });
});
