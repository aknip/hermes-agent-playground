import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
} from "../support/journey";

/**
 * Journey J-07 — Aufgabe über die Suche wiederfinden
 *
 * Ein Teammitglied will eine bestimmte Aufgabe wiederfinden, die in einem von
 * mehreren Projekten liegt. Der Weg geht über den dauerhaft sichtbaren
 * Header-Sucheinstieg („Search tasks, projects, comments…“) direkt von der
 * Arbeitsbereichs-Übersicht — ohne Tastatur, ohne den Kurzbefehl / zu kennen,
 * ohne die Sidebar auszuklappen.
 *
 * Schritte: 12 · Eigentümer: esf-qa-release
 */
test.describe("J-07 Aufgabe über die Suche wiederfinden", () => {
  test("Ein Anwender findet eine Aufgabe in einem anderen Projekt über die globale Suche", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j07");
    const token = `Rechnung QBE-${Date.now()}`;

    // Schritte 1-4 — Konto anlegen und den ersten Arbeitsbereich einrichten.
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page);

    // Schritt 5 — erstes Projekt („Projekt A“) anlegen.
    await projektAnlegen(page, "Projekt A");

    const workspaceId = page
      .url()
      .match(/\/dashboard\/workspace\/([^/]+)\/project/)?.[1];
    expect(workspaceId).toBeTruthy();

    // Schritt 6 — in Projekt A eine Aufgabe mit eindeutigem Titel anlegen.
    await page.getByTitle("Add task").first().click();
    await page.getByPlaceholder("Task title").fill(token);
    await page.getByRole("button", { name: "Create Task" }).click();

    // Schritt 7 — zweites Projekt („Projekt B“) anlegen, damit die Suche
    // wirklich projektübergreifend suchen muss (K9).
    await projektAnlegen(page, "Projekt B");

    // Schritt 8 — zur Arbeitsbereichs-Übersicht wechseln, weg vom Projekt-Board.
    await page.goto(`/dashboard/workspace/${workspaceId}`);

    // Schritt 9 — der Header-Sucheinstieg ist ohne Sidebar-Ausklappen sichtbar.
    const suchEinstieg = page.getByRole("button", {
      name: /Search tasks, projects, comments/,
    });
    await expect(suchEinstieg).toBeVisible();

    // Schritt 10 — den Header-Griff anklicken: der Such-Dialog erscheint, das
    // Eingabefeld ist fokussiert, die URL bleibt unverändert (keine Navigation).
    const urlVorher = page.url();
    await suchEinstieg.click();
    const abfrage = page.getByPlaceholder(
      "Search tasks, projects, comments...",
    );
    await expect(abfrage).toBeVisible();
    await expect(abfrage).toBeFocused();
    expect(page.url()).toBe(urlVorher);

    // Schritt 11 — den eindeutigen Titel eintippen (≥3 Zeichen) und den Treffer
    // anklicken: Navigation zur Aufgabe in Projekt A, ohne Seiten-Reload.
    let volleLaeder = 0;
    page.on("load", () => {
      volleLaeder += 1;
    });
    await abfrage.fill(token);
    await expect(page.getByText(token, { exact: true })).toBeVisible();
    await page.getByText(token, { exact: true }).click();
    await expect(page).toHaveURL(/\/project\/[^/]+\/task\//, {
      timeout: 30_000,
    });
    await expect(page.getByPlaceholder("Click to add a title")).toHaveValue(
      token,
    );
    expect(volleLaeder).toBe(0);

    // Schritt 12 — Gegenprobe: der Kurzbefehl "/" öffnet denselben Such-Dialog.
    await page.keyboard.press("/");
    await expect(
      page.getByPlaceholder("Search tasks, projects, comments...").first(),
    ).toBeVisible();
  });
});
