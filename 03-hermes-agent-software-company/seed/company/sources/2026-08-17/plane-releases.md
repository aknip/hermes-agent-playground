# plane — Releases

Quelle: GitHub Releases API. 30 Releases geliefert, die neuesten 12 stehen unten.
Je Release sind die ersten 1200 Zeichen der Beschreibung übernommen; längere sind mit […] markiert.

## v1.4.1
Veröffentlicht: 2026-08-07T10:10:59Z
Titel: v1.4.1

### ✨  Features

#### **Workspace Member Reactivation Command**

Self-hosted administrators can now restore a deactivated workspace member straight from the command line, without editing the database by hand. Running `reactivate_workspace_member <workspace-slug> <email>` re-enables the membership and reports the role the member is restored to.

- Validates the workspace, the user, and the existing membership before changing anything, with a clear error when any of them is missing
- Safe to re-run — an already-active member is reported as such instead of failing
- Keeps audit fields intact by limiting the write to the membership's active state

### ⬆️  Enhancements

- The workspace-level modules list now returns the member IDs for each module, so module members and member-based filters render correctly on the workspace modules view.
- Work item layouts are now wrapped in an error boundary. If a single layout fails to render, it degrades to a local "Something went wrong" message with a Retry button instead of taking down the whole page.

### 🐞  Bug fixes

- Fixed notifications failing to load on self-hosted deployments, where a missing trailing slash on the notificat

[…]

## v1.4.1-rc2
Veröffentlicht: 2026-08-05T10:11:02Z
Titel: v1.4.1-rc2

## What's Changed
* fix: enforce FILE_SIZE_LIMIT on published Space asset upload by @sriramveeraghanta in https://github.com/makeplane/plane/pull/9242
* fix(web): guard unguarded data derefs causing work-item and layout crashes by @codingwolf-at in https://github.com/makeplane/plane/pull/9546
* chore: resolve dependabot security alerts (pnpm + pip) by @sriramveeraghanta in https://github.com/makeplane/plane/pull/9549


**Full Changelog**: https://github.com/makeplane/plane/compare/v1.4.1-rc1...v1.4.1-rc2

## v1.4.1-rc1
Veröffentlicht: 2026-08-04T14:36:35Z
Titel: v1.4.1-rc1

