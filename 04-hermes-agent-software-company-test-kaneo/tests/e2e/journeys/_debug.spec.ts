import { expect, test } from "@playwright/test";
import {
  arbeitsbereichAnlegen,
  kontoAnlegen,
  neueIdentitaet,
  projektAnlegen,
} from "../support/journey";

test("debug J-04", async ({ page }) => {
  const ich = neueIdentitaet("j04debug");
  const aufgabe = `Debug ${Date.now()}`;
  await kontoAnlegen(page, ich);
  await arbeitsbereichAnlegen(page);
  await projektAnlegen(page);
  await page.getByTitle("Add task").first().click();
  await page.getByPlaceholder("Task title").fill(aufgabe);
  await page.getByRole("button", { name: "Create Task" }).click();
  await expect(page.getByText(aufgabe, { exact: true })).toBeVisible();

  const karte = page.getByText(aufgabe, { exact: true });
  const kartenBox = await karte.boundingBox();
  const zielkopf = page.getByText("In Progress", { exact: true });
  const zielBox = await zielkopf.boundingBox();
  console.log("SRC", JSON.stringify(kartenBox));
  console.log("DST", JSON.stringify(zielBox));
  await page.mouse.move(kartenBox.x + kartenBox.width / 2, kartenBox.y + kartenBox.height / 2);
  await page.mouse.down();
  await page.mouse.move(zielBox.x + zielBox.width / 2, zielBox.y + 120, { steps: 20 });
  await page.mouse.up();
  await page.waitForTimeout(1500);

  const cols = await page.evaluate(() => {
    return [...document.querySelectorAll("div")].filter((d) => (d.className?.toString() || "").includes("rounded-xl")).map((d) => d.innerText.replace(/\n/g, " | ").slice(0, 80));
  });
  console.log("COLUMNS:", JSON.stringify(cols, null, 1));
  console.log("TASK_VISIBLE:", await page.getByText(aufgabe, { exact: true }).count());
});