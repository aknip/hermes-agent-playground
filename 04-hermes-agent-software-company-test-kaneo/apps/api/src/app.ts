import { createNodeWebSocket } from "@hono/node-ws";
import * as Sentry from "@sentry/node";
import type { Session, User } from "better-auth/types";
import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { HTTPException } from "hono/http-exception";
import { describeRoute, openAPIRouteHandler, validator } from "hono-openapi";
import * as v from "valibot";
import activity from "./activity";
import { auth } from "./auth";
import billing from "./billing";
import column from "./column";
import comment from "./comment";
import config from "./config";
import db, { schema } from "./database";
import discordIntegration from "./discord-integration";
import { eventContext } from "./events";
import externalLink from "./external-link";
import genericWebhookIntegration from "./generic-webhook-integration";
import giteaIntegration, { handleGiteaWebhookRoute } from "./gitea-integration";
import githubIntegration, {
  handleGithubWebhookRoute,
} from "./github-integration";
import invitation from "./invitation";
import label from "./label";
import mcpRoutes, { mcpWellKnownRoutes } from "./mcp";
import notification from "./notification";
import notificationPreferences from "./notification-preferences";
import oauth from "./oauth";
import project from "./project";
import { getPublicProject } from "./project/controllers/get-public-project";
import { registerAssetRoutes } from "./routes/assets";
import { registerAuthRoutes } from "./routes/auth";
import { registerHealthRoutes } from "./routes/health";
import search from "./search";
import slackIntegration from "./slack-integration";
import task from "./task";
import taskRelation from "./task-relation";
import telegramIntegration from "./telegram-integration";
import timeEntry from "./time-entry";
import user from "./user";
import getAvatar from "./user/controllers/get-avatar";
import { authenticateApiRequest } from "./utils/authenticate-api-request";
import { getInvitationDetails } from "./utils/check-registration-allowed";
import {
  dedupeOperationIds,
  ensureOperationSummaries,
  markOptionalSchemaFieldsNullable,
  mergeOpenApiSpecs,
  normalizeApiServerUrl,
  normalizeEmptyAndEnumSchemas,
  normalizeEmptyRequiredArrays,
  normalizeMalformedPropertySchemas,
  normalizeNullableSchemasForOpenApi30,
  normalizeOrganizationAuthOperations,
} from "./utils/openapi-spec";
import { validateWorkspaceAccess } from "./utils/validate-workspace-access";
import workflowRule from "./workflow-rule";
import workspace from "./workspace";
import {
  addConnection,
  addUserConnection,
  removeConnection,
  removeUserConnection,
} from "./ws";

type ApiKey = {
  id: string;
  userId: string;
  enabled: boolean;
  permissions: Record<string, string[]> | null;
};

type AppVariables = {
  Variables: {
    user: User | null;
    session: Session | null;
    userId: string;
    apiKey?: ApiKey;
  };
};

export type ApiVariables = {
  Variables: {
    user: User | null;
    session: Session | null;
    userId: string;
    userEmail: string;
    apiKey?: ApiKey;
  };
};

