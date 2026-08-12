# Story 8 — Eine dauerhafte Identität mit eigenem Gedächtnis

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-8` |
| Profile | `inbox-triage`, `legal` |
| Mandant | `mailops` |
| Workspace-Art | `dir:` — derselbe Arbeitsraum in jedem Zyklus |
| Dauer | ca. 20 Minuten für zwei Zyklen |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Bisher war ein Profil eine **Rolle**, die für eine Karte gebraucht wurde. Hier
ist das Profil der **Agent**: eine benannte Identität, die jeden Zyklus auf
demselben Postfach für denselben Menschen arbeitet, mit eigener Stimme und
eigenem Gedächtnis.

```
   Zyklus 1 ──▶ MEMORY-NOTES.md ──▶ Zyklus 2 ──▶ MEMORY-NOTES.md ──▶ …
   inbox-triage                      inbox-triage
       │                                 │
       └──▶ Karte für @legal             └──▶ Karte für @legal
            (vom Worker selbst angelegt)
```

Es gibt **keinen Elternagenten**. Niemand delegiert an `inbox-triage` — das
Profil *ist* der Agent, es existiert über Läufe hinweg.

Zwei Dinge sollst du danach gesehen haben:

1. **Der Assistent wird besser**, weil er am Ende jedes Zyklus aufschreibt, was
   er gelernt hat, und es zu Beginn des nächsten wieder einliest.
2. **Er eskaliert, was er nicht entscheiden darf** — legt dafür mitten im Lauf
   selbst eine Karte für ein anderes Profil an und arbeitet weiter.

Warum kein reiner Cronjob? Cron gibt Zeitsteuerung, aber keinen
Übergabe-Mechanismus. Wenn `inbox-triage` einen Juristen braucht, routet das
Board die Aufgabe; ein Cronjob allein kann das nicht.

---

## Schritt 8.1 — Setup

```bash
cd "Story 8 - Digital Twin"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt Board `kanban-story-8`, die Profile `inbox-triage` und `legal`
(jeweils mit `SOUL.md`, Beschreibung, `config.yaml`) und `workspace/` aus
`seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an — `setup.sh` schreibt daher alle vier
Modell-Schlüssel aus deiner Root-Konfiguration ins Profil.

### Der Arbeitsraum

```
workspace/mailops/
├── PROFILE.md            wer der Eigentümer ist, wie er schreibt, wer zählt
├── MEMORY-NOTES.md       was der Assistent gelernt hat — zu Beginn fast leer
├── ESKALATIONSREGELN.md  was er NICHT entscheiden darf
├── inbox/zyklus-1/       fünf Nachrichten
├── inbox/zyklus-2/       fünf Nachrichten, teils dieselben Absender
├── drafts/               Ziel: Antwortentwürfe (nie versendet)
├── digests/              Ziel: der Zyklus-Digest
├── legal/                Ziel: die Einschätzung des @legal-Profils
└── logs/journal.jsonl    Ziel: eine Zeile je Entscheidung
```

Drei Dateien tragen die Story:

**`PROFILE.md`** — die Identität, für die geschrieben wird:

```markdown
**Anders Roth**, Geschäftsführer einer 40-köpfigen Softwareagentur.

## Wer für ihn zählt
| Person | Verhältnis | Reaktionszeit |
| Britta Kellermann | Prokuristin | sofort |
| Kunden mit laufendem Projekt | zahlend | am selben Tag |
| Neukundenanfragen mit Budgetangabe | Vertrieb | am selben Tag |
| Kaltakquise, Newsletter | — | ignorieren |

## Wie er schreibt
Kurz. … Kein „ich hoffe, es geht Ihnen gut". Er kommt im ersten Satz zur Sache
und nennt am Ende einen konkreten nächsten Schritt mit Datum.
```

**`MEMORY-NOTES.md`** — zu Beginn leer:

```markdown
## Absender
_(noch nichts gelernt — erster Zyklus)_

