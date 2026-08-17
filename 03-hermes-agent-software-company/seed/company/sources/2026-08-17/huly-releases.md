# huly — Releases

Quelle: GitHub Releases API. 30 Releases geliefert, die neuesten 12 stehen unten.
Je Release sind die ersten 1200 Zeichen der Beschreibung übernommen; längere sind mit […] markiert.

## v0.7.426
Veröffentlicht: 2026-07-05T03:43:54Z
Titel: v0.7.426

## Cards & Attributes
 
* Add readonly support to MarkupEditor and improve hierarchy-based attributes by @BykhovDenis in https://github.com/hcengineering/platform/pull/10835
* Fix markup check by @BykhovDenis in https://github.com/hcengineering/platform/pull/10836
* Fix main section lock by @BykhovDenis in https://github.com/hcengineering/platform/pull/10837
* Nested view setting by @BykhovDenis in https://github.com/hcengineering/platform/pull/10838
* Card version settings by @BykhovDenis in https://github.com/hcengineering/platform/pull/10843
* Fix relation versioning setting by @BykhovDenis in https://github.com/hcengineering/platform/pull/10844
* Fix enum presenter readonly by @BykhovDenis in https://github.com/hcengineering/platform/pull/10846
* Id override by @BykhovDenis in https://github.com/hcengineering/platform/pull/10847
* Fix tag attribute lock by @BykhovDenis in https://github.com/hcengineering/platform/pull/10850
* Support images in markup properties by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10882
* Fix markup field in md table by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10840
* Required attributes by

[…]

## v0.7.423
Veröffentlicht: 2026-05-10T03:53:50Z
Titel: v0.7.423

# Release v0.7.423

