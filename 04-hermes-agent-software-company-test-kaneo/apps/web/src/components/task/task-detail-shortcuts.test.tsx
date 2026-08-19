import { act, cleanup, render } from "@testing-library/react";
import { useMemo } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  KeyboardShortcutsProvider,
  useRegisterShortcuts,
} from "@/hooks/use-keyboard-shortcuts";
import {
  buildTaskDetailShortcutConfig,
  taskDetailActions,
} from "./task-detail-shortcuts";

afterEach(() => {
  cleanup();
  document.body.innerHTML = "";
});

/**
 * Testharness, der die Shelf-Kürzel und — als Realität der Anwendung — den
 * Projekt-Prefix "p l" gemeinsam registriert. Genau so konkurrieren sie auch
 * im Produktivbaum (CommandPalette registriert "p l"/"p c"; die offene
 * Detail-Shelf registriert "p" als Priorität, Entscheidung B).
 */
function Harness({
  open,
  onAction,
}: {
  open: boolean;
  onAction: (action: string) => void;
}) {
  // Referenziell stabil halten: useRegisterShortcuts registriert bei jeder
  // Objekt-Änderung neu (siehe Einsatzstelle in task-details-sheet).
  const shelfConfig = useMemo(
    () =>
      open ? buildTaskDetailShortcutConfig((action) => onAction(action)) : null,
    [open, onAction],
  );
  useRegisterShortcuts(shelfConfig ?? {});
  const projectPrefixConfig = useMemo(
    () => ({
      sequentialShortcuts: { p: { l: () => onAction("projectList") } },
    }),
    [onAction],
  );
  useRegisterShortcuts(projectPrefixConfig);
  return <div />;
}

/** Ein echter keydown auf document — so liefert der Browser ihn auch ab. */
function druecke(key: string) {
  document.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }));
}

describe("task-detail-shortcuts (Decision B — Detail-Kürzel verdrahten)", () => {
  it("kartiert die Detail-Kürzel s/p/a/l/d auf ihre Shelf-Aktionen", () => {
    expect(taskDetailActions).toEqual({
      s: "status",
      p: "priority",
      a: "assignee",
      l: "labels",
      d: "dueDate",
    });
  });

  it("öffnet bei geöffneter Shelf p als Priorität — der Projekt-Prefix verliert", () => {
    const onAction = vi.fn();
    render(
      <KeyboardShortcutsProvider>
        <Harness open onAction={onAction} />
      </KeyboardShortcutsProvider>,
    );

    druecke("p");
    expect(onAction).toHaveBeenCalledWith("priority");

    // p wurde als Einzelkürzel konsumiert, setzt also KEINEN Prefix: ein
    // folgendes "l" darf den Projekt-Prefix (p l) nicht auslösen.
    onAction.mockClear();
    druecke("p");
    druecke("l");
    expect(onAction).not.toHaveBeenCalledWith("projectList");
  });

  it("gibt außerhalb der Shelf den Buchstaben p als Projekt-Prefix wieder frei", () => {
    const onAction = vi.fn();
    render(
      <KeyboardShortcutsProvider>
        <Harness open={false} onAction={onAction} />
      </KeyboardShortcutsProvider>,
    );

    // Zwischen den beiden Tasten flush: p setzt den Prefix-Zustand über React
    // State, der erst mit act sichtbar wird.
    act(() => {
      druecke("p");
    });
    act(() => {
      druecke("l");
    });
    expect(onAction).toHaveBeenCalledWith("projectList");
    expect(onAction).not.toHaveBeenCalledWith("priority");
  });
});
