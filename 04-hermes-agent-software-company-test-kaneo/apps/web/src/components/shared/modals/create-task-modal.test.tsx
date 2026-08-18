import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import CreateTaskModal from "./create-task-modal";

/** Testzustand, der von den Mocks und den Tests geteilt wird. */
const testState = vi.hoisted(() => ({
  currentUserId: "user-1",
  members: [
    { userId: "user-1", user: { id: "user-1", name: "Tester" } },
    { userId: "user-2", user: { id: "user-2", name: "Kollegin" } },
  ],
}));

const useLocation = vi.fn();
const createTask = vi.fn(async (input: Record<string, unknown>) => ({
  id: "task-1",
  title: input.title,
  status: input.status,
  projectId: input.projectId,
  createdAt: "2026-08-05T00:00:00.000Z",
}));

afterEach(() => {
  cleanup();
  document.body.innerHTML = "";
  vi.clearAllMocks();
});

vi.mock("@tanstack/react-router", () => ({
  useLocation: () => useLocation(),
}));

vi.mock("@/components/providers/auth-provider/hooks/use-auth", () => ({
  default: () => ({
    user: { id: testState.currentUserId },
    isLoading: false,
    refetchUser: vi.fn(),
  }),
}));

vi.mock("@/components/task/task-description-editor", () => ({
  default: () => <div data-testid="description-editor" />,
}));

vi.mock("@/hooks/mutations/label/use-create-label", () => ({
  default: () => ({ mutateAsync: vi.fn() }),
}));

vi.mock("@/hooks/mutations/task/use-create-task", () => ({
  default: () => ({ mutateAsync: createTask }),
}));

vi.mock("@/hooks/mutations/task/use-delete-task", () => ({
  useDeleteTask: () => ({ mutateAsync: vi.fn() }),
}));

vi.mock("@/hooks/mutations/task/use-update-task", () => ({
  useUpdateTask: () => ({ mutateAsync: vi.fn() }),
}));

vi.mock("@/hooks/queries/label/use-get-labels-by-workspace", () => ({
  default: () => ({ data: [] }),
}));

vi.mock("@/hooks/queries/workspace/use-active-workspace", () => ({
  default: () => ({ data: { id: "workspace-1", name: "WS" } }),
}));

vi.mock(
  "@/hooks/queries/workspace-users/use-get-active-workspace-users",
  () => ({
    useGetActiveWorkspaceUsers: () => ({
      data: { members: testState.members },
    }),
  }),
);

vi.mock("@/hooks/use-workspace-permission", () => ({
  useWorkspacePermission: () => ({
    canCreateTasks: () => true,
    canCreateLabels: () => true,
  }),
}));

vi.mock("@/hooks/queries/project/use-get-projects", () => ({
  default: () => ({
    data: [
      { id: "project-1", name: "Alpha", slug: "alp" },
      { id: "project-2", name: "Beta", slug: "bet" },
    ],
  }),
}));

vi.mock("@/store/project", () => ({
  default: () => ({ project: null, setProject: vi.fn() }),
}));

vi.mock("@/lib/toast", () => ({
  toast: { error: vi.fn(), success: vi.fn() },
}));

vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const priorityLabels = {
        "tasks:priority.no-priority": "No priority",
        "tasks:priority.low": "Low",
        "tasks:priority.medium": "Medium",
        "tasks:priority.high": "High",
        "tasks:priority.urgent": "Urgent",
      } as const;
      return priorityLabels[key as keyof typeof priorityLabels] ?? key;
    },
  }),
  initReactI18next: { type: "3rdParty", init: vi.fn() },
}));

describe("CreateTaskModal project picker", () => {
  it("shows a project picker and creates the task in the chosen project", async () => {
    useLocation.mockReturnValue({
      pathname: "/dashboard/workspace/workspace-1",
    });

    render(<CreateTaskModal open onClose={vi.fn()} />);

    const pickerTrigger = screen.getByText(
      "common:modals.createTask.selectProject",
    );
    fireEvent.click(pickerTrigger);
    fireEvent.click(await screen.findByText("Beta"));

    fireEvent.change(
      screen.getByPlaceholderText(
        "common:modals.createTask.taskTitlePlaceholder",
      ),
      { target: { value: "Picked project task" } },
    );
    fireEvent.submit(document.querySelector("form") as HTMLFormElement);

    await vi.waitFor(() => {
      expect(createTask).toHaveBeenCalledWith(
        expect.objectContaining({
          title: "Picked project task",
          projectId: "project-2",
        }),
      );
    });
  });

  it("hides the picker when a project is in scope from the route", () => {
    useLocation.mockReturnValue({
      pathname: "/dashboard/workspace/workspace-1/project/project-1/board",
    });

    render(<CreateTaskModal open onClose={vi.fn()} />);

    expect(
      screen.queryByText("common:modals.createTask.selectProject"),
    ).toBeNull();
  });
});

describe("CreateTaskModal default assignee", () => {
  it("pre-selects the current user as assignee without opening the popover", async () => {
    useLocation.mockReturnValue({
      pathname: "/dashboard/workspace/workspace-1/project/project-1/board",
    });

    render(<CreateTaskModal open onClose={vi.fn()} />);

    fireEvent.change(
      screen.getByPlaceholderText(
        "common:modals.createTask.taskTitlePlaceholder",
      ),
      { target: { value: "Default assignee task" } },
    );
    // Kein Öffnen des Bearbeiter-Popovers — der Standard ist der Anwender.
    fireEvent.submit(document.querySelector("form") as HTMLFormElement);

    await vi.waitFor(() => {
      expect(createTask).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: "user-1",
        }),
      );
    });
  });

  it("keeps the assignee empty when the current user is no member", async () => {
    testState.currentUserId = "fremder";
    useLocation.mockReturnValue({
      pathname: "/dashboard/workspace/workspace-1/project/project-1/board",
    });

    render(<CreateTaskModal open onClose={vi.fn()} />);

    fireEvent.change(
      screen.getByPlaceholderText(
        "common:modals.createTask.taskTitlePlaceholder",
      ),
      { target: { value: "No assignee task" } },
    );
    fireEvent.submit(document.querySelector("form") as HTMLFormElement);

    await vi.waitFor(() => {
      expect(createTask).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: "",
        }),
      );
    });
  });
});

describe("CreateTaskModal inline priority", () => {
  it("sets the priority directly from the inline group without a popover trigger", async () => {
    testState.currentUserId = "user-1";
    useLocation.mockReturnValue({
      pathname: "/dashboard/workspace/workspace-1/project/project-1/board",
    });

    render(<CreateTaskModal open onClose={vi.fn()} />);

    // Inline: ein Klick auf „High" setzt die Priorität sofort.
    fireEvent.click(screen.getByRole("button", { name: /^High$/ }));

    fireEvent.change(
      screen.getByPlaceholderText(
        "common:modals.createTask.taskTitlePlaceholder",
      ),
      { target: { value: "Priority inline task" } },
    );
    fireEvent.submit(document.querySelector("form") as HTMLFormElement);

    await vi.waitFor(() => {
      expect(createTask).toHaveBeenCalledWith(
        expect.objectContaining({
          priority: "high",
        }),
      );
    });
  });
});
