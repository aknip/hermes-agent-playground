import type { KaneoClient } from "@kaneo/kaneo-client";
import { describe, expect, it } from "vitest";
import type { CsvTask, PlannedColumn } from "./mapping.js";
import { importCsv } from "./migrate.js";

type Call = { method: string; args: unknown[] };

function fakeKaneo(calls: Call[]) {
  let taskCounter = 0;
  let labelCounter = 0;
  const record = (method: string, ...args: unknown[]) => {
    calls.push({ method, args });
  };

  return {
    async listProjects() {
      record("listProjects");
      return [{ id: "p_existing", name: "Existing", slug: "MWR" }];
    },
    async listMembers() {
      record("listMembers");
      return [{ id: "ku_1", name: "Sam", email: "Sam@Example.com" }];
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
      record("createTask", input);
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

function task(
  partial: Partial<CsvTask> & { title: string; row: number },
): CsvTask {
  return {
    title: "t",
    row: 2,
    priority: "no-priority",
    labels: [],
    ...partial,
  };
}

const columns: PlannedColumn[] = [
  { name: "Backlog", slug: "backlog" },
  { name: "To Do", slug: "to-do" },
];

describe("importCsv (dry run)", () => {
  it("reports counts without calling Kaneo and never calls a write", async () => {
    const calls: Call[] = [];
    const report = await importCsv({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      projectName: "Team Move",
      tasks: [
        task({ title: "a", row: 2, labels: ["bug"] }),
        task({ title: "b", row: 3, comment: "hi", labels: ["bug"] }),
      ],
      columns,
      warnings: ["boom"],
      dryRun: true,
    });

    expect(calls).toEqual([]);
    expect(report.tasks).toBe(2);
    expect(report.rows).toBe(2);
    expect(report.columns).toBe(2);
    expect(report.labels).toBe(1);
    expect(report.comments).toBe(1);
    expect(report.warnings).toEqual(["boom"]);
  });
});

describe("importCsv (write)", () => {
  it("removes seeded columns, then creates columns in planned order", async () => {
    const calls: Call[] = [];
    await importCsv({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      projectName: "Team Move",
      tasks: [task({ title: "a", row: 2 })],
      columns,
      warnings: [],
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
    expect(created).toEqual([{ name: "Backlog" }, { name: "To Do" }]);
  });

  it("creates tasks with the mapped fields and status slug", async () => {
    const calls: Call[] = [];
    await importCsv({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      projectName: "Team Move",
      tasks: [
        task({
          title: "Write copy",
          row: 2,
          columnName: "To Do",
          priority: "high",
          dueDate: "2026-03-04T00:00:00.000Z",
        }),
      ],
      columns,
      warnings: [],
      dryRun: false,
    });

    const created = calls
      .filter((call) => call.method === "createTask")
      .map((call) => call.args[0]);
    expect(created).toEqual([
      {
        title: "Write copy",
        description: "",
        status: "to-do",
        priority: "high",
        dueDate: "2026-03-04T00:00:00.000Z",
      },
    ]);
  });

  it("resolves an assignee by email, case-insensitively", async () => {
    const [report, calls] = await runWith([
      task({ title: "a", row: 2, assigneeEmail: "sAm@example.com" }),
    ]);

    const created = calls
      .filter((call) => call.method === "createTask")
      .map((call) => call.args[0]);
    expect(created[0]).toMatchObject({ userId: "ku_1" });
    expect(report?.assignees).toBe(1);
  });

  it("leaves the task unassigned and warns when the email is not a member", async () => {
    const [report, calls] = await runWith([
      task({ title: "a", row: 2, assigneeEmail: "nobody@example.com" }),
    ]);

    const created = calls
      .filter((call) => call.method === "createTask")
      .map((call) => call.args[0]);
    expect(created[0]).not.toHaveProperty("userId");
    expect(report?.assignees).toBe(0);
    expect(report?.warnings.join(" ")).toContain("nobody@example.com");
  });

  it("creates each distinct label in the workspace and attaches it to the task", async () => {
    const [, calls] = await runWith([
      task({ title: "a", row: 2, labels: ["urgent", "copy"] }),
      task({ title: "b", row: 3, labels: ["urgent"] }),
    ]);

    const labelCalls = calls
      .filter((call) => call.method === "createLabel")
      .map((call) => call.args[0] as Record<string, unknown>);

    // workspace labels: urgent + copy once each
    expect(labelCalls.filter((call) => call.taskId === undefined).length).toBe(
      2,
    );
    // task attachments: urgent on both tasks, copy on the first
    expect(labelCalls.filter((call) => call.taskId !== undefined).length).toBe(
      3,
    );
  });

  it("creates one comment per row under the API key owner", async () => {
    const [, calls] = await runWith([
      task({ title: "a", row: 2, comment: "Great start" }),
    ]);

    const comments = calls.filter((call) => call.method === "createComment");
    expect(comments).toHaveLength(1);
    expect(comments[0]?.args[1]).toBe("Great start");
    expect(comments[0]?.args[2]).toBeUndefined();
  });

  it("records a failing row in the report and still imports the rest", async () => {
    const calls: Call[] = [];
    const fragile = {
      ...fakeKaneo(calls),
      async createTask() {
        throw new Error("boom");
      },
    } as unknown as KaneoClient;

    const report = await importCsv({
      kaneo: fragile,
      workspaceId: "ws_1",
      projectName: "Team Move",
      tasks: [task({ title: "a", row: 2 }), task({ title: "b", row: 3 })],
      columns,
      warnings: [],
      dryRun: false,
    });

    expect(report?.rowErrors).toHaveLength(2);
    expect(report?.rowErrors[0]).toMatchObject({ row: 2 });
    expect(report?.tasks).toBe(0);
    expect(report?.failed).toBe(true);
  });

  it("avoids a project key that is already taken in the workspace", async () => {
    const calls: Call[] = [];
    const report = await importCsv({
      kaneo: fakeKaneo(calls),
      workspaceId: "ws_1",
      projectName: "Marketing Website Redesign",
      tasks: [task({ title: "a", row: 2 })],
      columns,
      warnings: [],
      dryRun: false,
    });

    expect(report?.projectKey).toBe("MWR-2");
  });
});

async function runWith(tasks: CsvTask[]) {
  const calls: Call[] = [];
  const report = await importCsv({
    kaneo: fakeKaneo(calls),
    workspaceId: "ws_1",
    projectName: "Team Move",
    tasks,
    columns,
    warnings: [],
    dryRun: false,
  });
  return [report, calls] as [typeof report, Call[]];
}
