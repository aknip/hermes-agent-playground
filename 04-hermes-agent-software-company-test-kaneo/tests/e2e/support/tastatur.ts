import { expect, type Page } from "@playwright/test";

/**
 * Tastatur-Helfer für F-R1-3 (Tastaturbedienung & Command-Palette).
 *
 * Bewusst eine EIGENE Datei, nicht support/journey.ts — die teilt sich
 * esf-dev-b mit F-R1-4 und bleibt unangetastet.
 */

const PALETTE_PLACEHOLDER = "Search for apps and commands...";

/** Modifier für ⌘/Ctrl+K, wie die Anwendung ihn auf der Plattform wählt. */
async function paletteModifier(page: Page): Promise<"Meta" | "Control"> {
  const istMac = await page.evaluate(() =>
    navigator.platform.toLowerCase().includes("mac"),
  );
  return istMac ? "Meta" : "Control";
}

/** ⌘K/Ctrl+K — öffnet die Command-Palette. */
export async function paletteOeffnen(page: Page): Promise<void> {
  const mod = await paletteModifier(page);
  await page.keyboard.press(`${mod}+KeyK`);
  await expect(page.getByPlaceholder(PALETTE_PLACEHOLDER)).toBeVisible();
}

/**
 * Tastatur-Sequenz eines Palette-Befehls (z. B. "pc" für „Projekt anlegen").
 * `type` erzeugt pro Buchstabe echte keydown-Ereignisse, die der
 * Sequenz-Matcher der Palette auf document liest.
 */
export async function paletteBefehl(
  page: Page,
  sequenz: string,
): Promise<void> {
  await page.keyboard.type(sequenz, { delay: 40 });
}
