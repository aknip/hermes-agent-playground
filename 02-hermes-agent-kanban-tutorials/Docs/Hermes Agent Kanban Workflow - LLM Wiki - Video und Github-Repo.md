# Multi-Agent-Workflow zur Pflege eines LLM-Knowledge-Base in Hermes Agent

Quelle:
https://www.youtube.com/watch?v=hbKvO5MWq08
https://github.com/tonbistudio/llm-wiki
Basiert auf:
https://www.youtube.com/watch?v=EKVRqcpTT6s&t=881s
https://github.com/tonbistudio/hermes-multi-agent-workflow

---

## Abstract

Das Video stellt einen wiederverwendbaren Multi-Agent-Workflow vor, mit dem sich eine LLM-Wiki beziehungsweise eine Knowledge Base (im Karpathy-Stil) in Hermes Agent automatisiert aktuell und sauber halten lässt. Es ist die Fortsetzung einer früheren Video-Reihe, in der ein Multi-Agent-Framework über ein Compound-Board (Kanban) in Hermes Agent aufgebaut wurde. Dargestellt wird eine Flotte aus spezialisierten Agenten – Scout, Orchestrator, Researcher, Ingestor und Linter –, die über ein gemeinsames Board und einen Bewertungs-Loop mit menschlichem Gate zusammenarbeiten. Der Kern des Beitrags ist eine Hands-on-Demo: Ausgehend von einem offen lizenzierten Vorlagen-Repository wird Schritt für Schritt gezeigt, wie der Workflow aufgebaut wird, welche Dateien geändert werden müssen und wie der vollständige Ablauf von der Scout-Suche über Bewertung, Ingest und Linting bis zum Git-Commit funktioniert. Abschließend wird demonstriert, dass statt teurer proprietärer Modelle auch freie bzw. Open-Weight-Modelle (Nvidia Nemotron 3 Ultra, MiniMax M3) die Aufgaben zuverlässig ausführen.

---

## Kapitel 1: Motivation und Grundkonzept

Die manuelle Pflege einer Wissensbasis ist aufwändig. Statt einen Agenten bei jeder Arbeit an einem Thema sämtliche Informationen durchlaufen zu lassen, baut der Autor einmalig eine Knowledge Base auf und aktualisiert sie in regelmäßigen Abständen. Dies liefert im Ergebnis deutlich genauere und schnellere Antworten ohne Halluzinationen und ohne veraltete Informationen – besonders wichtig für ein sich rasch weiterentwickelndes Produkt wie Hermes Agent, das nahezu täglich Updates erhält.

Die Knowledge Base ist in Obsidian organisiert und strukturiert:
- **Raw Sources:** Rohmaterial wie offizielle Hermes-Agent-Dokumentation, Changelogs, GitHub-Informationen und Community-Ressourcen (Plugins, Skills, MCP-Server, Integrationen, Gotchas und Antworten auf spezifische Detailfragen).
- **Wiki:** Die aufbereitete, strukturierte Organisationsform der Inhalte (z. B. ein Bereich zum Memory-System), die für kommende Videos und die Masterclass genutzt wird.

Wegen der ständigen Notwendigkeit von Aktualisierung, Linting (Entfernen veralteter/obsoleter Informationen) und Begrenzung der Größe ist die manuelle Pflege mühsam. Genau dafür eignet sich ein Multi-Agent-Workflow.

Das Grundkonzept in Kürze:
- **Scout** beobachtet neue Hermes-Releases, Transkripte, Dokumente und sonstige neue Informationen.
- **Orchestrator** bewertet, ob das neue Wissen es wert ist, aufgenommen zu werden.
- **Ingestor** schreibt es in die Wiki (Zusammenfassungen, Konzepte, Verlinkungen).
- **Menschliche Freigabe** (Human Gate) als Kontrollinstanz, um Token nicht für offensichtlich falsche Inhalte zu verschwenden.
- **Linter** validiert, danach wird die Änderung committet.

Zwei Elemente machen das System funktionsfähig: ein **gemeinsames Board** und ein **Bewertungs-Loop mit menschlichem Gate**.

---

## Kapitel 2: Architektur der Agentenflotte

Die Flotte unterscheidet sich von der früheren Pain-Point-Demo durch eine zusätzliche Spezialisierung. Die Rollen im Überblick:

- **Knowledge Base Scout:** Sucht nach Releases, neuen Transkripten, Dokumenten und ähnlichen Neuigkeiten.
- **Orchestrator:** Gleiche Rolle wie zuvor – der bewertende und steuernde Treiber, der die gesamte Pipeline führt.
- **Researcher:** Verifiziert neue Informationen und ermittelt, welche Seiten betroffen sind.
- **Ingestor:** Schreibt die Wiki und fasst Konzepte sowie Entitäten zusammen.
- **Linter:** Validiert Format, Links und Aktualität (Freshness).

