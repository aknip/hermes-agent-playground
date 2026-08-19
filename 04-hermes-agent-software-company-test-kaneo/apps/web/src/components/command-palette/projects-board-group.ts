/**
 * Entscheidung A — Projektsuche in der Palette.
 *
 * Reine, testbare Bauhilfe für die Palette-Gruppe „Projekte & Boards“: ein
 * Eintrag pro Projekt, durchsuchbar über den bestehenden CommandInput-Filter
 * (value = Projektname). Die Navigation kapselt der Aufrufer hinter
 * `onRunProject`, damit diese Einheit ohne Router-Coupling testbar bleibt.
 */
export type ProjectsBoardGroupItem = {
  value: string;
  label: string;
  onRun: () => void;
};

export type ProjectsBoardGroup = {
  value: string;
  label: string;
  items: ProjectsBoardGroupItem[];
};

export function buildProjectsBoardGroup({
  label,
  projects,
  onRunProject,
}: {
  label: string;
  projects: { id: string; name: string }[];
  onRunProject: (projectId: string) => void;
}): ProjectsBoardGroup {
  return {
    value: "projects-boards",
    label,
    items: projects.map((project) => ({
      value: project.name,
      label: project.name,
      onRun: () => onRunProject(project.id),
    })),
  };
}
