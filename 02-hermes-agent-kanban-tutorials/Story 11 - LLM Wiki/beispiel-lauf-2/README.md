# Protokollierter Lauf 2 — Story 11, 2026-08-11, 18:28–20:37

Zweiter vollständiger Durchlauf auf **Hermes Agent v0.20.0 (2026.8.3)**, macOS,
Modell `deepseek/deepseek-v4-flash-0731` über OpenRouter — dieselbe Maschine,
dasselbe eingefrorene Korpus, dieselben Skripte wie [beispiel-lauf-1](../beispiel-lauf-1/).

**Der Zweck dieses Laufs ist die Gegenprobe.** Lauf 1 endet mit zwei
Nachschärfungen, die er selbst nicht mehr belegen konnte, weil er *vor* ihnen
entstand. Dieser Lauf prüft sie — und ist dabei über ein Loch gestolpert, das
Lauf 1 nur deshalb nicht gezeigt hat, weil seine Ingest-Reihenfolge zufällig eine
andere war.

> ⚠ **Wer hier der Mensch war.** Alle sieben Torentscheidungen hat der
> Claude-Code-Agent getroffen, der den Lauf gefahren hat — nicht Ansgar. Die
> Antworten stehen unten im Wortlaut, damit nachlesbar ist, *wofür* entschieden
> wurde. In der Zeile „Menschliche Entscheidungen" sind die beiden Läufe deshalb
> **nicht** vergleichbar.

```
intake/          die zwei Scout-Berichte (19 + 12 Kandidaten)
vault/           Items, Bahn-Ergebnisse, Konflikt-Dossier, Vorschläge, Lint-Berichte
wiki/            die Wissensbasis NACH den drei Merges (ohne .git)
belege/          die Belege zu den Befunden unten — u. a. der Branch-Stand VOR dem Discard
git-log.txt      git log --graph --oneline --stat von main
board.json       das Board am Ende (29 Karten, alle done)
laufzeiten.txt   Laufzeitprofil je Karte, aus board.json gerechnet
lint-final.txt   der Linter auf dem Endstand
ingest.yaml      die Pipeline-Konfiguration dieses Laufs (mit max_pro_lauf: 3)
```

## Die Zahlen, neben Lauf 1

| | Lauf 1 | **Lauf 2** |
|---|---|---|
| Karten | 37 | **29** — davon 3 von Hand, 26 von `kb-orchestrator` |
| Runs | 52, davon 5 `reclaimed` | **65 — 29 `completed`, 36 `blocked`, 0 `reclaimed`** |
| Ungeplante Karten | 0 | **0** |
| Kandidaten | 31 | **31** — identisch |
| Kandidaten → Items | 31 → 15 | **31 → 5** ⚠ siehe „Was nicht stabil ist" |
| Items geshelved | 9 (alle Score 20) | **1** (Score 62, unter der Schwelle) |
| Items zurückgestellt (Deckel) | — (gab es nicht) | **1** (Score 66, Rang 4) |
| Items im Fan-out | 6 | **3** — der Deckel greift |
| Menschliche Entscheidungen | 9 | **7** — 3× Tor 1, 4× Tor 2 |
| Merges nach `main` | 3 | **3 Items** — aber **5 `merge kb/…`-Commits** ⚠ |
| **Linter ERROR vorher → nachher** | **5 → 0** | **5 → 0** |
| **Linter STALE** | 1 → 1 (nicht angefasst) | **1 → 1 (nicht angefasst)** |
| Wanduhr | 2 h 12 min (davon 46 min Standby) | **2 h 09 min, 0 min Standby** |
| Summe aller Kartenlaufzeiten | 455 min | **226 min** → Parallelität ~1,8 |
| Teuerste Karte | Triage, 25,9 min | **Ingest block-semantik, 40,5 min** |
| Triage | 25,9 min | **5,6 min** |

