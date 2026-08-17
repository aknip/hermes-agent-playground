# Hermes Agent Playground

Tutorials, Demo-Projects, Tests rund um [Hermes Agent](https://hermes-agent.nousresearch.com)
(Stand: v0.20.0, macOS).

## [01 — Hermes Agent Theming](01-hermes-agent-theming/)

Recherche zur Frage, wie weit sich Hermes optisch an eigenes Branding anpassen
lässt — Wordmark, eigenes Logo, Anwendungsname, Icon. Alle Aussagen sind am
lokalen Quellcode der installierten Version belegt, nicht an der Online-Doku,
und jedes Dokument sagt explizit, was verifiziert ist und was nicht.

| Inhalt | Worum es geht |
|---|---|
| [Hermes Desktop Theming](01-hermes-agent-theming/Hermes%20Desktop%20Theming/Hermes%20Desktop%20Theming.md) | Die macOS-Desktop-App: Skins, Theme-Modell, Plugin-Slots, App-Icon und Menüname — inklusive der harten Grenzen, die nur ein Rebuild verschiebt |
| [Hermes Dashboard Theming](01-hermes-agent-theming/Hermes%20Dashboard%20Theming/Hermes%20Dashboard%20Theming.md) | Das Web-Dashboard (`hermes dashboard`): der deutlich freundlichere Fall — freies `customCSS`, Bild-Assets, Component-Overrides, Slots, alles ohne Rebuild |
| [Theme „Clean WebUI"](01-hermes-agent-theming/Hermes%20Dashboard%20Theming/Theme%20-%20Clean%20WebUI/) | Ein fertiges Dashboard-Theme zum Kopieren nach `~/.hermes/dashboard-themes/` (Quelle: [fplanque/hermes-agent-dashboard-theme-clean](https://github.com/fplanque/hermes-agent-dashboard-theme-clean)) |

## [02 — Hermes Agent Kanban Tutorials](02-hermes-agent-kanban-tutorials/)

Elf eigenständige Tutorials zum Kanban-Board von Hermes Agent — von der
einfachen Abhängigkeitskette bis zur autonomen Pipeline mit menschlichen Toren.
Jede Story bringt ihr eigenes Setup mit, läuft auf ihrem eigenen Board und
lässt sich einzeln durchspielen und wieder zurückbauen; ein übergreifendes
Setup gibt es nicht. Alle elf sind mit echten Workern durchgespielt worden,
die Konsolenausgaben stammen aus diesen Läufen.

| Story | Worum es geht |
|---|---|
| [1 — Solo Dev](02-hermes-agent-kanban-tutorials/Story%201%20-%20Solo%20Dev/TUTORIAL.md) | Abhängigkeitskette und strukturierter Handoff zwischen zwei Profilen |
| [2 — Fleet Farming](02-hermes-agent-kanban-tutorials/Story%202%20-%20Fleet%20Farming/TUTORIAL.md) | Zwölf unabhängige Tasks parallel auf drei Spezialisten |
| [3 — Role Pipeline](02-hermes-agent-kanban-tutorials/Story%203%20-%20Role%20Pipeline/TUTORIAL.md) | PM → Engineer → Reviewer, mit Block und Retry |
| [4 — Circuit Breaker](02-hermes-agent-kanban-tutorials/Story%204%20-%20Circuit%20Breaker/TUTORIAL.md) | Was bei Fehlern passiert: Circuit Breaker, Respawn-Sperre, Crash Recovery |
| [5 — Tenant Fleet](02-hermes-agent-kanban-tutorials/Story%205%20-%20Tenant%20Fleet/TUTORIAL.md) | Ein Profil, viele Mandanten, cron-getriebene Erzeugung |
| [6 — Research Triage](02-hermes-agent-kanban-tutorials/Story%206%20-%20Research%20Triage/TUTORIAL.md) | Fan-out auf Rechercheure, Fan-in in die Analyse, Block mitten im Lauf |
| [7 — Scheduled Briefing](02-hermes-agent-kanban-tutorials/Story%207%20-%20Scheduled%20Briefing/TUTORIAL.md) | Wiederkehrende Pipeline auf einem langlebigen Vault |
| [8 — Digital Twin](02-hermes-agent-kanban-tutorials/Story%208%20-%20Digital%20Twin/TUTORIAL.md) | Eine dauerhafte Identität mit eigenem Gedächtnis und Eskalation |
| [9 — Worktree Pipeline](02-hermes-agent-kanban-tutorials/Story%209%20-%20Worktree%20Pipeline/TUTORIAL.md) | Parallele Git-Worktrees, Fan-in in den Review |
| [10 — Triage Pipeline](02-hermes-agent-kanban-tutorials/Story%2010%20-%20Triage%20Pipeline/TUTORIAL.md) | Autonome Pipeline mit Rubrik, Selbst-Fan-out und genau einem menschlichen Tor |
| [11 — LLM Wiki](02-hermes-agent-kanban-tutorials/Story%2011%20-%20LLM%20Wiki/TUTORIAL.md) | Wissensbasis pflegen: ein Vertrag, ein deterministischer Linter, zwei menschliche Tore, Branch je Ingest |

Stories 1–4 folgen dem offiziellen Kanban-Tutorial, 5–9 der v1-Designspezifikation,
10 und 11 bilden ein Paar zum Thema „wie viel Logik gehört in die Skill, wie viel
in deterministischen Code".

Einstieg: [README](02-hermes-agent-kanban-tutorials/README.md) (Story-Übersicht,
Voraussetzungen, Rückbau) · [TUTORIAL.md](02-hermes-agent-kanban-tutorials/TUTORIAL.md)
(Grundmodell und Befehlsreferenz) · [VERIFIKATION.md](02-hermes-agent-kanban-tutorials/VERIFIKATION.md)
(was geprüft wurde — und was nicht).
