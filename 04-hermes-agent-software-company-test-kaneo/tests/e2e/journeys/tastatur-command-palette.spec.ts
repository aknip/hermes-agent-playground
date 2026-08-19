import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
  vorgangAnlegen,
} from "../support/journey";
import { paletteOeffnen } from "../support/tastatur";

/**
 * F-R1-3 — Tastaturbedienung & Command-Palette (zusätzliche E2E-Szenarien)
 *
 * Zwei eigenständige Beweise der Akzeptanzkriterien 6 und 7:
 *   · Die Palette wechselt das Board direkt (Projektsuche, Entscheidung A).
 *   · Kein Kurzbefehl feuert in einem Textfeld (Eingabeschutz-Regel).
 *
 * Eigentümer: esf-dev-a (F-R1-3)
 */
test.describe("F-R1-3 Command-Palette & Eingabeschutz", () => {
  test("Wechselt das Board direkt über die Projektsuche der Palette", async ({
    page,
  }) => {
    const ich = neueIdentitaet("f13a");
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);

    // Zwei Projekte im Arbeitsbereich anlegen — zuerst übers Leerzustands-
    // Formular, das zweite über die Palette (gleicher Weg wie J-02).
    const projektA = `Alpha ${Date.now()}`;
    await projektAnlegen(page, projektA);
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });

    await paletteOeffnen(page);
    // „Create project" über das Suchfeld filtern und mit Enter ausführen —
    // die Kürzel-Sequenz „pc" löst in einem Textfeld (Suchfeld) nichts aus.
    const suchfeld = page.getByPlaceholder("Search for apps and commands...");
    await expect(suchfeld).toBeFocused();
    await suchfeld.type("create project");
    await page.keyboard.press("Enter");
    await expect(page.getByPlaceholder("Project name")).toBeVisible();
    await page.keyboard.type(`Beta ${Date.now()}`);
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });

    // Nun zurück zu Projekt A: Palette öffnen, nach dem Namen filtern,
    // Enter wählt das Board.
    await paletteOeffnen(page);
    await page.keyboard.type(projektA);
    await page.keyboard.press("Enter");

    // Die Palette navigiert direkt in das Board des gewählten Projekts.
    await expect(page).toHaveURL(/\/project\/[^/]+\/board/, {
      timeout: 30_000,
    });
    await expect(page.getByText("To Do")).toBeVisible();
    // Die Palette ist nach der Auswahl geschlossen.
    await expect(
      page.getByPlaceholder("Search for apps and commands..."),
    ).not.toBeVisible();
  });

  test("Kein Kurzbefehl feuert in einem Textfeld (t/p/v/s bleiben Zeichen)", async ({
    page,
  }) => {
    const ich = neueIdentitaet("f13b");
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);
    await vorgangAnlegen(page, `Karte ${Date.now()}`);

    // Ein Textfeld fokussieren (Titel des Anlegen-Modals).
    await page.getByTitle("Add task").first().click();
    const titelFeld = page.getByPlaceholder("Task title");
    await expect(titelFeld).toBeVisible();

    // t/p/v/s tippen: der Eingabeschutz verhindert, dass ein Kurzbefehl das
    // Zeichen verschluckt oder ein Modal öffnet.
    for (const taste of ["t", "p", "v", "s"]) {
      await titelFeld.press(taste);
    }

    // Alle vier Zeichen stehen noch im Feld — kein Kürzel hat sie abgefangen.
    await expect(titelFeld).toHaveValue("tpvs");

    // Es hat sich kein Overlay geöffnet (weder Palette noch Projekt-Modal).
    await expect(
      page.getByPlaceholder("Search for apps and commands..."),
    ).not.toBeVisible();
    await expect(
      page.getByRole("button", { name: "Create Project", exact: true }),
    ).not.toBeVisible();
  });

  test("Tippen ins Suchfeld der Palette löst kein Kürzel aus (pc/tc bleiben Suche)", async ({
    page,
  }) => {
    const ich = neueIdentitaet("f13c");
    await kontoAnlegen(page, ich);
    await arbeitsbereichAnlegen(page, `ESF Probe ${Date.now()}`);
    await projektAnlegen(page, `Projekt ${Date.now()}`);

    // Palette öffnen — das Suchfeld (CommandInput) übernimmt den Fokus.
    await paletteOeffnen(page);
    const suchfeld = page.getByPlaceholder("Search for apps and commands...");
    await expect(suchfeld).toBeFocused();

    // 'pc' („Projekt anlegen") als reine Suche tippen: kein Modal, die
    // Palette bleibt offen, und das Getippte steht unverändert im Feld.
    await page.keyboard.type("pc");
    await expect(suchfeld).toHaveValue("pc");
    await expect(suchfeld).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Create Project", exact: true }),
    ).not.toBeVisible();

    // 'tc' („Task anlegen") — erneut als reine Suche, kein Task-Modal.
    await suchfeld.fill("");
    await page.keyboard.type("tc");
    await expect(suchfeld).toHaveValue("tc");
    await expect(suchfeld).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Create Task", exact: true }),
    ).not.toBeVisible();
  });
});
