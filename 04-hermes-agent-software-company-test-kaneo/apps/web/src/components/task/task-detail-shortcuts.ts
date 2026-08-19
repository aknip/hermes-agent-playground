import { shortcuts } from "@/constants/shortcuts";

/**
 * Entscheidung B — Detail-Kürzel verdrahten.
 *
 * Die Buchstaben s/p/a/l/d öffnen in der offenen Detail-Shelf das jeweilige
 * Eigenschafts-Popover (Status/Priorität/Bearbeiter/Labels/Fälligkeit). Die
 * Single Source sind die Kürzel aus `constants/shortcuts.ts` — hier entsteht
 * keine zweite (Duplikat-)Definition.
 *
 * Konflikt-Regel für `p`: p ist zugleich Prefix der Projekt-Kürzel (p l, p c).
 * Solange die Detail-Shelf offen ist, gewinnt p als Priorität; die Registrierung
 * als Single-Shortcut in `use-keyboard-shortcuts` konsumiert p in diesem Moment,
 * sodass der Projekt-Prefix an derselben Taste nicht mehr anläuft. Außerhalb der
 * Shelf (keine Registrierung) bleibt p der Projekt-Prefix.
 */
export type TaskDetailAction =
  | "status"
  | "priority"
  | "assignee"
  | "labels"
  | "dueDate";

/** data-Attribut auf den Popover-Trigger-Buttons der Shelf. */
export const TASK_DETAIL_ACTION_ATTR = "data-shelf-action";

/** Kürzel → Shelf-Aktion, abgeleitet aus der zentralen Kürzel-Tabelle. */
export const taskDetailActions: Record<string, TaskDetailAction> = {
  [shortcuts.taskDetails.status]: "status",
  [shortcuts.taskDetails.priority]: "priority",
  [shortcuts.taskDetails.assignee]: "assignee",
  [shortcuts.taskDetails.labels]: "labels",
  [shortcuts.taskDetails.dueDate]: "dueDate",
};

/**
 * Baut die Single-Shortcut-Registrierung für eine offene Detail-Shelf.
 * `openAction` öffnet das Popover für die gewählte Aktion.
 */
export function buildTaskDetailShortcutConfig(
  openAction: (action: TaskDetailAction) => void,
): { shortcuts: Record<string, () => void> } {
  return {
    shortcuts: Object.fromEntries(
      Object.entries(taskDetailActions).map(([key, action]) => [
        key,
        () => openAction(action),
      ]),
    ),
  };
}