## Muster
_(noch nichts gelernt)_

## Korrekturen
_(noch nichts)_
```

**`ESKALATIONSREGELN.md`** — die Grenze der Zuständigkeit:

```markdown
## An `legal` eskalieren
- Vertragsentwürfe, Klauseln, AGB, NDAs, Auftragsverarbeitungsverträge
- Haftung, Gewährleistung, Vertragsstrafen, Kündigungsfristen
…
Wie: eine Karte für das Profil `legal` anlegen (`kanban_create`), mit dem
vollständigen Sachverhalt im Body. Danach **weiterarbeiten** — die Eskalation
hält den Zyklus nicht an.
```

In `inbox/zyklus-1/` liegt eine Nachricht, die genau darunter fällt:

```
Betreff: NDA vor Angebotsphase — Rückfrage zu §7

  „Der Auftragnehmer haftet für jeden Verstoß gegen diese Vereinbarung mit
   einer Vertragsstrafe in Höhe von 250.000 EUR je Einzelfall, unabhängig
   vom Verschulden und ohne Anrechnung auf Schadensersatzansprüche."

Unsere Rechtsabteilung besteht auf dieser Formulierung. Können Sie das so
mitgehen?
```

---

## Schritt 8.2 — Zyklus 1

```bash
./create-tasks.sh 1
./pump.sh
```

Eine einzige Karte:

```console
▶ t_49fdbf13  ready     inbox-triage         [mailops]  Posteingang sichten — Zyklus 1
```

Nach knapp fünf Minuten stehen **zwei** Karten auf dem Board — die zweite hat
der Worker selbst angelegt:

```console
✓ t_49fdbf13  done      inbox-triage  [mailops]  Posteingang sichten — Zyklus 1
● t_b52a517c  running   legal         [mailops]  Rechtliche Pruefung: NDA §7 Vertragsstrafe Seehafen Logistik
```

### Die Eskalation

Das ist kein Befehl von dir. Der Worker hat mitten im Lauf `kanban_create`
aufgerufen:

```python
# Worker-Tool-Calls — KEINE Befehle für dein Terminal
kanban_create(
    title="Rechtliche Pruefung: NDA §7 Vertragsstrafe Seehafen Logistik",
    assignee="legal",
    parents=["<diese Karte>"],
    workspace_kind="dir",
    workspace_path="…/workspace/mailops",
    body="<vollständiger Sachverhalt, Dateiname der Nachricht, konkrete Frage>",
)
# … und dann den REST des Posteingangs weiter abgearbeitet
```

`kanban_create` kennt `title`, `assignee`, `body`, `parents`, `tenant`,
`priority`, `workspace_kind`, `workspace_path`, `project`, `triage`,
`idempotency_key`, `max_runtime_seconds` und `initial_status`. Der Dispatcher
startet die neue Karte im nächsten Tick.

**Der Zyklus hielt dabei nicht an.** Der Digest aus Zyklus 1, real entstanden:

```markdown
# Digest Zyklus 1

## Braucht dich
- **Britta / Freigabe Angebot Seehafen Logistik** (01-britta-freigabe.txt)
  Britta wartet seit Freitag auf deine Freigabe: 148 Tage, Festpreis 214.000 EUR.
  Sag bis Dienstag Bescheid, sonst schickt sie es so raus. Preiszusage — deine
  Entscheidung, kein Entwurf.
- **Nordhost / Preisanpassung Hosting** (05-lieferant-preise.txt)
  Managed-Kubernetes steigt zum 01.10. um 9 %. Sonderkündigungsrecht bis
  **31.08.** — Kostenentscheidung, kein Entwurf.

## Entwuerfe liegen bereit
- **Martin Saalfeld, Birkholz Armaturen** (04-neukunde-budget.txt)
  Neukundenanfrage mit Budget (300–400k EUR). → drafts/04-neukunde-budget.antwort.md

