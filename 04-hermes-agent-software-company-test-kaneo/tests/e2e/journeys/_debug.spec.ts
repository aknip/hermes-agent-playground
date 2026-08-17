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
  const sx = kartenBox.x + kartenBox.width / 2;
  const sy = kartenBox.y + kartenBox.height / 2;
  const tx = zielBox.x + zielBox.width / 2;
  const ty = zielBox.y + 120;

  // Synthetische Pointer-Events direkt am Karten-Element absetzen, damit
  // der dnd-kit-Zeigersensor den Zug sicher erkennt.
  const dragResult = await page.evaluate(
    async ({ sx, sy, tx, ty }) => {
      const fire = (target: Element | Document, type: string, x: number, y: number) => {
        target.dispatchEvent(
          new PointerEvent(type, {
            bubbles: true,
            cancelable: true,
            button: 0,
            buttons: type === "pointerup" ? 0 : 1,
            clientX: x,
            clientY: y,
            pointerId: 1,
            isPrimary: true,
            pointerType: "mouse",
          }),
        );
      };
      const el = document.elementFromPoint(sx, sy);
      if (!el) return "no-element";
      fire(el, "pointerdown", sx, sy);
      await new Promise((r) => setTimeout(r, 60));
      fire(document, "pointermove", sx + 15, sy);
      await new Promise((r) => setTimeout(r, 60));
      fire(document, "pointermove", tx, ty);
      await new Promise((r) => setTimeout(r, 60));
      fire(document, "pointerup", tx, ty);
      return "dispatched";
    },
    { sx, sy, tx, ty },
  );
  console.log("DRAG_RESULT", dragResult);
  await page.waitForTimeout(1800);

  const cols = await page.evaluate(() => {
    return [...document.querySelectorAll("div")].filter((d) => (d.className?.toString() || "").includes("rounded-xl")).map((d) => d.innerText.replace(/\n/g, " | ").slice(0, 80));
  });
  console.log("COLUMNS:", JSON.stringify(cols, null, 1));
  console.log("TASK_VISIBLE:", await page.getByText(aufgabe, { exact: true }).count());
});