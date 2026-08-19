// erzeugt von scripts/e2e-video.sh — nach dem Lauf wieder entfernt.
// Erbt die Projekt-Config und überstimmt genau fünf Dinge:
// Video an, headless erzwungen, eigenes Ergebnisverzeichnis, slowMo, Zeitlimit.
//
// Die Größe steht ausdrücklich dabei: Playwright zeichnet sonst in seiner
// Vorgabe 800x450 auf und skaliert den 1280x720-Viewport von Desktop Chrome
// herunter — real gemessen am 18.08.2026. Für ein Regressionsvideo reicht das,
// für ein lesbares Nutzerhandbuch nicht. 1280x720 ist der Viewport selbst,
// also 1:1 statt heruntergerechnet.
import base from "./playwright.config";
import { defineConfig } from "@playwright/test";

export default defineConfig({
  ...(base as object),
  timeout: 300000,
  use: {
    ...((base as { use?: object }).use ?? {}),
    video: { mode: "on", size: { width: 1280, height: 720 } },
    headless: true,
    launchOptions: {
      ...((base as { use?: { launchOptions?: object } }).use?.launchOptions ?? {}),
      slowMo: 350,
    },
  },
  outputDir: "./.esf-video-results",
});
