import { describe, expect, it } from "vitest";
import { parseCsv } from "./csv.js";
import {
  buildTasks,
  normalizePriority,
  planColumns,
  splitLabels,
  toDueDate,
} from "./mapping.js";

describe("normalizePriority", () => {
  it("keeps a valid priority case-insensitively", () => {
    expect(normalizePriority("HIGH").priority).toBe("high");
    expect(normalizePriority("medium").priority).toBe("medium");
  });

  it("falls back to no-priority with a warning on an invalid value", () => {
    const result = normalizePriority("urgentx");

    expect(result.priority).toBe("no-priority");
    expect(result.warning).toBeDefined();
  });

  it("defaults to no-priority when empty", () => {
    expect(normalizePriority(undefined).priority).toBe("no-priority");
    expect(normalizePriority(undefined).warning).toBeUndefined();
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
    expect(toDueDate("")).toBeUndefined();
    expect(toDueDate(undefined)).toBeUndefined();
  });
});

describe("splitLabels", () => {
  it("splits on semicolons, trims and dedupes", () => {
    expect(splitLabels("a ; b ; a")).toEqual(["a", "b"]);
  });

  it("returns an empty array for no labels", () => {
    expect(splitLabels("")).toEqual([]);
    expect(splitLabels(undefined)).toEqual([]);
  });
});

describe("planColumns", () => {
  it("keeps first-occurrence order and dedupes identical names", () => {
    expect(
      planColumns(["Backlog", "To Do", "Backlog"]).map((column) => column.name),
    ).toEqual(["Backlog", "To Do"]);
  });

  it("renames reserved virtual slugs", () => {
    const [planned] = planColumns(["Planned"]);

    expect(planned?.slug).toBe("planned-list");
    expect(planned?.renamedFrom).toBe("Planned");
  });

  it("disambiguates slug collisions", () => {
    const planned = planColumns(["To Do", "to do"]);

    expect(new Set(planned.map((column) => column.slug)).size).toBe(2);
    expect(planned[1]?.slug).toBe("to-do-2");
  });

  it("falls back to Untitled for an unusable name", () => {
    const [planned] = planColumns(["???"]);

    expect(planned?.slug).toBe("untitled");
  });

  it("uses Untitled for an empty column cell", () => {
    const [planned] = planColumns([""]);

    expect(planned?.name).toBe("Untitled");
  });
});

describe("buildTasks", () => {
  it("maps each field per spec §3.1", () => {
    const csv = [
      "title,description,column,priority,due_date,assignee_email,labels,comment",
      "Write copy,Homepage copy,Backlog,high,2026-03-04,sam@example.com,urgent;copy,Great start",
    ].join("\n");

    const result = buildTasks(parseCsv(csv));

    expect(result.tasks).toHaveLength(1);
    const task = result.tasks[0];
    expect(task?.title).toBe("Write copy");
    expect(task?.description).toBe("Homepage copy");
    expect(task?.columnName).toBe("Backlog");
    expect(task?.priority).toBe("high");
    expect(task?.dueDate).toBe("2026-03-04T00:00:00.000Z");
    expect(task?.assigneeEmail).toBe("sam@example.com");
    expect(task?.labels).toEqual(["urgent", "copy"]);
    expect(task?.comment).toBe("Great start");
    expect(result.columns[0]?.slug).toBe("backlog");
  });

  it("warns and falls back to no-priority for an invalid priority", () => {
    const result = buildTasks(parseCsv("title,priority\na,urgentx\n"));

    expect(result.tasks[0]?.priority).toBe("no-priority");
    expect(result.warnings.join(" ")).toContain("no-priority");
  });

  it("leaves optional fields empty and uses Untitled for a blank column cell", () => {
    const result = buildTasks(parseCsv("title,column\na,\n"));
    const task = result.tasks[0];

    expect(task?.description).toBeUndefined();
    expect(task?.dueDate).toBeUndefined();
    expect(task?.assigneeEmail).toBeUndefined();
    expect(task?.labels).toEqual([]);
    expect(task?.comment).toBeUndefined();
    expect(result.columns[0]?.name).toBe("Untitled");
  });

  it("numbers rows as file lines (header is row 1)", () => {
    const result = buildTasks(parseCsv("title\na\nb\n"));

    expect(result.tasks.map((task) => task.row)).toEqual([2, 3]);
  });
});
