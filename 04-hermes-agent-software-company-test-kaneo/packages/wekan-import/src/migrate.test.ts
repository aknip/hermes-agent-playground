import { readFileSync } from "node:fs";
import type { KaneoClient } from "@kaneo/kaneo-client";
import { describe, expect, it } from "vitest";
import { type PlannedBoard, planWekanExport } from "./mapping.js";
import { importWekan, type WekanBoardReport } from "./migrate.js";
import { parseExport } from "./parser.js";

type Call = { method: string; args: unknown[] };

const fixture = parseExport(
  readFileSync(
    new URL("./fixtures/wekan-export.json", import.meta.url),
    "utf8",
  ),
);

function fakeKaneo(
  calls: Call[],
  memberNames = ["Alex Beispiel", "Sam Mustermann"],
) {
  let taskCounter = 0;
  let labelCounter = 0;
  const record = (method: string, ...args: unknown[]) => {
    calls.push({ method, args });
  };

  return {
    async listProjects() {
      record("listProjects");
      return [{ id: "p_existing", name: "Existing", slug: "TM" }];
    },
    async listMembers() {
      record("listMembers");
      return memberNames.map((name, index) => ({
        id: `ku_${index + 1}`,
        name,
        email: `${name.toLowerCase().replace(/\s+/g, ".")}@example.com`,
      }));
    },
    async createProject(input: unknown) {
      record("createProject", input);
      return { id: "p_new", name: "x", slug: "X" };
    },
    async listColumns() {
      record("listColumns");
      return [
        { id: "c_default_1", name: "To Do", slug: "to-do" },
        { id: "c_default_2", name: "Done", slug: "done" },
      ];
    },
    async deleteColumn(id: string) {
      record("deleteColumn", id);
      return {};
    },
    async createColumn(_projectId: string, input: unknown) {
      record("createColumn", input);
      return { id: "c_new", name: "x", slug: "x" };
    },
    async createTask(_projectId: string, input: unknown) {
      record("createTask", _projectId, input);
      taskCounter++;
      return { id: `t_${taskCounter}`, title: "t", number: taskCounter };
    },
    async createLabel(input: unknown) {
      record("createLabel", input);
      labelCounter++;
      return { id: `l_${labelCounter}`, name: "l", color: "#000000" };
    },
    async createComment(
      taskId: string,
      content: string,
      externalUserName?: string,
    ) {
      record("createComment", taskId, content, externalUserName);
      return {};
    },
  } as unknown as KaneoClient;
}

function board(): PlannedBoard {
  const planned = planWekanExport(fixture, "Team Move").boards[0];
  if (!planned) throw new Error("fixture yields no planned board");
  return planned;
}

function firstReport(reports: WekanBoardReport[]): WekanBoardReport {
  const report = reports[0];
  if (!report) throw new Error("no report");
  return report;
}

describe("importWekan (dry run)", () => {
  it("reports counts without calling Kaneo and never writes", async () => {
    const calls: Call[] = [];
    const reports = await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: true,
    });

    expect(calls).toEqual([]);
    const report = firstReport(reports);
    expect(report.tasks).toBe(3);
    expect(report.columns).toBe(3);
    expect(report.labels).toBe(2);
    expect(report.comments).toBe(2);
    expect(report.checklistItems).toBe(2);
    expect(report.archivedLists).toBe(1);
    expect(report.archivedCards).toBe(1);
    expect(report.attachmentsSkipped).toBe(2);
    expect(report.projectKey).toBe("TM");
  });
});