⚠ **`git-log.txt` zeigt fünf `merge kb/…`-Commits, nicht drei.** Es sind
trotzdem nur drei Items: `skills-system` und `block-semantik-0-20-x` werden je
**zweimal** gemergt, weil der Orchestrator die Tor-2-Entscheidung *nach* dem
ersten Merge noch auf dem Branch nachträgt (`ingest-log …: Tor-2-Entscheidung
(merge) eingetragen`) und diesen Nachtrag ein zweites Mal mergt. Wer im Log
zählt, kommt auf 5.

⚠ **Die Laufzeiten der Tor-Karten sind keine Maschinenzeit.** Eine Tor-Karte
läuft, während sie auf die Antwort wartet. „Commit + Tor 2: block-semantik,
38,3 min" heißt: der Orchestrator hat wenige Minuten gearbeitet und 30+ Minuten
gewartet, bis ich geantwortet habe. Nur die Nicht-Tor-Karten sind Rechenzeit.

## Die zwei Nachschärfungen aus Lauf 1 — beide bestätigt

**1. `kb_git.py changed` ist nicht mehr blind.** Lauf 1 meldete an beiden Toren
„aendert gegenueber main nichts", weil der Ingestor seine Arbeit uncommitted im
Arbeitsbaum liegen ließ. Jetzt committen Ingestor und Linter selbst
([`belege/kb_git-changed-NACHSCHAERFUNG-1.txt`](belege/kb_git-changed-NACHSCHAERFUNG-1.txt)):

```
'kb/ingest-kanban-board-0-20-x' gegenueber main:
  M index.md   M log/ingest-log.md   M pages/cron-und-zeitplan.md
  M pages/kanban-board.md   M pages/memory-system.md
  M pages/release-historie.md   A pages/skills-system.md
  7 files changed, 98 insertions(+), 12 deletions(-)
```

Das Werkzeug, das dem Menschen am Tor den Diff zeigen soll, zeigt ihn. **Und es
war genau dieser Diff, der den Hauptbefund dieses Laufs sichtbar gemacht hat** —
mit Lauf-1-Verhalten hätte ich `pages/skills-system.md` dort nie gesehen.

**2. `rubrik.max_pro_lauf: 3` greift, und trennt die zwei Ausgänge sauber.**

| Item | Score | Status | Warum |
|---|---|---|---|
| skills-system | 88 | `recherche` | Rang 1 |
| block-semantik-0-20-x | 83 | `recherche` | Rang 2 |
| kanban-board-0-20-x | 75 | `recherche` | Rang 3 |
| gateway-dispatcher-0-20-x | 66 | **`zurueckgestellt`** | über der Schwelle, Rang 4 — Deckel |
| profile-install-description | 62 | `geshelved` | unter der Schwelle 65 |

Der Unterschied ist der Punkt: 66 ist **zurückgestellt** (kommt im nächsten
Sweep wieder), 62 ist **geshelved** (erledigt, mit Fundstelle). Ein Item, das
die Schwelle bestanden hat, verschwindet nicht mit einer Begründung, die nicht
zutrifft.

## Der Hauptbefund: der Linter hatte ein Loch im Tor 1

Am ersten Tor 2 stand im Torgrund „1 Seite neu (skills-system)" — für ein Item,
dessen **eigenes Tor 1 in genau diesem Moment noch blockiert wartete**.

Was passiert war: Der Linter reparierte den Startbefund `index-toter-link`
(`index.md:21` verlinkt `[[skills-system]]`, die Seite existierte nie). Die
Skill `kb-lint` bot ihm dafür drei Wege an, darunter **„Seite schreiben — der
Inhalt existiert als Wissen und gehört ohnehin hierher"**. Er wählte diesen Weg,
las `sources/transcripts/2026-08-07-skills-system.md` und schrieb eine
vollständige **57-Zeilen-Seite**
([`belege/linter-erzeugte-skills-system.md`](belege/linter-erzeugte-skills-system.md),
Commit `8a9fe6b`).

**Der Linter hat nichts falsch gemacht — er ist seiner Skill gefolgt.** Das Loch
war im Aufbau. Zwei Folgen, beide belegt:

