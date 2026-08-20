# OPTIMIERUNG — Baseline, Maßnahmen, Nachher

Diese Datei ist die Akte einer Optimierungsrunde an der ESF (20.08.2026). Sie
gehorcht demselben Vertrag wie `VERIFIKATION.md`: **Jede Zahl steht mit dem
Kommando da, das sie erzeugt hat.** Was nicht gemessen ist, steht als
„unverifiziert" drin und nicht als Erfolg.

Gemessen wird gegen das Testrepo
`../04-hermes-agent-software-company-test-kaneo` — dasselbe Repo, gegen das
`beispiel-lauf-2/` und `beispiel-lauf-3/` gefahren sind. Ein schlankeres
Beispielrepo hätte genau diese Vergleichbarkeit weggeworfen.

---

## BLOCK 1 — Baseline

Quellen: `beispiel-lauf-2/` (Phase 2 des ersten Rundlaufs, S1+S2, 17.08.2026),
`beispiel-lauf-3/` (zweiter Rundlauf, Phase 0/1 + R1 mit S1+S2, 18./19.08.2026),
`RUN-PROTOKOLL.md`, `VERIFIKATION.md`. **Kein neuer Lauf, keine Modell-Token.**

### 1.1 Kartenzeit gesamt und die Zeit, die nichts hervorgebracht hat

Erzeugt mit `jq` über `board.json` und `awk` über `laufzeiten.txt`:

```
jq -r '[ .karten[] | .runs[]? | {o: (.outcome // "null"),
        s: (if (.started_at and .ended_at) then (.ended_at - .started_at) else 0 end)} ]
       | group_by(.o) | map({o:.[0].o, n:length, min: ([.[].s]|add/60|floor)})
       | sort_by(-.min) | .[] | "\(.o)\tn=\(.n)\tMinuten=\(.min)"' <akte>/board.json
```

| Akte | Karten | Läufe | Kartenzeit (Summe der MINUTEN-Spalte) | Läufe ohne Ergebnis | davon verlorene Minuten | Anteil an der Kartenzeit |
|------|--------|-------|--------------------------------------|---------------------|-------------------------|--------------------------|
| `beispiel-lauf-2` | 33 | 54 | **1114** | **14** | **387** | **34,7 %** |
| `beispiel-lauf-3` | 34 | 39 | **541** | **3** | **165** | **30,5 %** |

Aufschlüsselung der Läufe nach `outcome`, in Minuten Wanduhr:

| `outcome` | Lauf 2: n / min | Lauf 3: n / min | zählt als Verlust? |
|-----------|-----------------|-----------------|--------------------|
| `completed` | 33 / 636 | 34 / 389 | nein |
| `crashed` (`pid … not alive`) | 10 / **198** | 0 / 0 | **ja** |
| `timed_out` | 2 / **180** | 3 / **165** | **ja** |
| `gave_up` | 2 / **9** | 0 / 0 | **ja** |
| `review_requested` | 1 / 101 | 0 / 0 | nein — Arbeit fertig, an Review übergeben |
| `blocked` | 2 / 3 | 2 / 4 | nein — Gate wartet auf den Menschen |
| `reclaimed`, `scheduled`, `spawn_failed` | 4 / 0 | 0 / 0 | ohne messbare Dauer |

**Das ist die Kernzahl der Baseline: rund ein Drittel aller Kartenzeit brennt in
Läufen, die kein Ergebnis hinterlassen.** In Lauf 2 dominiert `crashed`
(198 min, zehn Läufe), in Lauf 3 ist `timed_out` die *einzige* Verlustklasse
(165 min, drei Läufe).

### 1.2 Kartenzeit je Kartentyp

Erzeugt mit `awk` über `laufzeiten.txt`, Klassifikation nach Kartentitel.
`MEHRFACH` = Karten mit mehr als einem Lauf.

**`beispiel-lauf-2` (33 Karten, 1114 min, 33,8 min/Karte)**

| Typ | Min | Karten | Läufe | Min/Karte | mehrfach |
|-----|-----|--------|-------|-----------|----------|
| Nacharbeit | 400 | 5 | 13 | 80,0 | 2 |
| Umsetzung | 228 | 3 | 9 | 76,0 | 2 |
| Review | 186 | 4 | 8 | 46,5 | 2 |
| QA-Betriebsbefund | 106 | 2 | 2 | 53,0 | 0 |
| Spezifikation/Konzept | 60 | 4 | 4 | 15,0 | 0 |
| Kalibrierung | 45 | 2 | 3 | 22,5 | 1 |
| Merge | 24 | 5 | 5 | 4,8 | 0 |
| Sprint-Abschluss | 23 | 2 | 2 | 11,5 | 0 |
| Gate | 19 | 2 | 4 | 9,5 | 2 |
| Release-Abschluss | 13 | 1 | 1 | 13,0 | 0 |
| Schätzung | 10 | 3 | 3 | 3,3 | 0 |

**`beispiel-lauf-3` (34 Karten, 541 min, 15,9 min/Karte)**