describe("import run (write)", () => {
  it("removes seeded columns, then creates columns in planned order", async () => {
    const calls: Call[] = [];
    await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const sequence = calls.map((call) => call.method);
    expect(sequence.filter((m) => m === "deleteColumn")).toHaveLength(2);
    expect(sequence.lastIndexOf("deleteColumn")).toBeLessThan(
      sequence.indexOf("createColumn"),
    );
    const created = calls
      .filter((call) => call.method === "createColumn")
      .map((call) => call.args[0]);
    expect(created).toEqual([
      { name: "To Do" },
      { name: "In Progress" },
      { name: "Done" },
    ]);
  });

  it("creates tasks with mapped fields, status slug, priority and due date", async () => {
    const calls: Call[] = [];
    await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const writeCopy = calls
      .filter((call) => call.method === "createTask")
      .find(
        (call) =>
          (call.args[1] as { title: string }).title === "Anleitung schreiben",
      );
    expect(writeCopy?.args[1]).toMatchObject({
      title: "Anleitung schreiben",
      description: "Den Umzug erklären",
      status: "to-do",
      priority: "no-priority",
      dueDate: "2026-08-25T09:00:00.000Z",
    });
  });

  it("flattens a checklist into the description markdown", async () => {
    const calls: Call[] = [];
    await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const task = calls
      .filter((call) => call.method === "createTask")
      .find(
        (call) =>
          (call.args[1] as { title: string }).title === "Checkliste durchsehen",
      );
    const input = task?.args[1] as { description: string } | undefined;
    const description = input?.description ?? "";
    expect(description).toContain("- [x] Version erhöhen");
    expect(description).toContain("- [ ] Release taggen");
  });

  it("resolves an assignee by member name", async () => {
    const calls: Call[] = [];
    const reports = await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const created = calls
      .filter((call) => call.method === "createTask")
      .map((call) => call.args[1] as Record<string, unknown>);
    const withUser = created.filter((task) => task.userId);
    expect(withUser).toHaveLength(3);
    expect(firstReport(reports).assignees).toBe(3);
  });

  it("leaves a card unassigned and warns when no member matches", async () => {
    const calls: Call[] = [];
    const nobody: PlannedBoard = {
      ...board(),
      cards: [
        {
          id: "c_x",
          title: "Weird card",
          description: "",
          status: "to-do",
          priority: "no-priority",
          labels: [],
          memberNames: ["Nobody Wants"],
          comments: [],
        },
      ],
    };
    const reports = await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [nobody],
      dryRun: false,
    });

    const created = calls
      .filter((call) => call.method === "createTask")
      .map((call) => call.args[1] as Record<string, unknown>);
    expect(created[0]).not.toHaveProperty("userId");
    expect(firstReport(reports).assignees).toBe(0);
    expect(firstReport(reports).warnings.join(" ")).toContain("Nobody Wants");
  });

  it("creates each distinct label in the workspace and attaches it to tasks", async () => {
    const calls: Call[] = [];
    await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const labelCalls = calls
      .filter((call) => call.method === "createLabel")
      .map((call) => call.args[0] as Record<string, unknown>);
    const workspaceLabels = labelCalls.filter(
      (call) => call.taskId === undefined,
    );
    expect(workspaceLabels).toHaveLength(2);
    expect(workspaceLabels).toContainEqual({
      name: "Bug",
      color: "#eb5a46",
      workspaceId: "ws_1",
    });
    expect(labelCalls.filter((call) => call.taskId !== undefined)).toHaveLength(
      3,
    );
  });

  it("creates comments in order under the API key owner (no external author)", async () => {
    const calls: Call[] = [];
    await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    const comments = calls.filter((call) => call.method === "createComment");
    expect(comments).toHaveLength(2);
    expect(comments[0]?.args[1]).toBe(
      "Sam Mustermann am 2026-08-10: Bitte Screenshots ergänzen",
    );
    expect(comments[0]?.args[2]).toBeUndefined();
  });

  it("records a failing card in the report and still imports the rest", async () => {
    const calls: Call[] = [];
    const fragile = {
      ...fakeKaneo(calls),
      async createTask() {
        throw new Error("boom");
      },
    } as unknown as KaneoClient;

    const reports = await importWekan({
      kaneo: fragile,
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    expect(firstReport(reports).errors).toHaveLength(3);
    expect(firstReport(reports).errors[0]).toMatchObject({
      card: "Anleitung schreiben",
    });
    expect(firstReport(reports).tasks).toBe(0);
    expect(firstReport(reports).failed).toBe(true);
  });

  it("avoids a project key that is already taken in the workspace", async () => {
    const calls: Call[] = [];
    const reports = await importWekan({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: [board()],
      dryRun: false,
    });

    expect(firstReport(reports).projectKey).toBe("TM-2");
  });
});

describe("import run (multi board)", () => {
  it("creates one project per board and keeps a failing board isolated", async () => {
    const calls: Call[] = [];
    const fragile = {
      ...fakeKaneo(calls),
      async createProject(input: { name: string }) {
        if (input.name === "Team Move - Board A") {
          throw new Error("board A down");
        }
        return { id: "p_new", name: "x", slug: "X" };
      },
    } as unknown as KaneoClient;

    const multi = parseExport(
      readFileSync(
        new URL("./fixtures/wekan-export-multiboard.json", import.meta.url),
        "utf8",
      ),
    );
    const boards = planWekanExport(multi, "Team Move").boards;

    const reports = await importWekan({
      kaneo: fragile,
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards,
      dryRun: false,
    });

    expect(reports).toHaveLength(2);
    expect(reports[0]?.failed).toBe(true);
    expect(reports[0]?.error).toContain("board A down");
    expect(reports[1]?.failed).toBe(false);
  });

  it("names each board project distinctly", async () => {
    const multi = parseExport(
      readFileSync(
        new URL("./fixtures/wekan-export-multiboard.json", import.meta.url),
        "utf8",
      ),
    );
    const reports = await importWekan({
      kaneo: fakeKaneo([]),
      workspaceId: "ws_1",
      baseProjectName: "Team Move",
      boards: planWekanExport(multi, "Team Move").boards,
      dryRun: true,
    });

    expect(reports.map((report) => report.projectName)).toEqual([
      "Team Move - Board A",
      "Team Move - Board B",
    ]);
  });
});
