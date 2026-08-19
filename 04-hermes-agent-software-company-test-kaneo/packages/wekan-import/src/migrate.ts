import { type KaneoClient, toProjectKey, uniqueKey } from "@kaneo/kaneo-client";
import type { PlannedBoard } from "./mapping.js";
import { pickMemberByName } from "./mapping.js";

export type WekanBoardReport = {
  board: string;
  projectName: string;
  projectKey: string | null;
  kaneoProjectId: string | null;
  columns: number;
  tasks: number;
  labels: number;
  comments: number;
  assignees: number;
  checklistItems: number;
  archivedLists: number;
  archivedCards: number;
  attachmentsSkipped: number;
  warnings: string[];
  errors: { card: string; error: string }[];
  failed: boolean;
  error?: string;
};

export type WekanImportOptions = {
  kaneo: KaneoClient;
  workspaceId: string;
  baseProjectName: string;
  boards: PlannedBoard[];
  dryRun: boolean;
  onProgress?: (message: string) => void;
};

const FALLBACK_LABEL_COLOR = "#6b7280";

export async function importWekan(
  options: WekanImportOptions,
): Promise<WekanBoardReport[]> {
  const { kaneo, workspaceId, boards, dryRun, onProgress = () => {} } = options;

  const takenKeys = new Set<string>();
  const membersByName = new Map<string, string>();
  if (!dryRun) {
    for (const project of await kaneo.listProjects(workspaceId)) {
      if (project.slug) takenKeys.add(project.slug);
    }
    for (const member of await kaneo.listMembers(workspaceId)) {
      if (member.name) membersByName.set(member.name.toLowerCase(), member.id);
    }
  }

  const reports: WekanBoardReport[] = [];

  for (const board of boards) {
    const report: WekanBoardReport = {
      board: board.title,
      projectName: board.projectName,
      projectKey: null,
      kaneoProjectId: null,
      columns: board.columns.length,
      tasks: board.cards.length,
      labels: board.labels.length,
      comments: board.cards.reduce(
        (total, card) => total + card.comments.length,
        0,
      ),
      assignees: 0,
      checklistItems: board.checklistItems,
      archivedLists: board.archivedLists,
      archivedCards: board.archivedCards,
      attachmentsSkipped: board.attachmentCount,
      warnings: [],
      errors: [],
      failed: false,
    };

    try {
      await migrateBoard({
        kaneo,
        workspaceId,
        board,
        dryRun,
        takenKeys,
        membersByName,
        report,
        onProgress,
      });
    } catch (error) {
      report.failed = true;
      report.tasks = 0;
      report.comments = 0;
      report.error = error instanceof Error ? error.message : String(error);
    }

    reports.push(report);
    report.failed ||= report.errors.length > 0;
  }

  return reports;
}

async function migrateBoard(context: {
  kaneo: KaneoClient;
  workspaceId: string;
  board: PlannedBoard;
  dryRun: boolean;
  takenKeys: Set<string>;
  membersByName: Map<string, string>;
  report: WekanBoardReport;
  onProgress: (message: string) => void;
}): Promise<void> {
  const {
    kaneo,
    workspaceId,
    board,
    dryRun,
    takenKeys,
    membersByName,
    report,
    onProgress,
  } = context;

  onProgress(`Planning board "${board.title}" as "${board.projectName}"`);

  if (dryRun) {
    report.projectKey = toProjectKey(board.projectName);
    return;
  }

  const projectKey = uniqueKey(toProjectKey(board.projectName), takenKeys);
  takenKeys.add(projectKey);
  report.projectKey = projectKey;

  onProgress(`Creating project "${board.projectName}" (${projectKey})`);
  const project = await kaneo.createProject({
    name: board.projectName,
    workspaceId,
    icon: "Layout",
    slug: projectKey,
  });
  report.kaneoProjectId = project.id;

  // Kaneo seeds four default columns on create; drop them while still empty.
  for (const existing of await kaneo.listColumns(project.id)) {
    await kaneo.deleteColumn(existing.id);
  }

  for (const column of board.columns) {
    await kaneo.createColumn(project.id, { name: column.name });
  }

  const labelIdByName = new Map<string, string>();
  for (const label of board.labels) {
    const created = await kaneo.createLabel({
      name: label.name,
      color: label.color,
      workspaceId,
    });
    labelIdByName.set(label.name, created.id);
  }

  // Count only what is actually created; the planned totals are captured on
  // dry run and reset here so failures shrink the counters truthfully.
  report.tasks = 0;
  report.comments = 0;
  report.assignees = 0;

  let taskIndex = 0;
  for (const card of board.cards) {
    taskIndex++;
    onProgress(
      `Importing task ${taskIndex}/${board.cards.length} into "${board.projectName}"`,
    );

    const labelColor = new Map(
      board.labels.map((label) => [label.name, label.color]),
    );

    const assignee = pickMemberByName(card.memberNames, membersByName);
    if (assignee.userId) {
      report.assignees++;
    } else if (assignee.reason === "no_match") {
      report.warnings.push(
        `Karte "${card.title}": kein Workspace-Mitglied für ${card.memberNames.join(
          ", ",
        )}; die Karte bleibt unzugewiesen.`,
      );
    }

    try {
      const created = await kaneo.createTask(project.id, {
        title: card.title,
        description: card.description,
        status: card.status,
        priority: card.priority,
        ...(card.dueDate ? { dueDate: card.dueDate } : {}),
        ...(assignee.userId ? { userId: assignee.userId } : {}),
      });
      report.tasks++;

      for (const label of card.labels) {
        await kaneo.createLabel({
          name: label,
          color: labelColor.get(label) ?? FALLBACK_LABEL_COLOR,
          workspaceId,
          taskId: created.id,
        });
      }

      for (const comment of card.comments) {
        await kaneo.createComment(created.id, comment);
        report.comments++;
      }
    } catch (error) {
      report.errors.push({
        card: card.title,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}