| Typ | Min | Karten | Läufe | Min/Karte | mehrfach |
|-----|-----|--------|-------|-----------|----------|
| Onboarding | 152 | 5 | 6 | 30,4 | 1 |
| Umsetzung | 96 | 3 | 3 | 32,0 | 0 |
| Sprint-Abschluss | 59 | 2 | 3 | 29,5 | 1 |
| Schätzung | 38 | 3 | 4 | 12,7 | 1 |
| Video | 34 | 6 | 6 | 5,7 | 0 |
| Kalibrierung | 33 | 2 | 2 | 16,5 | 0 |
| Review | 26 | 3 | 3 | 8,7 | 0 |
| Merge | 25 | 3 | 3 | 8,3 | 0 |
| Spezifikation/Konzept | 23 | 3 | 3 | 7,7 | 0 |
| Gate | 20 | 2 | 4 | 10,0 | 2 |
| Release-Abschluss | 18 | 1 | 1 | 18,0 | 0 |
| Wartung | 17 | 1 | 1 | 17,0 | 0 |

Zwei Beobachtungen, die die Priorisierung in BLOCK 2 tragen:

- **Nacharbeit ist der teuerste Kartentyp** (Lauf 2: 400 von 1114 min = 36 %).
  Sie entsteht nicht aus Ausfällen, sondern aus Review-Befunden und
  CEO-Auflagen — `RUN-PROTOKOLL.md:783` beziffert die ungeplante Arbeit auf
  **555 min = 73 % der Sprint-Wanduhr**. Das ist kein Defekt, sondern der
  arbeitende Prüfapparat. Es ist ausdrücklich **nicht** Ziel dieser Runde,
  ihn kleiner zu machen.
- **Vier von vier Gate-Karten haben zwei Läufe.** Das ist der Normalfall
  (Lauf 1 blockt, Lauf 2 setzt nach dem `unblock` fort), keine Wiederholung.
  Die Spalte `MEHRFACH` ist also nicht gleichbedeutend mit „Fehlschlag".

### 1.3 Abgebrochene Läufe im Einzelnen

**`timed_out` — alle fünf gemessenen Fälle, mit Überschuss über den Deckel:**

```
jq -r '.karten[] | .runs[]? | select(.outcome=="timed_out")
       | "\(.error)  dauer=\((.ended_at - .started_at))s"' <akte>/board.json
```

| Akte | gemessen | Deckel | Überschuss |
|------|----------|--------|------------|
| `beispiel-lauf-2` | 7214 s | 7200 s | **14 s** |
| `beispiel-lauf-2` | 3626 s | 3600 s | **26 s** |
| `beispiel-lauf-3` | 5406 s | 5400 s | **6 s** |
| `beispiel-lauf-3` | 2704 s | 2700 s | **4 s** |
| `beispiel-lauf-3` | 1806 s | 1800 s | **6 s** |

Dazu ein sechster Fall aus `VERIFIKATION.md:304`, dessen Akte nicht gesichert
ist: Probelauf 2/4, **1516 s gegen 1500 s = 16 s**.

**Fünf von fünf gesicherten Fällen reißen um weniger als 30 Sekunden, vier von
fünf um weniger als 7 Sekunden.** Wäre die Dauer zufällig um den Deckel
verteilt, lägen die Überschüsse breit gestreut. Das ist die Signatur eines
Modells, das arbeitet, **bis es abgeschnitten wird** — der Deckel ist kein
Sicherheitsabstand, sondern ein Ziel. Der Gegenbeleg steht daneben: Der zweite
Lauf einer gerissenen Spezifikationskarte brauchte 20 Minuten gegen 45
(`VERIFIKATION.md:358`).

