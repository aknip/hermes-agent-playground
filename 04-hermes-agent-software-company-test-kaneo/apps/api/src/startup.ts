import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { serve } from "@hono/node-server";
import type { createNodeWebSocket } from "@hono/node-ws";
import { sql } from "drizzle-orm";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { app } from "./app";
import { getDatabase } from "./database";
import { prepareDatabaseStartup } from "./database/prepare-database-startup";
import { waitForDatabase } from "./database/wait-for-database";
import { migrateColumns } from "./migrations/column-migration";
import { initializePlugins } from "./plugins";
import { migrateGitHubIntegration } from "./plugins/github/migration";
import { initializeScheduler, shutdownScheduler } from "./scheduler";
import { migrateApiKeyReferenceId } from "./utils/migrate-apikey-reference-id";
import { migrateNotificationPreferencesSchema } from "./utils/migrate-notification-preferences-schema";
import { migrateSessionColumn } from "./utils/migrate-session-column";
import { migrateWorkspaceUserEmail } from "./utils/migrate-workspace-user-email";
import { seedDefaultWorkspaceRoles } from "./utils/seed-default-workspace-roles";
import { initializeWebSocketAdapter, shutdownWebSocketAdapter } from "./ws";

export async function runStartupTasks() {
  const currentDir = dirname(fileURLToPath(import.meta.url));

  await prepareDatabaseStartup({
    waitForDatabase: async () => {
      await waitForDatabase({
        query: async () => {
          await getDatabase().execute(sql`SELECT 1`);
        },
      });
    },
    runStartupMigrations: async () => {
      await migrateWorkspaceUserEmail();
      await migrateSessionColumn();

      console.log("🔄 Migrating database...");
      await migrate(getDatabase(), {
        migrationsFolder: `${currentDir}/../drizzle`,
      });
      console.log("✅ Database migrated successfully!");
    },
  });

  // After Drizzle migrations: apikey table must exist so we can align columns
  // with Better Auth (reference_id + nullable user_id).
  await migrateApiKeyReferenceId();

  await migrateNotificationPreferencesSchema();
  await migrateGitHubIntegration();
  await migrateColumns();
  await seedDefaultWorkspaceRoles();

  initializePlugins();
  initializeScheduler();
  await initializeWebSocketAdapter();
}

export async function startServer(
  injectWebSocket: ReturnType<typeof createNodeWebSocket>["injectWebSocket"],
  port = 1337,
) {
  try {
    await runStartupTasks();
  } catch (error) {
    console.error("❌ Database migration failed!", error);
    process.exit(1);
  }

  let shuttingDown = false;

  const server = serve(
    {
      fetch: app.fetch,
      port,
    },
    () => {
      console.log(
        `⚡ API is running at ${process.env.KANEO_API_URL || "http://localhost:1337"}`,
      );
    },
  );

  injectWebSocket(server);

  const gracefulShutdown = async () => {
    if (shuttingDown) return;
    shuttingDown = true;

    console.log("🛑 Shutting down gracefully...");
    shutdownScheduler();
    await shutdownWebSocketAdapter();
    server.close();
    process.exit(0);
  };

  process.on("SIGTERM", () => {
    void gracefulShutdown();
  });

  process.on("SIGINT", () => {
    void gracefulShutdown();
  });
}