Release highlights compared to [v0.7.413…v0.7.423](https://github.com/hcengineering/platform/compare/v0.7.413...v0.7.423).

---

## What's Changed

### Cards, processes, associations & automation

Card modeling, process steps, relations, and automation visibility — the bulk of this release’s feature work.

- **Card grid** — grid layout for cards — [#10749](https://github.com/hcengineering/platform/pull/10749) (@BykhovDenis)
- **Card space type selector** — submenu for choosing card space types — [#10750](https://github.com/hcengineering/platform/pull/10750) (@BykhovDenis)
- **EmptyValue process function** — process pipeline helper for empty values — [#10756](https://github.com/hcengineering/platform/pull/10756) (@BykhovDenis)
- **Min / max transformation functions** — numeric transforms in processes — [#10782](https://github.com/hcengineering/platform/pull/10782) (@BykhovDenis)
- **Execution cleanup trigger** — removes associated execution data when a card is removed — [#10795](https://github.com/hcengineering/platform/pull/10795) (@BykhovDenis)
- **Markup properties** — markup-related property handling — [#10804](https://github.com/hcengineerin

[…]

## v0.7.413
Veröffentlicht: 2026-04-14T01:05:37Z
Titel: v0.7.413

## What's Changed

### Bug fixes
* Fix applications customization ([#10755](https://github.com/hcengineering/platform/issues/10755))
* Fix controlled documents print ([#10763](https://github.com/hcengineering/platform/pull/10763)) 
* Update Slack link ([#10754](https://github.com/hcengineering/platform/issues/10754))

**Full Changelog**: https://github.com/hcengineering/platform/compare/v0.7.411...v0.7.413

## v0.7.411
Veröffentlicht: 2026-04-12T09:01:18Z
Titel: v0.7.411

## What's Changed

### Authentication
* Two-Factor Authentication (2FA) by @BykhovDenis in https://github.com/hcengineering/platform/pull/10658
* Email-confirmed password setup for SSO accounts by @dnplkndll in https://github.com/hcengineering/platform/pull/10649

### Guests access
* Add ability to configure guest permissions by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10708, https://github.com/hcengineering/platform/pull/10726
* Allow to configure guest auto-join by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10751

### Cards and processes
* Add new process functions for data type conversion, including s… by @BykhovDenis in https://github.com/hcengineering/platform/pull/10670
* Add configurable card layout modes by @BykhovDenis in https://github.com/hcengineering/platform/pull/10724
* Add automationOnly flag to associations and restrict manual change by @BykhovDenis in https://github.com/hcengineering/platform/pull/10730
* Add my cards section by @BykhovDenis in https://github.com/hcengineering/platform/pull/10604

### Editor
* Add highlight, subscript, superscript and mathematics toolbar actions by @ComputerCrack i

[…]

## v0.7.382
Veröffentlicht: 2026-03-02T05:41:17Z
Titel: v0.7.382

## What's Changed

### Card and processes
- Automation only processes by @BykhovDenis in https://github.com/hcengineering/platform/pull/10548
- Time service by @BykhovDenis in https://github.com/hcengineering/platform/pull/10546
- Implement field locking and unlocking functionality by @BykhovDenis in https://github.com/hcengineering/platform/pull/10573
- Add ability to revert document updates in processes by @BykhovDenis in https://github.com/hcengineering/platform/pull/10572

### Invite settings
- Configure who should be able to send invitation link by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10555


### Bug fixes
* fix: embed html instead of showing in iframe by @aonnikov in https://github.com/hcengineering/platform/pull/10549
* Fix fieldChangesCheck by @BykhovDenis in https://github.com/hcengineering/platform/pull/10550
* Fix missing enum when export type by @BykhovDenis in https://github.com/hcengineering/platform/pull/10551
* fix(account): handle empty $in array to prevent PostgreSQL IN () syntax error by @spatialy in https://github.com/hcengineering/platform/pull/10554
* Add ability to sort projects and hide archived by @ArtyomSavche

[…]

## v0.7.375
Veröffentlicht: 2026-02-23T04:37:31Z
Titel: v0.7.375

## What's Changed

### Internationalization
- Add Brazilian Portuguese translation by @ArtyomSavchenko and @CuriousFurBytes in https://github.com/hcengineering/platform/pull/10478, https://github.com/hcengineering/platform/pull/10522
- Enable Turkish translation by @Bahadir67 in https://github.com/hcengineering/platform/pull/10441

### Cards and processes
- Approve requests by @BykhovDenis in https://github.com/hcengineering/platform/pull/10486
- Add unlock card and section functionality with UI updates by @BykhovDenis in https://github.com/hcengineering/platform/pull/10492
- Implemented process import/export, improved process execution flow, and added CancelSubProcess action by @BykhovDenis in https://github.com/hcengineering/platform/pull/10528,  https://github.com/hcengineering/platform/pull/10530


### Controlled docs
- Added an activity section for controlled documents by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10457
- Improve controlled documents export from one workspace to another by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10465.

### Workspace invites & login
- Redesigned workspace join flow by @ArtyomS

[…]

## v0.7.353
Veröffentlicht: 2026-01-25T01:58:24Z
Titel: v0.7.353

## What's Changed

## Improvements:
* Link preview service by @aonnikov in https://github.com/hcengineering/platform/pull/10424
* Allow guest update profile (avatar, name etc) by @kristina-fefelova in https://github.com/hcengineering/platform/pull/10429
* Support PostgreSQL for telegram-bot by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10435
* Display space for controlled document templates by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10426

## Bug fixes:
* Minor process fixes by @BykhovDenis in https://github.com/hcengineering/platform/pull/10416
* Fix size predicate null handle by @BykhovDenis in https://github.com/hcengineering/platform/pull/10417
* Fix long title display by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10418
* Fix: sort qms templates in wizard by @aonnikov in https://github.com/hcengineering/platform/pull/10419
* Move metadata comment to the end by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10421
* Fix original table layout by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10427
* Add confirmation modal for table refresh by @ArtyomSav

[…]

## v0.7.350
Veröffentlicht: 2026-01-19T04:50:42Z
Titel: v0.7.350

## What's Changed

### Improvements:
* Print workspace logo in PDF (https://github.com/hcengineering/platform/pull/10407)
* Ability to copy documents as markdown table (beta) (https://github.com/hcengineering/platform/pull/10397)

### Bug fixes:
* Process service should ignore config user (https://github.com/hcengineering/platform/pull/10399)
* Fix accounts service retries (https://github.com/hcengineering/platform/pull/10400)
* Fix card export (https://github.com/hcengineering/platform/pull/10403)
* Fix card view settings (https://github.com/hcengineering/platform/pull/10404)
* Customize support links (https://github.com/hcengineering/platform/pull/10405)
* Fix controlled doc sequence conflicts (https://github.com/hcengineering/platform/pull/10406)
* Remove beta marks for cards and processes (https://github.com/hcengineering/platform/pull/10408)
* Fix default null value (https://github.com/hcengineering/platform/pull/10409)
* Fix view setting freeze (https://github.com/hcengineering/platform/pull/10410)
* Show custom icons for cards breadcrumbs (https://github.com/hcengineering/platform/pull/10412)
* Filter relations by workspaceId (https://github.com/hcengineerin

[…]

## v0.7.344
Veröffentlicht: 2026-01-13T01:44:52Z
Titel: v0.7.344

## What's Changed

### Improvements
* Add type/tag permissions by @BykhovDenis in https://github.com/hcengineering/platform/pull/10384
* Show doc attrs and collaborators for cards by @BykhovDenis in https://github.com/hcengineering/platform/pull/10390
* Sort controlled documents by rank and title by @aonnikov in https://github.com/hcengineering/platform/pull/10383

### Bug fixes
* Fix card type export by @BykhovDenis in https://github.com/hcengineering/platform/pull/10385
* Fix old card UI by @BykhovDenis in https://github.com/hcengineering/platform/pull/10386
* Hide processes if not exists by @BykhovDenis in https://github.com/hcengineering/platform/pull/10387
* Fix exporter ancestor order by @BykhovDenis in https://github.com/hcengineering/platform/pull/10388
* Enhance ObjectBoxPopup to handle category presentation by @BykhovDenis in https://github.com/hcengineering/platform/pull/10389
* Show doc attrs and collaborators for cards by @BykhovDenis in https://github.com/hcengineering/platform/pull/10390
* Fix card activity by @BykhovDenis in https://github.com/hcengineering/platform/pull/10393
* Fix email notifications by @ArtyomSavchenko in https://github.com/hcengin

[…]

## v0.7.342
Veröffentlicht: 2026-01-11T02:59:17Z
Titel: v0.7.342

## What's Changed

### eQMS Features
- **Traceability matrices** — Create and manage traceability matrices for quality management([PR #10286](https://github.com/hcengineering/platform/pull/10286))
- **Workspace document export** — Export documents from one workspace to another([PR #10283](https://github.com/hcengineering/platform/pull/10283))

### Cards and Processes Improvements
- **RBAC and enhanced security** — Improved role-based access control and security features([PR #10384](https://github.com/hcengineering/platform/pull/10384), [PR #10314](https://github.com/hcengineering/platform/pull/10314))
- **Card versioning** — Track and manage versions of cards([PR #10336](https://github.com/hcengineering/platform/pull/10336))

### Security Improvements
- **Password aging** — Enhanced password policy with aging requirements([PR #10287](https://github.com/hcengineering/platform/pull/10287))

### Infrastructure Improvements
- **PostgreSQL support** — Added support for PostgreSQL database([PR #10331](https://github.com/hcengineering/platform/pull/10331))

### Bug Fixes
- Fixed workspace access for guest users
- Fixed collaborator refresh after object changes
- Fixed p

[…]

## v0.7.314
Veröffentlicht: 2025-12-05T00:45:16Z
Titel: v0.7.314

## What's Changed

**Bugs fixes:**
* Fix attribute permissions for restricted spaces by @BykhovDenis in https://github.com/hcengineering/platform/pull/10269
* Fix process user input popup by @BykhovDenis in https://github.com/hcengineering/platform/pull/10274
* Fix gmail messages duplication by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10277
* Fix: do not remember project version by @aonnikov in https://github.com/hcengineering/platform/pull/10276
* Fix: revert document patches by @aonnikov in https://github.com/hcengineering/platform/pull/10278

**Documentation improvement:**
* Add architecture overview and versions description in Readme by @ArtyomSavchenko in https://github.com/hcengineering/platform/pull/10271

**Full Changelog**: https://github.com/hcengineering/platform/compare/v0.7.313...v0.7.314

## v0.7.313
Veröffentlicht: 2025-12-03T08:08:40Z
Titel: v0.7.313

## What's Changed
**Card and processes improvements:**
* Ability to duplicate a card by @BykhovDenis in https://github.com/hcengineering/platform/pull/10245
* Clear filters for card by @BykhovDenis in https://github.com/hcengineering/platform/pull/10246
* Improve cards permissions by @BykhovDenis in https://github.com/hcengineering/platform/pull/10260
* Process buttons by @BykhovDenis in https://github.com/hcengineering/platform/pull/10262
* Strict RBAC for spaces by @BykhovDenis in https://github.com/hcengineering/platform/pull/10261
* Hide removed types from selector by @BykhovDenis in https://github.com/hcengineering/platform/pull/10266

**Controlled documents improvements**
* Product and document patch versions by @aonnikov in https://github.com/hcengineering/platform/pull/10265

**UI improvements:**
* Improve performance for separator by @haiodo in https://github.com/hcengineering/platform/pull/10258


**Bug fixes:**
* Fix PDF print for documents by @aonnikov in https://github.com/hcengineering/platform/pull/10270
* Fix every time compacting and put images back to backup by @haiodo in https://github.com/hcengineering/platform/pull/10257
* Fix domain not foun

[…]

