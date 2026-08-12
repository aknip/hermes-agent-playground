# Multi-Agent-Workflow mit dem Hermes-Agent-Kanban-Board

https://www.youtube.com/watch?v=EKVRqcpTT6s
https://github.com/tonbistudio/hermes-multi-agent-workflow

## Abstract

In diesem Video zeigt der YouTuber und Entwickler hinter dem Kanal „Tonbi's AI Garage" einen vollständig autonom laufenden Multi-Agent-Workflow, den er mit dem **Kanban-Board von Hermes Agent** aufgebaut hat. Ausgangspunkt ist die häufig unterschätzte Schwierigkeit von Multi-Agent-Systemen: Nicht das Einrichten einzelner Agenten ist das Problem, sondern das koordinierte Zusammenarbeiten vieler Agenten an einer Aufgabe, ohne dass sie sich gegenseitig behindern, doppelte Arbeit verrichten oder durch einen Absturz alle Fortschritte verlieren.

Die Lösung ist ein zentrales Kanban-Board als „Single Source of Truth": Jede Arbeitseinheit ist eine Karte, Agenten beanspruchen Karten, bearbeiten sie und reichen sie weiter. Ein SQLite-gestützter **Dispatcher** koordiniert den gesamten Ablauf automatisch – inklusive parallel laufender Arbeit, event-driven Verkettung von Aufgaben, Wiederverarbeitung abgestürzter Tasks und vollständiger Auditierbarkeit.

Als Live-Demonstration führt der Autor eine Pipeline vor, die reale Schmerzpunkte von KI-Agenten-Nutzern aus dem Web (X, Reddit, YouTube) erfasst, mit einem 65-Punkte-Mindestrubel bewertet, in parallel forschende Sub-Agenten verzweigt und schließlich über genau **eine menschliche Freigabegenehmigung** (per Telegram) entweder ein Werkzeug baut oder eine Video-Idee samt Folien und Skript ausarbeitet. Das konkrete Beispiel erzeugt einen Codex-VS-Code-Sicherheitskonfigurations-Validator (CLI) und eine Video-Präsentation zum Fehlerbild „Cloud-Code-Sub-Agenten scheitern bei vielen MCP-Tools". Der Workflow wird als generalisierte, quelloffene Vorlage veröffentlicht, damit andere Nutzer ihn auf eigene Zwecke anpassen können.

---

## Kapitel 1: Das Grundproblem der Multi-Agent-Systeme

Viele Menschen sprechen über Multi-Agent-Workflows, aber kaum jemand setzt sie tatsächlich stabil in die Praxis um. Das Kernproblem ist laut Autor **nicht die Erstellung der Agenten selbst**, sondern deren Fähigkeit, an einem gemeinsamen Auftrag zu arbeiten, ohne sich gegenseitig zu überlagern.

**Ohne eine gemeinsame Koordinationsebene treten typische Probleme auf:**
- Agenten „rasen herum" und erledigen doppelte Arbeit
- Tokens und Geld werden verschwendet
- Es fehlt ein gemeinsamer Speicher über den Projektfortschritt
- Ein einziger Absturz kann den gesamten Bearbeitungsstand vernichten

Gegen diese Probleme existieren bereits viele Versuche von Multi-Agent-Systemen – alle mit Teilerfolgen, aber sie scheitern früher oder später am selben Punkt: der Vermeidung von Konflikten bei der Arbeit.

## Kapitel 2: Das Kanban-Board als Koordinationsschicht

Das Kanban-Board in Hermes Agent (über das Web-Dashboard unter `Plugins → Kanban` erreichbar) löst genau dieses Koordinationsproblem. Das Designprinzip ist bewusst simpel:

- **Jede Arbeitseinheit ist eine Karte** (mit Titel, Aufgabenbeschreibung, Zuständigem und Status).
- Agenten **beanspruchen eine Karte**, bearbeiten sie und reichen sie weiter.
- Der Zustand „liegt auf dem Tisch" (persistiert) und **überlebt einen Neustart**.
- Das **Board ist die einzige Wahrheitsquelle** – es gibt kein direktes Chatten zwischen Agenten, keine Message Queues oder glue code.