Der Autor plant, die Worker-Agenten mit unterschiedlichen Modellen zu betreiben: Der Scout soll Grok verwenden (um auch X durchsuchen zu können), der Orchestrator bleibt bei GPT als Haupttreiber, für weitere Worker sollen offene Modelle zum Einsatz kommen. Alle Agenten laufen über das gemeinsame Kanban-Board und kommunizieren nicht direkt miteinander.

### Pipeline-Ablauf

1. Der **Scout** findet Informationen und übergibt sie an den **Orchestrator**.
2. Der **Orchestrator** prüft: Wurde das bereits abgedeckt? Lohnt es sich? Er bewertet nach einem Rubrik-Score.
3. Bei bestandenem Rubrik-Score werden **zwei Researcher-Agenten parallel** eingesetzt: einer verifiziert die Informationen im Repository, der andere ermittelt die betroffenen Seiten.
4. Der **Orchestrator** routet und entscheidet, ob es sich um eine neue Seite, ein Update, einen Konflikt oder ablegbare Information (Shelve) handelt, und plant die Änderungen (welche Seiten geschrieben bzw. aktualisiert werden).
5. **Human Gate:** Der Mensch genehmigt oder legt die Änderung ab.
6. Je nach Entscheidung schreibt der **Ingestor** eine neue Seite bzw. mehrere Seiten (Konzept-/Entitäten-Seiten) oder aktualisiert bestehende Seiten.
7. Der **Linter** prüft am Ende alles: Format, lebende Links, korrekte Abschnitte und Aktualität. Dadurch kann veraltete Information entfernt werden.
8. Der **Orchestrator** committet die Änderungen (Git-Commit, Aktualisierung von Index und Logs).

### Bewertungsraster (Judging Score)

Die Bewertung der Quelle erfolgt anhand von fünf Kriterien:
- **Novelty** (Neuheitsgrad)
- **Source Confidence** (Vertrauenswürdigkeit der Quelle)
- **Scope Fit** (direkter Bezug zu Hermes Agent)
- **Version Relevance** (Versionsrelevanz)
- **Clarity Gain** (Klarheitsgewinn)

Zum Hinzufügen muss ein Schwellenwert von **65** erreicht werden. Ist ein Konzept nicht neu, die Quelle unsicher oder der Bezug zu Hermes Agent nicht direkt, wird der Eintrag übersprungen.

### Entscheidungstypen

Der Orchestrator – letztlich der Mensch am Gate – entscheidet zwischen:
- **Neue Seite:** Noch nichts abgedeckt.
- **Update:** Seite existiert, neue Informationen verfeinern sie.
- **Konflikt:** Neue Informationen widersprechen einer bestehenden Seite – dieser Fall muss hervorgehoben werden.
- **Shelve:** Zurücklegen.

Ein menschliches Gate ist durchgehend wichtig. Es gibt sogar **zwei Gates**: eines zur Freigabe von Hinzufügungen/Updates (läuft über Telegram, Genehmigung per kurzem "approve") und ein zweites zur Freigabe von Prunes (dem Löschen von Wissen), weil das Löschen von Informationen bewusst vom Menschen entschieden werden muss.

---

## Kapitel 3: Vorbereitung und benötigte Assets

Der Autor nutzt bereits vorhandene, offen lizenzierte Assets:
- ein **Hermes-Multi-Agent-Workflow-Template** (open source auf Tombi Studio GitHub)
- eine bestehende **Hermes-Agent-Knowledge-Base**
- sowie das **Tomb Studio LLM Wiki**-Template, mit dem sich eine eigene Wiki leicht aufbauen lässt.

Die Einrichtung findet teils in Claude Code (als unterstützender Helfer für Skripterstellung) und teils direkt in Hermes Agent statt. Der größte Teil ist organisatorischer Natur, da die Assets bereits vorhanden sind.

### Integration Boundary / Sicherheitsmodell

- Der **Workspace** ist das reale Hermes-KB-Git-Repository am KB-Pfad, **isoliert auf einem Branch pro Ingest**.
- Diese Sicherheit ergibt sich aus Branches, Gates und Git – der gesamte Ablauf ist vollständig umkehrbar.
- Die **Raw Sources werden nie angefasst**, sodass bei versehentlichem Einspeisen falscher Informationen jederzeit zurückgegangen werden kann.

### Die zentrale Datei: die AGENTS.md (hier "Claude MD" genannt)

