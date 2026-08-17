import { chromium, expect } from "@playwright/test";

/**
 * Kaltstart-Aufwärmung der Suite.
 *
 * Der erste Seitenaufruf nach einem kalten Vite-Dev-Server-Start ist der mit
 * Abstand teuerste: Vite transformiert das Modulnetz des Clients on demand und
 * die App ist in diesem Fenster noch nicht bedienbar. Gemessen am betroffenen
 * Endpunkt (POST /auth/organization/create) ist die API dabei schnell (< 100 ms)
 * — der Request wurde gar nicht erst abgesetzt, der Absenden-Button blieb auf
 * "Create workspace" stehen, weil die Frontend-Ereignisbehandlung kalt noch
 * nicht bereit war. J-03 war im Suitenlauf schlicht der erste Test, der die
 * Anwendung nach kaltem Vite-Start wirklich bediente, und bezahlte deshalb
 * immer als einziger den Preis.
 *
 * Statt den 30-s-Deckel einer einzelnen Journey zu erhoehen (die Grenze
 * verschoben, nicht beseitigt), faehrt dieser Schritt die Anwendung EINMAL warm,
 * bevor der erste Spec laeuft: ein realer Durchlauf "Konto → Arbeitsbereich",
 * der Vite zwingt, das gesamte Modulnetz zu transformieren. Jede spaetere
 * Journey landet damit auf einer schon bedienbaren App und laeuft unter dem
 * normalen 30-s-Deckel. Das heilt die Ursachenklasse fuer alle kuenftigen
 * Journeys, nicht nur fuer J-03.
 */
export default async function globalSetUp() {
  const baseURL = process.env.E2E_WEB_URL ?? "http://localhost:5173";
  const browser = await chromium.launch();
  const context = await browser.newContext({ baseURL });
  const page = await context.newPage();

  try {
    // Ein eindeutiger Wegwerf-Anwender — Journeys nutzen je Lauf eigene
    // Identitaeten, ein zusaetzlicher Nutzer stoert keine Zusicherung.
    const marke = `${Date.now()}-${Math.floor(Math.random() * 10_000)}`;
    const name = `Warmup ${marke}`;
    const email = `warmup-${marke}@esf.local`;

    const t0 = Date.now();
    await page.goto("/auth/sign-up");
    await page.getByLabel("Full Name").fill(name);
    await page.getByLabel("Email").fill(email);
    // Traps aus AGENTS.md: Das Passwort-Label zeigt auf den Wrapper-<div>,
    // nicht auf das <input> — deshalb der Name-Selektor.
    await page.locator('input[name="password"]').fill("EsfTest!2026");
    await page.getByRole("button", { name: "Create Account" }).click();
    await expect(page).toHaveURL(/\/onboarding/, { timeout: 120_000 });

    await page.locator('input[name="name"]').fill(`Warmup-WS ${marke}`);
    // Grosszuegiger Deckel: der kalte First-Load ist hier zu Hause, nicht im
    // Spec. Wuerden wir den Deckel des Helpers hoeher setzen, verschoeben wir
    // nur die Grenze — hier gehoert er her, einmalig und fuer alle Journeys.
    // Der erste Klick trifft oft auf die noch transformierende App; ob die
    // Anlage selbst durchlaeuft, ist fuer die Aufwaermung zweitrangig — das
    // Laden der onboard / create-Module ist der Zweck, nicht der Rucklauf.
    await page.getByRole("button", { name: "Create workspace" }).click();
    try {
      await page.waitForURL((url) => !url.pathname.startsWith("/onboarding"), {
        timeout: 90_000,
      });
    } catch {
      // best-effort: auch ohne abgeschlossene Anlage sind die Module warm.
    }

    console.warn(
      `[globalSetup] Warmlauf in ${Date.now() - t0}ms` + ` (${page.url()})`,
    );
  } catch (error) {
    // Der Warmlauf ist best-effort: bricht er selbst am kalten App-Start ab,
    // hat er die Module trotzdem schon angefragt — der naechste echte Lauf
    // trifft auf die bereits transformierte Anwendung.
    console.warn(
      "[globalSetup] Warmlauf abgebrochen (Details unter) — fahre fort; der erste echte Lauf laeuft dann warm.",
      error instanceof Error ? error.message : String(error),
    );
  } finally {
    await browser.close();
  }
}
