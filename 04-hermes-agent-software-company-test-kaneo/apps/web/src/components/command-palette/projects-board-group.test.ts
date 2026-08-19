import { describe, expect, it, vi } from "vitest";
import { buildProjectsBoardGroup } from "./projects-board-group";

describe("buildProjectsBoardGroup (Decision A — Projektsuche in der Palette)", () => {
  it("legt pro Projekt einen durchsuchbaren Eintrag an, dessen value der Projektname ist", () => {
    const group = buildProjectsBoardGroup({
      label: "Projects & Boards",
      projects: [
        { id: "p1", name: "Alpha" },
        { id: "p2", name: "Beta" },
      ],
      onRunProject: vi.fn(),
    });

    expect(group.label).toBe("Projects & Boards");
    expect(group.items).toHaveLength(2);
    expect(group.items.map((item) => item.value)).toEqual(["Alpha", "Beta"]);
    // Die Einträge sind reine Suchziele (value=Projektname, onRun die
    // Navigation) — sie tragen kein eigenes Tastenkürzel.
    expect(group.items.every((item) => typeof item.onRun === "function")).toBe(
      true,
    );
  });

  it("runnt die Navigation auf das gewählte Projekt-Board", () => {
    const onRunProject = vi.fn();
    const group = buildProjectsBoardGroup({
      label: "x",
      projects: [{ id: "p9", name: "Zeta" }],
      onRunProject,
    });

    group.items[0].onRun();

    expect(onRunProject).toHaveBeenCalledTimes(1);
    expect(onRunProject).toHaveBeenCalledWith("p9");
  });
});
