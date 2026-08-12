# Der zweite Lauf vom 2026-08-11, 10:08–10:56

Das ist **nicht** Teil des Setups, sondern das Protokoll eines zweiten
vollständigen Durchlaufs — abgelegt neben [`beispiel-lauf/`](../beispiel-lauf/),
damit sich die beiden vergleichen lassen.

Der entscheidende Unterschied: `beispiel-lauf/` entstand **vor** den zwei
Nachschärfungen an den Artefakten (Scout-Filter, `idempotency_key`). Dieser Lauf
lief mit den ausgelieferten Artefakten und misst damit nach, was TUTORIAL.md in
Schritt 10.8 und am Ende von „Das solltest du sehen" als **nicht erneut geprüft**
kennzeichnet.

```
intake/          die zwei Scout-Berichte (je 3 Kandidaten)
vault/items/     vier Items: zwei über der Schwelle, zwei archiviert
work/videos/     zwei Video-Ketten: auftrag, folien, skript, faktencheck
```

`workspace/` ist in `.gitignore` und wird von `reset-workspace.sh` aus `seed/`
aufgebaut. Dieses Verzeichnis hier bleibt unangetastet.

---

## Rahmen

Hermes Agent v0.20.0 (2026.8.3), macOS. Board `kanban-story-10`, Mandant
`triage`. Alle sieben Profile auf `deepseek/deepseek-v4-flash-0731` über
OpenRouter (von `setup.sh` aus der Root-Konfiguration übernommen). Gateway lief
(launchd, PID 14774), zusätzlich `./pump.sh 20 300`.

| | |
|---|---|
| Karten | **19**, alle `done` |
| Runs | **21** — 17 Karten mit einem Run, die zwei Tor-Karten mit je zwei (Lauf 1 `blocked`, Lauf 2 `completed`). Outcomes: 19 `completed`, 2 `blocked` |
| Selbst angelegt | `triage-orchestrator: 16`, `user: 3` |
| Fehlläufe | keine — `failed` / `gave_up` / `crashed`: 0 |
| Dauer | 48 min Wanduhr, bis zu sechs Worker gleichzeitig |
| Menschliche Entscheidungen | 2 × `approve` |

```
10:08  Scout x + Scout web        parallel
10:14  Triage                     6 Kandidaten → 4 Items, Fan-out: 8 Karten
10:18  6× Recherche-Bahn          sechs Prozesse gleichzeitig
10:22  2× Route                   beide → video
10:24  2× Prep outline
10:41  Tor #1 blockiert (subagenten-werkzeugflut)   ══ wartet auf einen Menschen ══
10:41  Tor #2 blockiert (config-pfade-mehrdeutig)   ══ wartet auf einen Menschen ══
10:44  beide Tore: approve → Lauf 2, Ketten angelegt
10:47  2× Fulfill folien
10:49  Fulfill skript #1
10:54  Fulfill skript #2
10:56  fertig
```

---

## Die Rubrik, und ein echter Grenzfall

```
subagenten-werkzeugflut         87   → Fan-out
config-pfade-mehrdeutig         81   → Fan-out
subagenten-allow-list-unbekannt 63   → archiviert   ← zwei Punkte unter der Schwelle
commit-emoji                    35   → archiviert
```

**`subagenten-allow-list-unbekannt` mit 63/100 ist das Interessanteste an diesem
Lauf.** In `beispiel-lauf/` lag der nächste Kandidat bei 26 — dort war die
Schwelle 65 unstrittig. Hier fehlen zwei Punkte, bei
`loesbar_oder_erklaerbar: 18/25`. Das Item wäre also gut erklärbar, und trotzdem
erfährt kein Mensch davon. Genau der Fallstrick aus TUTORIAL.md: *„Zu hoch, und
du erfährst nie von den Grenzfällen. 65 ist der Wert des Originals, kein
Naturgesetz."*

Wer die Rubrik auf sein eigenes Thema umstellt, hat hier den Fall, an dem sich
das durchspielen lässt: `rubrik.schwelle` in `triage.yaml` auf 60 setzen und den
Lauf wiederholen — dann steht ein drittes Tor da.

### Die Arbeitsteilung aus Schritt 10.8 hat gehalten