Diese eine Markdown-Datei übernimmt drei Aufgaben:
1. Der **Ingestor** schreibt Seiten gemäß dieser Datei.
2. Der **Linter** validiert gegen sie.
3. Sie beschreibt den automatisierten Workflow selbst.

Dadurch benötigt diese Domäne kaum neue Logik. Der entscheidende Punkt: Der **Verifikations-Linter ist deterministischer Code**, der aus der Claude-MD-Datei abgeleitet wird und daher eigens gebaut werden muss.

### Was geändert werden muss

Viele Komponenten bleiben unverändert und können aus dem offenen Template übernommen werden (Engine, CLI, das ganze Hermes-KB-Repository, Proposal Actions). Konkret geändert werden:
- **triage.yaml** – wird auf die Knowledge-Base-Domäne umgestellt (Bewertung nach Quellen, "Worth-Ingesting"-Rubrik, zwei Research-Linien, Routen-/Ingest-Map).
- **Ingest-Regeln** – angepasst, da es um eine Wissensbasis und nicht um den Pain-Point-Judge geht.
- Neue Dateien: das Python-Skript **`knowledge_base_lint`** (Verifikations-Linter) und **`KB git`**, ein dünner Git-Helfer, damit die Commit-Phase deterministisch ist und der Agent nicht frei mit Git auf einem echten Repository hantiert.
- **Vier Skills** für die Sub-Agenten, die jeweils ein eigenes Hermes-Profil erhalten und klare Anweisungen zu ihrer Aufgabe brauchen.
- **Umgebungsvariablen** sind nicht erforderlich (keine zusätzlichen API-Keys nötig).

### Besonderheit: die Konflikt-Route

Der bemerkenswerteste Teil ist der Konfliktfall: Neue Informationen, die einer bestehenden Seite widersprechen, müssen vom Menschen entschieden werden. Das Erkennen solcher Konflikte ist die eigentliche Bewertungsarbeit; alles andere sind deterministische Linter-Checks. Diese Konflikterkennung muss gegebenenfalls nachjustiert werden.

---

## Kapitel 4: Umsetzung Schritt für Schritt

Die Umsetzung erfolgt phasenweise:

1. **Template klonen** und zuerst den **KB-Linter** bauen (in Claude Code).
2. **Linter testen:** Es wurden keine False Positives auf der Testseite festgestellt; der Linter fand eine Reihe toter bzw. Stub-Links, die nicht existieren, sowie einige Frontmatter-/Abschnittsprobleme. Dies ist genau das, was ein Wartungs-Linter aufdecken soll, um die Knowledge Base gesund zu halten.
3. Das Verzeichnis in ein **Git-Repository** umwandeln (es war noch kein echtes Git-Repo).
4. Den **KB-git-Helfer** (Python-Skript) für den Commit-Schritt bauen.
5. **triage.yaml**, die vier Skills, einige Templates und die Seitenformat-Spezifikationen erstellen.
6. **Modellauswahl für Worker:** Der Autor wechselt die Modelle der Worker über die OpenRouter-API: **Grok** für den Scout, **Nvidia Nemotron 3 Ultra** (frei, zum Zeitpunkt des Videos neu) für Linter und Researcher sowie **MiniMax M3** (frisch veröffentlicht) für den Ingestor. So soll sich zeigen, ob offene Modelle im Workflow einsetzbar sind.
7. **Fünf Profile erstellen** (eines pro Agent) mit den jeweiligen Modell-Routen; einige benötigen Umgebungsvariablen mit dem OpenRouter-API-Key.
8. Ein **Runbook** wird von Claude erstellt und an Hermes übergeben, das die restliche Umgebung – Profile, Tests – eigenständig einrichtet.

### Übergang zu Hermes Agent

Im Hermes-TUI wird Hermes angewiesen, das Runbook zu lesen und die Anweisungen auszuführen. Dabei greift ein zuvor erstellter Custom-Skill ("Hermes Workflow Operations") für ähnliche Workflows. Ein neues Board für die LLM-Wiki-Knowledge-Base wird angelegt. Der einzige verbleibende manuelle Schritt ist das Hinterlegen von API-Keys (z. B. Grok-OAuth für den KB-Scout und die OpenRouter-Keys), die der Autor nicht über den Chat an Hermes weitergeben möchte.

---

## Kapitel 5: Live-Demo des Ablaufs

Der praktische Durchlauf zeigt den kompletten automatiserten Prozess:

