import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
} from "../support/journey";

/**
 * Journey J-03 — Einen Vorgang anlegen und einem Teammitglied zuweisen
 *
 * Der Kernhandgriff der Planung: Ein Vorgang wird angelegt und priorisiert.
 * In einem frischen Arbeitsbereich ist der Anwender das einzige Mitglied —
 * sein Bild/Initialen erscheinen nach dem Anlegen auf der Karte. Die Zuweisung
 * an ein zusätzlich eingeladenes Mitglied ist die Journey J-05.
 *
 * Schritte: 5 · Eigentümer: esf-qa-release
 */
test.describe("J-03 Vorgang anlegen und zuweisen", () => {
  test("Ein Anwender legt einen priorisierten Vorgang an und weist ihn zu", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j03");

    // Vorbedingung (J-00/J-01/J-02): Konto, Arbeitsbereich, Projekt und Board.
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);

    const modal = page.locator(".kaneo-create-task-modal");
    const titel = `Onboarding-Doku schreiben ${Date.now()}`;

    // Schritt 1 — Das „+" der ersten Spalte öffnet das Anlegeformular.
    await page.getByTitle("Add task").first().click();
    await expect(modal).toBeVisible();

    // Schritt 2 — Der Titel wird eingetragen.
    await modal.getByPlaceholder("Task title").fill(titel);

    // Schritt 3 — Die Priorität wird auf „High" gesetzt. Die Inline-Gruppe
    // zeigt alle fünf Werte direkt im Dialog; ein Klick genügt (kein Popover).
    await modal.getByRole("button", { name: /^High$/ }).click();
    await expect(
      modal.getByRole("button", { name: /High/ }).first(),
    ).toHaveAttribute("aria-pressed", "true");

    // Schritt 4 — „Create Task" legt den Vorgang an. Der Bearbeiter ist per
    // Standard der Anwender selbst — ein eigener Zuweisungsschritt entfällt.
    await modal
      .getByRole("button", { name: "Create Task", exact: true })
      .click();

    // Schritt 5 — Die Karte erscheint im Board mit Titel und Bearbeiter.
    // Die Karte ist ein Button, dessen zugänglicher Name Reihenfolge trägt:
    // Priorität, Bearbeiter-Initialen, Titel („P1 ET <Titel>"). Der Bearbeiter
    // steht als Avatar-Initialen („ET" für „ESF Test …"), nicht als Fliesstext.
    const karte = page.getByRole("button", {
      name: new RegExp(titel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")),
    });
    await expect(karte).toBeVisible();
    await expect(karte).toHaveAccessibleName(/ET/);
  });
});
