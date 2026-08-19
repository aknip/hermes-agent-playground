import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  parseExport,
  type WekanBoard,
  type WekanCard,
  WekanExportError,
} from "./parser.js";

const single = readFileSync(
  new URL("./fixtures/wekan-export.json", import.meta.url),
  "utf8",
);
const multi = readFileSync(
  new URL("./fixtures/wekan-export-multiboard.json", import.meta.url),
  "utf8",
);

function singleBoard(): WekanBoard {
  const board = parseExport(single).boards[0];
  if (!board) throw new Error("fixture has no board");
  return board;
}

function cardOn(title: string): WekanCard {
  const active = singleBoard().lists.flatMap((list) => list.cards);
  const card = active.find((candidate) => candidate.title === title);
  if (!card) throw new Error(`fixture has no card "${title}"`);
  return card;
}

describe("parseExport (single board fixture)", () => {
  it("normalizes one board with its active lists in sort order", () => {
    const board = singleBoard();
    expect(board.title).toBe("Produkt-Booster");
    expect(board.lists.map((list) => list.title)).toEqual([
      "To Do",
      "In Progress",
      "Done",
    ]);
    expect(board.lists.map((list) => list.sort)).toEqual([1, 2, 3]);
  });

  it("counts archived lists and cards instead of importing them", () => {
    const board = singleBoard();
    expect(board.archivedLists).toBe(1);
    expect(board.archivedCards).toBe(1);
    const activeCards = board.lists.flatMap((list) => list.cards);
    expect(activeCards).toHaveLength(3);
    expect(activeCards.map((card) => card.title)).not.toContain("Alte Idee");
  });

  it("counts card attachments as skipped", () => {
    expect(singleBoard().attachmentCount).toBe(2);
  });

  it("resolves labels and members to names on each card", () => {
    expect(cardOn("Anleitung schreiben").labels).toEqual(["Bug"]);
    expect(cardOn("Anleitung schreiben").memberNames).toEqual([
      "Alex Beispiel",
    ]);
    expect(cardOn("Testdaten anlegen").labels).toEqual(["Bug", "Feature"]);
    expect(cardOn("Testdaten anlegen").memberNames).toEqual(["Sam Mustermann"]);
    expect(cardOn("Checkliste durchsehen").memberNames).toEqual([
      "Alex Beispiel",
      "Sam Mustermann",
    ]);
  });

  it("keeps card titles and descriptions", () => {
    expect(cardOn("Anleitung schreiben").title).toBe("Anleitung schreiben");
    expect(cardOn("Anleitung schreiben").description).toBe(
      "Den Umzug erklären",
    );
  });

  it("normalizes due dates to ISO", () => {
    expect(cardOn("Anleitung schreiben").dueAt).toBe(
      "2026-08-25T09:00:00.000Z",
    );
  });

  it("collects comments per card in created order with author as text", () => {
    const c1 = cardOn("Anleitung schreiben");
    expect(c1.comments).toHaveLength(2);
    expect(c1.comments[0]).toEqual({
      text: "Bitte Screenshots ergänzen",
      authorName: "Sam Mustermann",
      createdAt: "2026-08-10T08:00:00.000Z",
    });
    expect(c1.comments[1]?.authorName).toBe("Alex Beispiel");
  });

  it("attaches checklists with their items and finished flags", () => {
    const checklist = cardOn("Checkliste durchsehen").checklists[0];
    expect(checklist?.title).toBe("Release-Schritte");
    expect(checklist?.items).toEqual([
      { title: "Version erhöhen", isFinished: true },
      { title: "Release taggen", isFinished: false },
    ]);
  });
});

describe("parseExport (multi board fixture)", () => {
  it("normalizes one board per entry of a boards bundle", () => {
    const boards = parseExport(multi).boards;
    expect(boards.map((board) => board.title)).toEqual(["Board A", "Board B"]);
    expect(boards[0]?.lists).toHaveLength(1);
    expect(boards[1]?.lists).toHaveLength(2);
  });
});

describe("parseExport (error behaviour, AC3)", () => {
  it("rejects an empty file", () => {
    expect(() => parseExport("")).toThrow(WekanExportError);
  });

  it("rejects broken JSON", () => {
    expect(() => parseExport("{ not json")).toThrow(WekanExportError);
  });

  it("rejects JSON without a board structure", () => {
    expect(() => parseExport('{"foo": "bar"}')).toThrow(WekanExportError);
    expect(() => parseExport('{"boards": []}')).toThrow(WekanExportError);
  });

  it("throws a message that names WeKan", () => {
    try {
      parseExport("{}");
      expect.unreachable("should have thrown");
    } catch (error) {
      expect(error).toBeInstanceOf(WekanExportError);
      expect((error as WekanExportError).message).toMatch(/wekan/i);
    }
  });
});
