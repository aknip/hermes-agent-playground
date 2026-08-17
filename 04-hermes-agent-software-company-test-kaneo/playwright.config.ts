import { defineConfig, devices } from "@playwright/test";

/**
 * E2E-Suite von Kaneo — Regressionsnetz und lebendes Nutzerhandbuch.
 *
 * Jede Spec unter tests/e2e/ spielt EINE Nutzeraufgabe (Journey) Schritt für
 * Schritt nach. Der Katalog aller Journeys steht im Firmen-Vault unter
 * analysis/journeys.html.
 *
 * Vorbedingung: Postgres läuft.
 *     docker compose -f compose.yml up -d postgres
 *
 * API und Web startet die Suite selbst (webServer unten) und lässt bereits
 * laufende Server stehen — `pnpm dev` neben einem Testlauf ist also erlaubt.
 */

const WEB_URL = process.env.E2E_WEB_URL ?? "http://localhost:5173";
const API_URL = process.env.E2E_API_URL ?? "http://localhost:1337";

export default defineConfig({
  testDir: "./tests/e2e",
  // Journeys teilen sich eine Datenbank. Parallelität würde sie über
  // Fremddaten stolpern lassen, bevor die Suite Mandantentrennung kann.
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [
    ["list"],
    ["html", { outputFolder: "test-results/html", open: "never" }],
    ["json", { outputFile: "test-results/results.json" }],
  ],
  outputDir: "test-results/artifacts",
  use: {
    baseURL: WEB_URL,
    // Traces und Screenshots sind die Akte, die der Merge-Riegel archiviert.
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  webServer: [
    {
      command: "pnpm --filter @kaneo/api dev",
      url: `${API_URL}/api/health`,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
      stdout: "pipe",
      stderr: "pipe",
    },
    {
      command: "pnpm --filter @kaneo/web dev",
      url: WEB_URL,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
      stdout: "pipe",
      stderr: "pipe",
    },
  ],
});