1. **Tor-1-Umgehung.** Korpus-Inhalt wäre in die Wissensbasis gelangt, ohne dass
   ein Mensch über die Aufnahme entschieden hat.
2. **Herkunftslücke.** `log/ingest-log.md` auf diesem Branch wies
   „**Seiten: 0 geschrieben** / 2 geaendert" aus
   ([`belege/ingest-log-auf-branch.md`](belege/ingest-log-auf-branch.md)) — die
   Seite kam darin nicht vor. Sie hätte in `main` gestanden **ohne jeden Eintrag
   im Ingest-Log**, also ohne die eine Stelle, an der eine menschliche
   Entscheidung dauerhaft im Repository steht.

> Warum Lauf 1 das nicht zeigt: dort war `skills-system` das **erste**
> ingestete Item, die Seite existierte also schon legitim, als der Linter lief.
> Hier kam `kanban-board` zuerst — und der Linter füllte die Lücke selbst.
> Derselbe Aufbau, andere Reihenfolge, anderes Ergebnis. **Ein Loch, das nur bei
> einer bestimmten Reihenfolge aufgeht, ist kein kleineres Loch.**

### Was daraufhin geschah

Antwort am Tor 2: **`discard`** — der einzige Lauf-2-Ausgang, den Lauf 1 unter
„Was hier nicht drin ist" als ungetestet führt. Danach hat die Flotte, ohne
weitere Anweisung, **von sich aus**:

- eine Karte `Fix kb-lint: Weg 'Seite schreiben' darf kein Tor-1-Loch sein`
  angelegt und ihre **eigene installierte Skill gepatcht**, Version 1.0.0 → 1.1.0
  ([`belege/kb-lint-selbstpatch.diff`](belege/kb-lint-selbstpatch.diff)):

  > „Ein Linter schreibt niemals neue Seiten ausserhalb des Seitensatzes, den
  > der Ingestor für genau dieses Item vorgegeben hat. […] das wäre Inhalt aus
  > einer fremden Seite, der Tor 1 umginge und eine Herkunftslücke im
  > Ingest-Log hinterliesse."

- eine **Re-Set-Kette** (Ingest → Lint → Commit + Tor 2) für das verworfene
  Item angelegt, mit beiden vorangegangenen Tor-2-Karten als `parents`.

Der Re-Set-Branch war sauber — 3 Dateien, `pages/skills-system.md` **nicht**
enthalten. Das Loch ist zu.

⚠ **Der Patch liegt in `~/.hermes/profiles/kb-linter/skills/`, nicht im
Repository.** `teardown.sh` entfernt ihn mit dem Profil; die Vorlage unter
`skills/kb-linter/kb-lint/SKILL.md` ist unverändert. Wer den Fix behalten will,
muss ihn dorthin übernehmen — der Diff liegt in `belege/`.

## Die sieben Torentscheidungen im Wortlaut

| # | Tor | Item | Verb |
|---|---|---|---|
| 1 | 1 | kanban-board-0-20-x (update, 75) | **modify** |
| 2 | 2 | kanban-board-0-20-x | **discard** |
| 3 | 1 | skills-system (neue_seite, 88) | **approve** |
| 4 | 1 | block-semantik-0-20-x (konflikt, 83) | **approve** |
| 5 | 2 | skills-system | **merge** |
| 6 | 2 | block-semantik-0-20-x | **merge** |
| 7 | 2 | kanban-board-0-20-x (Re-Set) | **merge** |

**`modify` (Tor 1, kanban-board).** Der Vorschlag bündelte sechs
Changelog-Aussagen. Vier aufgenommen (swarm-Signatur, Auto-Migration,
`diagnostics --kind`, `kanban_create`-Fehlschlag bei relativem
`workspace_path`), zwei gestrichen: das `stats`-Alter in Minuten und die
`complete a b c --summary`-Sperre. Grund: *„`kanban-board.md` ist die
Konzeptseite zum Board, nicht sein Changelog"* — und der Vorschlag bewertete sie
selbst mit `klarheitsgewinn 8/15` als „teils am Rand des Nennenswerten".
Nachgeprüft im Endstand: die vier stehen drin, die zwei nicht.

