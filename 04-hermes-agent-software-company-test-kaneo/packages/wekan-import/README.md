# @kaneo/wekan-import

Import boards from a [WeKan](https://wekan.team/) export into
[Kaneo](https://kaneo.app). A WeKan board export is a JSON document; each
board becomes a new Kaneo project with columns, cards, labels, assignees and
comments, written over Kaneo's public API. Nothing is written to the database
directly and no existing data is changed.

## Usage

```bash
npx @kaneo/wekan-import --file wekan-export.json --project-name "Team Move" --dry-run
```

A dry run reads and plans the whole export and prints what would be created,
without writing anything. When the plan looks right, add your Kaneo
credentials and drop `--dry-run`:

```bash
npx @kaneo/wekan-import \
  --file wekan-export.json \
  --project-name "Team Move" \
  --kaneo-url https://cloud.kaneo.app \
  --kaneo-api-key kaneo_xxx \
  --workspace ws_123
```

Create a Kaneo API key under **Settings → API keys** in Kaneo. Self-hosting?
Point `--kaneo-url` at your own instance.

## WeKan export format

Kaneo imports the JSON produced by WeKan's **Export board**
(`GET /api/boards/:boardId/export`, `_format: "wekan-board-1.0.0"`). A file
with a `boards` array is treated as a bundle of such exports and creates one
Kaneo project per board.

## What maps, what does not

| WeKan | Kaneo | How |
| --- | --- | --- |
| Board | Project | one board per project; several boards → `Name - Board title` |
| List | Column | same order, `isFinal=false` |
| Card | Task | title, description, status = column slug |
| Checklist | description checkboxes | `- [x] …` lines appended to the description |
| Due date | `dueDate` | ISO-normalized |
| Label | Label | workspace label + task label, WeKan color kept |
| Card member | Assignee | first matching workspace member (by name) |
| Comment | Comment | author and date carried in the text |
| Priority | — | WeKan has none → `no-priority` |

Attachments are counted and reported but not transferred (no API upload path),
and archived lists and cards are counted and skipped — they do not land in the
active board.

## Re-running

Each run creates new projects; it never updates an existing one. After a
partial run, delete the half-built projects and run again — the same rule as
the other importers.

## Notes

- WeKan's export deliberately strips user email addresses, so card members are
  matched to workspace members by display name rather than by email.
- Comments are created under the owner of the API key; the original author and
  date are written into the comment text, not as an `externalUserName`.