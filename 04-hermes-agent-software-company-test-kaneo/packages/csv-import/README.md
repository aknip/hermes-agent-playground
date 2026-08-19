# @kaneo/csv-import

Import tasks from a CSV file into [Kaneo](https://kaneo.app). Each row of the
CSV is one task; the import writes a new project with columns, tasks,
priorities, due dates, assignees, labels and comments over Kaneo's public API.
Nothing is written to the database directly and no existing data is changed.

## Usage

```bash
npx @kaneo/csv-import --file tasks.csv --project-name "Team Move" --dry-run
```

A dry run reads and plans the whole file and prints what would be created,
without writing anything. When the plan looks right, add your Kaneo
credentials and drop `--dry-run`:

```bash
npx @kaneo/csv-import \
  --file tasks.csv \
  --project-name "Team Move" \
  --kaneo-url https://cloud.kaneo.app \
  --kaneo-api-key kaneo_xxx \
  --workspace ws_123
```

Create a Kaneo API key under **Settings → API keys**. Self-hosting? Point
`--kaneo-url` at your own instance.

## CSV format

One row is one task; the first row is the header. Unknown columns are an error
(they would otherwise drop data silently).

| Column | Required | Maps to |
| --- | --- | --- |
| `title` | yes | Task title |
| `description` | no | Task description (multiline allowed) |
| `column` | no | Column; columns are created in their first-appearance order, an empty cell uses `Untitled` |
| `priority` | no | `no-priority\|low\|medium\|high\|urgent`; an invalid value falls back to `no-priority` with a warning |
| `due_date` | no | Due date (`YYYY-MM-DD` or ISO); an unreadable value is dropped |
| `assignee_email` | no | Task assignee, matched by email against the target workspace; no match warns and stays unassigned |
| `labels` | no | Semicolon-separated labels; each is created in the workspace and attached to the task |
| `comment` | no | One comment per row, created under the API key owner |

```csv
title,description,column,priority,due_date,assignee_email,labels,comment
Write copy,Homepage copy,Backlog,high,2026-03-04,sam@example.com,urgent;copy,Great start
Fix login,"Multi-line
description",To Do,medium,,,bug,
```

## What doesn't

- **Attachments.** Not part of the CSV schema.
- **Comment authorship.** A CSV has no author column; comments are created by
  the API key owner.
- **Due-done flags, task relations / subtasks.** The CSV is flat: one row is
  one task. Final columns and dependencies have no flat-CSV counterpart, so
  every column is created as a normal (non-final) column.

## Re-running

The importer always creates a new project; it never updates a project it
created earlier. If an import goes wrong, delete the created project and run
again. A failing row is recorded in the report and the run continues with the
next row; the summary and the `--report` JSON tell you exactly which rows
failed.

## Options

| Flag | Description |
| --- | --- |
| `--file <path>` | CSV file to import (required) |
| `--project-name <name>` | Name of the new Kaneo project (required) |
| `--kaneo-url <url>` | Kaneo instance URL (default `https://cloud.kaneo.app`) |
| `--kaneo-api-key <key>` | Kaneo API key (or set `KANEO_API_KEY`) |
| `--workspace <id>` | Target workspace (prompted if omitted, single workspace auto-selected) |
| `--dry-run` | Plan and report, write nothing |
| `--report <path>` | Write a JSON report with the counted result |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

## License

MIT