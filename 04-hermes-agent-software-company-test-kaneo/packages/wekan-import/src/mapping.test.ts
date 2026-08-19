import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  boardProjectName,
  buildDescription,
  DEFAULT_PRIORITY,
  formatComment,
  pickMemberByName,
  planWekanExport,
  toDueDate,
} from "./mapping.js";
import {
  parseExport,
  type WekanBoard,
  type WekanComment,
  type WekanExport,
} from "./parser.js";

const single: WekanExport = parseExport(
  readFileSync(
    new URL("./fixtures/wekan-export.json", import.meta.url),
    "utf8",
  ),
);
const multi: WekanExport = parseExport(
  readFileSync(
    new URL("./fixtures/wekan-export-multiboard.json", import.meta.url),
    "utf8",
  ),
);

function firstBoard(data: WekanExport): WekanBoard {
  const board = data.boards[0];
  if (!board) throw new Error("fixture has no board");
  return board;
}

describe("boardProjectName", () => {
  it("uses the base name for a single board", () => {
    expect(boardProjectName("Team Move", "Produkt-Booster", 1)).toBe(
      "Team Move",
    );
  });

  it("appends the board title when there are several boards", () => {
    expect(boardProjectName("Team Move", "Board A", 2)).toBe(
      "Team Move - Board A",
    );
  });
});

describe("toDueDate", () => {
  it("normalizes YYYY-MM-DD and ISO to ISO", () => {
    expect(toDueDate("2026-03-04")).toBe("2026-03-04T00:00:00.000Z");
    expect(toDueDate("2026-03-04T10:00:00.000Z")).toBe(
      "2026-03-04T10:00:00.000Z",
    );
  });

  it("drops unreadable and empty dates", () => {
    expect(toDueDate("not-a-date")).toBeUndefined();
    expect(toDueDate(undefined)).toBeUndefined();
  });
});

describe("buildDescription", () => {
  it("appends checklists as markdown checkboxes after the description", () => {
    const card = firstBoard(single).lists[1]?.cards[0];
    const description = card ? buildDescription(card) : "";
    expect(description).toContain("Karten müssen importiert werden");
    expect(description).toContain("## Release-Schritte");
    expect(description).toContain("- [x] Version erhöhen");
    expect(description).toContain("- [ ] Release taggen");
  });
});

describe("formatComment", () => {
  it("puts author and date into the text (AC5)", () => {
    const comment: WekanComment = {
      text: "Bitte Screenshots ergänzen",
      authorName: "Sam Mustermann",
      createdAt: "2026-08-10T08:00:00.000Z",
    };
    expect(formatComment(comment)).toBe(
      "Sam Mustermann am 2026-08-10: Bitte Screenshots ergänzen",
    );
  });

  it("falls back to the plain text when no date is known", () => {
    expect(
      formatComment({
        text: "hello",
        authorName: undefined,
        createdAt: undefined,
      }),
    ).toBe("hello");
  });
});

describe("planWekanExport", () => {
  it("keeps DEFAULT_PRIORITY because WeKan has no priority", () => {
    expect(DEFAULT_PRIORITY).toBe("no-priority");
    const card = planWekanExport(single, "Team Move").boards[0]?.cards[0];
    expect(card?.priority).toBe("no-priority");
  });

  it("names the single (only) board project after the base name", () => {
    const planned = planWekanExport(single, "Team Move");
    expect(planned.boards).toHaveLength(1);
    expect(planned.boards[0]?.projectName).toBe("Team Move");
  });

  it("plans columns in list order with unique slugs", () => {
    const board = planWekanExport(single, "Team Move").boards[0];
    expect(board?.columns.map((column) => column.name)).toEqual([
      "To Do",
      "In Progress",
      "Done",
    ]);
    expect(board?.columns.map((column) => column.slug)).toEqual([
      "to-do",
      "in-progress",
      "done",
    ]);
  });

  it("maps cards to their column slug status", () => {
    const board = planWekanExport(single, "Team Move").boards[0];
    const toDo = board?.cards.filter((card) => card.status === "to-do") ?? [];
    expect(toDo.map((card) => card.title)).toEqual([
      "Anleitung schreiben",
      "Testdaten anlegen",
    ]);
    expect(
      board?.cards.find((card) => card.title === "Checkliste durchsehen")
        ?.status,
    ).toBe("in-progress");
  });

  it("keeps only the labels used by real cards, with their colors", () => {
    const board = planWekanExport(single, "Team Move").boards[0];
    expect(board?.labels).toEqual([
      { name: "Bug", color: "#eb5a46" },
      { name: "Feature", color: "#61bd4f" },
    ]);
  });

  it("formats card comments in order", () => {
    const card = planWekanExport(single, "Team Move").boards[0]?.cards[0];
    expect(card?.comments).toEqual([
      "Sam Mustermann am 2026-08-10: Bitte Screenshots ergänzen",
      "Alex Beispiel am 2026-08-11: Erledigt, siehe unten",
    ]);
  });

  it("carries the reported counters for skipped work", () => {
    const board = planWekanExport(single, "Team Move").boards[0];
    expect(board?.archivedLists).toBe(1);
    expect(board?.archivedCards).toBe(1);
    expect(board?.attachmentCount).toBe(2);
    expect(board?.checklistItems).toBe(2);
  });

  it("names each board project distinctly in a multi-board export", () => {
    const planned = planWekanExport(multi, "Team Move");
    expect(planned.boards.map((board) => board.projectName)).toEqual([
      "Team Move - Board A",
      "Team Move - Board B",
    ]);
  });

  it("counts cards per board (1 and 2)", () => {
    const planned = planWekanExport(multi, "Team Move");
    expect(planned.boards.map((board) => board.cards.length)).toEqual([1, 2]);
  });
});

describe("pickMemberByName", () => {
  const membersByName = new Map([["alex beispiel", "ku_1"]]);

  it("matches the first present member case-insensitively", () => {
    expect(
      pickMemberByName(["Alex Beispiel", "Sam Mustermann"], membersByName),
    ).toEqual({ userId: "ku_1" });
  });

  it("reports no_match when no member matches", () => {
    expect(pickMemberByName(["Sam Mustermann"], membersByName)).toEqual({
      reason: "no_match",
    });
  });

  it("returns nothing for a card with no members", () => {
    expect(pickMemberByName([], membersByName)).toEqual({});
  });
});
