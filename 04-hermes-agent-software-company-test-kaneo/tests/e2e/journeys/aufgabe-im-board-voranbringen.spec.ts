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
 * Schritte: 13 · Eigentümer: esf-qa-release
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

    // Schritte 9-11 — eine Aufgabe in der ersten Spalte anlegen.
    await page.getByTitle("Add task").first().click();
    await page.getByPlaceholder("Task title").fill(aufgabe);
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByText(aufgabe, { exact: true })).toBeVisible();

    // Warte, bis das CreateTask-Modal samt Overlay vollständig ausgehängt ist —
    // sein Nachklang-Overlay würde sonst die Pointer-Events des Ziehens abfangen.
    await expect(page.locator(".kaneo-create-task-modal")).toHaveCount(0, {
      timeout: 10_000,
    });

    // Schritt 12 — die Karte von „To Do" in die Spalte „In Progress" ziehen.
    // Mit den Mauskoordinaten der Zielspalte, wie eine echte Drag-Geste.
    const karte = page.getByText(aufgabe, { exact: true });
    const kartenBox = await karte.boundingBox();
    const zielkopf = page.getByText("In Progress", { exact: true });
    const zielBox = await zielkopf.boundingBox();
    if (!kartenBox || !zielBox) throw new Error("Zieldaten nicht gefunden");
    const sx = kartenBox.x + kartenBox.width / 2;
    const sy = kartenBox.y + kartenBox.height / 2;
    const tx = zielBox.x + zielBox.width / 2;
    const ty = zielBox.y + 120; // Blickachse ins Ablagefeld der Spalte
    await page.mouse.move(sx, sy);
    await page.mouse.down();
    await page.mouse.move(sx + 20, sy, { steps: 3 });
    await page.mouse.move(tx, ty, { steps: 30 });
    await page.mouse.up();

    // Schritt 13 — die Aufgabe steht jetzt unter „In Progress", nicht mehr
    // in der ersten Spalte.
    const spalte = (name: string) =>
      page
        .getByText(name, { exact: true })
        .locator("xpath=ancestor::div[contains(@class,'rounded-xl')][1]");
    await expect(spalte("In Progress").getByText(aufgabe)).toBeVisible();
    await expect(spalte("To Do").getByText(aufgabe)).not.toBeVisible();
  });
});
