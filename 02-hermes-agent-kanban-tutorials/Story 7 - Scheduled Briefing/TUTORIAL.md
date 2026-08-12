# Story 7 — Wiederkehrendes Briefing auf einem langlebigen Vault

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-7` |
| Profile | `scout`, `editor`, `publisher` |
| Mandant | `briefing` |
| Workspace-Art | `dir:` — ein **langlebiger** Vault, kein Wegwerf-Verzeichnis |
| Dauer | ca. 20 Minuten für zwei Ausgaben |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Etwas, das **jeden Tag** läuft, auf einem Ordner, der **bleibt**. Nicht ein
Auftrag mit Anfang und Ende, sondern eine Zeitleiste, an die jede Ausgabe
angehängt wird.

```
   cron (tokenfrei)
        │
        ▼
   scout ──▶ editor ──▶ publisher
   sammelt   kürzt      schreibt die Ausgabe
                        und fortschreibt Index + Journal
```

Der eigentliche Prüfstein liegt in **Ausgabe 2**: der zweite Quellabwurf
enthält absichtlich zwei Meldungen, die schon in Ausgabe 1 standen. Wenn die
Pipeline ihren eigenen Verlauf liest, kommen sie nicht wieder.

Warum überhaupt ein Board und kein reiner Cronjob? Ein Cronjob gibt dir
Zeitsteuerung — aber keinen Übergabepunkt, keinen Teilfortschritt, keine
Historie, und keine Möglichkeit, an Tag 3 mittendrin einzugreifen. Genau das
sind die vier Dinge, die diese Story zeigt.

---

## Schritt 7.1 — Setup

```bash
cd "Story 7 - Scheduled Briefing"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh install-cron.sh scripts/briefing-tick.sh
./setup.sh
```

Das legt Board `kanban-story-7`, die drei Profile (jeweils mit `SOUL.md`,
Beschreibung, `config.yaml`) und `workspace/` aus `seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an, `hermes -p <profil> config set …`
schon — deshalb schreibt `setup.sh` alle vier Modell-Schlüssel aus deiner
Root-Konfiguration ins Profil.

```bash
hermes kanban --board kanban-story-7 assignees   # scout, editor, publisher: ON DISK = yes
```

### Der Vault

```
workspace/vault/
├── READER-PROFILE.md   für wen geschrieben wird — die Relevanzgrundlage
├── INDEX.md            Verzeichnis aller Ausgaben, wird fortgeschrieben
├── journal.jsonl       eine Zeile je Lauf — was die Pipeline schon getan hat
├── sources/2026-08-10/ der Rohabwurf von Tag 1 (drei Dateien)
├── sources/2026-08-11/ der Rohabwurf von Tag 2 (zwei Dateien)
├── shortlists/         Zwischenergebnis des Editors
└── editions/           die fertigen Ausgaben, eine Datei je Tag
```

`READER-PROFILE.md` ist das Herz der Story — Relevanz ist relativ zu einer
Person, nicht absolut:

```markdown
**Leserin:** Kirsten Aalborg, Partnerin bei einem Frühphasenfonds
(Ticketgröße 0,5–3 Mio EUR, Schwerpunkt Europa).

## Was sie interessiert
1. Frühphasenrunden in Europa — Pre-Seed bis Series A.
2. Infrastruktur und Werkzeuge für KI-Anwendungen, nicht Modelle selbst.
3. Bewertungen und Konditionen, wenn sie genannt werden.
…

## Was sie nicht interessiert
- Runden ab Series C und alles über 100 Mio EUR.
- USA und Asien, außer ein europäisches Unternehmen ist unmittelbar beteiligt.
- Alles, was sie in einer früheren Ausgabe schon gelesen hat.
```

---

## Schritt 7.2 — Ausgabe 1

```bash
./scripts/briefing-tick.sh 2026-08-10
```

```console
Briefing-Pipeline fuer 2026-08-10 auf Board kanban-story-7:
  scout      t_f64fb37d
  editor     t_52181f7b
  publisher  t_e3c6066a
```