## Eskaliert
- **Seehafen Logistik / NDA §7** (02-seehafen-nda.txt)
  Gegenpartei besteht auf verschuldensunabhängiger Vertragsstrafe von
  250.000 EUR je Einzelfall ohne Anrechnung. An legal eskaliert.
  → Karte t_b52a517c

## Ignoriert
- **DevSummit 2026 Gold-Sponsoring** (03-konferenz-werbung.txt)
  Konferenzwerbung/Kaltakquise. Entsprechend Profil ignorieren.
```

Der Assistent hat die Preiszusage **nicht** entworfen (Anders' Entscheidung),
die Vertragsklausel **nicht** kommentiert (an `legal`), die Kaltakquise
weggelassen — und für den einen Fall, der ihm zusteht, einen Entwurf in Anders'
Stimme geschrieben.

### Was `legal` daraus macht

```bash
hermes kanban --board kanban-story-8 runs t_b52a517c
cat workspace/mailops/legal/02-seehafen-nda.assessment.md
```

```markdown
# Rechtliche Pruefung — Seehafen Logistik NDA, §7 Vertragsstrafe

Karte: t_b52a517c
Sachverhalt: inbox/zyklus-1/02-seehafen-nda.txt

## 1. Die zu pruefende Klausel (wörtlich)
> „… Vertragsstrafe in Hoehe von 250.000 EUR je Einzelfall, unabhaengig vom
> Verschulden und ohne Anrechnung auf Schadensersatzansprueche."

Drei toxische Elemente:
  (a) verschuldensunabhaengig,
  (b) ohne Anrechnung auf Schadensersatz (kumulativ statt ersetzend),
  (c) keinerlei Deckelung.
```

Die Karte hat als Elternteil die Triage-Karte — die Kette ist damit im Board
nachvollziehbar, nicht nur im Digest.

---

## Schritt 8.3 — Was der Assistent gelernt hat

Das ist der Kern der Story. Vergleiche `MEMORY-NOTES.md` vor und nach dem
ersten Zyklus:

```bash
cat workspace/mailops/MEMORY-NOTES.md
```

Real entstanden:

```markdown
## Absender

- **Britta Kellermann** (Prokuristin, sofort): schreibt knapp, setzt klare
  Fristen ("Wenn du bis Dienstag nichts sagst, schicke ich es raus"). Erwartet
  Freigaben/Entscheidungen von Anders zu Preisen. Dringend, Tagessache.
- **Seehafen Logistik (Petra Dahlmann)**: laufendes Projekt/Angebotsphase mit
  NDA; Rechtsabteilung besteht hart auf Klauseln. Jede Vertragsformulierung →
  sofort an legal, nicht selbst kommentieren.
- **Birkholz Armaturen (Martin Saalfeld, Leiter IT)**: Neukunde mit Budget
  (300-400k EUR) … Vertriebschance — antworten am selben Tag.

## Muster

- Preiszusagen gehören immer zu Anders → '## Braucht dich', kein Entwurf.
  Auch wenn der Absender eine Frist setzt.
- Vertragsformulierungen von Gegenparteien → sofort legal, weiterarbeiten.
- Neukunden MIT Budgetangabe → Antwort am selben Tag, Entwurf.
- Konferenzwerbung/Kaltakquise → ignorieren.
```

Aus fünf Nachrichten hat der Assistent vier Regeln abgeleitet und drei
Absender charakterisiert. **Diese Datei liegt im Arbeitsraum, nicht im Board** —
sie überlebt jedes `teardown.sh`.

---

## Schritt 8.4 — Zyklus 2: derselbe Agent, klügere Arbeit

```bash
./create-tasks.sh 2
./pump.sh
```

Der zweite Posteingang enthält teils dieselben Absender, teils neue Lagen: eine
Produktivstörung bei einem laufenden Kunden, eine Folgeanfrage zum selben NDA,
Brittas Frist läuft heute ab.

Real gemessen:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  completed     inbox-triage            5m  2026-08-10 10:42   ← Zyklus 1
  1  completed     legal                   3m  2026-08-10 10:47   ← Eskalation Zyklus 1
  1  completed     inbox-triage            7m  2026-08-10 10:51   ← Zyklus 2
  1  completed     legal                   8m  2026-08-10 10:59   ← Eskalation Zyklus 2
```

