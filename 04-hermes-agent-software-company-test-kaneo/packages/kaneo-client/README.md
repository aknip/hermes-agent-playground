# @kaneo/kaneo-client

Shared typed HTTP client for Kaneo's public REST API, extracted from
`packages/planka-import` and reused by Kaneo's importers so no second,
untyped request layer has to exist.

## What it provides

- `KaneoClient` — a small `fetch`-based client that talks to the public Kaneo
  API with an API key (`Authorization: Bearer <key>`).
- `normalizeBaseUrl` — turns a base URL into the form all requests are built
  from (strips a trailing `/api` and slashes).
- Column/project key helpers shared by importers:
  - `toColumnSlug` — predicts the slug Kaneo derives from a column name.
  - `RESERVED_COLUMN_SLUGS` — the virtual task statuses Kaneo rejects as column
    slugs.
  - `toProjectKey` / `uniqueKey` — deterministic, collision-safe project keys.

Nothing here knows about any source system (PLANKA, CSV, WeKan). The mapping
from a source format to Kaneo stays in each importer package.

## Usage

```ts
import { KaneoClient } from "@kaneo/kaneo-client";

const kaneo = new KaneoClient({
  baseUrl: "https://kaneo.example.com",
  apiKey: "kaneo_xxx",
});

const projects = await kaneo.listProjects(workspaceId);
```

## License

MIT