[`scripts/briefing-tick.sh`](scripts/briefing-tick.sh) legt die drei Karten mit
`--parent` in Reihe. Zwei Details:

```bash
--workspace "dir:$VAULT"                       # derselbe Vault für alle drei
--idempotency-key "brief-scout-$DAY"           # ein Lauf je Tag und Stufe
```

Ohne den Idempotenzschlüssel würde ein Cron-Takt, der öfter als einmal täglich
feuert, dieselbe Ausgabe mehrfach erzeugen. Ist für `sources/<datum>/` kein
Abwurf da, tut das Skript gar nichts und sagt das:

```console
briefing-tick: kein Quellabwurf unter sources/2026-08-12 — nichts zu tun.
```

Laufen lassen:

```bash
./pump.sh
```

Real gemessen:

```console
[25] done=3

Nichts mehr offen — Pumpe beendet.
✓ t_f64fb37d  done      scout        [briefing]  Sichten: Quellabwurf 2026-08-10
✓ t_52181f7b  done      editor       [briefing]  Redigieren: Auswahl fuer 2026-08-10
✓ t_e3c6066a  done      publisher    [briefing]  Ausgabe schreiben: 2026-08-10
```

### Was jede Stufe beigetragen hat

**Der Scout sammelt und bewertet nicht.** Sechs Kandidaten, mit Lücken als
`null` statt als Erfindung:

```markdown
| Unternehmen | Ort | Runde | Betrag | Bewertung | Investoren | Quelle |
| Kaskade | Kopenhagen | Seed | 4,2 Mio EUR | 22 Mio EUR (kolportiert) | Northzone (Lead), … |
| Torvald Systems | Trondheim | Series B | 65 Mio EUR | null | Index Ventures (Lead) |
| Feldspat AI | Wien | Pre-Seed | 900k EUR | 6,5 Mio EUR | Speedinvest (Lead), … |
| Mariner Health | Boston | Series A | 40 Mio USD | null | a16z (Lead) |
| Perlmutt Data | Berlin | Series A (bereits 18.06. gemeldet) | 12 Mio EUR | null | Cherry Ventures |
| Kaskade — Personalie Ingrid Solheim | Kopenhagen | Personalie (CTO) | null | null | null |
```

**Der Editor kürzt und begründet jeden Rauswurf.** Aus sechs werden zwei:

```markdown
## Verworfen

- **Torvald Systems** — Series B, 65 Mio EUR: liegt außerhalb von Kirstens
  Frühphasenfenster (Pre-Seed bis Series A) und ist laut Quelle Industrielle
  Sensorik, also keine KI-Infrastruktur trotz Pitchdeck.

- **Mariner Health** (Boston) — reine US-Meldung ganz ohne europäische
  Beteiligung; fällt unter Kirstens expliziten Ausschluss von USA/Asien.

- **Perlmutt Data** (Berlin) — keine neue Runde: die Finanzierung wurde bereits
  am 18.06. kommuniziert; heutige Meldung betrifft nur die Büroeröffnung.
```

Und die Konsolidierung, die kein Rauswurf ist:

```markdown
*(Die vom Scout separat gelistete Kaskade-Personalie wurde nicht als eigener
Eintrag geführt, sondern in den Kaskade-Rundeneintrag aufgenommen — gleiche
Firma, gleicher Tag.)*
```

