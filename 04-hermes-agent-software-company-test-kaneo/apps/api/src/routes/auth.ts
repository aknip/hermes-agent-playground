import type { Hono } from "hono";
import { describeRoute, resolver, validator } from "hono-openapi";
import * as v from "valibot";
import type { ApiVariables } from "../app";
import { auth } from "../auth";

export function registerAuthRoutes(api: Hono<ApiVariables>): void {
  api.get(
    "/auth/get-session",
    describeRoute({
      operationId: "getSession",
      tags: ["Authentication"],
      description: "Get the current authenticated session",
      security: [],
      responses: {
        200: {
          description: "Current session details or null when unauthenticated",
          content: {
            "application/json": { schema: resolver(v.any()) },
          },
        },
      },
    }),
    async (c) => {
      return auth.handler(c.req.raw);
    },
  );

  // Better Auth serves GET /auth/device as JSON. Browsers that open the API URL
  // directly expect a page, so redirect full document navigations to the web app.
  const authDeviceQuerySchema = v.object({
    user_code: v.optional(v.string()),
    ui: v.optional(v.picklist(["1"])),
  });

  api.get(
    "/auth/device",
    describeRoute({
      operationId: "getDeviceAuthorizationPage",
      tags: ["Authentication"],
      description:
        "Redirect browser-based device authorization requests to the web UI",
      security: [],
      parameters: [
        {
          name: "user_code",
          in: "query",
          required: false,
          schema: {
            type: "string",
          },
          description: "The device authorization user code.",
        },
        {
          name: "ui",
          in: "query",
          required: false,
          schema: {
            type: "string",
            enum: ["1"],
          },
          description: "Force a redirect to the web UI.",
        },
      ],
      responses: {
        302: {
          description: "Redirects the browser to the web app device screen",
        },
        200: {
          description: "Device authorization payload from Better Auth",
          content: {
            "application/json": { schema: resolver(v.any()) },
          },
        },
      },
    }),
    validator("query", authDeviceQuerySchema),
    async (c) => {
      const { user_code: userCode, ui } = c.req.valid("query");
      const secFetchDest = c.req.header("Sec-Fetch-Dest");
      const forceUiRedirect = ui === "1";
      // Top-level browser tab / address bar (not `fetch()` / XHR from the SPA).
      // Optional `ui=1` forces redirect when Sec-Fetch-* headers are missing (e.g. some clients).
      if (forceUiRedirect || secFetchDest === "document") {
        const clientUrl = (
          process.env.KANEO_CLIENT_URL || "http://localhost:5173"
        ).replace(/\/$/, "");
        const deviceUrl = new URL(`${clientUrl}/device`);
        if (userCode) {
          deviceUrl.searchParams.set("user_code", userCode);
        }
        return c.redirect(deviceUrl.toString(), 302);
      }
      return auth.handler(c.req.raw);
    },
  );

  api.on(["POST", "GET", "PUT", "DELETE"], "/auth/*", async (c) => {
    const authHeader = c.req.header("Authorization");
    const apiKeyHeader = c.req.header("x-api-key");
    const bearerToken = authHeader?.match(/^Bearer\s+(\S+)$/i)?.[1];

    if (bearerToken && !apiKeyHeader) {
      const session = await auth.api.getSession({
        headers: c.req.raw.headers,
      });

      // Preserve Better Auth bearer session tokens on auth routes.
      if (session?.session && session.user) {
        return auth.handler(c.req.raw);
      }

      const headers = new Headers(c.req.raw.headers);

      // Better Auth API key plugin validates from x-api-key by default.
      headers.set("x-api-key", bearerToken);

      return auth.handler(
        new Request(c.req.raw, {
          headers,
        }),
      );
    }

    return auth.handler(c.req.raw);
  });
}