**`crashed` — 10 Läufe, 198 min, alle mit `pid … not alive`** (Lauf 2). Ursachen
laut Protokoll gemischt: Netzausfälle (`APIConnectionError`, `VERIFIKATION.md:269`
— „benannt, nicht quantifiziert") und **zwei Fehlkills des eigenen Wachhunds**
(`RUN-PROTOKOLL.md:430` „Der Wachhund war die Ursache, nicht die Rettung",
51 min und 30 min). Der Wachhund hat danach zwei zusätzliche Kriterien bekommen.

**`gave_up` — 2 Läufe, 9 min:** `git worktree add failed` und
`Iteration budget exhausted (500/500)`.

**`spawn_failed` — 1 Lauf:** `git worktree add failed`, ohne messbare Dauer.

### 1.4 Die bekannten Stabilitätsbefunde — mit Status

Die vier im Ziel namentlich genannten Befunde sind **drei bereits behoben und
einer offen**. Das steht hier ausdrücklich, damit die Auswahl in BLOCK 2 nicht
wie ein Ausweichen aussieht: BLOCK 2 priorisiert die **offene** Menge, weil ein
vor zwei Tagen behobener Defekt sich nicht mehr rot zeigen lässt.

| Befund | Quelle | Status |
|--------|--------|--------|
| **Turbo-Cache-Blindheit des Merge-Riegels** — `merge-riegel.sh` fuhr `turbo typecheck`/`test` ohne `--force`; gemessen `6 cached, 6 total — 170ms >>> FULL TURBO`. Zwei von sechs Riegel-Prüfungen waren blind. | `VERIFIKATION.md:300` | **behoben** — `merge-riegel.sh:129/131` setzt `--force`, seriell zusätzlich `--concurrency=1` |
| **Turbo-Cache-Blindheit des Reviews** — „Führe die Tests SELBST aus" war wirkungslos: turbo antwortete mit dem Protokoll des Entwicklers, der Reviewer meldete es als eigene Messung. | `VERIFIKATION.md:301` | **behoben** — alle 12 Kartentexte in `create-sprint.sh` schreiben `pnpm exec turbo typecheck test --force` vor, mit Begründung im Text |
| **Falsche Grün-Meldungen des Phase-1-Prüfers** — `check-onboarding.sh` meldete „9 von 9 Journeys haben eine Spec" bei fünf Specs (Zeilenfenster-Grep nahm die Spec der Nachbarzeile); dazu „5 von 6 P1" bei fünf P1; dazu Gate-Antwort `"?"`; dazu `null` statt Leerstring im neuen roten Zweig. | `RUN-PROTOKOLL.md:1015` | **behoben** — Commit `608cc8f`, Bericht nennt jetzt je Journey ihre Spec oder `(keine Spec)` |
| **Zeitgrenzen-Risse knapp über dem Deckel** — 6 gemessene Fälle, Überschuss 4–26 s, jeder kostete den ganzen Lauf. | 1.3, `VERIFIKATION.md:358` | **teilweise behoben, Detektion offen** — die Deckel sind angehoben (kein `--max-runtime` unter 75 m in den kartenlegenden Skripten außer `tick.sh`), aber **nichts zählt die Klasse**: `monitor.sh` kennt `timed_out` nicht |
| **Hängender Worker bei 0 % CPU** — 16 min bei 0 % CPU und `CLOSE_WAIT`; vom Board aus **nicht** von echter Arbeit zu unterscheiden (Heartbeats laufen weiter). | `VERIFIKATION.md:185` | **Werkzeug vorhanden, Auslöser fehlt** — `watchdog.sh` erkennt den Zustand an drei Kriterien, wird aber von **keinem** Skript aufgerufen; nur von Hand |
| `check-sprint.sh` Prüfung 5 suchte hart `^feat/esf-r1-` und gab bei einem R2-Sprint grün. | `VERIFIKATION.md:332` | **behoben** — Commit `78efa34` |
| Schätz-Handoff reißt ~1× je Sprint (3 Messpunkte S1/S2/S3). | `VERIFIKATION.md:331` | **behoben** — Bedingungen 2a/2b/2c des Roadmap-Gates R2 sind in `ledger-sync.sh` (Selbsttest mit sechs Fällen a–f) und `check-sprint.sh` Prüfung 7 umgesetzt |
| `turbo typecheck test --force` ist präexistent flaky, wenn beide Tasks parallel laufen (`mcp-internal-api-url.test.ts`). | `VERIFIKATION.md:323` | **Produktbefund, nicht ESF** — als Störfaktor in den Kartentexten benannt |

### 1.5 Schätzgüte

`check-sprint.sh` Prüfung 3 zieht (Schätzung, Ist)-Paare aus dem Ledger.
Verhältnis **Ist/Schätzung**, je Referenzklasse:

| Klasse | erster Rundlauf, S2 (`RUN-PROTOKOLL.md:761`) | zweiter Rundlauf (`RUN-PROTOKOLL.md:1181`) |
|--------|---------------------------------------------|--------------------------------------------|
| Umsetzung / `impl-worktree-M` | 1,04 (n=3) | S1 0,21 → S2 **1,38** |
| Review / `review-repo-M` | 0,68 (n=3) | S1 0,09 → S2 **0,88** |
| Merge / `merge-repo-S` | 0,50 (n=4, verzerrt) | S1 0,87 → S2 0,57 (n=2) |
| Schätzung / `estimate-vault-S` | 0,28 (n=3) | — |
| E2E-Bau | — | **0,63** |

Aussage der Baseline: **Die Schätzung wird über die Sprints besser** (Faktor 5–11
daneben in S1 → innerhalb Faktor ~1,6 in S2), aber **die Verlustzeit verzerrt
sie systematisch**: Eine Karte mit einem verlorenen Lauf steht im Ledger mit
ihrer vollen Wanduhr (`e2e-repo-L` 103 min für ~50 min Arbeit), und nur weil ein
Estimator das von Hand bereinigt hat, war der Anker brauchbar. **Jede in 1.1
gemessene Verlustminute ist damit zweimal teuer: einmal als Wanduhr und einmal
als verzerrter Schätzanker.**

### 1.6 Kosten je Sprint

`scripts/assign-keys.sh --verbrauch`, je Rolle kumulativ (die OpenRouter-API
liefert nur Kumulativwerte je Key — je Karte ist `cost_usd` grundsätzlich
`null`, `VERIFIKATION.md:252`).

| Lauf | USD | Karten | Kartenzeit | Verteilung |
|------|-----|--------|------------|------------|
| S1 (bis Merge), erster Rundlauf | **0,7085** | — | — | 80 % auf `esf-dev-a`, größter Teil davon in vier abgebrochenen Läufen |
| Phase 2 gesamt (S1+S2), erster Rundlauf | **9,3506** | 33 | 1131 min | `esf-dev-b` 63 % (2FA: vier Prüfzyklen, drei Zeitüberschreitungen, mehrere Netzausfälle) |
| S3, zweiter Rundlauf | **≈ 2,75** | — | 125 min | ≈ 2,45 auf die fünf ausführenden Rollen |

Die Konzept-Schätzung lautet „~20–60 USD je Sprint" — real liegt es deutlich
darunter. **Teuer wird nicht das Modell, sondern die Zahl der Anläufe.** Das ist
dieselbe Aussage wie 1.1, in USD statt in Minuten.

### 1.7 Ein Messfehler in der Messung selbst

`laufzeiten.txt` widerspricht in **beiden** Akten seiner eigenen Summenzeile, und
zwar um exakt denselben Betrag:

```
$ awk '/^t_/{s+=$3} END{print s}' beispiel-lauf-2/laufzeiten.txt   → 1114
$ grep Summe beispiel-lauf-2/laufzeiten.txt                        → 1131
$ awk '/^t_/{s+=$3} END{print s}' beispiel-lauf-3/laufzeiten.txt   →  541
$ grep Summe beispiel-lauf-3/laufzeiten.txt                        →  558
```

Ursache in `dump-lauf.sh:108` gegen `:114`: Die Spalte wird je Karte mit `floor`
auf Minuten abgeschnitten, die Summe aber aus den **Sekunden** gebildet und erst
danach gerundet. Bei 33 bzw. 34 Karten sammelt das im Mittel eine halbe Minute
je Karte — 17 und 17. Die Summe ist die genauere Zahl; nachrechenbar ist sie
nicht. Nach dem eigenen Vertrag des Projekts („Eine Zahl, die niemand nachrechnen
kann, ist kein Beleg", `RUN-PROTOKOLL.md:1040`) ist das ein Defekt — und er sitzt
in genau der Tabelle, aus der die Vorher/Nachher-Spalte dieser Datei kommt.

### 1.8 Regressionsnetz vor der ersten Änderung (BLOCK 3b, Ausgangsstand)

Gemessen am HEAD `e528909`, bevor irgendetwas geändert wurde:

| Riegel | erwartet | gemessen |
|--------|----------|----------|
| `python3 scripts/vault-lint.py seed/lint-selbsttest` | 9 ERROR | **9 ERROR**, 2 WARN |
| `python3 scripts/ceo-lint.py seed/ceo-selbsttest/*.html` (4 Dateien) | 5 ERROR | **5 ERROR** (1 + 0 + 2 + 2) |
| `bash -n` über alle 35 Shellskripte | Exit 0 | **alle Exit 0** |
| die drei Selbsttests am Ende von `setup.sh` | grün | erst in BLOCK 4 messbar (braucht einen Lauf) |

---

## BLOCK 2 — Maßnahmen

Priorisiert nach **Schaden × Häufigkeit**, gemessen an 1.1 bis 1.3. Alle sieben
sitzen in der ESF (`pump.sh`, `scripts/`), keine im Produktrepo, keine in
`~/.hermes/hermes-agent/`. Je Maßnahme ein Commit, dessen Message den Befund
benennt.

| # | Befund | Schaden (gemessen) | Häufigkeit | Datei | Commit |
|---|--------|--------------------|------------|-------|--------|
| **1** | `monitor.sh` war blind für `timed_out`, `gave_up`, `spawn_failed` — genau die Klassen, die Zeit kosten und nichts hinterlassen. Für einen Lauf, der 30 % seiner Zeit verlor, hätte er „Keine Befunde" gemeldet. | **345 min** (180 + 165) | 5 `timed_out`, 2 `gave_up`, 1 `spawn_failed` in 2 Akten | `scripts/monitor.sh` | `a7ba798` |
| **2** | `pump.sh` zeigte abgebrochene Läufe im Takt nicht — eine Karte, die ihre Retries verbrennt, sieht aus wie `running`. | **387 + 165 min**, erst nach dem Lauf sichtbar | jeder Lauf | `pump.sh` | `31383a4` |
| **3** | `pump.sh` rief `watchdog.sh` nie auf. Das Werkzeug erkennt den Hänger bei 0 % CPU, wurde aber nur von Hand gestartet. | 16 min gemessen, dazu 51 + 30 min später beendet | 2 Hänger beim ersten Wachhund-Lauf | `pump.sh` | `6474689` |
| **4** | `scripts/tick.sh:176` setzte `--max-runtime 60m`, unter der nach dem dritten Riss festgelegten Untergrenze von 75 m. Die Entscheidung stand als Kommentar da und wurde von nichts erzwungen. | 6 Risse × voller Lauf | 1 offene Fundstelle, jetzt durch Test gesperrt | `scripts/tick.sh` | `e783a34` |
| **5** | `pump.sh` schluckte Dispatcher-Fehler (`dispatch >/dev/null 2>&1 \|\| true`). Der Fehlertext existierte nie. | 1 `spawn_failed` + 1 `gave_up`, Ursache unsichtbar | jeder Fehlschlag | `pump.sh` | `8a370ea` |
| **6** | `laufzeiten.txt` widersprach seiner eigenen Summe um 17 min. Die Messbasis jeder Vorher/Nachher-Aussage — auch dieser. | 17 min in beiden Akten, Zahl nicht nachrechenbar | 2 von 2 Akten | `scripts/dump-lauf.sh` | `b6dfc3d` |
| **7** | `monitor.sh` starb still, wenn `cadence.yaml` fehlte: `2>/dev/null` verschluckt die Meldung, nicht den Exit-Code — `sed` gibt 2, `pipefail` trägt es durch, `set -e` beendet vor der Ausgabe. Ergebnis: leere Ausgabe, Exit 1 — dasselbe Signal wie „ich habe Befunde". | Monitor unbrauchbar zwischen `reset-workspace.sh` und `setup.sh` | jeder Aufruf in diesem Zustand | `scripts/monitor.sh` | `9b1dd5f` |

| **8** | `watchdog.sh` war blind für Hänger mit festgefahrenem Kind (`n_kinder -eq 0` statt „Kinder arbeiten"); dazu prüfte der Tötungs-Zweig `MIN_MINUTEN` nie. | 71 min an einer Karte, real gemessen | 1 von 4 Karten des Validierungslaufs | `scripts/watchdog.sh` | `429b520` |
| **9** | Kein Wort hielt einen Worker von einer Suche über das ganze Dateisystem ab. | **83 von 146 min** = 57 % der Kartenzeit | 2 von 4 Karten | `templates/HERMES-TOOLS.md` + 8 Profilkopien | `d0b6505` |
| **10** | Der Lage-Bericht der Pumpe fragte auch fertige Karten ab — 29 s je Bericht auf 62 Karten, und er meldete alte Sprints als neu. | Bericht unbrauchbar auf einem gewachsenen Board | jeder Bericht | `pump.sh` | `cd61ca7` |

Die Maßnahmen 8 bis 10 stammen **aus dem Validierungslauf selbst** (BLOCK 4.6),
nicht aus der Baseline — der Lauf hat sie gefunden.

**Befund 7 war vorher nicht bekannt.** Er ist beim Bauen von Testfall 1
aufgefallen, weil der Test das Skript in einer Umgebung aufrief, in der noch
kein Vault stand — dieselbe Fehlerklasse wie der `set -u`-Abbruch, der 200
Zeilen darüber schon kommentiert steht: *ein Prüfer, der still ausfällt.*

**Was ausdrücklich NICHT angefasst wurde**, obwohl es der teuerste Kartentyp ist:
die Nacharbeit (400 von 1114 min in Lauf 2, 73 % ungeplante Arbeit). Sie entsteht
aus Review-Befunden und CEO-Auflagen — das ist der arbeitende Prüfapparat, nicht
ein Defekt. Ihn kleiner zu machen wäre keine Optimierung, sondern eine
Verschlechterung mit besseren Zahlen.

### Zur Lesart von BLOCK 1

Drei der vier im Ziel namentlich genannten Befunde waren am Ausgangsstand
`e528909` **bereits behoben** (Turbo-Cache im Riegel, Turbo-Cache im Review,
falsche Grün-Meldungen des Phase-1-Prüfers — siehe 1.4 mit Commit-Nachweis). Ein
behobener Defekt lässt sich nicht mehr rot zeigen, und BLOCK 3(a) verlangt genau
das. Die Liste in BLOCK 1 ist deshalb als **Dokumentationspflicht** gelesen
(Befund + Status + Commit), die Priorisierung in BLOCK 2 als Priorisierung über
die **offene** Menge. Vom genannten Quartett ist nur der vierte offen gewesen —
die Zeitgrenzen-Risse — und der ist in dieser Runde zweimal adressiert:
Detektion (Maßnahme 1) und Untergrenze (Maßnahme 4).

## BLOCK 3 — Regressionsnetz

### (a) Je Maßnahme ein deterministischer Nachweis

`scripts/test-optimierung.sh` — **modellfrei, netzfrei, kostet keine Token.**
Jeder Fall baut in einem Wegwerf-Verzeichnis eine Miniatur-ESF: ein `hermes` auf
dem `PATH`, das Fixtures wiedergibt, und ein **Symlink auf das echte Skript**,
nicht auf eine Kopie — sonst prüft der Test seine eigene Kopie und nicht das,
was im Betrieb läuft.

| Fall | Maßnahme | rot vor dem Fix | grün nach dem Fix |
|------|----------|-----------------|-------------------|
| 1 | 1 | „timed_out NICHT gemeldet", kein Überschuss, keine Handlung | `timed_out` + „Überschuss 6 s" + „Deckel anheben" |
| 2 | 3 | „der Wachhund wurde NIE aufgerufen" | „2x in 2 Ticks", Pumpe meldet die Prüfung |
| 3 | 5 | „der Dispatcher-Fehler ist verschluckt" | Fehlertext `worktree add failed` steht in der Ausgabe |
| 4 | 2 | kein `timed_out`, kein `crashed`, keine Karten-ID im Bericht | beide Klassen + `t_aaa1`; die gesunde `t_bbb2` bleibt ungemeldet (kein Fehlalarm) |
| 5 | 6 | „`--nur-laufzeiten` gibt es nicht — die Arithmetik ist nicht prüfbar, ohne einen Lauf zu fahren" | Spaltensumme (30) = Summenzeile (30), Sekundenzahl daneben |
| 6 | 4 | `scripts/tick.sh:176: --max-runtime 60m` namentlich | „kein Deckel unter 75 min" |
| 7 | 7 | „leere Ausgabe — der Monitor ist mitten im Lauf gestorben" | gültiges JSON, Bericht abgegeben |

| 8 | 8 | Urteil `0.0 1 0 1 71` → `verdacht` (Hänger mit festgefahrenem Kind bleibt liegen); `0.0 1 0 0 2` → `toeten` (Kill unter der Mindestlaufzeit) | beide richtig, die anderen vier Fälle unverändert |
| 9 | 9 | Vorlage sagt nichts zu `find /`, nennt keinen Suchraum, eine Profilkopie abgedriftet | alle drei grün; die Invariante ist „Kopie enthält die Vorlage", weil `esf-video-designer` bewusst mehr trägt |

Beide Ausgaben stehen im Transkript dieser Runde. Reihenfolge je Maßnahme: Test
schreiben → rot zeigen → Fix → grün zeigen → Test **und** Fix zusammen
committen. Der erste Commit (`0acb8d5`) zeigt alle sechs damals bekannten Fälle
rot am unveränderten Ausgangsstand.

Voller Lauf nach allen zehn Fixes: **neun Fälle, 26 Prüfungen, alle grün, Exit 0.**

Zwei Ehrlichkeiten zum Netz selbst:

- Der erste rote Lauf von Fall 1 war **kontaminiert**: `monitor.sh` starb an
  Befund 7, bevor es überhaupt zur `timed_out`-Prüfung kam. Der Fall war rot,
  aber aus dem falschen Grund. Deshalb wurde Befund 7 zuerst behoben und Fall 1
  danach **noch einmal rot gezeigt** — diesmal mit einem Monitor, der einen
  Bericht abgab, in dem `timed_out` fehlte.
- Fall 4 prüfte zunächst die ganze Pumpen-Ausgabe auf Karten-IDs und war damit
  wertlos: Die Pumpe druckt am Ende ohnehin die Kartenliste, also erschien jede
  ID immer. Der Fall liest jetzt nur die Zeilen des Abbruch-Berichts.

### (b) Die bestehenden Riegel bleiben grün

| Riegel | erwartet | vor der Runde (`e528909`) | nach der Runde (`e783a34`) |
|--------|----------|---------------------------|----------------------------|
| `vault-lint.py seed/lint-selbsttest` | 9 | **9 ERROR**, 2 WARN | **9 ERROR**, 2 WARN |
| `ceo-lint.py seed/ceo-selbsttest/*.html` | 5 | **5** (1+0+2+2) | **5** (1+0+2+2) |
| `bash -n` auf jedem geänderten Skript | Exit 0 | — | **6 von 6 Exit 0** (`pump.sh`, `monitor.sh`, `dump-lauf.sh`, `tick.sh`, `watchdog.sh`, `test-optimierung.sh`) |
| `bash -n` auf allen 36 Skripten | Exit 0 | alle Exit 0 | **alle Exit 0** |
| die drei Selbsttests am Ende von `setup.sh` | grün | nicht messbar ohne Lauf | **grün** (BLOCK 4.1): Vault-Linter 9 ERROR/Exit 1, Merge-Riegel verweigert mit Exit 1, 13 Profile `ON DISK = yes` mit 13 Keys, CEO-Riegel 5 ERROR |

## BLOCK 4 — Der Validierungslauf, gefahren am 20.08.2026

Akte: `beispiel-lauf-5/`. Kosten: **0,1906 USD** (Startwert 19,9802 → 20,1708),
gegen einen Deckel von 5,00 USD. `install-cron.sh` und `teardown.sh` nicht
aufgerufen.

### 4.1 Der Lauf

`reset-workspace.sh` → `setup.sh` → `probelauf.sh` → `pump.sh` → `gate.sh` →
`probelauf.sh --pruefen`. **Ergebnis: `✓ Phase 0 nachgewiesen.` (Exit 0).**

`setup.sh` schließt damit auch die letzte offene Zeile aus 3(b): Vault-Linter
9 ERROR/Exit 1 wie erwartet, Merge-Riegel verweigert mit Exit 1 wie erwartet,
13 Profile `ON DISK = yes` mit 13 verschiedenen Keys, CEO-Riegel genau 5 ERROR.

### 4.2 Die Zähler — für diesen Lauf, über seine vier Karten

| Zähler | Ergebnis |
|--------|----------|
| `timed_out` | **0** |
| `crashed` | **0** |
| `respawn_guarded` | **0** |
| `block_loop_detected` | **0** |
| `gave_up`, `spawn_failed` | **0** |
| Unblocks ohne `gate.sh`-Verb | **0** (1 Unblock, 1 mit gültigem Verb) |
| Läufe für 4 Karten | **5** — der fünfte ist der `blocked`-Lauf der Gate-Karte, also kein Wiederholen |
| hängende Worker am Ende (`watchdog.sh`) | **0** („Keine verdächtigen Worker.") |

`monitor.sh` über das ganze Board: **keiner der 13 ERROR-Befunde betrifft eine
der vier Probe-Karten** — alle stammen aus der S3/S4-Historie (4.5).

### 4.3 Kartenzeit: Baseline gegen diesen Lauf

| Kartentyp | Baseline (Lauf 3) | dieser Lauf | Läufe |
|-----------|-------------------|-------------|-------|
| Spezifikation | 7,7 min/Karte | **1 min** | 1 |
| Bau / Umsetzung | 32,0 min/Karte | **54 min** | 1 |
| Review | 8,7 min/Karte | **12 min** | 1 |
| Gate | 10,0 min/Karte | **78 min** | 2 (blocked + Antwort) |
| **Summe** | — | **146 min** | 5 |

**Diese Spalte ist kein Effizienzgewinn, und sie ist auch keiner in der anderen
Richtung.** Sie ist mit der Baseline nicht vergleichbar: Die Baseline-Zeilen sind
Mittelwerte über echte Feature-Karten aus S1/S2, diese vier sind die
Dummy-Kette der Phase 0 — ein Dreizeiler in einer Datei. Der Vergleich steht hier
nur, damit niemand ihn selbst anstellt und sich daran verrechnet.

Was die Zahlen aber sehr wohl zeigen, ist etwas anderes, und das ist der
wichtigste Befund des Laufs.

### 4.4 Der teuerste Befund: 83 von 146 Minuten in `find`

| Karte | Kartenzeit | davon Suche über das Dateisystem |
|-------|------------|----------------------------------|
| Bau `t_ac33af63` | 54 min | ~12 min, zweimal `find $HOME` (Suche nach einem pnpm-Store) |
| Gate `t_e2ed027a` | 78 min | **71 min** `find / -name tastatur-command-palette.spec.ts`, bei 0,0 % CPU auf einem hängenden Netzlaufwerk |

**57 % der Kartenzeit dieses Laufs steckte in dateisystemweiten Suchen.** Die
Gate-Karte wäre ohne einen Eingriff von Hand 19 Minuten später in ihren
90-Minuten-Deckel gelaufen — voller Preis, kein Ergebnis, vollständige
Wiederholung. Behoben in `templates/HERMES-TOOLS.md` (Commit `d0b6505`), der
einen Stelle, die `setup.sh` an alle 13 Profile verteilt: benannt wird nicht nur
das Verbot, sondern der erlaubte Suchraum samt Befehlen.

**Und das ist die Ehrlichkeit, auf die es hier ankommt: Die 0 bei `timed_out`
ist teilweise von Hand erkauft.** Ich habe den festgefahrenen `find`-Prozess
beendet (nur ihn, nicht den Worker — das erhielt 71 Minuten Kontext). Ohne
diesen Eingriff stünde in der Tabelle 4.2 eine 1. Der Lauf belegt also: die
Kette trägt, die Zähler sind sauber — **aber sie waren es nicht von allein.**

### 4.5 Was die Maßnahmen im Lauf real geleistet haben

| Maßnahme | im Lauf belegt? |
|----------|-----------------|
| 1 — `monitor.sh` kennt `timed_out` | **ja, an echten Daten.** Auf demselben Board fand der aufgerüstete Monitor **6 Karten mit `timed_out` und 1 mit `crashed`**, für die der alte strukturell blind war. Überschüsse: **6, 4, 4, 16, 6, 6 Sekunden**. Zwei davon (`t_c8a338ba`, `t_e66652b4`) liegen in **S4** — dem Sprint, den der letzte Commit vor dieser Runde „der erste vollständig grüne Sprint" nennt. Drei der sechs Messpunkte waren in BLOCK 1 noch nicht bekannt; die Signatur steht damit bei **8 von 8 unter 30 s, 6 von 8 unter 17 s** |
| 2 — Abbruch-Bericht der Pumpe | **nicht ausgelöst** — es gab in diesem Lauf keinen Abbruch zu melden. Nur die Gegenprobe greift: er hat auch keinen Fehlalarm erzeugt |
| 3 — Wachhund in der Pumpe | **ja.** Er lief 14-mal, meldete zweimal einen Verdacht und beendete richtig nichts. Erstmals in diesem Repo an einem **echten** Prozess belegt, nicht nur an einer Attrappe |
| 4 — Zeitgrenzen-Untergrenze | **nicht ausgelöst** — keine Karte in der Nähe ihres Deckels (außer der Gate-Karte, siehe 4.4) |
| 5 — Dispatcher-Fehler | **nicht ausgelöst** — kein Dispatch ist fehlgeschlagen |
| 6 — `laufzeiten.txt` stimmt mit seiner Summe | **ja, an echten Daten**, dreimal: `beispiel-lauf-2` (1114 = 1114), `beispiel-lauf-4` (1348 = 1348, 61 Karten), `beispiel-lauf-5` (1494 = 1494) |
| 7 — `monitor.sh` stirbt nicht mehr still | **ja** — der Monitor lief unmittelbar nach `reset-workspace.sh` gegen einen Vault ohne `cadence.yaml`, genau der Zustand, in dem er vorher mit Exit 1 und leerer Ausgabe abbrach |

Drei von sieben Maßnahmen haben im Lauf real angeschlagen, vier hatten keinen
Anlass. Das ist der erwartete Ausgang für einen sauberen Lauf und **kein Beleg,
dass die vier wirken** — nur, dass sie keinen Fehlalarm erzeugen.

### 4.6 Was der Lauf zusätzlich gefunden hat

Drei Befunde, die vorher nicht bekannt waren und alle drei aus dem Lauf selbst
stammen, mit Fix und Nachweis:

| # | Befund | Commit |
|---|--------|--------|
| 8 | **Der Wachhund war blind für Hänger mit festgefahrenem Kind.** Kriterium 2 lautete `n_kinder -eq 0`, sein eigener Kommentar begründet aber „ein Prozess mit *arbeitenden* Kindern ist nicht untätig". Kriterium 1 misst die CPU des ganzen Baums — liegt die unter der Schwelle, arbeitet auch kein Kind. Genau der Fall der Gate-Karte. Dabei fiel ein **zweiter** Defekt auf: der Tötungs-Zweig prüfte `MIN_MINUTEN` nie, obwohl das Banner sie ausgibt — ein zwei Minuten alter Worker mit einem Pool-Socket auf `CLOSE_WAIT` war tötbar, plausibel einer der beiden historischen Fehlkills | `429b520` |
| 9 | **83 von 146 Minuten in `find`** (4.4) | `d0b6505` |
| 10 | **Der Lage-Bericht der Pumpe fragte auch fertige Karten ab** — auf dem echten Board 62 Karten, 29 s je Bericht, und er meldete die Abbrüche aller alten Sprints als neu. Gefunden in der ersten Minute des Laufs | `cd61ca7` |

### 4.7 Fazit, nach dem Verifikationsvertrag

**Belegt besser (an Messungen, nicht an Argumenten):**

- **Die Erkennung.** Der Monitor findet auf demselben Board 7 Verlustereignisse,
  die er vorher nicht sehen konnte — darunter zwei in einem Sprint, der als
  vollständig grün protokolliert war. Das ist der harte Gewinn dieser Runde.
- **Die Messbasis.** `laufzeiten.txt` stimmt jetzt mit seiner eigenen Summe, an
  drei echten Akten gegengeprüft. Jede Vorher/Nachher-Aussage über diese ESF
  ruht auf dieser Tabelle.
- **Das Urteil des Wachhunds.** Zwei Fehlklassifikationen behoben, sechs Fälle
  deterministisch abgesichert, einer davon direkt aus diesem Lauf.
- **Die Kette trägt.** Phase 0 ist nachgewiesen, alle Zähler auf 0, kein
  Unblock ohne Verb, kein `block_loop_detected` trotz `modify` am Gate.

**Unverändert:** Die Kartenzeit. Nichts an dieser Runde hat eine Karte
schneller gemacht, und die Zahlen in 4.3 taugen nicht als Gegenbeweis in
irgendeine Richtung.

**Bleibt unverifiziert:**

- **Ob die Effizienz steigt.** Maßnahme 9 (`find`-Disziplin) adressiert 57 % der
  Kartenzeit dieses Laufs, aber sie ist **eine Anweisung an ein Modell** und
  damit erst belegt, wenn ein Lauf gegen die neue Vorlage kürzere Karten zeigt.
  Bis dahin ist der Gewinn eine Begründung, keine Messung. Dasselbe gilt für die
  Maßnahmen 2, 4 und 5, die keinen Anlass hatten.
- **Der neue Tötungs-Zweig des Wachhunds an einem echten Hänger.** Die
  Entscheidung ist gegen Zahlentripel belegt (Fall 8), die Ausführung nicht:
  In diesem Lauf hat er nichts beendet, und ich habe von Hand eingegriffen,
  bevor er unter der neuen Regel zugeschlagen hätte. **Das ist die Stelle, an
  der ich meinen eigenen Fix nicht geprüft habe**, und sie gehört als erste in
  den nächsten Lauf.
- **Der schreibende Pfad von `dump-lauf.sh`** ist jetzt zweimal gelaufen
  (`beispiel-lauf-4`, `-5`) — nicht mehr unverifiziert. Die Zeile aus dem
  früheren Stand entfällt.
- **Ein Sprint-Lauf.** Phase 0 ist die Dummy-Kette. Ob die Maßnahmen unter der
  Last eines echten Features tragen, ist nicht gemessen.

---

## Anhang — warum BLOCK 4 zuerst nicht gefahren wurde

Nach BLOCK 3 war der Turn-Deckel der Bedingung (50) erreicht, und ich habe den
Validierungslauf bewusst **nicht** angefangen: Ein Phase-0-Lauf braucht mehr
Wanduhr als übrig war, und ihn anzufangen ohne ihn zu beenden hätte laufende
Worker ohne Aufsicht Token verbrauchen lassen, nachdem `reset-workspace.sh` den
Zustand gelöscht hat. Der Stand wurde als Tabelle offener Punkte protokolliert
statt als Lücke (Commit `91e735c`). Auf ausdrückliche Weisung ist der Lauf
danach nachgeholt worden — sein Ergebnis steht oben in BLOCK 4.

Die damalige Aussage „diese Runde belegt keine Effizienzverbesserung" gilt
unverändert. Der Lauf hat sie nicht widerlegt, sondern präzisiert: Er hat den
größten Effizienzhebel überhaupt erst gefunden (4.4).