Was im zweiten Zyklus anders ist:

**Er trägt Offenes über den Zyklus hinweg mit** — obwohl in Zyklus 2 keine
Nachricht von Nordhost kam:

```markdown
- **Nordhost / Preisanpassung Hosting** (weiterhin offen aus Zyklus 1)
  Sonderkündigungsrecht bei der 9-%-Erhöhung läuft bis 31.08. …
  (Kein neuer Eingang diesen Zyklus, bleibt offen.)
```

**Er erkennt die Verschärfung**, weil er Brittas Muster kennt:

```markdown
- **Britta / Freigabe Angebot Seehafen Logistik** (01-britta-nachfrage.txt)
  Dringend — Britta setzt heute eine HARTE Frist: "Wenn ich bis 12 Uhr nichts
  höre, schicke ich es raus." … Heute VORMITTAG handeln.
```

**Er eskaliert erneut, aber nicht redundant** — die neue `legal`-Karte
verweist auf die alte:

```markdown
## Eskaliert
- **Seehafen Logistik / NDA §7 — Folgeanfrage** (04-seehafen-nachfrage.txt)
  Petra Dahlmann signalisiert: Spielraum bei der Höhe der Vertragsstrafe,
  NICHT beim Verschuldensmaßstab. Nichts selbst kommentiert — an legal
  eskaliert, weitergearbeitet.
  → Karte t_bc6e2e4f (Eltern: diese Karte; Bezug: t_b52a517c)
```

Und dieselbe Regel steht danach im Gedächtnis:

```markdown
- Vertragsformulierungen von Gegenparteien → sofort legal, weiterarbeiten.
  Bei einer Folgeanfrage zum SELBEN Vertrag neue legal-Karte anlegen, im Body
  auf das bestehende Assessment (legal/02-seehafen-nda.assessment.md) und die
  Vorgänger-Karte verweisen — so bleibt die Eskalation je Zyklus nachvollziehbar.
```

**Und er korrigiert sich selbst.** Der auffälligste Eintrag steht unter
`## Korrekturen` bzw. `## Muster` — hier hat der Assistent einen eigenen Fehler
aus Zyklus 2 protokolliert:

```markdown
- Journal als APPEND führen; nie per write_file komplett neu schreiben,
  sonst gehen die Einträge früherer Zyklen verloren (Zyklus 2 Fehler).
```

Das ist genau der Unterschied zwischen einer Identität und einem Worker: ein
Wegwerf-Agent hätte denselben Fehler in Zyklus 3 wiederholt.

Kontrolle, dass das Journal vollständig ist:

```bash
wc -l workspace/mailops/logs/journal.jsonl
```

```console
      10 workspace/mailops/logs/journal.jsonl
```

Zehn Zeilen — fünf je Zyklus, keine verloren.

---

## Schritt 8.5 — Wo das Gedächtnis wirklich liegt

Drei Ebenen, die man auseinanderhalten muss:

| Ebene | Ort | Was drinsteht |
|---|---|---|
| **Arbeitsraum** | `workspace/mailops/MEMORY-NOTES.md` | was der Assistent über *dieses Postfach* gelernt hat |
| **Profil** | `~/.hermes/profiles/inbox-triage/` | `SOUL.md`, eigene `memories/`, eigene Sitzungen — die Identität selbst |
| **Board** | `kanban-story-8` | wer wann was entschieden hat — die Audit-Spur |

