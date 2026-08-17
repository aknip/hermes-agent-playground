import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
} from "../support/journey";

/**
 * Journey J-03 — Aufgabe erfassen und zuweisen
 *
 * Der tägliche Kernfluss: Arbeit als Aufgabe festhalten und einem
 * Verantwortlichen zuweisen. Der Weg geht über den „+" im Spaltenkopf in
 * das CreateTaskModal, dort Titel + „Assign" → Person → „Create Task".
 * In einem frischen Arbeitsbereich ist der einzige Anwender zugleich der
 * einzig wählbare Verantwortliche.
 *
 * Schritte: 13 · Eigentümer: esf-qa-release
 */
test.describe("J-03 Aufgabe erfassen und zuweisen", () => {
  test("Ein Anwender legt eine Aufgabe an und weist sie zu", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j03");
    const aufgabe = `Aufgabe ${Date.now()}`;

    // Schritte 1-4 — Konto anlegen.
    await kontoAnlegen(page, ich);
    // Schritt 5 — Arbeitsbereich einrichten.
    await arbeitsbereichAnlegen(page);

    // Schritte 6-8 — ein Projekt anlegen, um Arbeit aufzunehmen.
    await projektAnlegen(page);

    // Schritt 9 — im Kopf der ersten Spalte eine Aufgabe hinzufügen.
    await page.getByTitle("Add task").first().click();

    // Schritt 10 — den Titel der Aufgabe eintragen.
    await page.getByPlaceholder("Task title").fill(aufgabe);

    // Schritt 11 — die Zuweisung öffnen („Assign").
    await page.getByRole("button", { name: "Assign" }).click();

    // Schritt 12 — den verantwortlichen Kollegen wählen. In einem frischen
    // Arbeitsbereich ist das die eigene Person.
    await page.getByRole("button", { name: ich.name }).last().click();

    // Schritt 13 — die Aufgabe anlegen. Die Karte erscheint in der ersten
    // Spalte und zeigt die Zuweisung.
    await page.getByRole("button", { name: "Create Task" }).click();
    await expect(page.getByText(aufgabe, { exact: true })).toBeVisible();
  });
});