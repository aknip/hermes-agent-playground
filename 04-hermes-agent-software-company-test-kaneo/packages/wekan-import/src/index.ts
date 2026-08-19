#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { KaneoClient } from "@kaneo/kaneo-client";
import { DEFAULT_KANEO_URL, HELP_TEXT, parseArgs } from "./args.js";
import { planWekanExport } from "./mapping.js";
import { importWekan, type WekanBoardReport } from "./migrate.js";
import { parseExport } from "./parser.js";

const require = createRequire(import.meta.url);
const { version } = require("../package.json") as { version: string };

export type CliIO = {
  stdout: (text: string) => void;
  stderr: (text: string) => void;
  readFile: (path: string) => Promise<string>;
  writeFile: (path: string, data: string) => Promise<void>;
};

export async function runCli(args: string[], io: CliIO): Promise<number> {
  let parsed: ReturnType<typeof parseArgs>;
  try {
    parsed = parseArgs(args);
  } catch (error) {
    io.stderr(`${error instanceof Error ? error.message : String(error)}\n`);
    return 2;
  }

  if (parsed.help) {
    io.stdout(HELP_TEXT);
    return 0;
  }

  if (parsed.version) {
    io.stdout(`${version}\n`);
    return 0;
  }

  if (!parsed.file) {
    io.stderr("--file is required\n");
    return 2;
  }

  if (!parsed.projectName) {
    io.stderr("--project-name is required\n");
    return 2;
  }

  let text: string;
  try {
    text = await io.readFile(parsed.file);
  } catch (error) {
    io.stderr(
      `Cannot read ${parsed.file}: ${error instanceof Error ? error.message : String(error)}\n`,
    );
    return 2;
  }

  let exportData: ReturnType<typeof parseExport>;
  try {
    exportData = parseExport(text);
  } catch (error) {
    io.stderr(`${error instanceof Error ? error.message : String(error)}\n`);
    return 2;
  }

  const { boards, warnings } = planWekanExport(exportData, parsed.projectName);

  let kaneo: KaneoClient;
  if (parsed.dryRun) {
    kaneo = new KaneoClient({
      baseUrl: parsed.kaneoUrl ?? DEFAULT_KANEO_URL,
      apiKey: "",
    });
  } else {
    const apiKey = parsed.kaneoApiKey ?? process.env.KANEO_API_KEY;
    if (!apiKey) {
      io.stderr(
        "A Kaneo API key is required. Pass --kaneo-api-key or set KANEO_API_KEY.\n",
      );
      return 2;
    }
    kaneo = new KaneoClient({
      baseUrl: parsed.kaneoUrl ?? DEFAULT_KANEO_URL,
      apiKey,
    });
  }

  let workspaceId = parsed.workspace ?? "";
  if (!parsed.dryRun && !workspaceId) {
    workspaceId = await resolveWorkspace(kaneo, io);
  }

  const reports = await importWekan({
    kaneo,
    workspaceId,
    baseProjectName: parsed.projectName,
    boards,
    dryRun: parsed.dryRun,
  });

  const totals = summarize(reports);

  if (parsed.dryRun) {
    io.stdout(
      `Dry run: ${totals.boards} board(s), ${totals.tasks} tasks, ${totals.columns} columns, ${totals.labels} labels, ${totals.comments} comments, ${totals.checklistItems} checklist items, ${totals.archivedLists} archived list(s), ${totals.archivedCards} archived card(s), ${totals.attachmentsSkipped} attachment(s) skipped. Nothing was written to Kaneo.\n`,
    );
  } else {
    for (const report of reports) {
      io.stdout(
        `✔ ${report.projectName} (${report.projectKey})  ${report.columns} columns  ${report.tasks} tasks  ${report.labels} labels  ${report.comments} comments  ${report.assignees} assignees\n`,
      );
    }
  }

  for (const warning of warnings) io.stdout(`  ! ${warning}\n`);
  for (const report of reports) {
    for (const warning of report.warnings) io.stdout(`  ! ${warning}\n`);
  }
  for (const report of reports) {
    for (const rowError of report.errors) {
      io.stdout(
        `  ✖ ${report.projectName}/${rowError.card}: ${rowError.error}\n`,
      );
    }
  }

  if (parsed.report) {
    const payload = {
      dryRun: parsed.dryRun,
      baseProjectName: parsed.projectName,
      boards: reports,
      totals,
    };
    await io.writeFile(parsed.report, `${JSON.stringify(payload, null, 2)}\n`);
    io.stdout(`Report written to ${parsed.report}\n`);
  }

  return totals.failed ? 1 : 0;
}

function summarize(reports: WekanBoardReport[]) {
  return {
    boards: reports.length,
    projects: reports.length,
    columns: reports.reduce((total, report) => total + report.columns, 0),
    tasks: reports.reduce((total, report) => total + report.tasks, 0),
    labels: reports.reduce((total, report) => total + report.labels, 0),
    comments: reports.reduce((total, report) => total + report.comments, 0),
    assignees: reports.reduce((total, report) => total + report.assignees, 0),
    checklistItems: reports.reduce(
      (total, report) => total + report.checklistItems,
      0,
    ),
    archivedLists: reports.reduce(
      (total, report) => total + report.archivedLists,
      0,
    ),
    archivedCards: reports.reduce(
      (total, report) => total + report.archivedCards,
      0,
    ),
    attachmentsSkipped: reports.reduce(
      (total, report) => total + report.attachmentsSkipped,
      0,
    ),
    failed: reports.some((report) => report.failed),
  };
}

async function resolveWorkspace(
  kaneo: KaneoClient,
  io: CliIO,
): Promise<string> {
  const workspaces = await kaneo.listWorkspaces();
  if (workspaces.length === 0) {
    io.stderr("This Kaneo account has no workspaces.\n");
    return "";
  }
  const first = workspaces[0];
  if (workspaces.length === 1 && first) return first.id;
  io.stderr(
    `Several workspaces are available; pass --workspace with one of: ${workspaces
      .map((w) => `${w.name} (${w.id})`)
      .join(", ")}\n`,
  );
  return "";
}

async function main(): Promise<number> {
  return runCli(process.argv.slice(2), {
    stdout: (text) => process.stdout.write(text),
    stderr: (text) => process.stderr.write(text),
    readFile: (path) => readFile(path, "utf8"),
    writeFile,
  });
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error: unknown) => {
    process.stderr.write(
      `${error instanceof Error ? error.message : String(error)}\n`,
    );
    process.exitCode = 1;
  });
