# Protokollierter Lauf — Story 11, 2026-08-11, 15:21–17:33

Das vollständige Ergebnis eines echten Durchlaufs auf **Hermes Agent v0.20.0
(2026.8.3)**, macOS, Modell `deepseek/deepseek-v4-flash-0731` über OpenRouter.
`workspace/` wird bei jedem `reset-workspace.sh` neu aufgebaut — hier liegen die
Artefakte unverändert daneben, damit man sie lesen kann, ohne die Pipeline
laufen zu lassen.

```
intake/       die zwei Scout-Berichte (19 + 12 Kandidaten)
vault/        37 Zwischenartefakte: Items, Bahn-Ergebnisse, Konflikt-Dossier,
              Vorschläge, Lint-Berichte
wiki/         die Wissensbasis NACH den drei Merges
git-log.txt   git log --graph --oneline --stat der Wissensbasis
board.json    das Board am Ende (37 Karten, alle done)
laufzeiten.txt Laufzeitprofil je Karte, aus board.json gerechnet
```

## Die Zahlen

| | |
|---|---|
| Karten | 37 — davon **3 von Hand**, 34 von `kb-orchestrator` |
| Runs | 52, davon 5 `reclaimed` (Ursache unten) |
| Ungeplante Karten | **0** |
| Kandidaten → Items | 31 → 15 |
| Items geshelved (bereits abgedeckt) | **9**, alle mit Score 20 und Fundstelle |
| Items über der Schwelle 65 | 6 (Scores 98, 91, 85, 78, 76, 70) |
| Menschliche Entscheidungen | 9 — 6× Tor 1, 3× Tor 2 |
| Merges nach `main` | 3 |
| Linter: ERROR vorher → nachher | **5 → 0** |
| Linter: STALE | 1 → 1 (absichtlich nicht angefasst) |
| Wanduhr | 2 h 12 min — davon 46 min Standby, 86 min mit mindestens einer aktiven Karte, **0 min Leerlauf** |
| Summe aller Kartenlaufzeiten | 455 min → Parallelitätsfaktor ~3,5; Spitze **12 Karten gleichzeitig** |
| Die 6 Quelldateien kosteten | **3 min** (zwei Scouts parallel, je 3 Dateien) |
| Teuerste Karte | Triage, **25,9 min** — 31 Kandidaten gegen 7 Wiki-Seiten |
| Billigste Karten | die 6 Route-Karten, **0,6–1,4 min** — reiner Tabellen-Nachschlag |

## Wo man anfangen sollte

**1. `wiki/log/ingest-log.md`** — die Antwort auf „warum steht das hier?". Drei
Absätze, je einer pro Ingest, mit dem **Wortlaut** beider Torentscheidungen,
der Liste der geschriebenen/geänderten/geprunten Seiten und den Quellen. Das ist
die einzige Stelle, an der eine menschliche Entscheidung dauerhaft im
Repository steht.

**2. `vault/kanban-block-semantik-korrektur-konflikt.md`** — das Konflikt-Dossier.
Es stellt beide widersprüchlichen Aussagen wörtlich gegeneinander, mit
Fundstelle, Datum, Version und Quellenart, und trennt durchgehend **QUELLE** /
**VERIFIZIERT** / **INFERENZ**. Es entscheidet nicht — es macht die Entscheidung
billig.

**3. `git-log.txt`** — drei Ingest-Commits, drei Merge-Commits, `main` sauber.
Jeder Merge musste `kb_lint.py` bestehen.

## Was dieser Lauf belegt

**Dedup wirkt.** Neun Items wurden geshelved, weil die Wissensbasis sie schon
kannte — die `review`-Spalte, `swarm`, `--goal`, `--no-agent`, die Deprecation
von `kanban daemon`, die `unblock --reason`-Semantik. Für keines davon wurde
eine Karte angelegt.

Besonders instruktiv: `unblock-reason-semantik` (20, geshelved) steht neben
`kanban-block-semantik-korrektur` (91, weiter). **Dieselbe Seite, dieselbe
Quelle, zwei Aussagen** — die eine steht schon da, die andere widerspricht ihr.
Eine Pipeline, die pro Quelle statt pro Aussage entscheidet, kann das nicht
trennen.

**Der Konfliktfall funktioniert.** Die Wissensbasis dokumentierte
`hermes kanban block <id> --reason "…"`. Die Quellen (Changelog 0.20.1,
Transkript, plus ein CLI-Test des Rechercheurs gegen die lokale Installation)
belegten, dass der Grund positional ist. Der Mensch entschied am Tor 1 mit
`approve`, dass die Quelle gewinnt; der Ingestor hat die falsche Aussage
**ersetzt, nicht ergänzt**, und Tor 2 hat den Prune freigegeben.

**Der Ingest heilt einen Linter-Befund, ohne darauf angesetzt zu sein.**
`index.md:21` verlinkte `[[skills-system]]`, die Seite existierte nie
(`index-toter-link`). Das Korpus lieferte den Inhalt, die Rubrik gab ihm 98
Punkte, der Ingest schrieb die Seite — Befund weg.

**Der Linter löscht nichts.** `pages/profile-system.md` ist mit
`updated: 2026-01-20` seit 203 Tagen abgelaufen. Der Linter hat das als
Prune-Kandidat berichtet und `updated` **nicht** angefasst, mit der Begründung:
„das waere eine Frontmatter-Luege, weil ich den Inhalt nicht gegen die aktuelle
Version verifizieren konnte." Nachgeprüft — `git diff` zeigt keine Änderung an
`updated`.

