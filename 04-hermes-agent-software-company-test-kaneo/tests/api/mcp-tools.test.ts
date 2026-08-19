import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  type McpToolRegistrar,
  registerMcpTools,
} from "../../apps/api/src/mcp/tools";

type ToolCallback = (args: unknown) => Promise<{
  content: Array<{ text: string }>;
  isError?: boolean;
}>;

function collectTools() {
  const tools = new Map<string, ToolCallback>();
  const registrar: McpToolRegistrar = {
    registerTool: (name, _config, callback) => tools.set(name, callback),
  };
  registerMcpTools(registrar, "http://api.test", "test-token");
  return tools;
}

const tools = collectTools();

function call(name: string, args: unknown = {}) {
  const tool = tools.get(name);
  if (!tool) throw new Error(`Tool ${name} is not registered`);
  return tool(args);
}

let apiFetch: ReturnType<typeof vi.fn>;

beforeEach(() => {
  apiFetch = vi.fn(async () => Response.json({ ok: true }));
  vi.stubGlobal("fetch", apiFetch);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

function lastRequest() {
  const [input, init] = apiFetch.mock.calls.at(-1) as [
    RequestInfo | URL,
    RequestInit | undefined,
  ];
  return {
    url: String(input),
    method: init?.method ?? "GET",
    body: init?.body ? JSON.parse(String(init.body)) : undefined,
    auth: new Headers(init?.headers).get("authorization"),
  };
}

describe("MCP tool catalog", () => {
  it("registers exactly 36 tools", () => {
    expect(tools.size).toBe(36);
  });

  it("rejects an update_task whose expect values no longer match the current task", async () => {
    apiFetch.mockResolvedValueOnce(
      Response.json({
        title: "V1",
        description: "d",
        status: "open",
        priority: "medium",
        projectId: "p1",
        position: 1,
      }),
    );

    const result = await call("update_task", {
      taskId: "t1",
      status: "done",
      expect: { title: "OLD" },
    });

    expect(result.isError).toBe(true);
    const message = JSON.parse(result.content[0].text).error;
    expect(message).toContain('Conflict on "title"');
    expect(message).toContain("fetch and re-apply");
    expect(apiFetch).toHaveBeenCalledTimes(1);
  });

  it("rejects an update_project whose expect values no longer match", async () => {
    apiFetch.mockResolvedValueOnce(
      Response.json({ name: "Roadmap", slug: "roadmap" }),
    );

    const result = await call("update_project", {
      id: "p1",
      name: "Roadmap v2",
      expect: { slug: "old-slug" },
    });

    expect(result.isError).toBe(true);
    const message = JSON.parse(result.content[0].text).error;
    expect(message).toContain('Conflict on "slug"');
    expect(message).toContain("fetch and re-apply");
    expect(apiFetch).toHaveBeenCalledTimes(1);
  });

  it("rejects a create_task status that is not one of the project columns", async () => {
    apiFetch.mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]));

    const result = await call("create_task", {
      projectId: "p1",
      title: "Task",
      description: "",
      priority: "medium",
      status: "bogus",
    });

    expect(result.isError).toBe(true);
    const message = JSON.parse(result.content[0].text).error;
    expect(message).toContain('Invalid status "bogus"');
    expect(message).toContain("valid columns: [open]");
    expect(message).toContain("use list_project_columns");
    expect(apiFetch).toHaveBeenCalledTimes(1);
  });

  it("proceeds with a create_task whose status is a project column", async () => {
    apiFetch
      .mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]))
      .mockResolvedValueOnce(Response.json({ id: "task-1" }));

    const result = await call("create_task", {
      projectId: "p1",
      title: "Task",
      description: "",
      priority: "medium",
      status: "open",
    });

    expect(result.isError).toBe(false);
    expect(apiFetch).toHaveBeenCalledTimes(2);
  });

  it("accepts the API-virtual statuses planned and archived on create_task", async () => {
    apiFetch
      .mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]))
      .mockResolvedValueOnce(Response.json({ id: "t1" }))
      .mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]))
      .mockResolvedValueOnce(Response.json({ id: "t2" }));

    const planned = await call("create_task", {
      projectId: "p1",
      title: "Planned task",
      description: "",
      priority: "medium",
      status: "planned",
    });
    expect(planned.isError).toBe(false);

    const archived = await call("create_task", {
      projectId: "p1",
      title: "Archived task",
      description: "",
      priority: "medium",
      status: "archived",
    });
    expect(archived.isError).toBe(false);

    expect(apiFetch).toHaveBeenCalledTimes(4);
  });

  it("rejects a move_task destinationStatus that is not a target-project column", async () => {
    apiFetch.mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]));

    const result = await call("move_task", {
      taskId: "t1",
      destinationProjectId: "p2",
      destinationStatus: "bogus",
    });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("valid columns: [open]");
    expect(apiFetch).toHaveBeenCalledTimes(1);
  });

  it("rejects an update_task_status that is not a project column", async () => {
    apiFetch
      .mockResolvedValueOnce(Response.json({ id: "t1", projectId: "p1" }))
      .mockResolvedValueOnce(Response.json([{ id: "c1", slug: "open" }]));

    const result = await call("update_task_status", {
      taskId: "t1",
      status: "bogus",
    });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("valid columns: [open]");
    expect(apiFetch).toHaveBeenCalledTimes(2);
  });

  it("rejects a create_time_entry whose startTime is later than endTime", async () => {
    const result = await call("create_time_entry", {
      taskId: "t1",
      startTime: "2026-08-10T10:00:00Z",
      endTime: "2026-08-10T09:00:00Z",
    });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("endTime must be >= startTime");
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it("rejects an update_time_entry whose startTime is later than endTime", async () => {
    const result = await call("update_time_entry", {
      id: "te1",
      startTime: "2026-08-10T10:00:00Z",
      endTime: "2026-08-10T09:00:00Z",
    });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("endTime must be >= startTime");
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it("resolves workspace members", async () => {
    await call("list_workspace_members", { workspaceId: "ws 1" });

    const request = lastRequest();
    expect(request.url).toBe("http://api.test/api/workspace/ws%201/members");
    expect(request.auth).toBe("Bearer test-token");
  });

  it("passes only the search filters that were supplied", async () => {
    await call("search", { q: "login bug" });
    expect(lastRequest().url).toBe("http://api.test/api/search?q=login+bug");

    await call("search", {
      q: "login bug",
      type: "tasks",
      projectId: "p1",
      limit: 5,
    });
    const url = new URL(lastRequest().url);
    expect(Object.fromEntries(url.searchParams)).toEqual({
      q: "login bug",
      type: "tasks",
      projectId: "p1",
      limit: "5",
    });
  });

  it("rejects a search limit above the API maximum", async () => {
    const result = await call("search", { q: "x", limit: 500 });

    expect(result.isError).toBe(true);
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it("lists the columns whose slugs are valid task statuses", async () => {
    await call("list_project_columns", { projectId: "p1" });

    expect(lastRequest().url).toBe("http://api.test/api/column/p1");
  });

  it("deletes a task", async () => {
    await call("delete_task", { taskId: "t1" });

    expect(lastRequest()).toMatchObject({
      url: "http://api.test/api/task/t1",
      method: "DELETE",
    });
  });

  it("assigns and unassigns a task", async () => {
    await call("update_task_assignee", { taskId: "t1", userId: "u1" });
    expect(lastRequest()).toMatchObject({
      url: "http://api.test/api/task/assignee/t1",
      method: "PUT",
      body: { userId: "u1" },
    });

    await call("update_task_assignee", { taskId: "t1", userId: null });
    expect(lastRequest().body).toEqual({ userId: null });
  });

  it("rejects an empty assignee id rather than sending it", async () => {
    const result = await call("update_task_assignee", {
      taskId: "t1",
      userId: "",
    });

    expect(result.isError).toBe(true);
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it("sets and clears a due date", async () => {
    await call("update_task_due_date", {
      taskId: "t1",
      dueDate: "2026-09-01T10:00:00Z",
    });
    expect(lastRequest()).toMatchObject({
      url: "http://api.test/api/task/due-date/t1",
      method: "PUT",
      body: { dueDate: "2026-09-01T10:00:00Z" },
    });

    await call("update_task_due_date", { taskId: "t1" });
    expect(lastRequest().body).toEqual({});
  });

  it("rejects a due date that is not an ISO date-time", async () => {
    const result = await call("update_task_due_date", {
      taskId: "t1",
      dueDate: "next tuesday",
    });

    expect(result.isError).toBe(true);
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it("reads time entries for a task and by id", async () => {
    await call("list_task_time_entries", { taskId: "t1" });
    expect(lastRequest().url).toBe("http://api.test/api/time-entry/task/t1");

    await call("get_time_entry", { id: "te1" });
    expect(lastRequest().url).toBe("http://api.test/api/time-entry/te1");
  });

  it("creates a running time entry when endTime is omitted", async () => {
    await call("create_time_entry", {
      taskId: "t1",
      startTime: "2026-08-10T09:00:00Z",
    });

    expect(lastRequest()).toMatchObject({
      url: "http://api.test/api/time-entry",
      method: "POST",
      body: { taskId: "t1", startTime: "2026-08-10T09:00:00Z" },
    });
    expect(lastRequest().body).not.toHaveProperty("endTime");
  });

  it("updates a time entry", async () => {
    await call("update_time_entry", {
      id: "te1",
      startTime: "2026-08-10T09:00:00Z",
      endTime: "2026-08-10T10:30:00Z",
      description: "pairing",
    });

    expect(lastRequest()).toMatchObject({
      url: "http://api.test/api/time-entry/te1",
      method: "PUT",
      body: {
        startTime: "2026-08-10T09:00:00Z",
        endTime: "2026-08-10T10:30:00Z",
        description: "pairing",
      },
    });
  });

  it("reads task activity and notifications", async () => {
    await call("list_task_activity", { taskId: "t1" });
    expect(lastRequest().url).toBe("http://api.test/api/activity/t1");

    await call("list_notifications");
    expect(lastRequest().url).toBe("http://api.test/api/notification");
  });

  it("surfaces an API failure as a tool error", async () => {
    apiFetch.mockResolvedValueOnce(
      Response.json({ message: "Task not found" }, { status: 404 }),
    );

    const result = await call("delete_task", { taskId: "missing" });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Task not found");
  });
});
