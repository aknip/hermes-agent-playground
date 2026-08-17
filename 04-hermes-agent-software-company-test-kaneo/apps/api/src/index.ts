import "./instrument";

import { pathToFileURL } from "node:url";
import { app, injectWebSocket } from "./app";
import { startServer } from "./startup";

export { type AppType, createApp } from "./app";
export { runStartupTasks } from "./startup";
export { startServer };

const entrypoint = process.argv[1];
const isMainModule =
  entrypoint !== undefined &&
  entrypoint !== "" &&
  import.meta.url === pathToFileURL(entrypoint).href;

if (isMainModule) {
  void startServer(injectWebSocket);
}

export default app;
