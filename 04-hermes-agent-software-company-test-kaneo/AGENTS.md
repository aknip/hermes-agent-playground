# Kaneo agent guide

This is a fork from https://github.com/usekaneo/kaneo.git

Kaneo is a fast, deliberately simple, self-hosted project-management platform. The Hono API owns domain behavior and authorization, the React app consumes its typed client, PostgreSQL stores durable state, and events plus WebSockets keep clients current. Redis is optional and coordinates realtime delivery across multiple API instances.

This is an operating guide, not a README. These rules are good defaults; explicit developer and user instructions take precedence.

## Quickstart

Local development runs the API and web host-natively and PostgreSQL in a container.

```bash
docker compose -f compose.yml up -d postgres   # Postgres 16 on :5432
pnpm install
pnpm dev                                       # API :1337, web :5173
```

- Configuration lives in a single root `.env`; see `.env.sample` and `ENVIRONMENT_SETUP.md`. Set `DATABASE_URL` explicitly for host-native runs — the value derived from `POSTGRES_*` points at the Compose hostname `postgres`, which the host cannot resolve.
- Do not add a `.env.local`. The API loads environment variables through `dotenv-mono`, which reads only the single highest-priority file, so a `.env.local` replaces `.env` rather than extending it. `compose.local.yml` expects one, which is why the database above comes from `compose.yml`.
- `pnpm dev` is `turbo dev` and starts every workspace with a `dev` script, including `@kaneo/site` and the docs, so it binds more ports than 1337 and 5173.
- Liveness check: `curl http://localhost:1337/api/health`. Migrations run on API startup and a failed migration exits the process, so a dead port usually means a broken migration rather than a slow start.
- Dev login: `admin@admin.com` / `adminadmin` (display name `admin`, role `admin`). Its workspace is **Hermes**, slug `hermes`.

## Principles

- Simplicity is a product requirement. Build the smallest model that makes correct behavior obvious.
- Features should solve a real problem without making routine work heavier.
- Protect performance, especially on task-heavy boards and realtime views.
- Keep self-hosting straightforward and single-instance deployments first-class. Do not make Redis or another managed service mandatory without an explicit product decision.
- Support both bundled same-origin deployments and separately hosted API and web deployments.
- Protect user data, workspace boundaries, and authorization checks.
- Read the relevant implementation before changing it. Follow an established local pattern when it fits, but do not preserve accidental complexity merely because it exists.
- Stay focused. Do not mix requested work with speculative features, broad refactors, or unrelated cleanup.

## Architecture

- `apps/api` — Hono API, Better Auth, controllers, database access, events, integrations, MCP HTTP routes, and WebSockets.
- `apps/web` — React/Vite UI, TanStack Router and Query, fetchers, hooks, and realtime cache updates.
- `apps/docs` — product and API documentation content; `apps/site` — public Next.js site and documentation host.
- `packages/libs` — shared typed Hono client and URL helpers.
- `packages/permissions` — canonical permission vocabulary and built-in roles.
- `packages/mcp` — published stdio MCP package.
- `charts/kaneo` — Helm deployment surface.
- `tests/api` contains API unit tests; `tests/api-integration` contains PostgreSQL-backed integration tests.

## Boundaries that must hold

- The API is the authority for authentication and authorization. Hiding an action in the UI is not an authorization check.
- Workspace-scoped operations must use the existing `@kaneo/permissions` vocabulary and API middleware.
- Do not expose secrets, credentials, internal fields, or private workspace data through responses, logs, events, WebSockets, or MCP tools.
- Public API behavior must retain accurate Valibot validation and OpenAPI metadata.
- Mutations that affect realtime state must consider event publication, WebSocket delivery, and client cache invalidation.
- Database changes must work for existing installations, not only empty development databases.
- User-facing web copy must use static i18n keys. `i18n/en-US.json` is the source of truth.

## Follow a change through

Before calling a behavior change complete, decide which surfaces apply:

- API route, validator, controller, authorization, error behavior, and OpenAPI description.
- Typed client, web fetcher, query or mutation hook, cache invalidation, and UI states.
- Events, project- or user-scoped WebSockets, and optional Redis fan-out.
- Permission definitions, API enforcement, and UI capability checks.
- MCP, API keys, webhooks, and relevant external integrations.
- Schema, relations, generated migration, indexes, cascades, and existing data.
- Translations, accessibility, user documentation, Docker, and Helm.
- Reverse states: create/delete, assign/unassign, enable/disable, connect/disconnect, and a visible current state.

Not every change touches every surface. Make the decision deliberately rather than expanding scope automatically.

## Project conventions

- Keep API handlers thin and domain behavior in controllers or focused utilities.
- Validate API inputs with Valibot unless an existing integration requires another library. Use `HTTPException` for expected HTTP failures.
- Use `requireWorkspacePermission` rather than duplicating role checks.
- Use `publishEvent()` when a mutation drives activity, notifications, integrations, or realtime updates.
- Keep web requests in `apps/web/src/fetchers/` and server state in TanStack Query hooks.
- Use the client from `@kaneo/libs`; do not create a parallel untyped request layer.
- Define database schema in `apps/api/src/database/schema.ts` and relations in `apps/api/src/database/relations.ts`.
- Generate migrations with `pnpm --filter @kaneo/api db:generate`, inspect the SQL, and include it with the schema change.
- Prefer inferred TypeScript types and `type` over `interface` unless extension or declaration merging is required.
- Comments should explain constraints or surprising decisions, not narrate code.

