import type { Hono } from "hono";
import { describeRoute, resolver } from "hono-openapi";
import * as v from "valibot";
import type { ApiVariables } from "../app";
import getInstanceStatus from "../instance/controllers/get-instance-status";

export function registerHealthRoutes(api: Hono<ApiVariables>): void {
  api.get("/health", (c) => {
    return c.json({ status: "ok" });
  });

  api.get(
    "/instance/status",
    describeRoute({
      operationId: "getInstanceStatus",
      tags: ["Instance"],
      description:
        "Public instance setup status. When hasUsers is false the next signup becomes the instance admin.",
      security: [],
      responses: {
        200: {
          description: "Instance status",
          content: {
            "application/json": {
              schema: resolver(
                v.object({
                  hasUsers: v.boolean(),
                  hasAdmin: v.boolean(),
                }),
              ),
            },
          },
        },
      },
    }),
    async (c) => {
      const status = await getInstanceStatus();
      return c.json(status);
    },
  );
}