## What's Changed
* fix: strip control characters from sanitized filenames by @karthiksuki in https://github.com/makeplane/plane/pull/9151
* [SECUR-242] fix(api): scope bulk-asset associate by uploader, not project_id (regression from #9288) by @mguptahub in https://github.com/makeplane/plane/pull/9495
* [GIT-243]fix: InstanceConfiguration not created for some keys by @sangeethailango in https://github.com/makeplane/plane/pull/9303
* chore: retire departed code owners (apps/live, ox configs) by @mguptahub in https://github.com/makeplane/plane/pull/9504
* [INFRA-461] chore: bump nginx to 1.31-alpine in web and admin Dockerfiles by @akshat5302 in https://github.com/makeplane/plane/pull/9490
* chore: upgrade Django 4.2 → 5.2 by @sriramveeraghanta in https://github.com/makeplane/plane/pull/9325
* fix: resolve open CodeQL security alerts by @sriramveeraghanta in https://github.com/makeplane/plane/pull/9505
* fix: resolve React Doctor errors and restore its PR baseline by @sriramveeraghanta in https://github.com/makeplane/plane/pull/9488
* [WEB-8477] fix: created_at/updated_at filters return no work items by @mguptahub in https://github.com/makeplane/plane/pull/9513
* fix: cast avatar_as

[…]

## v1.4.0
Veröffentlicht: 2026-07-31T12:29:41Z
Titel: v1.4.0

### ✨  Features

#### **Lite List Endpoints in the REST API**

New lightweight list endpoints for projects, members, cycles, and modules return trimmed payloads built for pickers, dropdowns, and sync jobs that only need identifiers and display fields. They avoid the cost of the full list responses when you are populating a selector or mirroring structure into an external system, and they carry the same `order_by` sanitization and scoping guarantees as the full endpoints.

#### **Feature-Namespaced Translations**

The internationalization package now runs on `react-i18next` with translations stored as per-feature JSON namespaces (workspace, project, work item, cycle, intake, and more) instead of a single monolithic TypeScript file. Translators and contributors can work on one feature area at a time across all 19 supported languages, and the public translation API is unchanged, so no consumer code needed to move.

### ⬆️  Enhancements

- Webhook delivery payloads now include `workspace_slug`, so receivers can route events without an extra lookup.
- Self-hosted telemetry now reports through OTLP metrics instead of OTLP traces, giving instance operators cleaner gauges for 

[…]

## v1.4.0-rc2
Veröffentlicht: 2026-07-29T06:52:04Z
Titel: v1.4.0-rc2

## What's Changed
* fix: strip control characters from sanitized filenames by @karthiksuki in https://github.com/makeplane/plane/pull/9151
* [SECUR-242] fix(api): scope bulk-asset associate by uploader, not project_id (regression from #9288) by @mguptahub in https://github.com/makeplane/plane/pull/9495
* v1.4.0-fixes by @mguptahub in https://github.com/makeplane/plane/pull/9496


**Full Changelog**: https://github.com/makeplane/plane/compare/v1.4.0-rc1...v1.4.0-rc2

## v1.4.0-rc1
Veröffentlicht: 2026-07-29T05:33:32Z
Titel: v1.4.0-rc1

## What's Changed
* release: v1.2.1 by @sriramveeraghanta in https://github.com/makeplane/plane/pull/8322
* release: v1.2.2 by @sriramveeraghanta in https://github.com/makeplane/plane/pull/8645
* release: v1.2.3 by @sriramveeraghanta in https://github.com/makeplane/plane/pull/8717
* [WIKI-874] refactor: description input component by @aaryan610 in https://github.com/makeplane/plane/pull/8544
* chore(deps): bump python-json-logger from 3.3.0 to 4.0.0 in /apps/api by @dependabot[bot] in https://github.com/makeplane/plane/pull/8692
* chore(deps): bump pytest from 7.4.0 to 9.0.2 in /apps/api by @dependabot[bot] in https://github.com/makeplane/plane/pull/8693
* [WEB-6599] feat: instance not ready ui revamp by @anmolsinghbhatia in https://github.com/makeplane/plane/pull/8755
* [WEB-6610] Fix work item drag handle hover gap by @iam-vipin in https://github.com/makeplane/plane/pull/8759
* chore(deps): bump the actions group across 1 directory with 11 updates by @dependabot[bot] in https://github.com/makeplane/plane/pull/8741
* fix: added workspace member check in allow permission for creator by @NarayanBavisetti in https://github.com/makeplane/plane/pull/8778
* fix: unused imports by @srira

[…]

## v1.3.1
Veröffentlicht: 2026-05-14T20:16:06Z
Titel: v1.3.1

## ✨ Improvements

- **Scrollbar in keyboard shortcuts modal**
- **Skip role & use-case steps for self-hosted instances**

## 🐛 Bug Fixes

- **Prevent ORM field injection via analytics segment parameter** —
  Security fix (GHSA-93x3-ghh7-72j3). Centralizes analytics field allowlists into `VALID_ANALYTICS_FIELDS` / `VALID_YAXIS` and adds defense-in-depth validation in `build_graph_plot()` and `extract_axis()` so no caller can pass arbitrary field references to Django `F()` expressions. Also adds missing segment validation to `SavedAnalyticEndpoint`.
- **Enforce workspace membership on V2 asset endpoints** —
  Security fix (GHSA-qw87-v5w3-6vxx). Adds `@allow_permission` to all `WorkspaceFileAssetEndpoint` methods and scopes `DuplicateAssetEndpoint`'s source asset lookup to workspaces where the caller is an active member.
- **Sanitize filenames in upload paths to prevent path traversal** — 
  Security fix (GHSA-v57h-5999-w7xp). Server-side filename sanitization across all file upload endpoints; defense-in-depth against S3 key pollution. Handles Windows-style paths and leading-dot/whitespace edge cases.
- **Replace `IS_SELF_MANAGED` toggle with `WEBHOOK_ALLOWED_IPS` allowl

[…]

## v1.3.0
Veröffentlicht: 2026-04-06T14:36:47Z
Titel: v1.3.0

### **A cleaner, calmer Plane**
<img width="889" height="500" alt="image" src="https://github.com/user-attachments/assets/0aa129bc-055a-4490-93bc-1ba50beb08fb" />


We sharpened the visual foundation of Plane so your workspace feels more composed and intentional. Spacing is tuned to guide the eye, colors work harder to signal meaning, and themes feel cohesive from one view to the next. The result is a product that reads clearly, responds predictably, and makes it easier to stay in flow as your work scales.

### 🎉 Improvements

- Added support for Gitea Authentication.
- Enhanced `CustomSelect` with better dropdown context handling.
- Enhanced authentication logging with more detailed error reporting.
- Added Project Summary external API support.
- Added debounce support for mention search.
- Improved UI for workspace settings layout and members page.
- Enhanced workspace members settings UI/UX.
- Improved work item detail, list layout, sidebar, and comment UI.
- Updated work item detail properties UI.
- Added timezone selection to workspace settings, project timezon will default to workspace timezone during creation.
- Revamped the instance-not-ready UI screen.
-

[…]

## v1.2.3
Veröffentlicht: 2026-03-05T12:51:52Z
Titel: v1.2.3

### 🛡️ Security
- Added validation while saving webhooks with reserver IP addresses

## v1.2.2
Veröffentlicht: 2026-02-23T08:54:08Z
Titel: v1.2.2

### Security patch

- Fixed arbitrary modification of API token rate limits by enforcing server-side validation and authorization checks.
- Mitigated SSRF vulnerability in work item link handling through strict URL validation and outbound request controls.
- Fixed member information disclosure via publicly accessible endpoint by applying proper access control checks.
- Resolved IDOR vulnerabilities in asset and attachment endpoints to prevent unauthorized resource access.
- Upgraded Django to 4.2.28
- Upgraded the cryptography to 46.0.5

## v1.2.1
Veröffentlicht: 2025-12-12T11:13:02Z
Titel: v1.2.1

### 🛡️  Security

- Removed underlying NextJS dependencies. 

## v1.2.0
Veröffentlicht: 2025-12-11T14:57:34Z
Titel: v1.2.0

### ✨  Features

#### **Next.js to React Router + Vite Migration**

React Router + Vite now power all Plane web applications, replacing Next.js. The new stack brings faster hot reloads, clearer internals, and a consistent tooling workflow across builds and tests. [Here](https://plane.so/blog/why-did-we-migrate-plane-from-nextjs-to-react-router-vite) is a blog post about the same.

#### **Introducing a new way to navigate across your workspace**

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/71125591-b591-48ed-a9cf-e3b56c821610" />
You'll now find a new navigation bar at the top of your Plane workspace. `Search` and `Inbox` have moved to the top bar so they work globally across your workspace. Project features like Cycles, Modules, Epics, and Pages now live inside the project as clean horizontal tabs instead of expanding in the sidebar. You can also collapse the left nav, switch to icon-only mode, and choose which projects appear, keeping navigation focused and customizable.

The result: faster movement across Plane, less visual noise, and a layout that stays manageable even with hundreds of projects.

#### **Power K, superc

[…]