**Der Publisher schreibt die Ausgabe** und fasst dabei die Notiz aus dem
Twitter-Mitschnitt an („look at whoever is doing eval tooling for agents") mit
der Meldung zusammen:

```markdown
# AI-Funding-Briefing — 2026-08-10

Heute steht ein Pre-Seed aus Wien vorne: Feldspat AI sammelt 900k EUR bei
6,5 Mio EUR post-money und baut genau das Werkzeug, das in deiner Notiz als
Beobachtungsziel markiert war — Evaluierung und Observability für LLM-Agenten.
…
```

---

## Schritt 7.3 — Der Vault wächst

Das Journal ist der Grund, warum Tag 2 anders läuft als Tag 1:

```bash
cat workspace/vault/journal.jsonl
```

```json
{"ts": "2026-08-10T10:35:00Z", "stage": "scout",     "day": "2026-08-10", "candidates": 6}
{"ts": "2026-08-10T10:45:00Z", "stage": "editor",    "day": "2026-08-10", "kept": 2, "dropped": 3}
{"ts": "2026-08-10T10:50:00Z", "stage": "publisher", "day": "2026-08-10", "items": 2}
```

Und der Index:

```bash
cat workspace/vault/INDEX.md
```

```markdown
| Ausgabe | Eintraege | Wichtigste Meldung |
|---|---|---|
| 2026-08-10 | 2 | Feldspat AI (Wien): Pre-Seed 900k EUR, post-money 6,5 Mio EUR — LLM-Agenten-Eval/Observability |
```

Beides ist **Zustand im Vault**, nicht im Board. Es überlebt ein
`teardown.sh`, ein Board-Neuanlegen und den Wechsel der Maschine. Das Board
trägt die Ablaufsteuerung; der Vault trägt das Gedächtnis.

---

## Schritt 7.4 — Ausgabe 2: liest die Pipeline ihren eigenen Verlauf?

Der Quellabwurf vom 11. enthält absichtlich zwei Wiederholungen:

```
* Feldspat AI (Wien) — Pre-Seed, 900k EUR, Lead Speedinvest.
  (Nachtrag zur gestrigen Meldung, jetzt mit Investorenliste bestaetigt.)

* Kaskade (Kopenhagen) — Seed 4,2 Mio EUR, Lead Northzone.
  (Bereits am 10.08. gemeldet.)
```

Beide standen gestern in der Ausgabe. Der Editor hat im Task-Body die Regel:

> Lies `journal.jsonl` **und** die vorhandenen Dateien in `editions/`. Was in
> einer früheren Ausgabe schon stand, kommt **nicht** wieder. Das ist die
> wichtigste Regel dieser Karte.

```bash
./scripts/briefing-tick.sh 2026-08-11
./pump.sh
```

Real gemessen, `shortlists/2026-08-11-auswahl.md`:

```markdown
## Verworfen

- **Feldspat AI** (Wien, Pre-Seed 900k, Speedinvest) — bereits in der Ausgabe
  vom 10.08. ausführlich berichtet; heutige Nennung ist nur ein Nachtrag mit
  bestätigter Investorenliste. Kein neuer Eintrag.
- **Kaskade** (Kopenhagen, Seed 4,2 Mio, Northzone) — bereits in der Ausgabe
  vom 10.08. berichtet. Kein neuer Eintrag.
- **Sundara Labs** (Bangalore, Series A 30 Mio USD, Accel) — reiner
  Standort-Bangalore-Deal (Asien); europäischer Bezug nur über das kleine
  Balderton-Ticket.
- **Quantenhof AG** (München, Series C 140 Mio EUR, Softbank) — Series C mit
  über 100 Mio EUR, außerhalb von Kirstens Fenster.
```

**Die Wiederholungen sind erkannt worden.** Der Editor hat dafür nicht das
Board befragt, sondern `journal.jsonl` und `editions/` im Vault gelesen — Wissen,
das dem Board gar nicht gehört.

Die Ausgabe führt stattdessen die neuen Meldungen, mit der Personalie Deveaux
im Hallig-Eintrag statt als eigener Zeile:

```markdown
# AI-Funding-Briefing — 2026-08-11

Heute dominiert eine Seed-Runde aus Hamburg: Hallig Compute holt 3,1 Mio EUR
bei 15 Mio EUR post-money von Cherry Ventures (Lead) und HTGF für die
Abrechnungsschicht geteilter GPU-Cluster — und bringt zugleich eine Personalie
aus einem grossen Haus mit: Marc Deveaux wechselt von Mistral als VP
Engineering zu ihnen. …
```

Zur Kontrolle:

```bash
ls workspace/vault/editions/
cat workspace/vault/journal.jsonl
cat workspace/vault/INDEX.md
```

```console
2026-08-10.md   2026-08-11.md          ← die erste unverändert, 10:46 vs. 10:57
```

```json
{"ts": "…", "stage": "scout",     "day": "2026-08-10", "candidates": 6}
{"ts": "…", "stage": "editor",    "day": "2026-08-10", "kept": 2, "dropped": 3}
{"ts": "…", "stage": "publisher", "day": "2026-08-10", "items": 2}
{"ts": "…", "stage": "scout",     "day": "2026-08-11", "candidates": 7}
{"ts": "…", "stage": "editor",    "day": "2026-08-11", "kept": 2, "dropped": 4}
{"ts": "…", "stage": "publisher", "day": "2026-08-11", "items": 2}
```

```markdown
| Ausgabe | Eintraege | Wichtigste Meldung |
|---|---|---|
| 2026-08-10 | 2 | Feldspat AI (Wien): Pre-Seed 900k EUR … |
| 2026-08-11 | 2 | Hallig Compute (Hamburg): Seed 3,1 Mio EUR … |
```

`editions/2026-08-10.md` wurde **nicht** überschrieben — der Vault ist eine
Zeitleiste, und `INDEX.md` hat jetzt zwei Zeilen statt einer.

Ein Detail, das dir auffallen wird: die `ts`-Werte im Journal sind **vom Modell
gesetzt** und teilweise unstimmig (eine Zeile trägt `2026-08-11T09:00:00Z`,
obwohl der Lauf am 10. stattfand). Wenn du auf saubere Zeitstempel angewiesen
bist, gehört das Journal in ein Skript, nicht in den Task-Body — der Board-Zeitstempel
in `hermes kanban runs` ist dagegen verlässlich.

---

## Schritt 7.5 — Zeitsteuerung

Bis hier hast du die Pipeline von Hand gestartet. Im Betrieb macht das ein
Cron-Job.

```bash
./install-cron.sh              # werktags um 9 Uhr
./install-cron.sh "0 6 * * *"  # eigener Zeitplan
```

Real gemessen:

```console
Wrapper angelegt: /Users/…/.hermes/scripts/story7-briefing.sh
  VAULT_DIR   = …/Story 7 - Scheduled Briefing/workspace/vault
  VAULT_BOARD = kanban-story-7

Created job: 842db3ffc9a7
  Name: story7-briefing
  Schedule: 0 9 * * 1-5
  Script: story7-briefing.sh
  Mode: no-agent (script stdout delivered directly)
  Next run: 2026-08-11T09:00:00+02:00
```

Drei Dinge dazu:

- **`hermes cron` führt nur Skripte aus, die unter `~/.hermes/scripts/`
  liegen.** `install-cron.sh` legt dort einen Wrapper an, der `VAULT_DIR`
  setzt und den echten Erzeuger aufruft — so bleibt
  `scripts/briefing-tick.sh` die einzige Quelle.
- **`--no-agent` heißt: kein Modell.** Das Skript *ist* der Job und kostet
  **keine Tokens**. Die fallen erst bei `scout`, `editor` und `publisher` an.
- Der Wrapper erzeugt die Pipeline für **heute**. Liegt unter
  `vault/sources/<heute>/` kein Abwurf, tut er nichts.

Nicht auf den Zeitplan warten:

```bash
JID=$(jq -r '.jobs[]|select(.name=="story7-briefing")|.id' ~/.hermes/cron/jobs.json)
hermes cron run  "$JID"      # sofort feuern
hermes cron runs "$JID"      # Ausführungshistorie
hermes cron list
```

```console
Triggered job: story7-briefing (842db3ffc9a7)
  Next run: 2026-08-11T09:00:00+02:00
  Ran now: succeeded.
```

Ausgaben landen unter `~/.hermes/cron/output/<job-id>/`:

```console
**Mode:** no_agent (script)
---
Briefing-Pipeline fuer 2026-08-10 auf Board kanban-story-7:
  scout      t_f64fb37d
  editor     t_52181f7b
  publisher  t_e3c6066a
```

Der Job hat die Pipeline für heute erneut angefordert und **dieselben drei
Karten-IDs** zurückbekommen — der Idempotenzschlüssel hat gegriffen, die
Kartenzahl blieb bei sechs.

⚠ **Den Job entfernen, bevor du die Story wegräumst** — sonst legt er weiter
Karten an:

```bash
./install-cron.sh --remove
```

```console
Removed job: story7-briefing (842db3ffc9a7)
Wrapper /Users/…/.hermes/scripts/story7-briefing.sh entfernt.
```

---

## Schritt 7.6 — Eine Ausgabe absichtlich verschieben

Es gibt zwei Gründe, warum eine Karte nicht läuft, und sie sehen im Board
verschieden aus:

```bash
hermes kanban --board kanban-story-7 schedule <id> "erst nach dem Feiertag"
hermes kanban --board kanban-story-7 block    <id> "Quelle ist noch nicht freigegeben"
```

`scheduled` heißt „wartet auf **Zeit**", `blocked` heißt „wartet auf einen
**Menschen**". Beide sind nicht dispatchbar — geprüft mit:

```bash
hermes kanban --board kanban-story-7 dispatch --dry-run   # geparkte Karten tauchen nicht auf
```

Beide kommen mit demselben Befehl zurück:

```bash
hermes kanban --board kanban-story-7 unblock <id>
```

---

## Das solltest du sehen

```bash
hermes kanban --board kanban-story-7 list --tenant briefing
./reset-workspace.sh --diff
```

```console
✓ t_f64fb37d  done      scout        [briefing]  Sichten: Quellabwurf 2026-08-10
✓ t_52181f7b  done      editor       [briefing]  Redigieren: Auswahl fuer 2026-08-10
✓ t_e3c6066a  done      publisher    [briefing]  Ausgabe schreiben: 2026-08-10
✓ t_e3caa8f1  done      scout        [briefing]  Sichten: Quellabwurf 2026-08-11
✓ t_bb78535d  done      editor       [briefing]  Redigieren: Auswahl fuer 2026-08-11
✓ t_5bd14d78  done      publisher    [briefing]  Ausgabe schreiben: 2026-08-11
```

- Sechs Karten (zwei Ausgaben × drei Stufen), alle auf `done`.
- `editions/2026-08-10.md` **und** `editions/2026-08-11.md` — die erste
  unverändert.
- `journal.jsonl` mit sechs Zeilen.
- `INDEX.md` mit zwei Ausgabezeilen.
- In `shortlists/2026-08-11-auswahl.md` stehen Feldspat und Kaskade unter
  *Verworfen* mit Verweis auf die Ausgabe vom Vortag.

---

## Aufräumen

```bash
./install-cron.sh --remove     # zuerst!
hermes kanban --board kanban-story-7 list --tenant briefing --json \
  | jq -r '.[].id' | xargs hermes kanban --board kanban-story-7 archive
./reset-workspace.sh
```

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
| `hermes kanban create … --parent <id>` | Pipeline in Reihe |
| `… --idempotency-key <k>` | Ein Lauf je Tag und Stufe, auch bei häufigerem Takt |
| `… --workspace dir:<abs>` | Langlebiger Vault statt Wegwerf-Verzeichnis |
| `hermes kanban schedule <id> "…"` | Warten auf Zeit |
| `hermes kanban unblock <id>` | Geparkte Karte zurückholen |
| `hermes kanban dispatch --dry-run` | Prüfen, welche Karten ein Tick anfassen würde |
| `hermes cron create "<plan>" --name … --script <s> --no-agent --deliver local` | Zeitsteuerung ohne Modellkosten |
| `hermes cron run/runs/list/rm <id>` | Sofort feuern, Historie, auflisten, entfernen |
| `hermes cron tick` | Fällige Jobs einmal ausführen |
| `hermes cron status` | Läuft der Scheduler? |
