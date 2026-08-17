import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";

// This file drives the real apps/api/src/mcp module through HTTP requests.
// Its import graph (hono + hono-openapi + @modelcontextprotocol/{sdk,server} +
// better-auth + drizzle + pg) is heavy: under the merge-Riegel's parallel load
// a cold transform of the graph took 82–107s, far beyond vitest's 5000ms default
// test timeout. We therefore warm the graph once in beforeAll (outside any
// per-test timeout budget), and give this file a bounded testTimeout so a slow
// re-import under load still returns a real response instead of being killed.
const HEAVY_IMPORT_TIMEOUT = 60_000;

const authMocks = vi.hoisted(() => ({
  getSession: vi.fn(async () => ({ user: { id: "test-user" } })),
}));

vi.mock("../../apps/api/src/auth", () => ({
  auth: { api: { getSession: authMocks.getSession } },
}));

const protocolVersion = "2026-07-28";

function toolRequest() {
  return new Request("http://public.test:5273/mcp", {
    method: "POST",
    headers: {
      accept: "application/json, text/event-stream",
      authorization: "Bearer test-token",
      "content-type": "application/json",
      "mcp-method": "tools/call",
      "mcp-name": "whoami",
      "mcp-protocol-version": protocolVersion,
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "whoami",
        arguments: {},
        _meta: {
          "io.modelcontextprotocol/protocolVersion": protocolVersion,
          "io.modelcontextprotocol/clientInfo": {
            name: "kaneo-internal-url-test",
            version: "1.0.0",
          },
          "io.modelcontextprotocol/clientCapabilities": {},
        },
      },
    }),
  });
}

/** Import the mcp module with a fresh module graph and the given env. */
async function loadMcpRoutes(internalApiUrl?: string) {
  vi.stubEnv("KANEO_API_URL", "http://public.test:5273/api");
  vi.stubEnv("KANEO_INTERNAL_API_URL", internalApiUrl);
  vi.resetModules();
  return (await import("../../apps/api/src/mcp")).default;
}

// Warm the heavy mcp import graph once so the per-test re-imports (which reuse
// vitest's transform cache) are cheap and stay well inside the test timeout
// even when the machine is under load. beforeAll is not charged against any
// per-test timeout budget.
beforeAll(async () => {
  await loadMcpRoutes();
}, HEAVY_IMPORT_TIMEOUT);

beforeEach(() => {
  // Each test gets an isolated module graph and clean globals/mocks so a slow
  // sibling can never leak an in-flight fetch into this test's call count.
  vi.resetModules();
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.resetModules();
  authMocks.getSession.mockClear();
});

describe(
  "MCP API URLs",
  () => {
    it(
      "advertises the public URL while fetching tools through the internal URL",
      async () => {
        const apiFetch = vi.fn(async () =>
          Response.json({ user: { id: "test-user" } }),
        );
        vi.stubGlobal("fetch", apiFetch);
        const mcpRoutes = await loadMcpRoutes();

        const metadataResponse = await mcpRoutes.request(
          "/.well-known/oauth-authorization-server/api",
        );
        const metadata = (await metadataResponse.json()) as {
          issuer: string;
          authorization_endpoint: string;
        };

        expect(metadata).toMatchObject({
          issuer: "http://public.test:5273/api",
          authorization_endpoint: "http://public.test:5273/api/mcp/authorize",
        });

        const toolResponse = await mcpRoutes.request(toolRequest());

        expect(toolResponse.status).toBe(200);
        expect(apiFetch).toHaveBeenCalledOnce();
        expect(String(apiFetch.mock.calls[0]?.[0])).toBe(
          "http://127.0.0.1:1337/api/auth/get-session",
        );
      },
      HEAVY_IMPORT_TIMEOUT,
    );

    it.each(["http://api.internal:1337/api/", "http://api.internal:1337/"])(
      "uses the configured internal URL %s without duplicate slashes",
      async (internalApiUrl: string) => {
        const apiFetch = vi.fn(async () =>
          Response.json({ user: { id: "test-user" } }),
        );
        vi.stubGlobal("fetch", apiFetch);
        const mcpRoutes = await loadMcpRoutes(internalApiUrl);

        const toolResponse = await mcpRoutes.request(toolRequest());

        expect(toolResponse.status).toBe(200);
        expect(apiFetch).toHaveBeenCalledOnce();
        expect(String(apiFetch.mock.calls[0]?.[0])).toBe(
          "http://api.internal:1337/api/auth/get-session",
        );
      },
      HEAVY_IMPORT_TIMEOUT,
    );
  },
  HEAVY_IMPORT_TIMEOUT,
);