**`approve` (Tor 1, Konflikt).** Die Wissensbasis dokumentierte
`hermes kanban block <id> --reason "…"`; Changelog 0.20.1 und das Transkript
belegten, dass der Grund positional ist. **Ich habe es nicht geglaubt, sondern
selbst gemessen:**

```console
$ hermes kanban block t_nonexistent --reason "test"
hermes: error: unrecognized arguments: --reason test
$ hermes kanban block t_nonexistent "test"
kanban: unknown task t_nonexistent          ← kommt durch die Argumentpruefung
```

Die Quelle gewinnt. Der Ingest hat die falsche Zeile **ersetzt, nicht ergänzt**;
die richtige Aussage über `unblock --reason` blieb stehen — sie war nie falsch.

## Was dieser Lauf sonst belegt

**Der Linter löscht nichts, auch beim zweiten Mal nicht.**
`pages/profile-system.md` ist mit `updated: 2026-01-20` 203 Tage alt. Der Linter
hat es als STALE berichtet und `updated` nicht angefasst —
[`belege/stale-profile-system-diff.txt`](belege/stale-profile-system-diff.txt)
ist **0 Bytes**.

**Die Serialisierung hält.** Die Re-Set-Ingest-Karte trug *beide*
vorangegangenen Tor-2-Karten als `parents`:

```console
$ hermes kanban show t_0aabf951 --json | jq -c '{status:.task.status, parents:.parents}'
{"status":"todo","parents":["t_81b6bac5","t_d14180d5"]}
```

**Keine ungeplante Karte.** `created_by` kennt nur `kb-orchestrator` (26) und
`user` (3) — wie in Lauf 1.

### Der Konkurrenzschutz hat zum ersten Mal auf der Code-Ebene gegriffen

Das ist nach dem Linter-Loch der zweitwichtigste Befund — und er ist eine
**direkte Folge der ersten Nachschärfung**.

Die 65 Runs verteilen sich auf **29 `completed` und 36 `blocked`**. Sieben der
blockierten sind die Tore. Die übrigen **29 gehören einer einzigen Karte**:
`Ingest: block-semantik-0-20-x` wurde neunundzwanzigmal angestoßen und
neunundzwanzigmal von `kb_git.py` abgewiesen:

```
Branch kb/ingest-block-semantik-0-20-x abgewiesen: offener Ingest
kb/ingest-skills-system (Commit 0020d6f, ungemergt, main=4052eda).
```

Warum die Kanten-Ebene das nicht verhindert hat:

```console
$ hermes kanban show t_0f946269 --json | jq -c '{parents}'   # Ingest block-semantik
{"parents":["t_6abd06fe"]}
$ hermes kanban show t_a49aaf79 --json | jq -c '{parents}'   # Ingest skills-system
{"parents":["t_6abd06fe"]}
```

**Beide Ingest-Karten hingen an derselben Elternkarte** — dem Tor 2 der ersten
Kette. Als ich dort `discard` antwortete, wurden sie im selben Moment lauffähig.
Der Orchestrator hatte jede Kette gegen die *damals* offene serialisiert, aber
nicht die beiden Geschwister gegeneinander. Die Kanten-Ebene hatte hier ihren
blinden Fleck, und die Code-Ebene hat ihn gedeckt.

`TUTORIAL.md` (Schritt 11.10) sagt für Lauf 1 ausdrücklich, dass die
deterministische Ebene dort **nicht** greifen konnte:

> ⚠ Genau in diesem Zustand greift die deterministische Ebene noch nicht. Ein
> Branch **ohne eigene Commits** ist aus Git-Sicht in `main` enthalten und zählt
> für `kb_git.py branch` nicht als „offener Ingest". […] Dass der Ingestor seine
> Arbeit inzwischen **selbst committet**, schließt die verbleibende [Lücke].