## Safety and tooling

- Use pnpm 10.32.1 and Node.js 20.19 or newer. Server environment variables come from the root `.env`; local Vite-only overrides belong in `apps/web/.env.local`. See `ENVIRONMENT_SETUP.md`.
- Never use production databases, storage, or credentials for development or tests.
- Preserve unrelated work in a dirty worktree. Do not delete data or generated files unless the task requires it and the target is verified.
- Track processes you start and stop only those processes; never kill by broad name or path patterns.
- The root and package `lint` scripts run Biome with `--write` and can modify unrelated files. Prefer targeted checks while iterating and inspect formatter changes.
- Do not commit, push, or open a pull request unless explicitly requested.

## Verification

Use the smallest proof that covers the changed behavior, then broaden it when the blast radius requires it.

- Utility or UI logic: focused unit/component tests and the affected package typecheck.
- API behavior: focused API tests; use integration tests when routing, authentication, authorization, or PostgreSQL behavior matters.
- Database changes: relevant integration tests and migration inspection.
- Cross-package contracts: typecheck or build all affected consumers.
- Realtime changes: verify the event-to-WebSocket-to-cache path and consider both in-memory and Redis delivery.
- Deployment changes: validate the affected Docker, Helm, or startup path.
- User-visible flows: use a real browser pass when requested or when it is the only meaningful proof.

Run repository-wide checks when a change crosses packages broadly, before a requested commit or pull request, or when explicitly asked. Report what ran and what did not.

## ESF — Definition of Done

This repository is developed by the ESF, an autonomous agent organisation
(`../03-hermes-agent-software-company`). A feature card is done when all of
these hold. Nothing here replaces the sections above; it makes them checkable.

- **The change is committed on its own `feat/…` branch, in its own worktree.**
  Never on `main`, never merged by hand.
- **Tests came first.** Red, green, refactor. A test written after the code
  tests what was built, not what was asked for.
- **The user journey is in the E2E suite.** Every feature adds or extends a
  Playwright spec under `tests/e2e/journeys/`, written from the user's point of
  view with visible steps. Run the full suite yourself before completing:

      docker compose -f compose.yml up -d postgres    # Vorbedingung
      pnpm exec playwright test

- **The completion metadata names `changed_files`, the tests added, the E2E
  journey covered, and what was deliberately left undone.**

### The commit hook, and why it is not the repo's own

`core.hooksPath` points at `.esf-hooks/`, installed by
`scripts/install-repo-hooks.sh` in the ESF directory. That hook lints **only
the staged files**; the `commit-msg` hook is taken over from `.husky/`
unchanged, because Conventional Commits is a real convention here.

The reason is **speed, not a broken linter** — and that correction matters,
because the first version of this section claimed the opposite:

- `biome ci .` on the baseline commit `e714f87`, in a tree without ESF
  worktrees, **exits 0** (78 warnings, 1 info). There was no upstream debt.
- It turned red only because the ESF itself created git worktrees under
  `.worktrees/`. `biome.json` sets `vcs.enabled: false`, so Biome ignores
  `.gitignore`, walks into the worktree, finds its `biome.json` and aborts with
  *nested root configuration*. Fixed by excluding `.worktrees` and
  `.esf-hooks` in `biome.json`.
- What genuinely could not stay in a per-commit hook is `pnpm run build`:
  minutes of work on every single commit.

So the ESF measures the **regression** at commit time — your lines — and keeps
the full proof where it belongs: once per merge, in `scripts/merge-riegel.sh`
(conflict check, staged-file lint, typecheck, unit tests, full E2E suite). That
script merges or refuses. **It is the only thing that may write to `main`.**
If it refuses, it is right; read the reason and fix the cause.

Do not reach for `--no-verify`. The first ESF commits used it on a false
premise and shipped a lint regression into `main` — a formatting error and two
undeclared env vars in `playwright.config.ts` — that the lean hook would have
caught. Fixed in `c9e0343`.

`.husky/` is left untouched. `scripts/install-repo-hooks.sh --remove` restores
the original state exactly.

### Two traps in this codebase that cost E2E authors an hour

- The password field's `<label for=…>` points at the wrapper `<div>`, not the
  `<input>`. `getByLabel("Password")` returns an element you cannot fill — use
  `input[name="password"]`.
- A freshly registered account lands on `/onboarding`, not `/dashboard`. It has
  no workspace yet. `tests/e2e/support/journey.ts` has helpers for both steps.

## Glossary

- **instance**: one deployed Kaneo installation.
- **workspace**: the top-level collaboration and authorization boundary.
- **project**: a task container inside a workspace.
- **role**: a workspace-scoped set of permission statements.
- **activity**: durable, user-visible history.
- **event**: an internal notification used by activity, integrations, notifications, or realtime updates.

Update this guide only for recurring, observed failure modes. Put narrow workflows in skills or dedicated documentation.
