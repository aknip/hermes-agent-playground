import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
} from "../support/journey";

/**
 * Journey J-04 — Aufgabe im Board voranbringen
 *
 * Der zweite Kernfluss des Boards: eine Aufgabe von „To Do" nach „In
 * Progress" (Status ändern), hier per Ziehen wie im täglichen Umgang.
 * Das Board nutzt dnd-kit mit Zeiger-Sensoren (kein natives HTML5-DnD),
 * deshalb zieht der Test mit rohen Mausereignissen statt dragTo.
 *
 * Schritte: 12 · Eigentümer: esf-qa-release
 */
test.describe("J-04 Aufgabe im Board voranbringen", () => {
  test("Ein Anwender zieht eine Aufgabe von Spalte zu Spalte", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j04");
    const aufgabe = `Durchziehen ${Date.now()}`;

    // Schritte 1-4 — Konto anlegen.
    await kontoAnlegen(page, ich);
    // Schritt 5 — Arbeitsbereich einrichten.
    await arbeitsbereichAnlegen(page);

    // Schritte 6-8 — ein Projekt anlegen, um Arbeit aufzunehmen.
    await projektAnlegen(page);

    // Schritte 9-10 — eine Aufgabe in der ersten Spalte anlegen.
    await page.getByTitle("Add task").first().click();
    await page.getByPlaceholder("Task title").fill(aufgabe);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByText(aufgabe, { exact: true })).toBeVisible();

    // Schritt 11 — die Karte von „To Do" in die Spalte „In Progress" ziehen.
    // Mit den Mauskoordinaten der Zielspalte, wie eine echte Drag-Geste.
    const karte = page.getByText(aufgabe, { exact: true });
    const kartenBox = await karte.boundingBox();
    const zielkopf = page.getByText("In Progress", { exact: true });
    const zielBox = await zielkopf.boundingBox();
    if (!kartenBox || !zielBox) throw new Error("Zieldaten nicht gefunden");
    await page.mouse.move(
      kartenBox.x + kartenBox.width / 2,
      kartenBox.y + kartenBox.height / 2,
    );
    await page.mouse.down();
    // Blickachse 120px unter den Spaltenkopf, ins Ablagefeld der Spalte.
    await page.mouse.move(zielBox.x + zielBox.width / 2, zielBox.y + 120, {
      steps: 20,
    });
    await page.mouse.up();

    // Schritt 12 — die Aufgabe steht jetzt unter „In Progress", nicht mehr
    // in der ersten Spalte.
    const spalte = (name: string) =>
      page
        .getByText(name, { exact: true })
        .locator("xpath=ancestor::div[contains(@class,'rounded-xl')][1]");
    await expect(spalte("In Progress").getByText(aufgabe)).toBeVisible();
    await expect(spalte("To Do").getByText(aufgabe)).not.toBeVisible();
  });
});