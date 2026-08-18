import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import type { ComponentType, ReactNode } from "react";
import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";
import { Route } from "./verify-otp";

// vi.hoisted: die Mocks müssen vor dem vi.mock-Factory-Hoist existieren, damit
// `toast` im Test typisiert als vi.fn() zugreifbar ist (mockReset etc.).
const { toastError, toastSuccess } = vi.hoisted(() => ({
  toastError: vi.fn(),
  toastSuccess: vi.fn(),
}));

// The OTP input measures itself on mount, which jsdom cannot do.
vi.stubGlobal(
  "ResizeObserver",
  class {
    observe() {}
    unobserve() {}
    disconnect() {}
  },
);

const push = vi.fn();

let search: {
  email: string;
  invitationId?: string;
  redirect?: string;
} = { email: "invitee@kaneo.test" };

vi.mock("@tanstack/react-router", () => ({
  createFileRoute: () => (options: unknown) => options,
  Link: ({ children }: { children: ReactNode }) => <a href="/">{children}</a>,
  useRouter: () => ({ history: { push } }),
  useSearch: () => search,
}));

vi.mock("@/lib/auth-client", () => ({
  authClient: {
    emailOtp: { sendVerificationOtp: vi.fn() },
  },
}));

vi.mock("@/lib/toast", () => ({
  toast: { error: toastError, success: toastSuccess },
}));

vi.mock("react-i18next", () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}));

const VerifyOtp = (Route as unknown as { component: ComponentType }).component;

function submitCode() {
  render(<VerifyOtp />);
  fireEvent.change(screen.getByRole("textbox"), {
    target: { value: "123456" },
  });
}

beforeEach(() => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ token: "t", user: {} }),
    }),
  );
});

afterEach(async () => {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
  cleanup();
  push.mockReset();
  toastError.mockReset();
  toastSuccess.mockReset();
  search = { email: "invitee@kaneo.test" };
});

afterAll(() => {
  vi.unstubAllGlobals();
});

describe("VerifyOtp", () => {
  it("forwards the invitation so a first OTP sign-in can create the account", async () => {
    search = { email: "invitee@kaneo.test", invitationId: "invitation-1" };

    submitCode();

    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledTimes(1));
    const [url, init] = (globalThis.fetch as ReturnType<typeof vi.fn>).mock
      .calls[0] as [string, RequestInit];
    expect(url).toMatch(/\/api\/auth\/sign-in\/email-otp$/);
    expect(init.headers).toMatchObject({ "x-invitation-id": "invitation-1" });
    expect(JSON.parse(String(init.body))).toEqual({
      email: "invitee@kaneo.test",
      otp: "123456",
    });
  });

  it("sends no invitation header when the visitor arrived without one", async () => {
    submitCode();

    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledTimes(1));
    const init = (globalThis.fetch as ReturnType<typeof vi.fn>).mock
      .calls[0][1] as RequestInit;
    expect(init.headers).not.toHaveProperty("x-invitation-id");
  });

  it("shows an actionable two-factor notice instead of hanging when the server rejects a 2FA account", async () => {
    (globalThis.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      ok: false,
      status: 401,
      json: async () => ({
        message:
          "Dieses Konto nutzt Zwei-Faktor-Anmeldung; bitte mit Passwort anmelden",
      }),
    });

    submitCode();

    // The visible, handlungsleitende Meldung erscheint — kein Toast für einen
    // „ungültigen Code“, kein hängender Spinner (der Button kehrt zurück).
    await waitFor(() =>
      expect(
        screen.getByText("auth:verifyOtp.twoFactorRequired.title"),
      ).toBeTruthy(),
    );
    expect(
      screen.getByText("auth:verifyOtp.twoFactorRequired.description"),
    ).toBeTruthy();
    expect(
      screen.getByText("auth:verifyOtp.twoFactorRequired.signInWithPassword"),
    ).toBeTruthy();
    expect(toastError).not.toHaveBeenCalled();
    // Nach der Abweisung ist der Spinner beendet: der Submit-Button zeigt wieder
    // den Ruhezustand statt „Verifying…“.
    expect(screen.getByText("auth:verifyOtp.verifyAndSignIn")).toBeTruthy();
  });

  it("shows a toast for an invalid code instead of the two-factor notice", async () => {
    (globalThis.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      ok: false,
      status: 400,
      json: async () => ({ message: "Invalid OTP", code: "INVALID_OTP" }),
    });

    submitCode();

    await waitFor(() => expect(toastError).toHaveBeenCalledWith("Invalid OTP"));
    expect(
      screen.queryByText("auth:verifyOtp.twoFactorRequired.title"),
    ).toBeNull();
  });
});
