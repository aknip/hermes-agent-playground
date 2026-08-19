import { type Browser, expect, type Page } from "@playwright/test";
import { kontoAnlegen, neueIdentitaet } from "./journey";

/**
 * Additive Helfer für Journey J-05 (Teammitglied einladen).
 *
 * Diese Datei ist bewusst klein und additiv: Der zweite Browser-Kontext und
 * die Annahme-Schritte von J-05 wohnen hier, damit tests/e2e/support/journey.ts
 * unangetastet bleibt (dort arbeitet F-R1-3 parallel).
 */

const BASE_URL = process.env.E2E_WEB_URL ?? "http://localhost:5173";

/**
 * Legt das Gast-Konto in einem EIGENEN Browser-Kontext an. Zwei getrennte
 * Kontexte heißen getrennte Cookies (storageState) — beide Konten sind
 * gleichzeitig eingeloggt, ohne Logout-/Login-Tanz.
 *
 * Die E-Mail des Kontos ist dieselbe, die der Einladende später in der
 * Mitglieder-Seite einträgt (aber dieselbe neueIdentitaet-Signatur wie in der
 * Spec), so ist die eingeladene Adresse mit Sicherheit die des Gasts.
 */
export async function gastKontoAnlegen(
  browser: Browser,
  gast = neueIdentitaet("j05-gast"),
) {
  const kontext = await browser.newContext({ baseURL: BASE_URL });
  const seite = await kontext.newPage();
  await kontoAnlegen(seite, gast);
  return { kontext, seite, gast };
}

/**
 * Der bereits eingeloggte Gast öffnet den Einladungslink und nimmt die
 * Einladung an. Erwartung (sichtbarer Zustand): nach dem Klick auf
 * „Accept Invitation" navigiert die Route in den Arbeitsbereich des
 * Einladenden — ein URL-Wechsel auf /dashboard/workspace/.
 */
export async function einladungAnnehmen(
  seite: Page,
  link: string,
): Promise<void> {
  await seite.goto(link);
  await seite.getByRole("button", { name: "Accept Invitation" }).click();
  await expect(seite).toHaveURL(/\/dashboard\/workspace\/[^/]+/, {
    timeout: 30_000,
  });
}
