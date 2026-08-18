import { expect, type Page } from "@playwright/test";

/**
 * Gemeinsame Bausteine der Journeys.
 *
 * Regel der Suite: Ein Spec beschreibt EINE Nutzeraufgabe in sichtbaren
 * Schritten mit sichtbaren Erwartungen. Was hier steht, ist deshalb bewusst
 * dünn — nur was jede Journey braucht, um überhaupt anzufangen. Fachliche
 * Schritte gehören in den Spec, nicht in diesen Helfer: Ein Helfer, der eine
 * Journey abkürzt, nimmt ihr genau die Aussagekraft, für die sie existiert.
 */

/** Eine je Lauf eindeutige Identität. Journeys teilen sich eine Datenbank. */
export function neueIdentitaet(praefix = "esf") {
  const marke = `${Date.now()}-${Math.floor(Math.random() * 10_000)}`;
  return {
    name: `ESF Test ${marke}`,
    email: `${praefix}-${marke}@esf.local`,
    passwort: "EsfTest!2026",
  };
}

/**
 * Schritt 0 fast jeder Journey: ein Konto anlegen. Kaneo lässt öffentliche
 * Registrierung zu (`/api/config` → disableRegistration false); ohne SMTP ist
 * keine Mailbestätigung nötig.
 *
 * Ein frisches Konto landet NICHT im Dashboard, sondern im Onboarding — es hat
 * noch keinen Arbeitsbereich. Wer bis ins Dashboard will, nimmt danach
 * `arbeitsbereichAnlegen`.
 */
export async function kontoAnlegen(
  page: Page,
  identitaet = neueIdentitaet(),
): Promise<ReturnType<typeof neueIdentitaet>> {
  await page.goto("/auth/sign-up");

  await page.getByLabel("Full Name").fill(identitaet.name);
  await page.getByLabel("Email").fill(identitaet.email);
  // Achtung: Das Passwort-Label zeigt per `for` auf den Wrapper-<div>, nicht
  // auf das <input> — getByLabel("Password") liefert deshalb ein nicht
  // befüllbares Element. Deshalb hier der Name-Selektor.
  await page.locator('input[name="password"]').fill(identitaet.passwort);
  await page.getByRole("button", { name: "Create Account" }).click();

  await expect(page).toHaveURL(/\/onboarding/, { timeout: 30_000 });
  return identitaet;
}

/** Der zweite Einstiegsschritt: den ersten Arbeitsbereich anlegen. */
export async function arbeitsbereichAnlegen(
  page: Page,
  name = `Arbeitsbereich ${Date.now()}`,
): Promise<string> {
  // Befund 'Workspace name is required' (Karte t_288738fa): Der Name läuft
  // durch ein React-kontrolliertes Feld (react-hook-form über Base-UI-Field).
  // RHF liest den Wert beim input-Event aus seinem Feld-Register; ist dieses
  // unter Last noch nicht bereit, wird ein LEERER Wert festgehalten und das
  // kontrollierte Feld bleibt dauerhaft "" — fill ging verloren. Deshalb füllen
  // wir nach, bis der Wert wirklich hält (und nicht nur im DOM steht). Das heilt
  // die Befundklasse für ALLE Journeys, denn sie teilen sich diesen Helfer.
  const nameFeld = page.locator('input[name="name"]');
  for (let versuch = 0; versuch < 5; versuch += 1) {
    await nameFeld.fill(name);
    await page.waitForTimeout(75);
    if ((await nameFeld.inputValue()) === name) {
      break;
    }
    // fill wurde verworfen (Kontroll-Register war noch nicht bereit) → erneut.
  }
  await expect(nameFeld).toHaveValue(name);

  await page.getByRole("button", { name: "Create workspace" }).click();

  await expect(page).not.toHaveURL(/\/onboarding/, { timeout: 30_000 });
  return name;
}

/**
 * Bis ins Board eines frisch angelegten Projekts. Erwartet eine Sitzung auf
 * einer Arbeitsbereichsseite (nach `arbeitsbereichAnlegen` oder aus dem
 * Dashboard) und wiederholt den sichtbaren Weg, den die Journey J-02
 * dokumentiert: „Add project" — Projektname — „Create Project".
 */
export async function projektAnlegen(
  page: Page,
  name = `Projekt ${Date.now()}`,
): Promise<string> {
  await page.getByRole("button", { name: "Add project" }).click();
  await page.getByPlaceholder("Project name").fill(name);
  await page.getByRole("button", { name: "Create Project" }).click();
  await expect(page).toHaveURL(/\/project\/[^/]+\/board/, { timeout: 30_000 });
  return name;
}
