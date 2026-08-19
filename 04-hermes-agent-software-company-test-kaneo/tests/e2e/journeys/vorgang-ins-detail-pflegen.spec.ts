import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
  vorgangAnlegen,
} from "../support/journey";

/**
 * Journey J-06 — Einen Vorgang bis ins Detail pflegen
 *
 * Der Anwender öffnet einen Vorgang im Board, ergänzt Beschreibung, Termin
 * und einen Kommentar in der seitlichen Detail-Shelf und prüft, dass der
 * gepflegte Zustand über das Schließen und erneute Öffnen der Shelf bestehen
 * bleibt.
 *
 * Schritte: 5 · Eigentümer: esf-qa-release
 */
test.describe("J-06 Vorgang bis ins Detail pflegen", () => {
  test("Ein Anwender ergänzt Beschreibung, Termin und Kommentar an einem Vorgang", async ({
    page,
  }) => {
    const ich = neueIdentitaet("j06");
    const titel = `Detail pflegen ${Date.now()}`;

    // Vorbedingung (J-00 bis J-03): Konto, Arbeitsbereich, Projekt, Vorgang.
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);
    await vorgangAnlegen(page, titel);

    const karte = page.getByRole("button", {
      name: new RegExp(titel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")),
    });
    await expect(karte).toBeVisible();

    // Schritt 1 — Klick auf die Karte öffnet die Detail-Shelf; die URL erhält ?taskId=.
    await karte.click();
    await expect(page).toHaveURL(/\?taskId=/);
    await expect(page.locator(".kaneo-tiptap-prose")).toBeVisible();

    // Schritt 2 — Beschreibung ergänzen; der Text erscheint sichtbar im Editor.
    const beschreibung = `Detail-Beschreibung ${Date.now()}`;
    const editor = page.locator(".kaneo-tiptap-prose");
    await editor.click();
    await page.keyboard.type(beschreibung);
    await expect(page.locator(".kaneo-tiptap-prose")).toContainText(
      beschreibung,
    );

    // Schritt 3 — Einen Termin (Fälligkeitsdatum) im Kalender setzen.
    await page.getByRole("button", { name: "No date", exact: true }).click();
    const zieldatum = new Date(
      new Date().getFullYear(),
      new Date().getMonth(),
      15,
    );
    await page
      .locator('[data-slot="calendar"]')
      .getByText(String(zieldatum.getDate()), { exact: true })
      .click();
    const erwartetesDatum = new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
    }).format(zieldatum);
    await expect(
      page.getByRole("button", { name: erwartetesDatum, exact: true }),
    ).toBeVisible();

    // Schritt 4 — Einen Kommentar schreiben und senden; er erscheint in der Aktivitätsliste.
    const kommentar = `Kommentar ${Date.now()}`;
    const kommentareditor = page.locator(
      ".kaneo-comment-editor-content .ProseMirror",
    );
    await kommentareditor.click();
    await page.keyboard.type(kommentar);
    await page.keyboard.press("ControlOrMeta+Enter");
    await expect(page.getByText(kommentar, { exact: true })).toBeVisible();

    // Schritt 5 — Nach Schließen und erneutem Öffnen bleibt der Vorgang gepflegt.
    // Die Shelf wird über Escape geschlossen (das Sheet ist dismissible); die
    // Karte liegt unter dem Sheet-Viewport und ist nicht anklickbar, solange
    // die Shelf offen ist.
    await page.keyboard.press("Escape");
    await expect(page).not.toHaveURL(/\?taskId=/);
    await karte.click();
    await expect(page).toHaveURL(/\?taskId=/);

    await expect(page.locator(".kaneo-tiptap-prose")).toContainText(
      beschreibung,
    );
    await expect(
      page.getByRole("button", { name: erwartetesDatum, exact: true }),
    ).toBeVisible();
    await expect(page.getByText(kommentar, { exact: true })).toBeVisible();
  });
});
