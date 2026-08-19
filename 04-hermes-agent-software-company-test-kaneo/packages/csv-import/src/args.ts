export type ParsedArgs = {
  file?: string;
  projectName?: string;
  kaneoUrl?: string;
  kaneoApiKey?: string;
  workspace?: string;
  report?: string;
  dryRun: boolean;
  help: boolean;
  version: boolean;
};

const STRING_FLAGS: Record<string, keyof ParsedArgs> = {
  "--file": "file",
  "--project-name": "projectName",
  "--kaneo-url": "kaneoUrl",
  "--kaneo-api-key": "kaneoApiKey",
  "--workspace": "workspace",
  "--report": "report",
};

const BOOLEAN_FLAGS: Record<string, "dryRun" | "help" | "version"> = {
  "--dry-run": "dryRun",
  "-h": "help",
  "--help": "help",
  "-v": "version",
  "--version": "version",
};

export function parseArgs(argv: string[]): ParsedArgs {
  const parsed: ParsedArgs = {
    dryRun: false,
    help: false,
    version: false,
  };

  for (let index = 0; index < argv.length; index++) {
    const raw = argv[index] as string;
    const equals = raw.indexOf("=");
    const flag = equals === -1 ? raw : raw.slice(0, equals);
    const inlineValue = equals === -1 ? undefined : raw.slice(equals + 1);

    if (flag in BOOLEAN_FLAGS) {
      parsed[BOOLEAN_FLAGS[flag] as "dryRun" | "help" | "version"] = true;
      continue;
    }

    if (flag in STRING_FLAGS) {
      const value = inlineValue ?? argv[++index];
      if (value === undefined) throw new Error(`${flag} requires a value`);
      const key = STRING_FLAGS[flag] as Exclude<
        keyof ParsedArgs,
        "dryRun" | "help" | "version"
      >;
      parsed[key] = value;
      continue;
    }

    throw new Error(`Unknown option: ${flag}`);
  }

  return parsed;
}

export const DEFAULT_KANEO_URL = "https://cloud.kaneo.app";

export const HELP_TEXT = `kaneo-csv-import: import tasks from a CSV file into Kaneo

Usage:
  npx @kaneo/csv-import --file <path> --project-name <name> \
    --kaneo-api-key <key> [options]

Source:
  --file <path>              CSV file to import (one task per row)

Target:
  --project-name <name>      Name of the new Kaneo project (required)
  --kaneo-url <url>          Kaneo instance URL (default ${DEFAULT_KANEO_URL})
  --kaneo-api-key <key>      Kaneo API key (env KANEO_API_KEY)
  --workspace <id>           Target workspace ID (prompted if omitted)

Behaviour:
  --dry-run                  Plan the CSV and report counts, write nothing
  --report <path>            Write a JSON report to this path
  -h, --help                 Show this help
  -v, --version              Show the version

CSV columns (canonical):
  title (required), description, column, priority
  (no-priority|low|medium|high|urgent), due_date (YYYY-MM-DD or ISO),
  assignee_email, labels (semicolon-separated), comment

Each run creates a new project; it never updates an existing one.
The owner of the API key creates the project and the comments.

Examples:
  npx @kaneo/csv-import --file tasks.csv --project-name "Team Move" --dry-run
  npx @kaneo/csv-import --file tasks.csv --project-name "Team Move" \\
    --kaneo-api-key kaneo_xxx --workspace ws_123
`;