Genau das ist hier eingetreten: weil der Ingestor jetzt committet, *ist* der
offene Branch aus Git-Sicht offen — und die Abweisung feuert. **Die Behauptung
aus Lauf 1 ist damit nicht mehr Konstruktion, sondern Messung.**
[`belege/konkurrenzschutz-29-abweisungen.txt`](belege/konkurrenzschutz-29-abweisungen.txt)

⚠ **Der Preis ist hoch.** 29 Anläufe kosteten diese Karte 40,5 Minuten
Wanduhrzeit für rund drei Minuten Arbeit. Die Abweisung ist korrekt, aber sie
wird durch *Neustart* erreicht, nicht durch Warten: jeder Dispatcher-Tick
startet einen vollen Worker, der die Lage prüft und aufgibt. Wer das im Betrieb
fährt, sollte die Ingest-Karten **kettenweise** verketten (jede neue
Ingest-Karte bekommt die zuletzt angelegte Commit-Karte als `parent`, nicht die
gerade offene) — dann fällt die Code-Ebene auf ihre Rolle als Notbremse zurück,
statt Taktgeber zu sein.

**Kein Standby, keine `reclaimed`-Runs.** Der Lauf lief unter `caffeinate -i`;
65 Runs, kein einziger zurückgeholt. Lauf 1 hat mit 5 `reclaimed`-Runs die
*Wiederaufnahme* belegt — dieser Lauf belegt den ungestörten Normalfall.

## ⚠ Was an diesem Lauf nicht gut war

**1. Das Ingest-Log der Re-Set-Kette ist doppelt und falsch sortiert.**
`kanban-board-0-20-x` steht **zweimal** in `wiki/log/ingest-log.md`: oben mit
`Entscheidung Tor 2: (offen)` (vom Re-Set-Ingest korrekt so geschrieben), unten
mit `merge` — und der zweite Eintrag steht *unter* dem manuellen Eintrag vom
2026-08-04, obwohl das Format „neueste oben" verlangt. Der Orchestrator hat am
Tor 2 einen **neuen** Eintrag angehängt, statt den vorhandenen zu vervollständigen.

Beim normalen Ablauf (skills-system, block-semantik) funktioniert es; nur die
Re-Set-Kette bricht es. **Der Linter fängt das nicht** — er prüft Seitenformat,
nicht die Struktur des Logs. Für ein Repository, dessen wichtigste Datei genau
dieses Log ist, ist das eine Lücke: `kb_lint.py` sollte `ingest-log.md` auf
doppelte Slugs, Datumsreihenfolge und offene `Tor 2:`-Felder prüfen.

**2. Der Deckel ist gut, aber Lauf 2 hat nur 5 Items zum Deckeln.** Siehe unten —
die Bündelung ist grob geraten, und dadurch prüft dieser Lauf `max_pro_lauf`
an einer kleineren Menge, als der Deckel eigentlich adressiert.

**3. Sieben statt sechs Torfragen.** Der Discard hat eine vierte Tor-2-Frage
erzeugt. Das ist richtig so — aber es heißt, dass ein abgelehnter Branch die
Aufmerksamkeitskosten *erhöht*, und die Aufmerksamkeit am Tor ist laut
`ingest.yaml` die knappe Ressource. Wer `max_pro_lauf` setzt, sollte
einkalkulieren, dass jeder Discard eine Runde nachlegt.

## ⚠ Was nicht stabil ist — und ein Fehler in TUTORIAL.md

`TUTORIAL.md` führt unter „Das solltest du sehen" (Zeilen 1408–1414) auf, *was
sich nicht ändert und worauf du deshalb prüfen kannst*. Der erste Punkt lautet:

> **9 Items geshelved, alle mit Score 20 und Fundstelle.** Der Deckel greift
> nach der Bewertung; die Dedup-Aussage ist von ihm unberührt.

