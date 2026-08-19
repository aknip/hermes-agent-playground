// A WeKan board export (`_format: "wekan-board-1.0.0"`, produced by
// `GET /api/boards/:boardId/export`) is a flat JSON document: the board's own
// fields plus top-level arrays `lists`, `cards`, `comments`, `checklists`,
// `checklistItems`, `attachments`, `labels` and `users`. This module reads that
// real shape and normalizes it into the structural model the mapping and the
// write path consume. A WeKan export carries no user email addresses (the
// exporter only whitelists username/fullname), so card members are resolved to
// display names, not emails.

export type WekanLabel = { name: string; color: string };

export type WekanComment = {
  text: string;
  authorName: string | undefined;
  createdAt: string | undefined;
};

export type WekanChecklistItem = { title: string; isFinished: boolean };

export type WekanChecklist = {
  title: string;
  items: WekanChecklistItem[];
};

export type WekanCard = {
  id: string;
  title: string;
  description: string;
  labels: string[];
  memberNames: string[];
  dueAt: string | undefined;
  checklists: WekanChecklist[];
  comments: WekanComment[];
};

export type WekanList = {
  id: string;
  title: string;
  sort: number;
  cards: WekanCard[];
};

export type WekanBoard = {
  id: string;
  title: string;
  labels: WekanLabel[];
  lists: WekanList[];
  archivedLists: number;
  archivedCards: number;
  attachmentCount: number;
};

export type WekanExport = {
  boards: WekanBoard[];
};

export class WekanExportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WekanExportError";
  }
}

type JsonRecord = Record<string, unknown>;

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null
    ? (value as JsonRecord)
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asNumber(value: unknown): number {
  return typeof value === "number" ? value : 0;
}

function normalizeLabel(raw: JsonRecord): WekanLabel {
  return {
    name: asString(raw.name).trim() || "Unlabeled",
    color: asString(raw.color),
  };
}

function normalizeBoard(raw: JsonRecord): WekanBoard {
  const labelIdToName = new Map<string, string>();
  for (const label of asArray(raw.labels)) {
    const rec = asRecord(label);
    const id = asString(rec._id);
    const name = asString(rec.name).trim() || "Unlabeled";
    if (id) labelIdToName.set(id, name);
  }

  // The export whitelists a user's id, username and fullname (never email),
  // so members resolve to a display name.
  const userIdToName = new Map<string, string>();
  for (const user of asArray(raw.users)) {
    const rec = asRecord(user);
    const id = asString(rec._id);
    const fullname = asString(asRecord(rec.profile).fullname).trim();
    const name = fullname || asString(rec.username).trim() || id;
    if (id) userIdToName.set(id, name);
  }

  const rawLists = asArray(raw.lists).map((list) => asRecord(list));
  const archivedLists = rawLists.filter(
    (list) => list.archived === true,
  ).length;

  const rawCards = asArray(raw.cards).map((card) => asRecord(card));
  const archivedCards = rawCards.filter(
    (card) => card.archived === true,
  ).length;

  const commentsByCard = new Map<string, JsonRecord[]>();
  for (const comment of asArray(raw.comments)) {
    const rec = asRecord(comment);
    const cardId = asString(rec.cardId);
    if (!cardId) continue;
    const list = commentsByCard.get(cardId) ?? [];
    list.push(rec);
    commentsByCard.set(cardId, list);
  }

  const checklistsByCard = new Map<string, JsonRecord[]>();
  for (const checklist of asArray(raw.checklists)) {
    const rec = asRecord(checklist);
    const cardId = asString(rec.cardId);
    if (!cardId) continue;
    const list = checklistsByCard.get(cardId) ?? [];
    list.push(rec);
    checklistsByCard.set(cardId, list);
  }

  const itemsByChecklist = new Map<string, JsonRecord[]>();
  for (const item of asArray(raw.checklistItems)) {
    const rec = asRecord(item);
    const checklistId = asString(rec.checklistId);
    if (!checklistId) continue;
    const list = itemsByChecklist.get(checklistId) ?? [];
    list.push(rec);
    itemsByChecklist.set(checklistId, list);
  }

  const mapCard = (card: JsonRecord): WekanCard => {
    const id = asString(card._id);
    const labelNames = asArray(card.labelIds)
      .map((labelId) => labelIdToName.get(asString(labelId)))
      .filter((name): name is string => Boolean(name));
    const memberNames = asArray(card.members)
      .map((memberId) => userIdToName.get(asString(memberId)))
      .filter((name): name is string => Boolean(name));

    const checklists = (checklistsByCard.get(id) ?? []).map((checklist) => {
      const checklistId = asString(checklist._id);
      const items = (itemsByChecklist.get(checklistId) ?? [])
        .sort((a, b) => asNumber(a.sort) - asNumber(b.sort))
        .map((item) => ({
          title: asString(item.title).trim(),
          isFinished: item.isFinished === true,
        }));
      return { title: asString(checklist.title).trim(), items };
    });

    const comments = (commentsByCard.get(id) ?? [])
      .sort(
        (a, b) =>
          new Date(asString(a.createdAt)).getTime() -
          new Date(asString(b.createdAt)).getTime(),
      )
      .map((comment) => {
        const userId = asString(comment.userId);
        return {
          text: asString(comment.text),
          authorName: userId ? userIdToName.get(userId) : undefined,
          createdAt: asString(comment.createdAt) || undefined,
        };
      });

    return {
      id,
      title: asString(card.title).trim(),
      description: asString(card.description),
      labels: labelNames,
      memberNames,
      dueAt: asString(card.dueAt) || undefined,
      checklists,
      comments,
    };
  };

  const lists: WekanList[] = rawLists
    .filter((list) => list.archived !== true)
    .sort((a, b) => asNumber(a.sort) - asNumber(b.sort))
    .map((list) => {
      const id = asString(list._id);
      const cards = rawCards
        .filter(
          (card) => card.archived !== true && asString(card.listId) === id,
        )
        .sort((a, b) => asNumber(a.sort) - asNumber(b.sort))
        .map(mapCard);
      return {
        id,
        title: asString(list.title).trim() || "Untitled",
        sort: asNumber(list.sort),
        cards,
      };
    });

  const labels = asArray(raw.labels).map((label) =>
    normalizeLabel(asRecord(label)),
  );

  return {
    id: asString(raw._id),
    title: asString(raw.title).trim() || "Unbenanntes Board",
    labels,
    lists,
    archivedLists,
    archivedCards,
    attachmentCount: asArray(raw.attachments).length,
  };
}

export function parseExport(text: string): WekanExport {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new WekanExportError("The file is not valid JSON.");
  }

  if (json === null || typeof json !== "object") {
    throw new WekanExportError(
      "The file does not look like a WeKan board export.",
    );
  }

  const record = json as JsonRecord;

  if (asArray(record.lists).length > 0 || asArray(record.cards).length > 0) {
    // A single-board export: the board document itself carries lists/cards.
    return { boards: [normalizeBoard(record)] };
  }

  if (Array.isArray(record.boards)) {
    const boards = (record.boards as unknown[]).map((board) =>
      normalizeBoard(asRecord(board)),
    );
    if (boards.length === 0) {
      throw new WekanExportError(
        "The WeKan export contains no boards (boards[] is empty).",
      );
    }
    return { boards };
  }

  throw new WekanExportError(
    "The file is not a WeKan board export: no boards or lists were found.",
  );
}