- Der **Scout** führt den Sweep durch (beim Betrieb als Cron-Job wird genau dieses Scout-Profil getriggert). Die erste Karte "Intake" erscheint auf dem Board.
- Der **Orchestrator** nimmt das Update auf; es sind mehrere Updates seit der letzten manuellen Pflege vorhanden (zwei Patch-Releases und das neue Velocity-Release **Version 15**).
- Zahlreiche betroffene Seiten werden ermittelt; bis zu sechs Researcher-Agenten laufen parallel (ausgeführt vom **Nemotron**-Modell).
- Ein zentraler Beweis für die Funktionsfähigkeit: Der Orchestrator **shelved das Version-15-Release**, weil die Knowledge Base es angeblich bereits enthielt. Der Autor erinnerte sich anders, hatte es aber tatsächlich schon manuell aktualisiert – die **Deduplizierung funktioniert**.
- Für zwei verbleibende Patch-Releases wird eine Ingest-Proposal erstellt: Der Ingest-Score von **89** wird ausgewiesen, betroffen sind einige Seiten, der Index bleibt unverändert. Der Autor genehmigt mit "approve".
- Der **Ingestor** (MiniMax M3) schreibt die Wiki-Seiten – inklusive einer Zusammenfassung der Patch-Details. Wichtig: Ingest bedeutet nicht bloßes Kopieren der Notizen, sondern Lesen, Zusammenfassen und Verarbeiten, damit die Inhalte später für den Agenten schnell und effizient zugänglich sind.
- **Konkurrenzschutz:** Zwei Ingestoren arbeiteten an derselben Seite. Der Workflow pausierte den zweiten Ingestor automatisch ("paused by operator"), um gleichzeitige Schreibvorgänge auf der geteilten Knowledge Base zu vermeiden, und setzte ihn nach dem Commit des ersten fort.
- Der **Linter** validiert die gesamte Knowledge Base nach dem Update und entfernt veraltete Informationen.
- Die Änderungen werden in das lokale Git committet; zur Freigabe des **Merges in main** ist eine letzte menschliche Freigabe nötig. Beide Genehmigungen werden erteilt und landen in main.
- Das Ergebnis lässt sich in der Knowledge Base prüfen: Die Patches zum Release 15 sind mit detaillierten Änderungszusammenfassungen eingepflegt.

### Kosten und Modellbewertung

Der Ingest der Seiten über OpenRouter mit MiniMax kostete rund **95 Cent**. Beide getesteten offenen Modelle – MiniMax M3 und Nemotron – arbeiteten über die gesamte Demo ohne Fehler und erfüllten ihre Aufgaben zuverlässig. Damit ist belegt, dass für diesen Workflow keine teuren proprietären Modelle erforderlich sind; frei nutzbare bzw. Open-Weight-Modelle genügen.

---

## Kapitel 6: Ausblick und geplante Erweiterungen

Aktuell beobachtet der Scout nur Informationen vom YouTube-Kanal des Autors sowie offizielle GitHub-Releases. Künftig soll er um weitere Quellen erweitert werden: Community-Ressourcen, X-Posts und grundsätzlich alles Neue rund um Hermes Agent.

Der Autor verfolgt mit Wissensbasen ein größeres Projekt – im Forschungsprozess entsteht die Idee, die "perfekte" Knowledge Base zu entwickeln, die für Agenten und Modelle aller Art leicht lesbar und effizient verarbeitbar ist. Geplant ist, Wissensbasen zu hosten: Die meisten kostenlos, ergänzt um einen Premium-Service mit individuell erstellten und gepflegten Wissensbasen, angebunden über MCP-Server. Der Arbeitstitel lautet vorläufig *"Cyberbrain"* (angelehnt an Ghost in the Shell) – der Autor sucht allerdings noch nach einem passenderen Namen und lädt die Community zu Vorschlägen ein.

---

## Fazit

Der Beitrag zeigt einen weitgehend operationalen Multi-Agent-Workflow zur automatisierten Pflege einer LLM-Wissensbasis in Hermes Agent. Kombiniert werden ein gemeinsames Kanban-Board, ein Bewertungs-Loop mit menschlichem Gate und eine Reihe spezialisierter Agenten (Scout, Orchestrator, Researcher, Ingestor, Linter). Der autoritative Kern besteht aus einer einzigen AGENTS-MD-Datei plus einem deterministischen Linter-Skript. Die Demo belegt sowohl die Funktionsfähigkeit (Deduplizierung, Konflikt-/Konkurrenzschutz, automatisierter Commit) als auch die Kosteneffizienz durch offene Modelle. Beide genutzten Vorlagen (Hermes-Multi-Agent-Workflow und LLM-Wiki) sind open source und ermöglichen eine einfache eigene Nachnutzung.