**Das trifft nicht zu — und der Widerspruch steht zwei Absätze weiter unten in
derselben Datei.** Zeile 1416 f. sagt nämlich:

> Die Scores selbst (98, 91, 85, …) und **welche Kandidaten das Modell zu welchem
> Item bündelt**, sind **Modellentscheidungen** und werden bei dir abweichen.

Die Geshelvt-Zahl hängt an der Bündelung. Das Tutorial erklärt die Bündelung
für variabel und führt eine daraus abgeleitete Zahl als fest — in benachbarten
Absätzen.

Dieser Lauf hat aus denselben 31 Kandidaten **5 Items**
gemacht (Lauf 1: 15) und davon **1** geshelved (Lauf 1: 9). Der Grund ist keine
schwächere Dedup-Leistung, sondern eine andere **Bündelungs-Granularität**:

| | Lauf 1 | Lauf 2 |
|---|---|---|
| Bündelt nach | **Aussage** | **Zielseite** |
| Ergebnis | 15 Items, 9 davon abgedeckt → geshelved | 5 Items; Abdeckung steht *innerhalb* der Item-Datei |

Der Dedup ist in Lauf 2 nicht ausgefallen — er ist nur nicht als Item-Zahl
sichtbar. `vault/kanban-board-0-20-x.md` führt ihn pro Aussage mit Fundstelle:

> „`hermes kanban swarm` steht nur als Einzeller in `release-historie.md`
> (Zeile 29) ohne die Signatur `--worker/--verifier/--synthesizer`; in
> `kanban-board.md` fehlt der Befehl ganz. Auto-Migration, `diagnostics --kind`,
> […] stehen in keiner Seite. Keine dieser Aussagen ist in gleicher Genauigkeit
> abgedeckt."

Beides sind zulässige Lesarten von `ingest.yaml`. Die Regel lautet dort: „Zwei
Kandidaten gehoeren in dasselbe Item, wenn sie **dieselbe Seitengruppe betreffen
UND aus derselben Release-Linie bzw. demselben Vorgang stammen**." Lauf 2 hat
0.20.0/0.20.1/0.20.2 als *eine* Release-Linie mit *einer* Zielseite gelesen —
regelkonform, nur gröber. Damit ist die Item-Zahl eine
**Modellentscheidung** — und die Geshelvt-Zahl hängt an ihr. Sie gehört nicht in
die Liste der prüfbaren Invarianten.

**Was tatsächlich in beiden Läufen stabil war:**

- Linter **5 ERROR → 0**, STALE 1 → 1, `updated` nicht angefasst
- `created_by` kennt nur `kb-orchestrator` und `user` — 0 ungeplante Karten
- die Ingest-Ketten laufen **seriell**, über `parents` verkettet
- 31 Kandidaten aus 6 Quelldateien; das Community-Transkript liefert **0**
- `main` bleibt sauber: nur Inhalt, der beide Tore und den Linter passiert hat

Empfehlung für `TUTORIAL.md`: die Zeile „9 Items geshelved" aus der
Invariantenliste herausnehmen und durch „**Dedup gegen die Wissensbasis findet
statt und ist mit Fundstelle belegt** — ob als eigenes Item oder innerhalb einer
Bündelung, entscheidet das Modell" ersetzen.

## Was auch dieser Lauf nicht zeigt

- **`merge-ohne-prune`** — weiterhin ungetestet. Es ist definiert als
  *Löschungen zurücknehmen*; in diesem Lauf gab es genau eine Prune (die
  widerlegte `--reason`-Zeile), und die war richtig.
- **Der automatische `shelve`-Pfad aus `wissensstand: abgedeckt`** — alle drei
  Items im Fan-out bekamen `fehlt`, `unvollstaendig` bzw. `widerspruch`.
- **Ein zweiter Sweep**, der das zurückgestellte Item `gateway-dispatcher-0-20-x`
  aufnimmt.

Siehe auch [beispiel-lauf-1](../beispiel-lauf-1/README.md) und
[VERIFIKATION.md](../../VERIFIKATION.md).
