import { RESERVED_COLUMN_SLUGS, toColumnSlug } from "@kaneo/kaneo-client";
import type { RawCsv } from "./csv.js";

export const VALID_PRIORITIES = [
  "no-priority",
  "low",
  "medium",
  "high",
  "urgent",
] as const;

export const DEFAULT_PRIORITY = "no-priority";

export type PlannedColumn = {
  name: string;
  slug: string;
  renamedFrom?: string;
};

export type CsvTask = {
  /** 1-based line number in the file (the header is row 1). */
  row: number;
  title: string;
  description?: string;
  columnName?: string;
  priority: string;
  dueDate?: string;
  assigneeEmail?: string;
  labels: string[];
  comment?: string;
};

export type BuildResult = {
  tasks: CsvTask[];
  columns: PlannedColumn[];
  warnings: string[];
};

const UNTITLED_COLUMN = "Untitled";

export function normalizePriority(raw: string | undefined): {
  priority: string;
  warning?: string;
} {
  if (!raw?.trim()) return { priority: DEFAULT_PRIORITY };
  const parsed = raw.trim().toLowerCase();
  if ((VALID_PRIORITIES as readonly string[]).includes(parsed)) {
    return { priority: parsed };
  }
  return {
    priority: DEFAULT_PRIORITY,
    warning: `Unknown priority "${raw.trim()}" on row -> ${DEFAULT_PRIORITY}`,
  };
}

export function toDueDate(raw: string | undefined): string | undefined {
  if (!raw?.trim()) return undefined;
  const parsed = new Date(raw.trim());
  return Number.isNaN(parsed.getTime()) ? undefined : parsed.toISOString();
}

export function splitLabels(raw: string | undefined): string[] {
  if (!raw?.trim()) return [];
  const seen = new Set<string>();
  const labels: string[] = [];
  for (const label of raw.split(";")) {
    const trimmed = label.trim();
    if (trimmed && !seen.has(trimmed)) {
      seen.add(trimmed);
      labels.push(trimmed);
    }
  }
  return labels;
}

// Kaneo rejects duplicate and reserved slugs, so a colliding or reserved name
// has to be adjusted before the column is created. Columns appear in the order
// of their first occurrence in the CSV (spec §3.1 / AC5).
export function planColumns(columnNames: string[]): PlannedColumn[] {
  const ordered: string[] = [];
  for (const raw of columnNames) {
    const trimmed = raw.trim();
    const original = trimmed || UNTITLED_COLUMN;
    const name = toColumnSlug(original) ? original : UNTITLED_COLUMN;
    if (!ordered.includes(name)) ordered.push(name);
  }

  const taken = new Set<string>();
  const planned: PlannedColumn[] = [];
  for (const original of ordered) {
    let name = original;
    if (RESERVED_COLUMN_SLUGS.includes(toColumnSlug(name))) {
      name = `${name} list`;
    }

    let slug = toColumnSlug(name);
    for (let suffix = 2; taken.has(slug); suffix++) {
      name = `${original.replace(/ \d+$/, "")} ${suffix}`;
      slug = toColumnSlug(name);
    }

    taken.add(slug);
    planned.push({
      name,
      slug,
      ...(name !== original ? { renamedFrom: original } : {}),
    });
  }

  return planned;
}

export function buildTasks(raw: RawCsv): BuildResult {
  const headers = raw.headers.map((header) => header.trim());
  const at = (row: string[], name: string): string => {
    const index = headers.indexOf(name);
    return index >= 0 ? (row[index] ?? "").trim() : "";
  };

  const columnOrder: string[] = [];
  const warnings: string[] = [];
  const tasks: CsvTask[] = [];

  for (let index = 0; index < raw.rows.length; index++) {
    const row = raw.rows[index] as string[];
    const rowNumber = index + 2;

    const title = at(row, "title");
    const columnName = at(row, "column");
    if (columnName.length > 0 && !columnOrder.includes(columnName)) {
      columnOrder.push(columnName);
    }

    const priorityResult = normalizePriority(at(row, "priority") || undefined);
    if (priorityResult.warning) warnings.push(priorityResult.warning);

    const dueDate = toDueDate(at(row, "due_date") || undefined);

    tasks.push({
      row: rowNumber,
      title,
      ...(at(row, "description")
        ? { description: at(row, "description") }
        : {}),
      ...(columnName ? { columnName } : {}),
      priority: priorityResult.priority,
      ...(dueDate ? { dueDate } : {}),
      ...(at(row, "assignee_email")
        ? { assigneeEmail: at(row, "assignee_email") }
        : {}),
      labels: splitLabels(at(row, "labels") || undefined),
      ...(at(row, "comment") ? { comment: at(row, "comment") } : {}),
    });
  }

  return {
    tasks,
    columns: planColumns(
      columnOrder.length > 0 ? columnOrder : [UNTITLED_COLUMN],
    ),
    warnings,
  };
}