```bash
ls ~/.hermes/profiles/inbox-triage/
```

```console
.env  SOUL.md  config.yaml  cron/  home/  logs/  memories/  profile.yaml  …
```

Jedes Profil hat ein eigenes `HERMES_HOME` mit eigenem `memories/`. Für dieses
Tutorial liegt das fachliche Gedächtnis bewusst **im Arbeitsraum**, nicht im
Profilverzeichnis: so kannst du es lesen, vergleichen und zurücksetzen.

⚠ **`$HERMES_TENANT` trennt Gedächtnis nicht von selbst.** Der Dispatcher setzt
die Variable; ob ein Worker danach trennt, ist eine Konvention, die der
Task-Body oder eine Skill durchsetzen muss.

---

## Das solltest du sehen

```bash
hermes kanban --board kanban-story-8 list --tenant mailops
./reset-workspace.sh --diff
```

```console
✓ t_49fdbf13  done  inbox-triage  [mailops]  Posteingang sichten — Zyklus 1
✓ t_b52a517c  done  legal         [mailops]  Rechtliche Pruefung: NDA §7 …
✓ t_b89f335e  done  inbox-triage  [mailops]  Posteingang sichten — Zyklus 2
✓ t_bc6e2e4f  done  legal         [mailops]  Rechtliche Pruefung: … Folgeanfrage (Zyklus 2)
```

- **Vier** Karten, obwohl du nur **zwei** angelegt hast — zwei hat der
  Assistent selbst erzeugt.
- `MEMORY-NOTES.md` ist gewachsen und enthält eine Selbstkorrektur.
- `digests/zyklus-1.md` und `zyklus-2.md`, `drafts/` mit drei Entwürfen,
  `legal/` mit den Einschätzungen.
- `logs/journal.jsonl` mit zehn Zeilen.
- **Kein einziger Entwurf zu einer Preiszusage oder Vertragsklausel** — die
  Eskalationsregeln haben gehalten.

---

## Aufräumen

```bash
hermes kanban --board kanban-story-8 list --tenant mailops --json \
  | jq -r '.[].id' | xargs hermes kanban --board kanban-story-8 archive
./reset-workspace.sh          # setzt auch MEMORY-NOTES.md auf leer zurück
```

Willst du das Gelernte behalten und nur die Postfächer zurücksetzen, kopiere
`MEMORY-NOTES.md` vorher weg — `reset-workspace.sh` überschreibt sie mit dem
leeren Stand aus `seed/`.

Alles entfernen:

⚠ **Vorher die Desktop App schließen** (oder im Board-Switcher auf `Default`
schalten). Solange sie dieses Board anzeigt, pollt der Zähler in der
Statusleiste es weiter — auch ohne offene Kanban-Seite — und legt es nach dem
Löschen innerhalb von 60 s als leeres Board neu an.

```bash
./teardown.sh                  # Board + Profile + Arbeitsdateien
./teardown.sh --keep-profiles  # Board + Arbeitsdateien
./teardown.sh --files-only     # nur Arbeitsdateien
```

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --workspace dir:<abs>` | Derselbe Arbeitsraum in jedem Zyklus |
| `… --idempotency-key triage-zyklus-N` | Ein Lauf je Zyklus |
| `… --max-runtime 20m` | Laufzeitdeckel; danach SIGTERM/SIGKILL und erneut in die Queue |
| `hermes kanban list --tenant mailops` | Alle Karten dieser Identität |
| `hermes kanban runs <id>` | Versuchshistorie |
| `hermes kanban context <id>` | Was der Assistent im nächsten Zyklus sieht |
| `hermes -p inbox-triage skills list` | Was das Profil an Skills mitbringt |
| `hermes profile show inbox-triage` | Profildetails, Modell, Beschreibung |
| **Worker-Werkzeug** `kanban_create(assignee=…, parents=[…])` | Eskalation an ein anderes Profil, mitten im Lauf |