Der Scout hat `commit-emoji` **gemeldet** — `intake/x.md` führt drei Kandidaten,
nicht zwei —, und die Rubrik hat es mit 35 aussortiert. Damit ist die Schwelle in
diesem Lauf **zweimal wirksam** geworden. In `beispiel-lauf/` liegen nur zwei
Items, weil der Scout den schwachen Fall damals selbst wegfilterte und die
Schwelle deshalb eine Attrappe war.

---

## Was dieser Lauf nachmisst

### 1. Die `triage-producer`-Regression trat nicht auf

TUTORIAL.md beschreibt unter „Was in diesem Lauf schiefgegangen ist" zwei Karten,
die der `folien`-Worker selbst nachlegte, und kennzeichnet die Korrektur
(`idempotency_key = "fulfill-<slug>-<stufe>"` plus „do NOT create cards yourself"
in der `SOUL.md`) ausdrücklich als **nicht erneut gemessen**.

```console
$ hermes kanban --board kanban-story-10 list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'
triage-orchestrator: 16   user: 3
```

Kein `triage-producer`-Eintrag; 19 Karten statt 21. `faktencheck.md` entstand als
**Datei** innerhalb der `skript`-Stufe — so wie `pipeline/specs/video.md` es
verlangt —, ohne dass eine Karte dafür angelegt wurde. Die Karte, die in
`beispiel-lauf/` entglitt (`Fulfill folien: subagenten-werkzeugflut`), war dabei
und hat nichts angelegt.

⚠ **Das ist ein Lauf, keine Beweisführung.** Der ursprüngliche Fehler war selbst
nicht deterministisch — ein Modell war hilfsbereit. Von den beiden Griffen ist nur
der `idempotency_key` strukturell wirksam; die Prosa-Regel in der `SOUL.md` ist
mit einem einzelnen Durchlauf nicht belegt.

### 2. `pump.sh` endet von selbst am Tor

TUTORIAL.md kennzeichnet diese Ausgabe als *„aus einer separaten Probe mit zwei
blockierten Wegwerf-Karten"*. Hier stammt sie aus dem Lauf selbst:

```console
Nichts mehr offen — Pumpe beendet.
…
⊘ t_71dcd1d9  blocked   triage-orchestrator  Vorschlag + Tor: config-pfade-mehrdeutig
⊘ t_031f477b  blocked   triage-orchestrator  Vorschlag + Tor: subagenten-werkzeugflut

2 Karte(n) warten auf einen Menschen:
  t_71dcd1d9  Vorschlag + Tor: config-pfade-mehrdeutig
  t_031f477b  Vorschlag + Tor: subagenten-werkzeugflut

Worauf genau, zeigt:  ./gate.sh
```

### 3. Der Block hält, mit fertigen Eltern

```console
$ hermes kanban --board kanban-story-10 show t_031f477b --json \
    | jq -r '[.events[]|select(.kind=="blocked")]|last|.payload.kind'
needs_input

$ hermes kanban --board kanban-story-10 dispatch --dry-run
Promoted:     0
Spawned:      0
```

Beide Eltern der Karte standen zu diesem Zeitpunkt auf `done`. Der Dispatcher hat
sie trotzdem nicht angefasst — das ist die Aussage aus Schritt 10.6, unabhängig
noch einmal ausgelöst.

### 4. Beide Tor-Karten haben die Antwort im zweiten Lauf gelesen

```console
t_71dcd1d9  blocked:   FREIGABE config-pfade-mehrdeutig (video, 81/100): …
            completed: approve config-pfade-mehrdeutig: Umsetzungskette angelegt (2 Karten) …
t_031f477b  blocked:   FREIGABE subagenten-werkzeugflut (video, 87/100): …
            completed: approve subagenten-werkzeugflut: Umsetzungskette angelegt
                       (2 Karten: folien t_0e4b4125, skript t_35f3c1a6) …
```

---

## Unterschiede zu `beispiel-lauf/`

