import { RESERVED_COLUMN_SLUGS, toColumnSlug } from "@kaneo/kaneo-client";
import type {
  WekanBoard,
  WekanCard,
  WekanComment,
  WekanExport,
  WekanLabel,
  WekanList,
} from "./parser.js";

// WeKan has no priority concept; Kaneo requires one on create.
export const DEFAULT_PRIORITY = "no-priority";

const UNTITLED_COLUMN = "Untitled";
const FALLBACK_LABEL_COLOR = "#6b7280";

export type PlannedColumn = {
  name: string;
  slug: string;
  renamedFrom?: string;
};

export type PlannedCard = {
  id: string;
  title: string;
  description: string;
  status: string;
  priority: string;
  dueDate?: string;
  labels: string[];
  memberNames: string[];
  comments: string[];
};

export type PlannedBoard = {
  id: string;
  title: string;
  projectName: string;
  columns: PlannedColumn[];
  cards: PlannedCard[];
  labels: WekanLabel[];
  checklistItems: number;
  archivedLists: number;
  archivedCards: number;
  attachmentCount: number;
};

export type PlanResult = {
  boards: PlannedBoard[];
  warnings: string[];
};

export function boardProjectName(
  baseProjectName: string,
  boardTitle: string,
  boardCount: number,
): string {
  return boardCount <= 1
    ? baseProjectName
    : `${baseProjectName} - ${boardTitle}`;
}

export function toDueDate(raw: string | undefined): string | undefined {
  if (!raw?.trim()) return undefined;
  const parsed = new Date(raw.trim());
  return Number.isNaN(parsed.getTime()) ? undefined : parsed.toISOString();
}

export function buildDescription(card: WekanCard): string {
  const sections: string[] = [];
  const description = card.description.trim();
  if (description) sections.push(description);

  for (const checklist of card.checklists) {
    if (checklist.items.length === 0) continue;
    const lines = checklist.items.map(
      (item) => `- [${item.isFinished ? "x" : " "}] ${item.title}`,
    );
    sections.push(`## ${checklist.title}\n\n${lines.join("\n")}`);
  }

  return sections.join("\n\n");
}

// The export strips email addresses, so the author is carried inside the text
// and the comment is created under the API key owner (spec §5.1 / AC5).
export function formatComment(comment: WekanComment): string {
  const date = comment.createdAt
    ? new Date(comment.createdAt).toISOString().slice(0, 10)
    : null;
  if (!date) return comment.text;
  const who = comment.authorName ?? "Unbekannt";
  return `${who} am ${date}: ${comment.text}`;
}

// Kaneo has a single assignee; take the first card member that is present in
// the workspace (matched by display name, because the WeKan export carries no
// email to match against).
export function pickMemberByName(
  memberNames: string[],
  membersByName: ReadonlyMap<string, string>,
): { userId?: string; reason?: "no_match" } {
  for (const name of memberNames) {
    const userId = membersByName.get(name.trim().toLowerCase());
    if (userId) return { userId };
  }
  return memberNames.length > 0 ? { reason: "no_match" } : {};
}

// Each WeKan list becomes one Kaneo column, in list order, with every slug
// made unique (reserved virtual slugs and collisions are adjusted).
function planColumns(lists: WekanList[]): {
  columns: PlannedColumn[];
  slugByListId: Map<string, string>;
  warnings: string[];
} {
  const takenSlugs = new Set<string>();
  const columns: PlannedColumn[] = [];
  const slugByListId = new Map<string, string>();
  const warnings: string[] = [];

  for (const list of lists) {
    const original = list.title.trim() || UNTITLED_COLUMN;
    let name = toColumnSlug(original) ? original : UNTITLED_COLUMN;

    if (RESERVED_COLUMN_SLUGS.includes(toColumnSlug(name))) {
      name = `${name} list`;
    }

    let slug = toColumnSlug(name);
    for (let suffix = 2; takenSlugs.has(slug); suffix++) {
      name = `${name.replace(/ \d+$/, "")} ${suffix}`;
      slug = toColumnSlug(name);
    }

    takenSlugs.add(slug);
    slugByListId.set(list.id, slug);
    columns.push({
      name,
      slug,
      ...(name !== original ? { renamedFrom: original } : {}),
    });
    if (name !== original) {
      warnings.push(
        `Liste "${original}" wurde als Spalte "${name}" importiert, um einen Namenskonflikt in Kaneo zu vermeiden.`,
      );
    }
  }

  return { columns, slugByListId, warnings };
}

function planBoard(
  board: WekanBoard,
  baseProjectName: string,
  boardCount: number,
  warnings: string[],
): PlannedBoard {
  const projectName = boardProjectName(
    baseProjectName,
    board.title,
    boardCount,
  );
  const {
    columns,
    slugByListId,
    warnings: columnWarnings,
  } = planColumns(board.lists);
  warnings.push(...columnWarnings);

  const cards: PlannedCard[] = [];
  const usedLabels = new Map<string, WekanLabel>();
  let checklistItems = 0;

  for (const list of board.lists) {
    const status = slugByListId.get(list.id) ?? UNTITLED_COLUMN.toLowerCase();
    for (const card of list.cards) {
      for (const labelName of card.labels) {
        const color =
          board.labels.find((label) => label.name === labelName)?.color ??
          FALLBACK_LABEL_COLOR;
        if (!usedLabels.has(labelName)) {
          usedLabels.set(labelName, { name: labelName, color });
        }
      }
      for (const checklist of card.checklists) {
        checklistItems += checklist.items.length;
      }

      cards.push({
        id: card.id,
        title: card.title,
        description: buildDescription(card),
        status,
        priority: DEFAULT_PRIORITY,
        ...(card.dueAt ? { dueDate: toDueDate(card.dueAt) } : {}),
        labels: card.labels,
        memberNames: card.memberNames,
        comments: card.comments.map(formatComment),
      });
    }
  }

  return {
    id: board.id,
    title: board.title,
    projectName,
    columns,
    cards,
    labels: [...usedLabels.values()],
    checklistItems,
    archivedLists: board.archivedLists,
    archivedCards: board.archivedCards,
    attachmentCount: board.attachmentCount,
  };
}

export function planWekanExport(
  exportData: WekanExport,
  baseProjectName: string,
): PlanResult {
  const warnings: string[] = [];
  const boards = exportData.boards.map((board) =>
    planBoard(board, baseProjectName, exportData.boards.length, warnings),
  );
  return { boards, warnings };
}
