# kanboard — Releases

Quelle: GitHub Releases API. 30 Releases geliefert, die neuesten 12 stehen unten.
Je Release sind die ersten 1200 Zeichen der Beschreibung übernommen; längere sind mit […] markiert.

## v1.2.53
Veröffentlicht: 2026-07-24T19:41:54Z
Titel: Kanboard 1.2.53


### Security fixes

- Scope restriction removal to the authorized project so a project manager can no longer delete restrictions belonging to other projects (`ProjectRoleRestrictionModel`, `ColumnRestrictionModel`, `ColumnMoveRestrictionModel`)
- Verify that a task belongs to the project before moving it with board drag and drop
- Validate the destination project in the task move/copy form to prevent reading metadata of inaccessible projects
- Restrict "remember me" session removal to the user that owns the session
- Validate `user_id` in subtask time tracking write methods
- Escape user-provided text in several templates: comment reply textarea, web notification titles, and the project name in the task links tooltip

### Improvements

- Add a per-user preference to make bare task search match titles, descriptions, and comments instead of titles only (title-only search remains the default)

### Bug fixes

- Fix the age indicator so items between 20 and 30 minutes old are labelled `<30m` instead of `<1h`
- Fix Markdown rendering of task links: text following a `#id` link at the start of a line is no longer swallowed
- Suppress PHP warnings triggered by hook calls 

[…]

## v1.2.52
Veröffentlicht: 2026-04-05T00:12:33Z
Titel: Kanboard 1.2.52

* Enforce comment visibility rules for public and unauthenticated users:
  * Restricted comments are no longer exposed in public task views.
  * Users cannot create comments with a visibility level higher than their role.
* Revoke public access tokens for inactive users.
* Use timing-safe comparisons (`hash_equals`) for API and webhook token validation to mitigate timing attacks.
* Replace raw SQL interpolation with parameterized queries in:
  * Task queries (`TaskFinderModel`)
  * iCalendar export conditions
* Validate task ownership in bulk operations:
  * Ensure tasks belong to the specified project before applying bulk changes.

## v1.2.51
Veröffentlicht: 2026-03-07T21:07:34Z
Titel: Kanboard 1.2.51

### Security fixes

- Add SSRF protection for webhook notifications with the new configuration option `WEBHOOK_ALLOW_PRIVATE_NETWORKS`
- Prevent unsafe deserialization in the database session handler
- Restrict invite signup input to expected fields only to prevent parameter injection
- Add missing permission checks in several API procedures
- Validate user external ID values
- Check file attachment ownership before deletion
- Prevent SSRF bypasses by controlling HTTP client redirect behavior

### Improvements

- Improve accessibility by increasing text/background contrast in the light theme

### Dependencies and build

- Upgrade PHPUnit to version 12
- Update several GitHub Actions and dependencies
- Update dependency `pimple/pimple` to version 3.6.2

## v1.2.50
Veröffentlicht: 2026-02-08T05:27:52Z
Titel: Kanboard 1.2.50

### Security Improvements

* Added missing authorization checks in multiple controllers.
* Enforced project-level authorization checks where they were missing.
* Improved plugin security by enforcing installer checks in `PluginController` actions.
* Enabled Parsedown safe mode to add an extra layer of protection to Markdown rendering against unsafe content.
* Added CSRF protection for project role changes and enforced JSON content type for related endpoints.

### Maintenance & Tooling

* Updated the PHPUnit version used for the test suite.
* Switched the GitHub workflow to use the `php-cs-fixer` Docker image instead of installing it via Composer.

### Dependencies

* Updated `pimple/pimple` from version 3.5.0 to 3.6.1.

## v1.2.49
Veröffentlicht: 2026-01-07T03:53:50Z
Titel: Kanboard 1.2.49

### Security

* Fixed an LDAP injection issue by properly escaping placeholders in LDAP queries.
* Prevented protocol-relative URLs (`//example.com`) from being used as login redirect targets.
* Added a new `TRUSTED_PROXY_NETWORKS` configuration option to explicitly define trusted reverse proxy networks.
* Introduced an optional security feature to block private network access when fetching external web links (configurable).

### Improvements

* Restored **Ctrl + Enter** keyboard shortcut for submitting the task creation form.
* Updated translations for multiple languages.

### Maintenance

* Added a GitHub Actions workflow to mirror the repository to Codeberg.
* Removed an outdated `tests/Dockerfile`.
* Regenerated Composer autoload files.

### Build & Dependencies

* Updated Alpine Linux base image from **3.22** to **3.23**.
* Updated GitHub Actions dependencies:

  * `actions/checkout` from v5 to v6
  * `actions/upload-artifact` from v4 → v5 → v6

## v1.2.48
Veröffentlicht: 2025-10-18T21:44:11Z
Titel: Kanboard 1.2.48

