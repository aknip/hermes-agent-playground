# linear changelog

Quelle: HTML-Seite, auf sichtbaren Text reduziert (Skripte, Styles und
Auszeichnung entfernt). Roh waren es 1728843 Byte.

Changelog – Linear
Skip to content →
Product
Resources
Customers
Pricing
Now
Contact
Docs
Open app
Log in
Sign up
Now
All    Changelog    Product launches    From the team    From the community    Press
Search…
August 13, 2026
Team initiatives
Initiatives are Linear’s way to manage product strategy and high-level planning across projects. Strategy may start at the company level, but teams carry it forward. You can now assign a team to lead an initiative, making it clear who is responsible for driving the work and how it contributes to the broader direction.
For work that requires tighter access, initiatives led by private teams are only visible to team members. This creates a secure place for confidential planning, regulated projects, audits, and other restricted work.
Learn more about initiatives in the  docs .
Enterprise-managed authorization for MCP   ⁠
Linear’s MCP now supports managing employee access through your existing Okta-managed identity.
When employees connect from a supported Anthropic agent, Linear verifies their identity through Okta and applies their existing Linear permissions. Admins can manage access centrally, without requiring employees to sign in or authorize Linear individually.
Available to Enterprise workspaces with Okta SAML configured. Learn more in the  docs .
Fixes
Agent
Fixed agent sometimes not showing a progress indicator
Agent
Fixed Linear Agent sometimes claiming a Slack thread synced when it did not
Comments
Prevented document comment threads from shifting away from their referenced text when content changes size
Cycles
Fixed new cycle names with quarter or half-year labels not incrementing correctly
Cycles
Fixed fast issue creation while viewing completed cycles
Diffs
Fixed code review discussions crashing when a file path is missing
Diffs
Fixed comment links not opening the associated thread
Diffs
Fixed authored pull requests appearing in “To review” after commenting
Diffs
Fixed closing an already-closed GitHub pull request failing to remove it from review lists
Diffs
Fixed stale PR Guides not refreshing after a pull request update
Editor
Added support for comments on Mermaid diagrams
GitHub
Fixed closing an abandoned draft pull request changing the status of an issue already marked Done or Canceled
GitLab
Fixed merge requests from deleted users failing to process
Integrations
Fixed disconnecting a personal Notion account opening Notion instead of removing the connection
Integrations
Renaming an OAuth application now updates the name shown in the activity of issues it creates
Issues
Fixed imported recurring issues missing their recurring-series link in issue history
Issues
Fixed drag-and-drop for sub-issues in views sorted by status, title, or due date
Issues
Fixed “Copy as” prompt copying a parent issue instead of the selected sub-issue
Notifications
Fixed duplicate notifications for GitHub review requests
Notifications
Fixed members being unable to disable Slack alerts for shared custom views
Projects
Fixed blocking and blocked-by relationships appearing in the wrong direction in project activity
Projects
Fixed project and initiative update reminders being sent when an update was already posted on the previous business day
Search
Improved exact user name matches in search results
Triage
Added GitHub usernames to GitHub-sourced issues in triage
Improvements
Agent
Linear Agent can now update releases
Billing
Added the ability to remove a previously set tax ID
Coding sessions
Added GPT-5.6 Luna as a model option
Cycles
Added an explanation of cycle success to the tooltip
Diffs
Added a branch-status widget showing whether a branch is up to date, behind, or has conflicts
Diffs
Grouped agent and bot review comments under Agents & Bots
Diffs
Made structural diff highlighting the default
Diffs
Showed merge-queue time on pull request hover
Editor
Added support for mentioning pull requests from the editor mention picker
Editor
Pressing  Enter  at the end of an issue or document title now starts a new line at the top of the content below it
Git
Updated  relates to  and  related to  magic words to mark pull requests as related rather than contributing
Importer
Added an option to skip workspace-level labels and templates during Linear-to-Linear imports
Integrations
Improved the channel connection labels across Slack and Microsoft Teams menus
IOS
We now indicate progress while importing photo library attachments for comments
Loops
Made the  Disabled  badge interactive so loops can be re-enabled directly
Projects
Added project milestone agent widgets on iOS
API
Added  subscribers  field on  Document
Added a subscription for user settings updates
Keyboard shortcuts
Teams
Fixed  Ctrl  Shift  1–9  shortcuts for opening team home pages
July 30, 2026
Coding sessions on mobile
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Your coding session doesn’t have to stop when you leave your desk. Use the Linear mobile app to review code changes, comment on specific lines, and iterate with Linear Agent.
Open any diff and switch to the Changes tab to inspect the code. When you spot something to change, tap the relevant line to add it to your message to steer the coding session in the direction you want.
We’ve also added section under My Issues → Assigned for your delegated issues. It shows the status of each coding session, and gives you a quick way back into active work.
Download the Linear mobile app for  iOS  and  Android .
Guided Reviews are now generally available  ⁠
Guided Reviews  break diffs into focused sections with explainers on what changed and why. As part of general availability, they are now generated for larger pull requests, with a bigger context window and better latency.
Guided Reviews are available on Business and Enterprise plans at no additional cost.
Support for GitHub teams in reviews  ⁠
You can now assign reviews to GitHub teams. Review requests assigned to your GitHub teams appear in a dedicated section of the Reviews inbox. Learn more in the  docs .
Signed commits for coding sessions  ⁠
Coding sessions now support signed commits. Add your SSH or GPG key in  Settings  to enable signing.
Workspace admins can also require users to upload a signing key before using coding sessions.
GitHub Copilot for Linear  ⁠
GitHub Copilot users can assign issues directly to Copilot’s cloud agent from Linear. Copilot uses the issue context to work in its own development environment, open draft pull requests, and update the issue as it makes progress.
Choose model and agent settings, set the base and working branches, then steer ongoing work through comments in Linear. To get started, install  GitHub Copilot for Linear , or read the  GitHub announcement  for more details.
Fixes
Agents
Queued agent messages now display readable text in previews instead of raw markup
API
Fixed issue SLA sort to order by the displayed SLA bucket (Breached / High / Medium / Low / Achieved / Failed) instead of raw  slaBreachesAt , so mobile lists no longer show repeated SLA sections
Comments
Inline images no longer appear too large in iOS comments
Diffs
Pull request reviews no longer unexpectedly open an inline comment draft when the revision changes
Diffs
Dismissed issue suggestions no longer reappear on pull requests
GitHub
Pull request events now update issue statuses when a Git automation branch pattern contains unsupported regex syntax
Inbox
Fixed new project and initiative update notifications appearing as separate inbox entries for the same parent
Integrations
GitHub Enterprise Server setup no longer gets stuck on “Verifying installation” after the Linear app is created
Integrations
Prevented Slack Asks from responding to unmentioned thread messages after creating an Ask
IOS
File, image, and video attachments in document comments now open when tapped, and attachment cards have better contrast in the comments drawer
Issues
Issue boards now show an error instead of an empty state when too many issues match
Reviews
Structural diffs no longer mark entire reformatted statements as changed when only part of the statement changed
Reviews
Resolving a review thread that no longer exists in GitHub now shows a clear message instead of a generic error
Search
Searching for a GitHub URL now finds issues that reference the pull request
Slack
Fixed Slack review request notifications sometimes showing the wrong person as the requester
Slack
Fixed pasting a project milestone link into Slack now previewing that milestone instead of another milestone from the same project
Teams
Fixed internal custom view and dashboard links in Team Home displaying generic labels or icons
Triage
“Copy as prompt” no longer moves issues out of triage
Improvements
Diffs
Diffs linked as  Related  no longer change the status of the issue
Diffs
AI can now generate a Linear issue from a pull request or suggest an existing issue to link
Diffs
Inline feedback can now be sent to the Linear Agent, added to a review, or posted to the diff
Diffs
New agent sessions can now be started from any pull request using the Agent panel
Diffs
TypeScript and JavaScript regular expressions can now be tested directly from the file where they’re introduced
Diffs
Pull requests now show the number of meaningful changes, excluding tests and documentation
Diffs
Improved Slack notifications for a pull request removed from the merge queue to include the reason it was removed
Editor
Updated the keyboard shortcut cheat sheet to show  Cmd/CtrlEnter  for toggling checklist items
Importers
It is now possible to import issues into a sub-team if it doesn’t inherit statuses from its parent team
Issues
You can now restore an archived or deleted issue from the iOS app
Loops
Improved the “Authenticated email intake” trusted source by renaming it to “Email intake” and explaining when an email is treated as trusted
Loops
Added ability for Loops to send user notification
Zendesk
Improved the Zendesk integration to allow connection using an agent role instead of an end-user role
MCP server
Added Zapier to the built-in MCP connector directory
Keyboard shortcuts
Editor
Toggle a checklist item with  Cmd/CtrlEnter  when the cursor is inside it. Hold  Shift  to also toggle nested items
Search
Escape now clears the search input while keeping the current results, then dismisses search when the input is empty
Triage
Triage keyboard shortcuts now follow the order of the actions:  1  accepts,  2  declines,  3  marks as duplicate
July 23, 2026
Text attribution and agent-assisted editing
Documents and project descriptions are critical context for your teams and agents.
You can now edit text with  Linear Agent , and use  Loops  to keep docs and project descriptions up-to-date. Author name indicators let you check if text was written by a colleague or added by a loop.
When editing, changes you make through Linear Agent highlight separately so they’re easy to review. If you need to revert to an earlier version, restore to any previous checkpoint from version history.
Show author names or open version history from the  ⌘ / Ctrl  +  K  menu, or in document display options. Learn more in our  documentation .
Refreshed issue sidebar  ⁠
The issue sidebar now closely integrates issue properties with the main content. We’ve pinned Diffs to the top of this panel so you can access the issue’s pull requests from anywhere on the page.
Fixes
Asks
Fixed issues created through Slack Asks ignoring a chosen template’s default status
Comments
The resolved comments menu no longer appears when there are no resolved comments
Diffs
Submit review flyouts now properly close when clicking outside them
GitHub
Prevented revert pull requests from reopening issues linked to another GitHub repository
GitHub
Fixed linking GitHub pull requests to issues via pasted URLs.
Initiatives
Fixed oversized initiative titles
Integrations
Fixed a bug where removing a linked GitHub pull request disconnecting GitHub issue sync
Integrations
Fixed Slack project channel setup retrying after a project was deleted or archived
Settings
Fixed IP restrictions not appearing when searching for “IP” in settings
Slack
Fixed truncated issue summaries in Slack unfurls
Views
Fixed view filters (like  Cmd/Ctrl   F  filtering) resetting when navigating to an item in a split view list
Improvements
Editor
Added Backspace navigation from empty issue descriptions and document bodies back to the title
Issues
Improved issue composer to suggest templates as a quick suggestion, surfaced before other suggestions because they apply a bundle of issue properties
Projects
Added a way to view a project’s issues filtered by a specific milestone from the project overview on iOS
Triage
Added triage responsibility to the triage screen on iOS, showing who is responsible for incoming issues and letting you manage the action and responsible members
Diffs
“Quick to review” now shows up for slightly larger PRs and also appears for the author of the PR
API
Added  bodyData  to GraphQL pull request comments
CycleCreate  and  CycleUpdate  now prevent overlapping schedules and validate neighboring cycles using their dates.
July 20, 2026
Introducing Loops
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Loops are a new way for Linear Agent to take on recurring work for your team.
Describe the job in plain language and then choose whether it should run on a schedule or in response to an event. From there, Loops use context from your workspace and connected tools to decide on the next best action.
For example:
Review incoming issues, research root causes, and dispatch to coding agents
Create and coordinate follow-up work based on unstructured notes, like meeting transcripts or incident reports
Keep launch plans and project specifications up-to-date
See more ways to use Loops in the  docs
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Loops run at the team and workspace level, with shared visibility and control. Anyone with access can review their instructions, see how they are configured, and inspect what happened during each run.
Loops are available today on Business and Enterprise plans and use AI credits. To help you get started and understand usage, we’re giving your workspace $20 per seat in promotional credits. These credits are applied automatically to runs, and expire on August 20, 2026.
Read the  blog post  to learn more.
Fixes
Android
Added a fallback page for auth redirects so users can reopen the app when browser handoff fails
Asks
Fixed Asks created by mentioning the Asks agent in private Slack channels weren’t syncing the originating thread to the issue
Cycles
Fixed archived cycles getting stuck behind persisted label and other view filters with no visible way to clear them
Diffs
Pull requests with more than 50 commits now loading up to 450 commits
Documents
Private team document templates now consistently appearing in the template selector
Editor
Fixed checklists pasted from Google Docs rendering incorrectly
Email
Prevented notification emails from being sent to deactivated users
Inbox
Fixed email intake issues not appearing in the assignee’s inbox when the intake template auto-assigned the issue back to the sender
Integrations
Fixed GitHub Enterprise Cloud installation webhooks routing to the wrong workspace region before the installation was known to Linear
Integrations
Fixed GitHub Enterprise Cloud setup showing a generic error when an IP allow list blocked Linear, with clearer guidance on allowing Linear IPs
Notifications
Fixed duplicate Slack notifications when a newly created issue is added to a view with Slack notifications enabled
Projects
Fixed project pages crashing when a graph tooltip referenced a stale date
Pulse
Added an unsubscribe action for Pulse items shown through team project update subscriptions
Triage Intelligence
Fixed Triage Intelligence no longer requiring destination teams to have workspace-wide scope to be eligible for suggestions
Improvements
Agent
Linear Agent can now manage inbox notifications
Asks
Email intake threads can now be resolved and unresolved
Asks
Synced comment threads (Slack and Asks) can now be resolved and unresolved, and a new reply reopens a resolved thread
Comments
Added inline issue description comments on iOS, including highlights in the description, tap-to-scroll to the thread, and quoted text above description comments
Desktop
Added support for Cmd+Z to restore accidentally closed tabs, with timeline-ordered priority and batch restore for bulk close operations
Diffs
Added the Diffs inbox as a default home view option
Diffs
Improved visibility of auto-merge status in review controls
Diffs
Showed failed checks in merge queue removal events
Diffs
Showed GitHub force-push events in pull request timelines
Interface
Added an Underline links preference under Interface and theme to always underline links in issue descriptions, comments, and documents
Teams
Added display options to team member lists for sorting, filtering by member type, and choosing visible columns
MCP server
Improved attachment uploads to accept base64 payloads with whitespace or  data:  URL prefixes
July 2, 2026
Initiative properties
Initiatives define your company’s high-level goals and organize the projects that contribute to them. To help you manage initiatives as your roadmap grows, we’ve added a new set of focused initiative properties:
Proposed  and  canceled  statuses make it clear when an initiative is under consideration or has been intentionally set aside
Priority  communicates which initiatives are most important
Labels  group initiatives by product line, region, or other meaningful categories
Use these properties to group and filter initiatives on any plan, or build custom initiative views on Enterprise plans. Learn more about initiative properties in the  docs .
Centrally manage access to Linear’s MCP server in Claude  ⁠
Give employees secure access to Linear and other MCP servers in Claude, without requiring them to authenticate with each server individually.
Enterprise-managed Authorization lets Okta administrators manage access and permissions centrally, and users automatically get access to the MCP servers they’re authorized to use when they sign in to Claude.
Enterprise-Managed Authorization is available to Enterprise workspaces using Okta as an identity provider and Claude as an MCP client. Learn more in the  docs  or in the  MCP specification .
Share filtered views  ⁠
You can now share any filtered view by copying its URL from your browser, or by pressing  ⌘ / Ctrl   Shift   C  on desktop.
Share filtered views to discuss a subset of an existing view with someone else — like an issue view filtered by an assignee, or project or initiative view filtered by a label.
Fixes
Agents
Fixed issues with editing collapsible sections inside documents and descriptions with the Linear agent
API
Stopped automatically cancelling and restarting active Triage Intelligence runs after issue content changes
API
Fixed fieldless GraphQL input metadata from turning persisted filters into match-all filters
Asks
Slack  /asks  commands now pre-fill the modals with the entered text
Automations
Fixed showing agent automation  Show more  prompt buttons only when hovering an automation block
Comments
Fixed a transient agent session wrapper appearing after mentioning an agent that only handles comment events
Cycles
Fixed renamed cycles showing their local generated cycle number in some client Chrome
Desktop
Fixed OAuth application creation form resetting when switching tabs on desktop
Diffs
Added Linear details comments for manually linked GitHub pull requests when the link is created or changed
Diffs
Kept combined code review diffs aligned with side-by-side view when inserted additions are followed by a later paired helper extraction
Diffs
Show pull request status icons for coding session inbox notifications tied to PRs
Diffs
Fixed review notifications to now open the diff at the relevant comment instead of the guide
Diffs
Fixed Team reviews settings appearing when Diffs were disabled
Diffs
Fixed poor contrast of JSDoc comments in the GitHub Light syntax theme
Diffs
Fixed scroll position jumping when expanding collapsed code sections in diff view
Diffs
Fixed commit navigation controls shifting when the changed file count changes between selected commits
Diffs
Comment filters on the PR Diffs tab no longer hide comments in the Guide
Editor
Fixed emoji rendering in italicized text so emojis remain upright
Editor
Improved autolink for a broader list of TLDs when pasting URLs in the editor
Email
Fixed email intake settings occasionally displaying an incomplete email address
Initiatives
Fixed initiative list with sub-initiatives correctly restoring scroll position on navigation
Initiatives
Fixed transparency issues with the icon picker when editing initiatives inline in the list
Integrations
Reverted a GitHub sync change that stopped updates from Linear to GitHub once an issue is synced via the  one-way  sync
Integrations
Added a warning to Slack issue dialogs when selected labels include multiple labels from the same label group
Integrations
Fixed Google Calendar out-of-office status labels showing an absence as starting today when it starts tomorrow in the user’s timezone
Integrations
Fixed GitHub issue sync sending Linear label updates back to repositories configured for one-way GitHub-to-Linear sync
Integrations
Fixed Linear user mentions in Slack unfurls notifying mentioned users
Integrations
Fixed Slack synced comment import retries when Slack returns missing scopes while fetching message replies
Issue Activity
Fixed issue activity history no longer briefly reordering or regrouping while loading when lots of labels are involved
Issue templates
Fixed blank optional-only form template submissions from creating empty issues
Issues
Fixed issue sidebar hover styles not updating after switching between dark and light mode
Issues
Fixed copied issues including sub-issues after the Include sub-issues option was disabled
Issues
Fixed SLA workflow triggers failing when a workflow condition did not include an issue filter
Mobile
Prevented synced email threads from being resolved from Android
Project Views
Fixed a problem where hidden groups could not be restored in timeline views
Projects
Fixed completed projects appearing in project dependency blocker counts
Projects
Fixed newly created projects now receiving varied default icon colors, matching initiatives
Projects
Fixed the project update editor border disappearing after Agent highlight interactions
Releases
Fixed started release stage rows appearing taller than other rows in release pipeline settings
Settings
Fixed existing application images now showing when editing an OAuth application
Settings
Fixed settings search input box now respecting custom sidebar theme colors
Settings
Fixed customer status and tier row dividers appearing brighter than the header divider in settings
Settings
Fixed workspace security settings copy incorrectly referencing recurring issues for workspace template management
Sidebar
Properly aligned controls in the sidebar into one consistent column and fixed their focus rings
Slack
Stopped retrying permanent Slack webhook errors for disabled app message tabs and invalid block payloads
Teams
Fixed duplicate favorite action in action menu on team views
Triage
Fixed Triage rules sometimes showing duplicate or missing rows immediately after saving
Triage
Fixed the issue preview closing when a new issue entered a label-filtered Triage queue
Views
Fixed some server-backed views not loading correctly with some complex filter conditions
Projects
Project and initiative overview latest updates no longer inherit the previous latest update’s open state
Diffs
Fixed commit titles of specific lengths from overflowing the commit selector dropdown
Initiatives
Initiative target dates now use the same completed date rendering semantics as project target dates
Initiatives
Show the notifications subscribe control on initiative pages
Estimates
Restored the selected issue’s estimate total in the bulk action toolbar
Editor
Fixed dragging URL-backed Linear content into editors that was inserting duplicated mentions
Pulse
Fixed Pulse summary item navigation inside the inbox and added a breadcrumb back to the originating summary
Documents
Fixed restoring deleted documents whose project parent is archived
Pull requests
Cmd-clicking linked pull requests now opens them in a new tab
Diffs
Fixed bug where some code in Code Review diffs could not be copied to the clipboard
Improvements
Android
Added support for toggling todo checkboxes directly in issue descriptions and comments
Diffs
Added syntax highlighting for  .gjs  and  .gts  files in Diffs
Diffs
Added settings to control whether GitHub team review requests appear in Reviews and count as To Do
Diffs
Collapsed generated protobuf Go files in pull request diffs by default
Diffs
Changed PR comment copy menu label to refer to threads when copying prompts for comment threads
Inbox
Added ability to filter inbox notifications by related review status
Issues
Renamed canonical issue duplicate relation labels from “Duplicated by” to “Duplicates”
Search
Updated search tabs to show the search term with a Search prefix and a search-results icon
Teams
Improved the spacing between team home columns at medium-width resolutions
Settings
Clarified the keyboard preference for submitting comments and agent chat messages
Insights
Improved performance of issue and insights queries that filter by initiative
GitHub
Added  Linear issue  to the list of  magic words  linking pull requests to issues
MCP server
Added read-only MCP tools for listing and retrieving Linear Agent skills
Added support for managing releases, release notes, and release issue associations through the MCP server
Added source URL support to the  save_customer_need  tool
API
Added an external-user actor variant to the webhook actor union
Included the top-level  url  field in data-change webhook payloads for remove actions when an entity URL is available
Fixed entity webhooks for external-user actions so their top-level actor is populated
Keyboard shortcuts
Added the  ]  shortcut to show or hide the Agent sidebar from Diffs when an Agent session is available
Fixed  Shift   Cmd/Ctrl   ArrowDown  not opening sub-issues in board view
June 18, 2026
Agent assisted project updates
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Project and initiative updates keep teams aligned, but writing them means pulling out recent changes from issues, documents, and discussions.
Instead of finding that context manually, click  Write with Agent  to let Linear do it for you. The agent reviews changes made since the last update, checks messages in the linked Slack channel, and writes an update draft for you to refine.
Add your own perspective by prompting for further changes or editing directly, then publish the update.
Desktop navigation history and pinned tabs  ⁠
We’ve rebuilt our desktop tabs to make navigation feel fluid and predictable.
Each desktop tab now has its own history stack, so moving backwards won’t navigate you to another tab
Pinned tabs are now a reliable home for important work. They stay anchored in the tab bar, persist after quitting and reopening the app, and aren’t replaced by new content you open.
These changes are live for current desktop users. Try Linear on desktop by  downloading the app .
Private sub-teams  ⁠
Private sub-teams organize groups that work together under one umbrella, like independent business units, skunkworks efforts, or teams handling sensitive data like People Ops.
When you create a sub-team under a private team, you can now choose between two access options:
Restricted to parent team members  — parent team members can see and choose to join the sub-team. This makes it easy to manage private team structures without coordinating invitations to each sub-team.
Private to team members  — the team is hidden, except to members directly invited to that sub-team
Private sub-teams are available on Business and Enterprise plans. Learn more in our  documentation .
Build agents with Vercel Eve  ⁠
Vercel Eve is an open-source framework for building custom agents.
Build agents that can investigate incidents, monitor SLAs, or analyze customer feedback. You can deploy agents on Vercel with the guided setup, or host them wherever you run your Eve app.
Once connected to Linear, teammates can delegate issues to your agent or mention it in comments. Learn more about Eve in Vercel’s  documentation .
Release pipeline changelogs  ⁠
Releases  let you plan and track your software releases. Now, you can also keep your team aligned on what’s shipping with changelogs for each release pipeline. These changelogs bring a pipeline’s release notes together in one place, so progress is easy to review and share.
Choose to auto-generate release notes in pipeline settings so your changelog is always up to date. Learn more in our  documentation .
OAuth application manifests  ⁠
OAuth application manifests let platforms provide a one-click OAuth app setup experience for users creating integrations.
Use URL parameters to send users directly to a pre-filled  Create OAuth App  form in Linear. An equivalent JSON manifest format lets you store configurations in files, validate them locally, or generate them programmatically.
Find the details in our  developer docs .
Fixes
Command menu
Added the missing command menu action for recently deleted initiatives
Comments
Threaded comment highlight corners now match with the reply composer below the thread
Customers
Fixed stale customer request counts on issues and projects after archiving or restoring customer requests
Desktop
Middle-clicking a link to a document comment now properly navigates to the comment
Diffs
Fixed the Unified/Split layout toggle not taking effect when a narrow column had forced the diff into unified view
Diffs
The tooltip on group headers in the Reviews inbox now covers the entire clickable header
Documents
Creating an issue from a selection in a team document now creates it in the correct team
Duplicates
When you remove a duplicate relation, it now restores the issue’s last status
Duplicates
Fixed duplicate merges running concurrently for the same issue during bulk deduplication
Filters
Fixed the filter button not staying visually active while its menu is open
Front
Fixed processing Front conversation links for conversations without a primary recipient
GitHub
Fixed GitHub integrations being marked “disconnected” after a transient GitHub authentication blip
Inbox
We no longer send a  removed from merge queue  notification when a pull request is successfully merged by GitHub’s merge queue
Inbox
Fixed inbox notifications occasionally appearing as blank while the sender’s name was loading
Insights
Fixed release-filtered burn-up charts failing to render
Issues
Fixed oversized issue status icons in delete confirmation toasts
Milestones
Fixed a flicker in the milestone list when creating the first milestone from a project overview
Notifications
Each recipient’s name display preference is now respected in project and initiative update notifications
Project Updates
Fixed the project updates panel occasionally leaving an empty wrapper element on the page after navigating elsewhere
Pull requests
Right-clicking pull request pills in issue lists now opens the correct menu
Pull requests
Fixed pull request details overflowing their container when hovering over a PR badge
SCIM
Renaming a linked SCIM role group (e.g.  linear-admins ) in the identity provider no longer causes Linear to stop managing the associated role
Settings
Prevented the language selector from overlapping the scrollbar in Code & Reviews settings
Settings
Fixed an odd transition when switching between the same settings page of different teams
Slack
Slack thread sync no longer fails to import a comment when one of its reactions came from a user without access to the issue
Slack
Underscores in pull request titles are now preserved in Slack notifications
Slack
Slack comment notifications now link out to unsupported images instead of sending invalid Slack image blocks
Slack
Slack pasted message links now sync to Linear threads as a clickable link
Improvements
Agents
AI chat thinking steps are now shown as blockquotes when copying conversations as markdown
Diffs
Added a “Missing issue” PR filter that shows PRs without a linked issue
Diffs
Raised the size limit for generating Guides on larger pull request diffs
Diffs
Holding  Opt  and clicking the chevron in the file header now expands/collapses all files
Diffs
Review list approval copy now shows who approved a pull request
Diffs
Whole added/removed lines in diffs render more clearly with the same color as inline added/removed characters
Diffs
Added the ability to use custom font for code in diffs
Diffs
Added contextual help about the Reviews feature and related keyboard shortcuts
Diffs
Polished the pull request review layout — removed the divider between the conversation and code columns, and the Guide now has even horizontal padding with the scrollbar no longer overlapping content
Diffs
Added copy link to file actions in pull request diffs
GitHub/GitLab
Unassigned triage issues remain in triage for Git request and commit automations, unless the final merged change closes the issue
PagerDuty
Added support for PagerDuty shift-based schedules, so triage responsibility on-call now syncs from both shift-based (v3) and classic layer-based schedules (v2)
Team documents
The documents list now supports multi-select
Views
Updated the sort direction icons so the arrow direction matches the active sort order
MCP server
MCP project status update tools are now available in workspaces without recent project update history
Fixed issue with fetches failing when descriptions contained Unicode line or paragraph separators
API
templateCreate  and  templateUpdate  now reject unsupported form field payloads
June 11, 2026
Coding sessions in Linear
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Earlier this year, we launched  Linear Agent , giving teams a new way to plan and coordinate their issues and projects. Since then, we’ve added  Code Intelligence  to extend that understanding to the codebase, and  MCP support  to bring all of your context together.
Today we’re closing the loop:  Linear Agent can now write code using Claude Code and Codex.  You can triage, plan, review, and ship—all in Linear.
Start a coding session by assigning an issue to Linear, or ask it to make a change in a chat, comment, or Slack thread. Each session is grounded in your workspace context, pulling in issue details, history, customer requests, discussions, and related work.
A coding agent your team will love  ⁠
Coding sessions run in the cloud, so you can prototype ideas and make changes without setting up a local development environment.
When the change is ready, Linear returns a new diff for review. Share  preview links , bring teammates into the discussion, and address feedback with further iterations in the same thread.
Automate the first pass  ⁠
When a new issue is reported, Linear Agent can investigate and attempt a fix before it reaches an engineer, reducing the load on your team.
It follows your team’s guidance, gathers evidence from tools like Sentry or Datadog through MCP, and inspects the codebase to trace the root cause before producing a fix.
Linear uses this workflow internally to resolve roughly 30% of incoming bug reports, mostly on the first pass.
You can set up your own agent automation in your team’s Triage settings.
Availability and pricing  ⁠
Coding sessions are available on Basic, Business, and Enterprise plans. They require a GitHub connection with code access and use AI credits to run. Workspace admins can enable coding sessions in  Settings  and manage access, usage, and credits from the usage dashboard.  Learn more in the docs .
Fixes
Agents
Filled in the thumbs down button after submitting AI feedback
Agents
Fixed a missing space between the integrations link and surrounding text on the team agents settings page
Agents
Vertically centered the label and preview text in the agent session card’s status row
Agents
Fixed left padding of the agent session card header to match other activity cards
Archive
Fixed restoring a trashed issue or document failing in rare cases where the document’s trashed flag was stored as  false
Asks
Allowed Slack workflows and external users using the Asks Agent to access private teams’ channel-configured templates
Customers
Fixed excessive row spacing and the limited customer list on the unfiltered customers page
Customers
Fixed the customer merge preview showing annual revenue under the monthly revenue label
Customers
Fixed a bug where linking a Slack channel to a customer failed for workspaces with multiple Slack connections but a single Asks connection
Diffs
Opening a  linear.review  link in a workspace without Diffs enabled now routes to enable-reviews instead of bouncing back to GitHub
Diffs
Fixed showing GitHub legacy commit statuses (e.g. external CI like RWX or Jenkins) in PR checks
Diffs
Fixed “Update branch → with rebase” creating a merge commit instead of rebasing
Diffs
Fixed the file list sidebar not scrolling when the file tree was taller than the viewport
Display options
Fixed the display options menu being slow to open on views grouped into a large number of items
Editor
Fixed customer and customer request mentions not loading their details in the iOS editor
Editor
Pasting  linear.app/review/<owner>/<repo>/pull/<id>  now properly embeds as a PR mention
Editor
Fixed the tooltip for plain links covering link controls
GitHub
Fixed Linear issues with comma-containing label names failing to sync to GitHub
Initiatives
Fixed Initiative projects table columns occasionally overlapping or taking up too much width
Integrations
Fixed an importer freeze when mapping a large number of users
Issues
Fixed a line break appearing between an issue’s status icon and its identifier in undo/redo toasts
Labels
Archived labels no longer appear in the form-template label group picker
Links
Fixed a crash when a link embed with a missing or invalid URL failed to load a preview
Mobile
Release, Release Note, and Release Pipeline mentions now display properly on mobile
Notifications
Fixed agent completion notifications not being delivered to the user who delegated the work
Projects
Project issue list deep links now redirect to the project overview instead of the filtered issue view
Project Views
Fixed saved project views unexpectedly showing empty groups when grouping and filtering projects
Pulse
Fixed daily Pulse summaries being skipped when a single feed update had a malformed body
SCIM
Fixed SCIM role group pushes not repairing a stale role when the user was  already tracked in the role’s membership
Settings
AI settings dependent on the Linear Agent now show “Disabled” when the Linear Agent is turned off
Slack
Sharing a project comment link in Slack now unfurls the comment instead of the project
SLAs
Fixed missing SLAs for issues created from Slack asks
Updates
Fixed inconsistent icon spacing in the project/initiative update health control
Improvements
Asks
Improved longer, cleaner fallback issue titles when creating Asks from Slack without an AI-generated title
Diffs
The “Copy pull request number” action now copies just the number, without the leading  #
Diffs
Added a file action to open the full file in GitHub from the review diff
Diffs
Guided reviews now jump directly to a selected file instead of scrolling slowly through every file in between
Documents
Added “New document” and “New document from template” to the right click menu on the create issue button
Team Documents
Added cycle documents to the team documents tab, including support for grouping documents by cycle
Triage
On Android, choosing a status that requires a priority to leave triage now opens the priority picker automatically instead of hiding those statuses
Keyboard shortcuts
Editor
Changed the strikethrough shortcut to  Cmd/Ctrl   Shift   X
MCP server
list_comments  now returns comments on archived issues
Documents can now be listed and created under a team
June 4, 2026
Team documents
Important team context doesn’t always belong in a specific issue, project, or initiative. Teams also need a dedicated place for the notes, docs, and shared references that support their work over time. Now, every team has a page to keep its context organized and easy to access.
Teams can create documents directly from their home page, add existing documents from projects and issues, and group resources into sections.
Open a team’s page by clicking on its name in your sidebar, or search by pressing  o , then  t . Learn more in our  documentation .
Shared skills for Linear Agent  ⁠
Skills  let you save reusable instructions for Linear Agent.
We now support sharing skills with your team so great personal workflows can become shared team process. Sharing a skill helps your team standardize recurring workflows like writing specs, running weekly planning, or drafting updates.
Use skills in any agent conversation by clicking on  Skills  or using a slash command. You can share an existing skill from  settings , or by asking Linear Agent. Learn more in our  documentation .
Issue description comments  ⁠
You can now comment directly on text or images in issue descriptions.
Select any part of a description to leave a comment anchored to that exact spot. Use description comments to share feedback on a specific part of the description, rather than commenting on the issue as a whole.
Fixes
Asks
The Creator in activity log copy for Slack Asks issues now always matches the  creator  filter.
Attachments
Linear now preserves the original filename (and extension) when downloading attachments whose name contains characters like middle dot ( · ) or non-breaking space.
Comments
Fixed synced Slack thread replies that could fail or disappear after switching threads.
Comments
Fixed mentioning app users in comments created through triage automations.
Comments
We now correctly strip leading whitespace from comment paragraphs on submit.
Diffs
Files marked as viewed in the Guide tab now stay collapsed when returning to the Diff tab.
Diffs
Fixed links in Guide jumping or over-scrolling past the target when navigating to a file or symbol.
Diffs
Fixed the diff horizontal scrollbar not being draggable when a collapsed unchanged-lines row was present.
Diffs
Fixed Guide showing large blocks of unchanged code when an LLM-supplied hide directive sat adjacent to a long unchanged stretch.
Documents
Capped the document table of contents markers height, showing only top-level headings when there are too many to fit.
Documents
Fixed a previously open document staying selected after creating a new document in side-by-side view.
Display options
Toggling a display option back to its default now correctly clears the modified indicator on the Display button.
Editor
Fixed portrait videos being clamped when going fullscreen.
Figma
Fixed Figma links in comments triggering repeated comment update errors and slow issue loads.
GitHub
GitHub backlink comments are now posted for issues that reference a GitHub URL even when the target repo isn’t synced to a Linear team, as long as the GitHub install can access it.
GitHub
We now correctly handle null GitHub ghost users across webhook, issue sync, and pull request intake paths.
GitHub
Fixed GitHub issue sync failing with a 401 “A JSON web token could not be decoded” error in some GitHub Enterprise Cloud workspaces.
Google Sheets
Fixed a Google Sheets export failure caused by large issue batches overflowing the call stack.
Inbox
Returning to Inbox no longer scrolls to a previously-viewed notification without selecting it.
Insights
Fixed incorrect Insights results when using “Time in status” after an issue status was renamed.
Integrations
Fixed Linear Agent creating a Slack channel for new projects when “Automatically create channel for new projects” was disabled.
Keyboard
Pressing  Esc  on a page opened directly in a new tab no longer wipes that page from browser history, so the browser back button can still return to it.
Linear Agent
Stopped the Linear agent from chiming in on later Slack thread chatter after it creates an issue/Ask.
Login
Login now shows a clear error instead of a false “email sent” confirmation when emails can’t be delivered to a suppressed address.
Onboarding
Fixed the onboarding invite step hanging on desktop after sending invites.
Performance
Loading icon animations are more performant and use less CPU.
Projects
Fixed missing icons on project milestone context menu actions.
Projects
Fixed missing padding around the milestones help text shown when a project has no milestones.
Projects
Fixed project activity showing the wrong priority change after consecutive priority updates.
Pulse
Fixed Pulse summaries rendering document links with a stray  @  prefix instead of a proper document mention.
Releases
Fixed a bug that caused only partial release names to be saved.
Diffs
Clicking “Request review” on a draft pull request that already has requested reviewers now marks it ready for review directly.
Diffs
Outdated review comments are now reflected separately from resolved comments in the code review comment summary.
Search
Fixed exact issue identifier searches with different casing not ranking the matching issue first.
Sidebar
Fixed alt-clicking a team in the sidebar downloading an HTML file instead of collapsing/expanding all teams.
Sidebar
Fixed the “Exploring” sidebar section dropping a team when navigating to its documents tab.
Sidebar
Sidebar nav item hover state changes are now instant.
Slack project channels
Linear no longer overwrites a connected Slack channel’s topic when a project’s description changes.
Templates
Fixed an error that could occur when saving templates that contained legacy invalid content.
Templates
Fixed issue templates intermittently losing their default project and milestone.
Triage
Fixed the triage automation actor name showing “Triage Behaviour” instead of “Triage Behavior”.
Triage
Fixed the triage responsibility settings separators appearing darker than the triage rules card.
Version history
Fixed the “Highlight changes” toggle disappearing when turned off in version history.
Views
Fixed a freeze that could occur when opening some saved issue views.
Improvements
Agents
Added an  Error  option to the agent session issue filter and insights grouping.
Diffs
You can now paste a GitHub pull request link into command menu to open it in Linear.
Diffs
Customers on legacy plans can now use Diffs.
Diffs
We now show indentation changes in diffs for more whitespace-sensitive languages (CoffeeScript, Elm, F#, HAML, Haskell, LiveScript, MoonScript, Nim, Stylus, Makefile).
Editor
We now support right-clicking an issue mention in a doc or editor to change its properties.
Editor
We now treat ) and ( as emoji autocomplete aliases for standard smile and sad results.
May 28, 2026
Linear Diffs
Elapsed 00:00
Seek to: 00:00    /   Duration 00:00
Remaining  − 00:00
0.25 ×  0.5 ×  0.75 ×  1 ×  1.25 ×  1.5 ×  1.75 ×  2 ×
Agents generate large volumes of code, but individuals are still accountable for the changes that merge. This leads to a lot of review work, and the capability and performance of traditional review tools hasn’t kept up.
Today, we’re releasing Linear Diffs to make reviewing code a fast and fluid experience native to Linear.
You can now review diffs from any issue with a PR, iterate on further changes with agents, and ship code from Linear. All reviews in Linear sync back to GitHub, so the current state of review work is always clear.
Guided reviews (beta)  ⁠
Guided reviews help you efficiently review large PRs. When you view a diff in this format, you’ll see the core of change first, so you don’t have to dig for an entrypoint.
Each section of diffs has an explanation — starting with what the change is, then moving into its consequences. Guided reviews separate out glue code and secondary changes so you can stay focused on what matters. This style of review makes it much easier to move through large changes in a single sitting.
Guided reviews are free during beta and available for Linear customers on Business and Enterprise plans.
Review Inbox  ⁠
Staying on top of reviews is easier when review notifications live alongside the rest of your work. Linear notifies your Inbox for work like review requests, your approved PRs, and comment mentions. You can set up additional real-time desktop, Slack, email, or mobile  notifications .
We’ve also added a dedicated Reviews tab in your sidebar so you can see all your review work at once. The default focus ordering sorts reviews by what’s closest to shipping, so the work that needs your attention most rises to the top.
Reviewing code  ⁠
When a review calls for changes, keep iterating from the diff surface with a background coding agent. Agent changes update the diff in real-time, so you don’t need to check out the branch locally for every small tweak.
Diffs is responsive when reviewing even very large PRs. You can view unified or split diffs, enable line wrapping and structural highlighting, and choose custom code themes.
Linear Diffs is available now on all plans. Guided reviews are free during beta and available for Linear customers on Business and Enterprise plans.
Workspace admins can enable Diffs by  upgrading  Linear’s GitHub integration for code access. Then, individual users can choose to  review diffs in Linear .
To learn more about why we built Diffs, read  Code review should be fast . For more on Diffs functionality, check our  documentation .
Fixes
Agents
Fixed choppy animation when expanding agent thoughts
Agents
Fixed agent chat incorrectly minimizing on external link click
Agents
Fixed the “Worked for X” label on agent session turns to measure active work time, excluding any idle wait between turns
Agents
Fixed agent panel staying focused when expanding or collapsing
Agents
Prevented the Ask Linear popup from reopening off-screen after the window height shrinks
Agents
Fixed Ask Linear drafts being lost when switching between chats
Agents
Fixed agent lists showing too many skills
Asks
Linear Asks Agent will now automatically reply to external users when requesting additional information
Asks
Fixed Asks Web submission attributions when the submitter logged into Asks Web before accepting their Linear workspace invite
Desktop
Fixed an issue where the desktop application could hang when waking up your computer from sleep
Desktop
Fixed desktop app flash of white background on new window open
Diffs
Fixed deduplication of linked PRs in issue attachment data
Diffs
Fixed refreshing the diff when a PR’s target branch changes (e.g., after a stacked parent merges and GitHub retargets the child)
Diffs
Stopped attributing GitHub PR comments authored by deleted (“ghost”) users to the wrong user in notifications
Documents
Fixed document mention notifications firing on every edit instead of just when a user is newly mentioned
Documents
Shortened the placeholder in the “Change document subscribers” action menu so its keyboard shortcut indicator no longer gets clipped
GitHub
Comments on a not-yet-linked GitHub PR now backfill the issue→PR link via magic-word matching the same way PR lifecycle and review events do
Inbox
Fixed “From is not” filter to correctly exclude issue assignment notifications from integration and OAuth application-driven assignments
Inbox
Fixed inbox badge getting stuck when arriving on a review via a legacy  /agent  URL
Insights
Fixed a bug where two Duplicate options appeared in the Time in status filter
Integrations
Figma links now show a clean  Figma  title instead of the raw marketing page title
Issues
Removed Duplicate status from quick issue create and issue template
Project templates
Allowed project-template sub-issues to target other private teams again
Sentry
Fixed a bug where Sentry-created issues could be assigned to deactivated users in triage
Settings
We now correctly truncate long team names in Teams settings list instead of overlapping the next column
Shortcuts
Fixed the Copy as Prompt shortcut so it updates issue status when auto-start-on-open is enabled
Sync
Fixed “Linear servers are not reachable” error that could appear after laptop unlock
Triage
Fixed workspace issue templates not appearing in triage automation filters
Views
Fixed list rows shifting horizontally when toggling a group in views with grouped columns
Improvements
Android
Improved Android to use server-side filtering for skills
Agents
Dashboard pages are now used as context in the Linear agent chat
Integrations
Connecting GitHub now defaults to enabling code access
Project Slack channels
Used an info-style toast when starting project Slack channel creation
Reviews
Activity page file and code comment links, and PR notifications, now open whichever code view (Diffs or Guide) you last visited
Skills
Updated empty state for skills to match other settings
Timeline
Improved timeline projects aside panel visibility to be remembered per view instead of globally
Updates
Removed the UI for hiding project and initiative update details
May 21, 2026
Project Slack channels
Project teams often use a Slack channel to discuss and share feedback about their project as it takes shape.
Now, Linear can spin up that Slack channel automatically every time a new project is created. All project members are automatically added to the project Slack channel, and project updates post to that channel by default.
When working in a project’s Slack channel, you can use Linear Agent to answer questions or take actions in the project. Try sending messages to the channel like “ @Linear  what’s our target date?” or “ @Linear  file this bug and assign it to me.”
Admins can enable channel creation from  settings . Learn more about project Slack channels in our  documentation .
Linear Asks Agent  ⁠
Linear Asks  brings internal requests into Linear, where the appropriate team can work on them.
Now, anyone in your Slack workspace can file a request in Linear by mentioning  @Linear Asks . Linear checks the templates enabled for that channel, picks the best match, and creates an issue using the conversation as context.
When a template uses required fields, Linear follows up to collect any missing details before creating the issue.
Admins can configure Linear Asks agent in  settings  for any connected Slack workspace. Asks is available on Business and Enterprise plans. Learn more in our  documentation .
Issue duplicates  ⁠
Duplicate issues now use a dedicated status type in Linear and move context to the original issue.
When an issue is marked as a duplicate, its customer requests, synced Slack threads, and attachments are moved to the original issue. Whether a teammate, agent or Triage Intelligence marks an issue as a duplicate, the issue context moves to the right place.
Because of theses changes, every issue with a duplicate status must now link to the original issue. On duplicate issues, that original issue is shown clearly in the sidebar.
When the original issue is completed, every synced Slack thread is notified. Each linked customer ticket in Zendesk or Intercom also reopens, so you can keep your customers in the loop.
Reorder groups in issue and project views  ⁠
Issues and projects in views are often organized into groups like status, priority, or label. You can now reorder these groups in any list or board view to put the most important sections first.
Click the reorder groups icon in display options, then drag groups into your preferred order. You can reset the view back to the default order at any time.
GitHub Enterprise Cloud integration  ⁠
Linear now supports GitHub Enterprise Cloud.
Once connected, GitHub Enterprise Cloud users have access to all the benefits of our popular GitHub integration. Linked pull requests update issue statuses automatically, GitHub Issues sync can be enabled for select repos, and you can review PRs natively with Linear Diffs.
This integration is available on Linear’s Enterprise plan. Read more in our  documentation , and install the  GitHub Enterprise Cloud integration  to get started.
Fixes
Agent chat
Fixed highlights on the agent chat buttons
Agents
Issues created from templates via the Linear agent (in-app, Slack, Microsoft Teams) now respect required form fields and serialize submitted values into the issue description
Agents
Fixed a freeze when pasting long Markdown content that included todo items into agent toolbar input
Asks
Fixed Asks Web template submissions that create child issues for authenticated non-members
Cycles
Fixed progress ring background blending into the row hover color in quick filter overviews
Drafts
Fixed a bug where saving as draft would fail when an issue template included a sub-issue on a sub-team
Duplicates
Duplicate issues now appear in the canceled section in focus-grouped issue lists instead of active buckets
Editor
Copying part of the text of a list item no longer copies the list structure, only the text itself
Editor
When pasting Markdown content that includes code blocks, the cursor now lands correctly at the end of the pasted content
Filters
Fixed missing rows on Author, Reviewers, Team owners, Customer owner, and Project milestone filters on first open
Filters
Fixed missing rows on Creator filter on search page
Filters
Fixed header filter buttons highlighted while their filter menu is open
Labels
Restored input focus when switching between New group and New label while creating a label
Linear Agent
Fixed resuming Slack threads when the user answers an agent’s follow-up question without  @Linear , even after a long delay
Notifications
Fixed an issue where users could be unexpectedly subscribed to issues they never interacted with
Performance
Fixed an issue where switching workspaces could leave the app stuck on the workspace loading screen until a restart
Projects
Fixed public project Slack channels incorrectly appearing as private after renames
Releases
Fixed order of releases by stage position so canceled releases are sorted after completed ones
Reviews
Showed only the relative timestamp for opened pull requests in the review list
Settings
Fixed dropdown text overflowing on narrow viewports
Slack
Fixed double-notifying on Slack when an issue is deduplicated — the duplicate-relation event is now the only user-facing event
Sidebar
Reduced blur and fixed positioning in animated unread count digits on non-retina displays
Teams
Fixed issue where team owners can now update the “Restrict team membership” setting without needing workspace admin permissions
Templates
Fixed moving a project or document template to the parent team or workspace silently reverting
Updates
Switching the project or initiative on an update composer no longer deletes the previously saved draft
Workflow
Show the visible workflow-state icon for merged issue status group headers, with a generic fallback when multiple team states are visible
API
Added parallel  AgentSkill  GraphQL query and mutation types alongside deprecated  AiPrompt  roots for the skill migration
Added  Team.visibility  and deprecated  Team.private
Returns  410 Gone  from  /oauth/migrate_old_token ; old OAuth token migration is no longer supported
Improvements
Inbox
Grouped agent-authored inbox replies into a dedicated Agents section in focus inbox grouping
Issues
You can now link the same pull request to multiple selected issues from issue actions and  Cmd/CtrlK
Reviews
Unreviewed sta

[… nach 60000 Zeichen abgeschnitten]
