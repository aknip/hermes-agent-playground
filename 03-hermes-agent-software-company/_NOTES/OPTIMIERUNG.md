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

*(wird beim Umsetzen gefüllt)*

## BLOCK 4 — Nachher

*(wird nach dem Validierungslauf gefüllt)*