Die gesamte Koordination steckt in einer einzigen **SQLite-Datei**, die als Bus, Zustandspeicher und Audit-Log zugleich dient. Jeder Agent entspricht dabei im Grunde einem **Profil innerhalb von Hermes Agent**, wodurch unterschiedliche Agenten unterschiedliche Modelle und Aufgaben zugewiesen bekommen können.

Der zentrale Ablauf ist der **Dispatcher**, ein einziger wiederkehrender Loop:
1. Das Board enthält eine Karte mit Status „bereit".
2. Der Dispatcher **beansprucht** sie (stellt sicher, dass nie zwei Agenten dieselbe Karte greifen).
3. Er startet den zugewiesenen Agenten in einer **eigenen sauberen Workspace**.
4. Der Agent erledigt die Arbeit und markiert die Karte als „erledigt".
5. Der Loop läuft kontinuierlich – sogenanntes **Ticking**.

## Kapitel 3: Fortschrittliche Eigenschaften des Boards

Das Board unterstützt mehrere baulich „clevere" Merkmale, die den Workflow robust machen:

- **Automatisches Warten:** Eine Karte bleibt im Status „zu tun", bis ihre Eltern-Karten abgeschlossen sind, und befördert sich dann selbst auf „bereit".
- **Parallelität & Fan-out:** Eine Aufgabe kann sich in mehrere parallele Unteraufgaben verzweigen (z. B. drei Forschungsagenten nebeneinander). Eine Route-Aufgabe feuert automatisch, sobald **die letzte** Eltern-Aufgabe abgeschlossen ist.
- **Event-driven:** Der Workflow fließt selbstständig durch den Graphen – ohne Polling-Loops oder „Babysitting".
- **Selbstheilung:** Eine abgestürzte/verwaiste Aufgabe wird automatisch zurückgeholt und neu gestartet.
- **Auditierbar:** Jede Beanspruchung, jeder Kommentar und jede Fertigstellung wird vollständig protokolliert und ist später nachvollziehbar.

Laut Autor hatte die erste Version des Boards anfängliche Probleme, die mit den Updates behoben wurden; in seiner Nutzung funktionierte es stabil.

## Kapitel 4: Die Demo-Pipeline – von der Erkennung zum Deliverable

Als Demonstration entwarf der Autor einen Workflow zur Lösung dieses Problems: *Echte Schmerzpunkte von KI-Agenten-Nutzern finden und darauf reagieren.* Der Ablauf gliedert sich in **Detect → Validate → Route → Ship**, mit genau **einem menschlichen Gate (Freigabe)**.

**Agentenflotte (alles Profile auf einer Maschine):**
- **Zwei Scout-Agenten** für die Recherche: einer speziell auf X (mit Grok-Modell), einer für das Web (Reddit, YouTube, Web) – übrige nutzen GPT-5.5 oder ein beliebiges Modell.
- **Zentraler Orchestrator:** dient als „Richter und Fahrer", der die gesamte Pipeline steuert.
- **Worker:** Researcher, Analyst, Builder, Tester und Video Producer – die eigentliche Arbeit.

**Pipeline im Detail:**
1. **Scouts** (stündlich oder alle zwei Stunden, per Cron): recherchieren auf X, Web und Reddit.
2. **Orchestrator** nimmt die Berichte entgegen, entfernt Duplikate, bewertet anhand eines **Rubric** (Häufigkeit des Problems, Schmerzintensität, Lösbarkeit/Erklärbarkeit, Lösungslücke, strategischer Fit zum Kanal). Alles unter 65/100 wird archiviert und nicht weiterverfolgt.
3. **Researcher (drei parallel pro Issue):** verifizieren die Quelle, analysieren den Kontext und bestehende Lösungen.
4. **Orchestrator** entscheidet erneut: „Bauen wir ein Tool?", „Eignen wir es als Video-Idee?" oder „Archivieren wir es?".
5. **Analyst** (bei Build-Idee) synthetisiert die Infos; **Video Producer** (bei Video-Idee) forscht und erstellt eine Outline.
6. **Menschliches Gate per Telegram:** Vier Vorschläge warten auf Freigabe – mit Optionen „approve", „shelf" (ablegen) oder planen anpassen. Dies ist der einzige manuelle Eingriffspunkt.
7. Nach Freigabe: **Builder** baut (z. B. ein Python-Skript unter 500 Zeilen) und **Tester** testet; alternative **Video-Pipeline** erstellt Präsentationsfolien, Skript und Sprechernotizen. Lieferung erfolgt zurück ins Telegram (Code bzw. Folien + Skript).

