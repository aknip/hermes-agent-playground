# openproject — Releases

Quelle: GitHub Releases API. 30 Releases geliefert, die neuesten 12 stehen unten.
Je Release sind die ersten 1200 Zeichen der Beschreibung übernommen; längere sind mit […] markiert.

## v17.7.2
Veröffentlicht: 2026-08-13T12:25:20Z
Titel: OpenProject 17.7.2

Release date: 2026-08-13

We released [OpenProject 17.7.2](https://community.openproject.org/versions/2321).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
<!-- END SECURITY FIXES AUTOMATED SECTION -->
<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: The hourly rate cannot be adjusted for individual projects \[[#78111](https://community.openproject.org/wp/78111)\]
- Bugfix: Non-working days saved while reschedule job is running are not applied to work packages \[[#78219](https://community.openproject.org/wp/78219)\]
- Bugfix: Bubble with + in timeline view does not make sense \[[#78284](https://community.openproject.org/wp/78284)\]
- Bugfix: When using multiple seeded custom styles, most are lost \[[#78397](https://community.openproject.org/wp/78397)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->


## v17.7.1
Veröffentlicht: 2026-08-06T12:11:20Z
Titel: OpenProject 17.7.1

Release date: 2026-08-06

We released [OpenProject 17.7.1](https://community.openproject.org/versions/2318).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
<!-- END SECURITY FIXES AUTOMATED SECTION -->
<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: Retrying a stopped import creates duplicate OpenProject users \[[#78165](https://community.openproject.org/wp/78165)\]
- Bugfix: Jira attachment authors are not created as users \[[#78168](https://community.openproject.org/wp/78168)\]
- Bugfix: Resource management permissions not visible under Roles &gt; Administration \[[#78202](https://community.openproject.org/wp/78202)\]
- Bugfix: Wrong activation of project attributes in PIR \[[#78153](https://community.openproject.org/wp/78153)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->


## v17.7.0
Veröffentlicht: 2026-08-05T09:16:26Z
Titel: OpenProject 17.7.0

Release date: 2026-08-05

We released [OpenProject 17.7.0](https://community.openproject.org/versions/2304). The release contains several bug fixes and we recommend updating to the newest version. In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

## Important feature changes

OpenProject 17.7 introduces new resource management capabilities to help teams plan capacity and staffing more effectively. The release also brings major improvements to agile project management, wiki collaboration, and new features for project management with PM² or PMflex.

Take a look at our release video showing the most important features introduced in OpenProject 17.7:

[Release video of OpenProject 17.7](https://openproject-docs.s3.eu-central-1.amazonaws.com/videos/OpenProject_17_7_release.mp4)

### Organizational management

OpenProject 17.7 introduces new organizational management capabilities that provide the foundation for the new [Resource management module](#resource-management-module-enterprise-add-on). Departments, work-related user attributes, and individual work schedules help organizations re

[…]

## v17.6.0
Veröffentlicht: 2026-07-08T07:22:12Z
Titel: OpenProject 17.6.0

Release date: 2026-07-08

We released [OpenProject 17.6.0](https://community.openproject.org/versions/2298).
The release contains several bug fixes and we recommend updating to the newest version.
In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

## Important feature changes

OpenProject 17.6 continues our vision of providing a comprehensive open source platform for project management and collaboration. The new XWiki integration brings project management and enterprise knowledge management closer together, while further improvements for Backlogs, Meetings, and administration help teams plan, collaborate, and execute their work more efficiently.

Take a look at our release video showing the most important features introduced in OpenProject 17.6.0:

[Release video of OpenProject 17.6](https://openproject-docs.s3.eu-central-1.amazonaws.com/videos/OpenProject_17_6_release.mp4)

### XWiki integration (Enterprise add-on)



OpenProject 17.6 introduces a new integration with XWiki, enabling teams to connect project work and documentation more closely. Together, OpenProject and XWiki provi

[…]

## v17.5.1
Veröffentlicht: 2026-06-15T14:07:38Z
Titel: OpenProject 17.5.1

Release date: 2026-06-15

We released [OpenProject 17.5.1](https://community.openproject.org/versions/2303).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
<!-- END SECURITY FIXES AUTOMATED SECTION -->
<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: Capital letters in user email or login break import with error. \[[#75924](https://community.openproject.org/wp/75924)\]
- Bugfix: Page scrolls down to the bottom if user clicks on WP description when top of description is out of screen \[[#74186](https://community.openproject.org/wp/74186)\]
- Bugfix: Creation of new work packages and status transitions not possible aber upgrade to 17.5 \[[#75961](https://community.openproject.org/wp/75961)\]
- Bugfix: Renaming of projects causes AMPF sync to fail \[[#76022](https://community.openproject.org/wp/76022)\]
- Bugfix: Direct upload failing on SaaS since new prefix key is added \[[#75811](https://communit

[…]

## v17.5.0
Veröffentlicht: 2026-06-10T05:53:43Z
Titel: OpenProject 17.5.0

Release date: 2026-06-10

We released [OpenProject 17.5.0](https://community.openproject.org/versions/2293). The release contains several bug fixes and we recommend updating to the newest version. In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

## Important feature changes

Take a look at our release video showing the most important features introduced in OpenProject 17.5.0:

[Release video of OpenProject 17.5](https://openproject-docs.s3.eu-central-1.amazonaws.com/videos/OpenProject_17_5_release.mp4)

### Project-based work package identifiers for clearer references and Jira migrations

OpenProject 17.5 introduces **optional project-based work package identifiers in Beta**. Administrators can choose between the **default numerical sequence** and **project-based IDs** for the entire OpenProject instance.

> [!NOTE]
> The setting can be reverted later. Existing numerical IDs remain valid and continue to resolve to the same work packages throughout the application, including existing URLs, bookmarks, and references.

![Work package table for version 17.5 with highlighted project-ba

[…]

## v17.4.1
Veröffentlicht: 2026-06-08T08:05:04Z
Titel: OpenProject 17.4.1

Release date: 2026-06-08

We released [OpenProject 17.4.1](https://community.openproject.org/versions/2301).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
## Security fixes

### CVE-2026-47193 - Journal diff endpoint bypasses object, journal, and field visibility checks
This vulnerability was reported as part of the [YesWeHack.com OpenProject Bug Bounty program](https://yeswehack.com/programs/openproject), sponsored by the European Commission.

For more information, please see the [GitHub advisory #GHSA-f2rx-x2qj-2hgj](https://github.com/opf/openproject/security/advisories/GHSA-f2rx-x2qj-2hgj)

### CVE-2026-49355 - Private work package data disclosure through single meeting agenda item API
`GET /api/v3/meetings/:meeting_id/agenda_items/:agenda_item_id` discloses private work package data from a linked work package that belongs to a private/inaccessible project.

This vulnerability was reported as part of the [YesWeHack.com OpenProject Bug Bounty program](https://yeswehack.com/programs/openproject), sponsored by the European Comm

[…]

## v17.3.4
Veröffentlicht: 2026-06-08T13:31:43Z
Titel: OpenProject 17.3.4

Release date: 2026-06-08

We released [OpenProject 17.3.4](https://community.openproject.org/versions/2305).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
<!-- END SECURITY FIXES AUTOMATED SECTION -->
<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: Memcached serialization is broken in 17.3.3 \[[#75753](https://community.openproject.org/wp/75753)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->


## v17.3.3
Veröffentlicht: 2026-06-08T08:00:28Z
Titel: OpenProject 17.3.3

Release date: 2026-06-08

We released [OpenProject 17.3.3](https://community.openproject.org/versions/2299).
The release contains several bug fixes and we recommend updating to the newest version.
Below you will find a complete list of all changes and bug fixes.
<!-- BEGIN SECURITY FIXES AUTOMATED SECTION -->
## Security fixes

### CVE-2026-47193 - Journal diff endpoint bypasses object, journal, and field visibility checks
This vulnerability was reported as part of the [YesWeHack.com OpenProject Bug Bounty program](https://yeswehack.com/programs/openproject), sponsored by the European Commission.

For more information, please see the [GitHub advisory #GHSA-f2rx-x2qj-2hgj](https://github.com/opf/openproject/security/advisories/GHSA-f2rx-x2qj-2hgj)

### GHSA-3vpx-94qx-xpw6 - IDOR through /projects/<A>/settings/project_storages/<A_ps_id> via PATCH parameter "storages_project_storage[project_folder_id]" leads to Access to Unauthorized Resources
A project-admin in one project can hijack the managed Nextcloud or OneDrive folder of another project on the same storage by writing the victim project&#39;s `project_folder_id` into the attacker&#39;s `Storages::ProjectStorage` row. The next ma

[…]

## v17.4.0
Veröffentlicht: 2026-05-13T06:47:05Z
Titel: OpenProject 17.4.0

Release date: 2026-04-23

 We released [OpenProject 17.4.0](https://community.openproject.org/versions/2267). The release contains several bug fixes and we recommend updating to the newest version. In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

<!-- BEGIN CVE AUTOMATED SECTION -->

## Security fixes



### GHSA-r85r-gjq2-f83r - Docker Container starts with SECRET_KEY_BASE default value

When an attacker knew the secret key base that the application used to derive internal keys from, they could construct encrypted cookies that on the server side were decoded using [Object Marshalling](https://docs.ruby-lang.org/en/4.0/Marshal.html) which allowed the attacker to execute almost arbitrary ruby code within the container, up to a complete remote code execution. This was especially present in Docker containers that shipped with a default value as the secret key base, when it was not manually overwritten, as mentioned in the documentation.



As a fix, the docker containers now validate that a proper `SECRET_KEY_BASE` environment variable is set Otherwise the application aborts the boot

[…]

## v17.3.2
Veröffentlicht: 2026-05-13T05:19:52Z
Titel: OpenProject 17.3.2

Release date: 2026-05-13

 We released [OpenProject 17.3.2](https://community.openproject.org/versions/2296).
 The release contains several bug fixes and we recommend updating to the newest version.
 Below you will find a complete list of all changes and bug fixes.

<!-- BEGIN CVE AUTOMATED SECTION -->

## Security fixes



### GHSA-r85r-gjq2-f83r - Docker Container starts with SECRET_KEY_BASE default value

When an attacker knew the secret key base that the application used to derive internal keys from, they could construct encrypted cookies that on the server side were decoded using [Object Marshalling](https://docs.ruby-lang.org/en/4.0/Marshal.html) which allowed the attacker to execute almost arbitrary ruby code within the container, up to a complete remote code execution. This was especially present in Docker containers that shipped with a default value as the secret key base, when it was not manually overwritten, as mentioned in the documentation.



As a fix, the docker containers now validate that a proper `SECRET_KEY_BASE` environment variable is set Otherwise the application aborts the boot process with an error message. The documentation has been updated to make it even 

[…]

## v17.2.4
Veröffentlicht: 2026-05-13T05:09:21Z
Titel: OpenProject 17.2.4

Release date: 2026-05-13

 We released [OpenProject 17.2.4](https://community.openproject.org/versions/2300).
 The release contains several bug fixes and we recommend updating to the newest version.
 Below you will find a complete list of all changes and bug fixes.

<!-- BEGIN CVE AUTOMATED SECTION -->

## Security fixes



### GHSA-r85r-gjq2-f83r - Docker Container starts with SECRET_KEY_BASE default value

When an attacker knew the secret key base that the application used to derive internal keys from, they could construct encrypted cookies that on the server side were decoded using [Object Marshalling](https://docs.ruby-lang.org/en/4.0/Marshal.html) which allowed the attacker to execute almost arbitrary ruby code within the container, up to a complete remote code execution. This was especially present in Docker containers that shipped with a default value as the secret key base, when it was not manually overwritten, as mentioned in the documentation.



As a fix, the docker containers now validate that a proper `SECRET_KEY_BASE` environment variable is set Otherwise the application aborts the boot process with an error message. The documentation has been updated to make it even 

[…]