export function createApp() {
  const app = new Hono<AppVariables>();

  app.onError((err, c) => {
    if (err instanceof HTTPException) {
      // expected errors (401/404/...) are not reported; real failures are
      if (err.status >= 500) {
        Sentry.captureException(err);
      }
      return err.getResponse();
    }

    Sentry.captureException(err);
    return c.json({ message: "Internal Server Error" }, 500);
  });
  const nodeWs = createNodeWebSocket({ app });
  const { upgradeWebSocket, injectWebSocket } = nodeWs;
  const corsOriginSource = [
    process.env.CORS_ORIGINS,
    process.env.KANEO_CLIENT_URL,
  ].find((value) => value?.trim());
  const corsOrigins = corsOriginSource
    ?.split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  const reflectUnconfiguredOrigins = process.env.NODE_ENV !== "production";

  if (!corsOrigins && !reflectUnconfiguredOrigins) {
    console.warn(
      "[cors] Neither CORS_ORIGINS nor KANEO_CLIENT_URL is set, so cross-origin requests are refused. Same-origin deployments (the bundled image) are unaffected; set KANEO_CLIENT_URL if the web app is served from another origin.",
    );
  }

  app.use(
    "*",
    cors({
      credentials: true,
      origin: (origin) => {
        // Reflecting an arbitrary origin alongside credentials lets any site
        // read authenticated responses, so it stays a development convenience.
        if (!corsOrigins) {
          return reflectUnconfiguredOrigins ? origin || "*" : null;
        }

        if (!origin) {
          return null;
        }

        return corsOrigins.includes(origin) ? origin : null;
      },
    }),
  );

  const api = new Hono<ApiVariables>();

  registerHealthRoutes(api);

  const publicProjectApi = api.get("/public-project/:id", async (c) => {
    const { id } = c.req.param();
    const project = await getPublicProject(id);

    return c.json(project);
  });

  api.post("/github-integration/webhook", handleGithubWebhookRoute);

  api.post(
    "/gitea-integration/webhook/:integrationId",
    handleGiteaWebhookRoute,
  );

  const invitationPublicApi = api.get("/invitation/public/:id", async (c) => {
    const { id } = c.req.param();
    const result = await getInvitationDetails(id);
    return c.json(result);
  });

  registerAuthRoutes(api);
  registerAssetRoutes(api);

  api.get(
    "/user/avatar/:id",
    describeRoute({
      operationId: "getUserAvatar",
      tags: ["User"],
      description: "Download a user avatar by its avatar ID",
      security: [],
      responses: {
        200: {
          description: "The avatar image",
          content: {
            "image/*": { schema: { type: "string", format: "binary" } },
          },
        },
        404: {
          description: "Avatar not found",
        },
      },
    }),
    validator("param", v.object({ id: v.string() })),
    async (c) => {
      const { id } = c.req.valid("param");
      const avatar = await getAvatar(id);

      if (!avatar) {
        throw new HTTPException(404, { message: "Avatar not found" });
      }

      const etag = `"${avatar.id}"`;
      if (c.req.header("If-None-Match") === etag) {
        return new Response(null, { status: 304, headers: { ETag: etag } });
      }

      return new Response(new Uint8Array(avatar.data) as BodyInit, {
        headers: {
          "Cache-Control": "public, max-age=31536000, immutable",
          "Content-Length": avatar.size.toString(),
          "Content-Type": avatar.mimeType,
          "X-Content-Type-Options": "nosniff",
          ETag: etag,
          "Last-Modified": avatar.updatedAt.toUTCString(),
        },
      });
    },
  );

  const configApi = api.route("/config", config);

  const honoOpenApiHandler = openAPIRouteHandler(api, {
    documentation: {
      openapi: "3.0.3",
      info: {
        title: "Kaneo API",
        version: "1.0.0",
        description:
          "Kaneo Project Management API - Manage projects, tasks, labels, and more",
      },
      servers: [
        {
          url: normalizeApiServerUrl(
            process.env.KANEO_API_URL || "https://cloud.kaneo.app",
          ),
          description: "Kaneo API Server",
        },
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: "http",
            scheme: "bearer",
            description: "API key or session token (Bearer)",
          },
        },
      },
      security: [{ bearerAuth: [] }],
    },
  });

  api.get("/openapi", async (c) => {
    const maybeResponse = await honoOpenApiHandler(c, async () => {});
    const honoSpecResponse = maybeResponse ?? c.res;
    const honoSpec = (await honoSpecResponse.json()) as Record<string, unknown>;

    let authSpec: Record<string, unknown> = {};
    try {
      authSpec = (await auth.api.generateOpenAPISchema()) as Record<
        string,
        unknown
      >;
    } catch (error) {
      console.error("Failed to generate Better Auth OpenAPI schema:", error);
    }

    const normalizedAuthSpec = normalizeOrganizationAuthOperations(authSpec);
    return c.json(
      ensureOperationSummaries(
        dedupeOperationIds(
          markOptionalSchemaFieldsNullable(
            normalizeNullableSchemasForOpenApi30(
              normalizeEmptyAndEnumSchemas(
                normalizeEmptyRequiredArrays(
                  normalizeMalformedPropertySchemas(
                    mergeOpenApiSpecs(honoSpec, normalizedAuthSpec),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });

  api.route("/", mcpRoutes);

  api.use("*", async (c, next) => {
    const path = c.req.path;
    if (
      path.startsWith("/api/mcp") ||
      path.startsWith("/api/.well-known/") ||
      path === "/api/billing/webhook"
    ) {
      return next();
    }
    return Sentry.withIsolationScope(async () => {
      Sentry.setUser(null);
      try {
        await authenticateApiRequest(c);
        const windowId = c.req.header("X-Kaneo-Window-Id");
        const userId = c.get("userId");
        const initiatorId = windowId ? `${userId}:${windowId}` : userId;
        return await eventContext.run({ initiatorId }, next);
      } catch (error) {
        if (!(error instanceof HTTPException)) {
          console.error("API authentication failed:", error);
          throw new HTTPException(500, { message: "Internal Server Error" });
        }
        throw error;
      } finally {
        Sentry.setUser(null);
      }
    });
  });

  const oauthApi = api.route("/oauth", oauth);

  const billingApi = api.route("/billing", billing);
  const projectApi = api.route("/project", project);
  const taskApi = api.route("/task", task);
  const columnApi = api.route("/column", column);
  const activityApi = api.route("/activity", activity);
  const commentApi = api.route("/comment", comment);
  const timeEntryApi = api.route("/time-entry", timeEntry);
  const labelApi = api.route("/label", label);
  const notificationApi = api.route("/notification", notification);
  const notificationPreferencesApi = api.route(
    "/notification-preferences",
    notificationPreferences,
  );
  const searchApi = api.route("/search", search);
  const githubIntegrationApi = api.route(
    "/github-integration",
    githubIntegration,
  );
  const giteaIntegrationApi = api.route("/gitea-integration", giteaIntegration);
  const genericWebhookIntegrationApi = api.route(
    "/generic-webhook-integration",
    genericWebhookIntegration,
  );
  const discordIntegrationApi = api.route(
    "/discord-integration",
    discordIntegration,
  );
  const slackIntegrationApi = api.route("/slack-integration", slackIntegration);
  const telegramIntegrationApi = api.route(
    "/telegram-integration",
    telegramIntegration,
  );
  const taskRelationApi = api.route("/task-relation", taskRelation);
  const externalLinkApi = api.route("/external-link", externalLink);
  const workflowRuleApi = api.route("/workflow-rule", workflowRule);
  const invitationApi = api.route("/invitation", invitation);
  const workspaceApi = api.route("/workspace", workspace);
  const userApi = api.route("/user", user);

  app.route(
    "/",
    mcpWellKnownRoutes(
      (process.env.KANEO_API_URL || "http://localhost:1337").replace(
        /\/api\/?$/,
        "",
      ),
    ),
  );

  // User-scoped WebSocket endpoint; MUST be registered before /ws/:projectId
  // so the literal path "user" isn't consumed by the param route.
  api.get(
    "/ws/user",
    upgradeWebSocket(async (c) => {
      try {
        await authenticateApiRequest(c);
      } catch (error) {
        if (error instanceof HTTPException) {
          throw error;
        }
        console.error("API authentication failed:", error);
        throw new HTTPException(500, { message: "Internal Server Error" });
      }

      const userId = c.get("userId");
      let conn: ReturnType<typeof addUserConnection> | null = null;

      return {
        onOpen(_evt, ws) {
          if (userId) {
            conn = addUserConnection(userId, ws);
          }
        },
        onMessage(evt) {
          try {
            const raw =
              typeof evt.data === "string"
                ? evt.data
                : Buffer.isBuffer(evt.data)
                  ? evt.data.toString()
                  : null;
            if (raw) {
              const msg = JSON.parse(raw) as { type?: string };
              if (msg?.type === "ping") {
                // keepalive, no-op
              }
            }
          } catch {
            // Ignore malformed messages
          }
        },
        onClose() {
          if (conn && userId) {
            removeUserConnection(userId, conn);
          }
        },
      };
    }),
  );

  api.get(
    "/ws/:projectId",
    upgradeWebSocket(async (c) => {
      const projectId = c.req.param("projectId");

      try {
        await authenticateApiRequest(c);
      } catch (error) {
        if (error instanceof HTTPException) {
          throw error;
        }
        console.error("API authentication failed:", error);
        throw new HTTPException(500, { message: "Internal Server Error" });
      }

      const userId = c.get("userId");

      if (projectId) {
        const [project] = await db
          .select({ workspaceId: schema.projectTable.workspaceId })
          .from(schema.projectTable)
          .where(eq(schema.projectTable.id, projectId))
          .limit(1);

        if (!project) {
          throw new HTTPException(401, { message: "Unauthorized" });
        }

        await validateWorkspaceAccess(userId, project.workspaceId);
      }

      const windowId = c.req.query("windowId");
      const initiatorId = windowId ? `${userId}:${windowId}` : userId;
      let conn: ReturnType<typeof addConnection> | null = null;

      return {
        onOpen(_evt, ws) {
          if (projectId) {
            conn = addConnection(projectId, ws, userId, initiatorId);
          }
        },
        onMessage(evt) {
          // Respond to client keepalive pings (sent every 30s to prevent
          // Cloudflare from closing idle connections at 100s timeout)
          try {
            const raw =
              typeof evt.data === "string"
                ? evt.data
                : Buffer.isBuffer(evt.data)
                  ? evt.data.toString()
                  : null;
            if (raw) {
              const msg = JSON.parse(raw) as { type?: string };
              if (msg?.type === "ping") {
                // No-op: receiving the ping is enough to satisfy Cloudflare.
                // A pong response is optional but helps confirm liveness.
              }
            }
          } catch {
            // Ignore malformed messages
          }
        },
        onClose() {
          if (conn && projectId) {
            removeConnection(projectId, conn);
          }
        },
      };
    }),
  );

  app.route("/api", api);

  return {
    app,
    api,
    injectWebSocket,
    activityApi,
    billingApi,
    columnApi,
    commentApi,
    configApi,
    discordIntegrationApi,
    externalLinkApi,
    genericWebhookIntegrationApi,
    githubIntegrationApi,
    giteaIntegrationApi,
    invitationApi,
    invitationPublicApi,
    labelApi,
    notificationApi,
    notificationPreferencesApi,
    projectApi,
    publicProjectApi,
    searchApi,
    slackIntegrationApi,
    taskApi,
    taskRelationApi,
    telegramIntegrationApi,
    timeEntryApi,
    userApi,
    workflowRuleApi,
    workspaceApi,
    oauthApi,
  };
}

const createdApp = createApp();

export const app = createdApp.app;
export const injectWebSocket = createdApp.injectWebSocket;

export type AppType =
  | ReturnType<typeof createApp>["activityApi"]
  | ReturnType<typeof createApp>["billingApi"]
  | ReturnType<typeof createApp>["columnApi"]
  | ReturnType<typeof createApp>["commentApi"]
  | ReturnType<typeof createApp>["configApi"]
  | ReturnType<typeof createApp>["discordIntegrationApi"]
  | ReturnType<typeof createApp>["externalLinkApi"]
  | ReturnType<typeof createApp>["genericWebhookIntegrationApi"]
  | ReturnType<typeof createApp>["githubIntegrationApi"]
  | ReturnType<typeof createApp>["giteaIntegrationApi"]
  | ReturnType<typeof createApp>["invitationApi"]
  | ReturnType<typeof createApp>["invitationPublicApi"]
  | ReturnType<typeof createApp>["labelApi"]
  | ReturnType<typeof createApp>["notificationApi"]
  | ReturnType<typeof createApp>["notificationPreferencesApi"]
  | ReturnType<typeof createApp>["projectApi"]
  | ReturnType<typeof createApp>["publicProjectApi"]
  | ReturnType<typeof createApp>["searchApi"]
  | ReturnType<typeof createApp>["slackIntegrationApi"]
  | ReturnType<typeof createApp>["taskApi"]
  | ReturnType<typeof createApp>["taskRelationApi"]
  | ReturnType<typeof createApp>["telegramIntegrationApi"]
  | ReturnType<typeof createApp>["timeEntryApi"]
  | ReturnType<typeof createApp>["userApi"]
  | ReturnType<typeof createApp>["workflowRuleApi"]
  | ReturnType<typeof createApp>["workspaceApi"]
  | ReturnType<typeof createApp>["oauthApi"];