* fix: handle Windows-style paths in `sanitize_path` function
* feat(locale): added missing German translation phrases
* feat(locale): added Arabic translation
* feat(api): add board, rss and ical public links to the API response
* feat: display sub-tasks completion in numbers (x/y) alongside percentage
* feat: add basic support for right-to-left (RTL) languages
* chore: update .gitattributes to ignore additional configuration files
* build(deps): bump actions/setup-python from 5 to 6
* build(deps): bump actions/checkout from 4 to 5

## v1.2.47
Veröffentlicht: 2025-08-11T18:24:04Z
Titel: Kanboard 1.2.47

* refactor: add namespace to test files
* fix: the `$escape` parameter must be provided in PHP 8.4 for CSV functions
* fix: sanitize and validate uploaded files path
* fix: do not load `RememberMeAuth` provider when `REMEMBER_ME_AUTH` is `false`
* fix: avoid PHP warning when external user creation is disabled
* feat!: remove file cache driver to avoid using `unserialize()`
* feat!: ignore legacy events serialized with PHP due to potential security issues
* feat: add new actions: `TaskAssignCurrentUserColumnIfNoUserAlreadySet` and `TaskAssignToUserOnCreationInColumn`
* feat: Add new `pdf()` method in `Core\Http\Response`
* ci: run `php-cs-fixer` on GitHub Actions
* ci: remove unnecessary labels from issue templates
* chore: replace deprecated `gh-cli` feature source in devcontainer configuration

## v1.2.46
Veröffentlicht: 2025-06-22T21:31:00Z
Titel: Kanboard 1.2.46

* refactor: update return type in filter apply methods
* fix(security): prevent potential `Host` header injection via `SERVER_NAME`
   -  You must specify the Kanboard application URL explicitly to generate correct URLs from email notifications. The default is `http://localhost/`.
* fix: make various PHP 8.x compatibility changes
* fix: avoid `Implicitly nullable parameter declarations` errors in PHP 8.4
* feat: validate plugin archive URL before downloading
* feat: use PHP 8.4 in the official Docker image
* feat: show CAPTCHA on login form regardless of user existence
* feat: add new option to enable notifications by default for new users
* feat: add healthcheck endpoint `healthcheck.php`, and new Docker Compose files for MariaDB, Postgres, and SQLite
* feat: add `TRUSTED_PROXY_HEADERS` config option
    - If you use a reverse proxy, you can now specify which headers to trust for the client IP address. Nothing is trusted by default.
* docs: add `CONTRIBUTING.md` file
* ci(docker): avoid using `set-output` deprecated command
* chore!: PHP 8.1 is now the minimum version supported
    - **!! PHP 7.4 is no longer supported !!**
* chore: update `docker-compose.yml` samp

[…]

## v1.2.45
Veröffentlicht: 2025-05-23T02:09:05Z
Titel: Kanboard 1.2.45

* refactor: reuse existing helpers in tasks import form
* fix(filter): handle `null` input in the `Lexer` class
* fix(docker): legacy key/value format with whitespace separator should not be used
* fix(api): allow and validate creator ID assignment in task creation
* feat(routes): add `view` routes for project and task file browsing
* feat(locale): update all language files using machine translation
* feat(api): add priority fields to `createProject` and `updateProject` procedures
* feat: allow attaching screenshots and files when creating a task
* feat: add task title to overdue notification title
* ci: replace GitHub Issue Markdown templates with YAML forms
* ci: remove broken SQL Server unit tests pipeline
* ci: improve pull request template
* ci: add commit linter to validate conventional commit messages in pull requests

## v1.2.44
Veröffentlicht: 2025-03-21T23:39:49Z
Titel: Kanboard 1.2.44

* fix: prevent internal task titles from wrapping under the dropdown menu icon
* feat(locale): update Greek and French translations
* feat: display tag color squares next to their names in project and global settings
* feat: enable bulk addition/removal of internal links
* feat: provide an option to add tags without replacing existing ones during bulk operations

## v1.2.43
Veröffentlicht: 2024-12-18T22:33:48Z
Titel: Kanboard 1.2.43

* fix: verify the session hasn't expired before returning data
* fix: avoid PHP 8.4 deprecation notices in third-party libraries
* fix: avoid Composer warnings regarding PSR compatibility
* feat(locale): add missing Brazilian Portuguese translations
* ci: run GitHub Actions tests with `ubuntu-24.04`
* chore: don't `export-ignore` the ChangeLog
* build(deps): bump `symfony/service-contracts` from `2.5.3` to `2.5.4`
* build(deps): bump `symfony/event-dispatcher-contracts` from `2.5.3` to `2.5.4`
* build(deps): bump `symfony/deprecation-contracts` from `2.5.3` to `2.5.4`
* build(deps): bump `alpine` from `3.20` to `3.21`

## v1.2.42
Veröffentlicht: 2024-11-10T22:47:51Z
Titel: Kanboard 1.2.42

* fix: validate translation filename before loading locales
* fix: avoid path traversal in `FileStorage`
* feat: add Peruvian Sol to the list of currencies
* build(deps): bump `symfony/finder` from `5.4.43` to `5.4.45`
* build(deps-dev): bump `symfony/stopwatch` from `5.4.40` to `5.4.45`