**Konkretes Demo-Ergebnis der Live-Ausführung:**
- Ein **Build-Proposal**: „Codex VS Code Extension – Config-Camel-Approve-Settings weichen vom IDE-Verhalten ab". Der Builder erzeugte einen CLI-Validator (Python), der Kandidaten-`config.toml`-Pfade auf Linux/WSL/Windows prüft, Secrets redigiert und Policy-Werte protokolliert – alle Tests bestanden.
- Ein **Video-Proposal**: „Cloud-Code-Sub-Agenten scheitern, wenn viele MCP-Tools konfiguriert sind". Der Producer erstellte Folien, Skript und einen Fact-Check, der unter anderem den Levers: „Tool-Suche prüfen" und „nicht jedem Sub-Agenten jedes Tool geben" (Allow-List) empfiehlt.

**Live-Beobachtungen während des Runs:**
- Zeitgleich arbeiteten **18 Worker** ohne Konflikte parallel.
- In diesem einen Durchlauf wurden **97 Aufgaben** erledigt.
- Es trat sogar ein realer Fehler auf: Die ersten Folien wurden in temporäre Workspaces geschrieben. Das System erkannte dies **autonom** und regenerierte die Folien in einem persistenten Verzeichnis – ein demonstriertes Beispiel der eingebauten **Selbstheilung**.

## Kapitel 5: Veröffentlichung, Einordnung und Take-aways

Der Autor gibt an, diese komplette Workflow-Vorlage **quelloffen** als generalisierte Version veröffentlicht zu haben (Repo unter „Tonbi Studio / Hermes multi-agent workflow"). Die Vorlage folgt dem gleichen Grundpfad (Recherche → Bewertung → Entscheidung über Handlungspfad → menschliche Freigabe → Umsetzung), lässt sich aber auf beliebige Zwecke anpassen.

**Zentrale Empfehlungen des Autors:**
- Das menschliche Gate **beibehalten** – auch nach guter Recherche kommen Vorschläge durch, die keinen Sinn ergeben; das Gate spart Tokens und Geld.
- Die Scouts nicht zu häufig laufen lassen (eher ein- bis zweimal täglich statt stündlich).
- Ein deliverable (Tool oder Video) ist ein solider, recherchierter **Startpunkt**, muss aber vor Produktionseinsatz noch manuell nachgearbeitet („aufgepoliert") werden.
- Bei laufenden Gateway-/Orchestrator-Prozessen ein persistentes Terminal (z. B. tmux) verwenden.

---

## Fazit

Das Video demonstriert praxisnah, wie mit dem Hermes-Agent-Kanban-Board eine **dauerhafte, parallele und selbstheilende Multi-Agent-Pipeline** realisierbar ist, die ohne direkte Inter-Agenten-Kommunikation über eine einzige Board-Quelle koordiniert wird. Der gesamte Ablauf arbeitet autonom und kollisionsfrei, mit genau einem menschlichen Entscheidungspunkt. Die veröffentlichte, generalisierte Vorlage lädt zum Nachbau und zur Anpassung ein.

**Metadata:** Kanal „Tonbi's AI Garage" · Sprache: Englisch · Untertitel: Auto-generiert (Englisch) · Quelle: YouTube `EKVRqcpTT6s` · Liefert am Ende zwei konkrete, per Telegram zugestellte Deliverables als Nachweis der Funktion.