**`modify` ist mehr als Kosmetik.** Der Vorschlag zu
`dispatcher-reclaim-und-tick` enthielt eine Changelog-Aussage, die die
Verifikations-Bahn nicht nachweisen konnte. Die `modify`-Antwort hat sie
gestrichen; das Ingest-Log hält das fest.

**Die Serialisierung hält.** Die Ingest-Karte des zweiten Items hatte die
Commit-Karte des ersten als `parents` — gefunden vom Orchestrator per
`kanban_list`. Drei Ingests, einer nach dem anderen, keine Kollision im
gemeinsamen Arbeitsbaum.

## ⚠ Was an diesem Lauf nicht gut war

**1. `kb_git.py changed` war an beiden Toren blind.** Der Ingestor ließ seine
Arbeit im Arbeitsbaum liegen, weil die Skill `kb-ingest` ihm sagte, er solle
nicht committen. `changed` meldete darum „aendert gegenueber main nichts". Das
Ergebnis war richtig — der Orchestrator baute den Torgrund aus `git status` und
dem Lint-Bericht —, aber das Werkzeug, das dem Menschen den Diff zeigen soll,
lief leer.

**Nachgeschärft:** Ingestor und Linter committen jetzt selbst auf ihrem Branch.
⚠ **Dieser Lauf entstand vor der Änderung** und zeigt das Problem, nicht die
Lösung.

**2. Sechs Items über der Schwelle sind zwölf Torfragen.** Die Schwelle sortiert
nach Wichtigkeit, begrenzt aber die Menge nicht. Ich habe drei Tore mit `shelve`
beantwortet, obwohl die Items inhaltlich in Ordnung waren.

**Nachgeschärft:** `ingest.yaml` hat jetzt `rubrik.max_pro_lauf: 3`; überzählige
Items werden `zurueckgestellt` (nicht `geshelved`) und kommen im nächsten Sweep
wieder. ⚠ Auch das gab es beim Lauf noch nicht.

**3. Der Rechner schlief 46 Minuten mitten im Lauf.** Um 16:20 wurde der Deckel
zugeklappt (Netzwerkausfall), Wake um 17:06. Das ist **kein** Mangel des Laufs,
sondern sein interessantester Teil — ein unfreiwilliger, echter Test der
Wiederaufnahme. Belege aus `pmset -g log` gegen die Run-Historie:

| Uhrzeit | System | Board |
|---|---|---|
| 16:17 | wach | Run 1 (`Ingest: skills-system`) startet |
| **16:20:03** | `Clamshell Sleep` | Worker friert ein, Modell-Verbindung reißt |
| **16:45:00** | DarkWake, 45 s | Tick erkennt `stale_lock=…:99349` → Run 2 startet 16:45 |
| 16:45:45 | Sleep, 1018 s | Run 2 friert sofort wieder ein |
| **17:06:13** | `Wake … lid` | Run 3 startet 17:06 und läuft durch |

Beide `reclaimed`-Runs tragen `stale_lock=<host>:<pid>` — der Dispatcher hat den
verwaisten Claim erkannt, die Karte zurück in die Queue gelegt und neu gestartet.
**Nichts ging verloren, nichts Halbfertiges landete in `main`.**

Dass der Schlaf nichts kaputt gemacht hat, ist Konstruktion: der Neustart macht
die Stufe **von vorn** (nicht ab einer halben Datei), der Linter prüft danach die
ganze Wissensbasis, und `kb_git.py merge` lässt nichts nach `main`, was den
Linter nicht besteht. Der deterministische Linter ist damit nicht nur eine
Formatprüfung, sondern **das Sicherheitsnetz unter jeder unterbrochenen Arbeit** —
so war er nicht geplant.

Zwei Betriebslehren: **`--max-runtime` rechnet Wanduhrzeit** (Run 1 stand mit
„27m" da und hat real drei Minuten gearbeitet), und **für echten Betrieb nimmt
man das Gateway**, nicht ein Skript in einem Terminal. Separat geprüft: Worker
überleben den Tod der Pumpe (nach `pkill -f pump.sh` liefen drei weiter) — sie
sind eigenständige OS-Prozesse.

⚠ **Korrektur gegenüber einer früheren Fassung:** Die fünf `reclaimed`-Runs waren
hier meinen eigenen Prozess-Kills zugeschrieben. Das war falsch — mein `pkill`
lief erst um 17:07, nach allen drei Anläufen.

**4. Die Triage brauchte 25 Minuten.** Sie muss 31 Kandidaten gegen sieben Seiten
prüfen; das ist die teuerste Karte der Story. Mit `max_pro_lauf` wird sie nicht
schneller — der Deckel greift *nach* der Bewertung. Wer sie schneller braucht,
gibt ihr `--max-runtime` mit Luft und ein stärkeres Modell.

## Was hier nicht drin ist

- Der Ausgang `merge-ohne-prune` und `discard` an Tor 2 — beide Verben sind
  implementiert und in `gate.sh` geprüft, aber in diesem Lauf wurde dreimal
  `merge` geantwortet.
- Der Route-Ausgang `shelve` (aus `wissensstand: abgedeckt`) — die neun
  abgedeckten Items fielen schon in der Triage heraus und erreichten die
  Route-Stufe nie. Das ist der Regelfall und billiger, aber es heißt, dass der
  automatische `shelve`-Pfad in `paths:` in diesem Lauf nicht durchlaufen wurde.
- Ein zweiter Sweep, der die drei zurückgestellten Items aufnimmt.

Siehe auch [VERIFIKATION.md](../../VERIFIKATION.md).
