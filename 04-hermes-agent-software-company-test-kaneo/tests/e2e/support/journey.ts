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
  // Kurz nach der Registrierung kann der Submit laufen, bevor React Hook Form
  // sein Feld angeschlossen hat: Das Input zeigt den Namen, aber RHF ist leere
  // und weist den Submit mit „required" ab. Dann ist das Formular verbunden und
  // ein erneuter Versuch klappt. Da die Validierung clientseitig greift, legt
  // ein leerer Fehlversuch keinen Arbeitsbereich an — erneutes Senden ist sicher.
  const nameInput = page.locator('input[name="name"]');
  const submit = page.getByRole("button", { name: "Create workspace" });
  for (let versuch = 0; versuch < 5; versuch++) {
    await expect(nameInput).toBeVisible({ timeout: 15_000 });
    await nameInput.fill(name);
    await submit.click();
    try {
      await expect(page).not.toHaveURL(/\/onboarding/, { timeout: 8_000 });
      return name;
    } catch {
      // Noch auf /onboarding: entweder eine echte Anlage in Lauf (Success-Schritt
      // dauert ~1,5 s + Navigation) oder ein leerer Submit. Ist das Namensfeld
      // weg, laufen wir dem Redirect hinterher; sonst erneut ausfüllen.
      if (!(await nameInput.isVisible().catch(() => false))) {
        await expect(page).not.toHaveURL(/\/onboarding/, { timeout: 20_000 });
        return name;
      }
    }
  }
  throw new Error(
    "arbeitsbereichAnlegen: Onboarding blieb nach 5 Versuchen auf /onboarding",
  );
}

/**
 * Einstieg ab J-02: im Arbeitsbereich das erste Projekt anlegen. Landet direkt
 * auf dem Board des neuen Projekts. Die fachlichen Schritte (leere Projektliste
 * sehen, Formular ausfüllen, bestätigen) bleiben dem Spec von J-02 vorbehalten;
 * dieser Helfer ist nur der gemeinsame Aufhänger für Journeys, die danach auf
 * einem Board beginnen.
 */
export async function projektAnlegen(
  page: Page,
  name = `Projekt ${Date.now()}`,
): Promise<void> {
  // Leere Projektliste: der Einstiegspunkt „Create project" (Kleinbuchstaben,
  // workspace:projects.createProject) im Kopf und im Leerzustand.
  await page
    .getByRole("button", { name: "Create project", exact: true })
    .first()
    .click();
  // Nur der Name ist Pflicht; der Projekt-Schlüssel wird automatisch erzeugt.
  await page.getByPlaceholder("Project name").fill(name);
  await page
    .getByRole("button", { name: "Create Project", exact: true })
    .click();
  await expect(page).toHaveURL(/\/project\/[^/]+\/board/, { timeout: 30_000 });
}

/** Einstieg für J-04: einen Vorgang in der ersten Spalte („To Do") anlegen. */
export async function vorgangAnlegen(page: Page, title: string): Promise<void> {
  // Das „+" jeder Spaltenüberschrift (title "Add task") öffnet das Formular;
  // die erste Spalte des neuen Projekts ist „To Do".
  await page.getByTitle("Add task").first().click();
  await expect(page.locator(".kaneo-create-task-modal")).toBeVisible();
  await page.getByPlaceholder("Task title").fill(title);
  await page.getByRole("button", { name: "Create Task", exact: true }).click();
  // Der Vorgang ist erst angelegt, wenn das Formular wieder zu ist und die
  // Karte im Board liegt — beides gehört zur sichtbaren Erwartung.
  await expect(page.locator(".kaneo-create-task-modal")).not.toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText(title, { exact: true })).toBeVisible();
}
