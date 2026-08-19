import { type KaneoClient, toProjectKey, uniqueKey } from "@kaneo/kaneo-client";
import type { CsvTask, PlannedColumn } from "./mapping.js";

export type CsvReport = {
  dryRun: boolean;
  projectName: string;
  projectKey: string | null;
  kaneoProjectId: string | null;
  rows: number;
  tasks: number;
  columns: number;
  labels: number;
  comments: number;
  assignees: number;
  warnings: string[];
  rowErrors: { row: number; error: string }[];
  failed: boolean;
  error?: string;
};

export type CsvImportOptions = {
  kaneo: KaneoClient;
  workspaceId: string;
  projectName: string;
  tasks: CsvTask[];
  columns: PlannedColumn[];
  warnings: string[];
  dryRun: boolean;
  onProgress?: (message: string) => void;
};

const FALLBACK_LABEL_COLOR = "#6b7280";

export async function importCsv(options: CsvImportOptions): Promise<CsvReport> {
  const {
    kaneo,
    workspaceId,
    projectName,
    tasks,
    columns,
    warnings,
    dryRun,
    onProgress = () => {},
  } = options;

  const distinctLabels = [...new Set(tasks.flatMap((task) => task.labels))];

  const report: CsvReport = {
    dryRun,
    projectName,
    projectKey: null,
    kaneoProjectId: null,
    rows: tasks.length,
    tasks: 0,
    columns: columns.length,
    labels: distinctLabels.length,
    comments: 0,
    assignees: 0,
    warnings: [...warnings],
    rowErrors: [],
    failed: false,
  };

  if (dryRun) {
    report.tasks = tasks.length;
    report.comments = tasks.filter((task) => task.comment).length;
    return report;
  }

  const takenKeys = new Set<string>();
  const membersByEmail = new Map<string, string>();
  for (const project of await kaneo.listProjects(workspaceId)) {
    if (project.slug) takenKeys.add(project.slug);
  }
  for (const member of await kaneo.listMembers(workspaceId)) {
    if (member.email) membersByEmail.set(member.email.toLowerCase(), member.id);
  }

  const projectKey = uniqueKey(toProjectKey(projectName), takenKeys);
  report.projectKey = projectKey;

  onProgress(`Creating project "${projectName}" (${projectKey})`);
  const project = await kaneo.createProject({
    name: projectName,
    workspaceId,
    icon: "Layout",
    slug: projectKey,
  });
  report.kaneoProjectId = project.id;

  // Kaneo seeds four default columns on create; drop them while still empty.
  for (const existing of await kaneo.listColumns(project.id)) {
    await kaneo.deleteColumn(existing.id);
  }

  for (const column of columns) {
    await kaneo.createColumn(project.id, { name: column.name });
  }

  const labelIdByName = new Map<string, string>();
  for (const name of distinctLabels) {
    const label = await kaneo.createLabel({
      name,
      color: FALLBACK_LABEL_COLOR,
      workspaceId,
    });
    labelIdByName.set(name, label.id);
  }

  const slugByName = new Map(
    columns.map((column) => [column.name, column.slug]),
  );

  let taskIndex = 0;
  for (const task of tasks) {
    taskIndex++;
    onProgress(
      `Importing task ${taskIndex}/${tasks.length} into "${projectName}"`,
    );

    const status = slugByName.get(task.columnName ?? "Untitled") ?? "untitled";
    const assigneeId = task.assigneeEmail
      ? membersByEmail.get(task.assigneeEmail.toLowerCase())
      : undefined;

    if (task.assigneeEmail && !assigneeId) {
      report.warnings.push(
        `Row ${task.row}: "${task.assigneeEmail}" is not a member of this workspace; the task stays unassigned.`,
      );
    }

    try {
      const created = await kaneo.createTask(project.id, {
        title: task.title,
        description: task.description ?? "",
        status,
        priority: task.priority,
        ...(task.dueDate ? { dueDate: task.dueDate } : {}),
        ...(assigneeId ? { userId: assigneeId } : {}),
      });
      report.tasks++;
      if (assigneeId) report.assignees++;

      for (const label of task.labels) {
        await kaneo.createLabel({
          name: label,
          color: FALLBACK_LABEL_COLOR,
          workspaceId,
          taskId: created.id,
        });
      }

      if (task.comment) {
        await kaneo.createComment(created.id, task.comment);
        report.comments++;
      }
    } catch (error) {
      report.rowErrors.push({
        row: task.row,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  report.failed = report.rowErrors.length > 0;
  return report;
}