| | `beispiel-lauf/` | dieser Lauf |
|---|---|---|
| Kandidaten Scout x / web | 2 / 2 | 3 / 3 |
| Items | 2 (+1 archiviert, aus späterem Lauf) | 2 (+2 archiviert) |
| Scores | 85 / 76 | 87 / 81 |
| Klassifikator, zweites Item | `schlecht_erklaert` | `verwirrend` |
| Slug, zweites Item | `konfigurationspfade-ambig` | `config-pfade-mehrdeutig` |
| Route | beide `video` | beide `video` |
| Tor-Entscheidung | `approve` + `modify` | `approve` + `approve` |
| Karten / Runs | 21 / 23 | 19 / 21 |
| Pfade ausgeführt | `video` **und** `build` | nur `video` |

Scores, Slugs und Klassifikatorwerte sind **Modellentscheidungen**. TUTORIAL.md
sagt das im Abschnitt „Der ehrliche Tausch: Prosa gegen Python" ausdrücklich:
zwei Läufe können 85 und 81 ergeben. Beide `loesungsqualitaet`-Werte bilden über
`route.tabelle` auf `video` ab — derselbe Ausgang, anderes Urteil.

### ⚠ Der `build`-Pfad fehlt in diesem Verzeichnis

Er kam über die Route nicht vor (wie in `beispiel-lauf/` auch) und wurde diesmal
**nicht** per `modify` erzwungen, weil beide Tore `approve` bekamen.
`triage-builder` und `triage-tester` liefen also nicht. Wer das gebaute Werkzeug,
die Fixtures und den Testbericht sehen will, findet sie in
[`beispiel-lauf/work/builds/`](../beispiel-lauf/work/builds/).

Das ist eine Folge der menschlichen Entscheidung, kein Defekt — und ein Beleg für
den Sinn des Tors: dieselbe Pipeline liefert bei gleicher Route zwei verschiedene
Ergebnisse, je nachdem, was der Mensch sagt.

---

## Worauf zu schauen lohnt

- **`vault/items/subagenten-allow-list-unbekannt.md`** — der Grenzfall mit 63.
  Der `score_breakdown` zeigt, welche Dimension die zwei fehlenden Punkte gekostet
  hat.
- **`vault/items/*.md`, Kopf** — `score` und `score_breakdown` bei allen vier
  Items, auch den archivierten. Das ist der Grund, warum die Bewertung nachprüfbar
  ist, obwohl sie ein Modell vergeben hat.
- **`work/videos/*/auftrag.md`, Abschnitt „Freigabe"** — der Bescheid wörtlich
  (`> UNBLOCK: approve`) und darunter der vollständig einkopierte Vorschlag. Nicht
  verlinkt: die Worker der Kette sehen den Rest des Workspace nicht.
- **`work/videos/subagenten-werkzeugflut/faktencheck.md`, Abschnitt
  „Ungeklaert"** — die Zitierdisziplin der Skill `scout-report` ist bis ins
  Deliverable durchgekommen: *„Die Schwelle ‚~50-80' ist ein Streubereich aus drei
  Quellen (~60 / 50-70 / 4-9 Server), keine Einzelmessung"* und *„Quellen-URLs
  sind Platzhalter … extern nicht nachprüfbar."* Eine Zahl aus einer Quelle ist
  nicht dieselbe Aussage wie eine gemessene Zahl.

## Eine beobachtete Inkonsistenz

Die beiden `Prep outline`-Worker haben ihr Ergebnis an **verschiedene Stellen**
geschrieben:

```
vault/items/config-pfade-mehrdeutig-outline.md      wie in beispiel-lauf/
work/videos/subagenten-werkzeugflut/outline.md      abweichend
```

Beide Ketten liefen trotzdem sauber durch, weil der Orchestrator den Vorschlag
ohnehin in `auftrag.md` kopiert. Der Ablageort der Prep-Stufe scheint in der Skill
`triage-pipeline` nicht eindeutig festgelegt. Absichtlich nicht wegretuschiert.

## Was in diesem Lauf **nicht** schiefgegangen ist

Keine Karte `failed`, `gave_up` oder `crashed`. Keine Seed-Datei überschrieben —
`./reset-workspace.sh --diff` zeigte ausschließlich `Only in …/workspace`, kein
`Files … differ`. Beide Ketten liefen in ihrem dauerhaften Verzeichnis unter
`work/videos/<slug>/`; die `skript`-Stufe fand die `folien.md` der Vorgängerstufe
vor.
