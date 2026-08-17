import { expect, test } from "@playwright/test";

/**
 * Journey J-00 — Anwendung erreichbar
 *
 * Die kürzeste Journey der Suite und die Vorbedingung aller anderen: Ein
 * Besucher ohne Sitzung ruft die Anwendung auf und steht vor der Anmeldung.
 *
 * Schritte: 2 · Eigentümer: esf-qa-release
 */
test.describe("J-00 Anwendung erreichbar", () => {
  test("Ein Besucher ohne Sitzung landet auf der Anmeldeseite", async ({
    page,
  }) => {
    // Schritt 1 — Der Besucher ruft die Startseite auf.
    await page.goto("/");

    // Schritt 2 — Er sieht die Anmeldung, nicht den Arbeitsbereich.
    // Die Anwendung merkt sich das Ziel als ?redirect=/dashboard.
    await expect(page).toHaveURL(/\/auth\/sign-in/);
    await expect(page.getByText("Welcome back")).toBeVisible();
    await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
  });

  test("Die Anmeldeseite bietet den Weg zur Registrierung an", async ({
    page,
  }) => {
    // Schritt 1 — Der Besucher steht auf der Anmeldeseite.
    await page.goto("/auth/sign-in");

    // Schritt 2 — Er folgt dem Hinweis "Noch kein Konto?".
    await page.getByRole("link", { name: "Create account" }).click();

    // Schritt 3 — Er steht im Registrierungsformular.
    await expect(page).toHaveURL(/\/auth\/sign-up/);
    await expect(page.getByLabel("Full Name")).toBeVisible();
  });
});
