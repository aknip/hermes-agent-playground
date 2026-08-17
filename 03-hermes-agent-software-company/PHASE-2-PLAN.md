# ESF — Umsetzungsplan Phase 2 (Begleiteter Betrieb)

Umsetzung von Kapitel 12 des Konzepts (`KONZEPT.html`) gegen das Ziel-Repo
`../04-hermes-agent-software-company-test-kaneo` (Kaneo v2.19.1). Setzt Phase 0
und Phase 1 voraus (`PHASE-0-1-PLAN.md`, `RUN-PROTOKOLL.md`).

**Modell:** `deepseek/deepseek-v4-flash-0731` über OpenRouter, alle drei Tiers.
**CEO-Rolle:** Claude beantwortet alle Gates selbst (`./gate.sh`), jede Antwort
mit Begründung in `RUN-PROTOKOLL.md`.

## Was Kapitel 12 für Phase 2 verlangt

> **2 — Begleiteter Betrieb.** Erste zwei Sprints unter Beobachtung: Mensch
> liest täglich mit, korrigiert SOULs und Vorlagen; Markt-Eingang zunächst
> manuell befüllt; Kalibrierung beginnt.
>
> **Abschluss-Nachweis:** Zwei Sprint-Reports mit (Schätzung, Ist)-Paaren;
> erstes Release durch das Release-Gate; Schätzgüte-Baseline im
> Controller-Report.

Drei Nachweise, alle deterministisch prüfbar — `scripts/check-phase2.sh`.

## Zwei CEO-Entscheidungen vor dem ersten Kartenzug

Beide gehören hierher und nicht in ein Skript, weil ein Leser sie sonst aus
Shell-Code zurückrechnen müsste.

### 1. Release 1 läuft in zwei Sprints, nicht in vier

`cadence.yaml` sagt `sprints_pro_release: 4` — das ist eine **Obergrenze**
(„max. 4 Sprints je Release", Kapitel 5), kein Soll. R1 trägt nach der
CEO-Änderung vom 17.08.2026 nur noch **drei** Features. Und die beiden
Phase-2-Nachweise gehen nur zusammen auf, wenn das Release wirklich landet:
zwei Sprint-Reports **und** ein Release durch das Gate.

    S1  R1-F5   Technische Härtung (apps/api/src/index.ts zerlegen)
    S2  R1-F1 ∥ R1-F2   Globaler Sucheinstieg · 2FA
    ──  Release-Abschluss R1 + GATE Release

Die Sprint-Rollen aus Kapitel 5 (Plan · Umsetzung · Umsetzung · Härtung) sind
damit nicht verletzt, sondern zusammengelegt: S1 ist Plan **und** Härtung (die
Härtung steht auf CEO-Anweisung an Position 1), S2 ist Umsetzung, und die
Integration wandert in die Release-Abschluss-Karte, wo Kapitel 5 sie ohnehin
verortet („Integration, Release Notes, voller E2E-Regressionslauf, Paket am
Riegel").

### 2. Phase 2 startet auf einem **wiederhergestellten** Phase-1-Stand

Zwischen Phase 1 und Phase 2 lag ein Rückbau: Das Board `sw-company` ist leer,
`workspace/company/` wurde aus `seed/` neu erzeugt. Die Phase-1-Artefakte liegen
als Akte in `beispiel-lauf-1/`. `restore-phase1.sh` spielt sie zurück.

Was dabei **nicht** zurückkommt, und das steht so im Protokoll: die
Karten-Historie des ersten Laufs. Die `esf-karte`-Metas in den
wiederhergestellten Dokumenten nennen Karten-IDs, die es auf dem Board nicht
mehr gibt (`t_3c0f38b8` und Geschwister). Nachschlagen kann man sie nur in
`beispiel-lauf-1/board.json`. Der Weg vom Dokument zur Entscheidung führt also
über die Akte statt über das Board — eine echte Lücke, kein Formfehler.

## Der Ledger-Backfill: warum die erste Schätzung überhaupt möglich ist

Das ist der Knackpunkt der ganzen Phase. `ledger/estimates.jsonl` ist **leer** —
`ledger-sync.sh` ist über die Phase-1-Karten nie gelaufen, nachgeprüft an
`beispiel-lauf-1/vault/ledger/estimates.jsonl` (0 Zeilen). Ein `esf-estimator`
ohne Ledger darf nach `AGENTS.md 6` keine Zahl schreiben. Ohne Zahl gibt es kein
(Schätzung, Ist)-Paar. Ohne Paar fällt Nachweis 1 aus.

Der Ausweg ist keine Erfindung, sondern eine Nachbuchung: Die
**Wanduhrzeiten der zehn Phase-0/1-Karten sind gemessen** und liegen in
`beispiel-lauf-1/board.json` als Board-Zeitstempel (`runs[].started_at`,
`ended_at`) — genau die Quelle, die Kapitel 8 als die verlässliche benennt.
`restore-phase1.sh --ledger` bucht sie nach. Drei Regeln dabei:

- **`estimate` bleibt `null`.** Die Phase-1-Karten trugen keine Schätzung. Eine
  nachträglich hineingeschriebene wäre die vergiftete Kalibrierung aus
  `AGENTS.md 6`.
- **Die Referenzklasse wird zugeordnet, nicht geraten** — über eine sichtbare
  Tabelle im Skript, Titel-Muster → Klasse. Sie ist eine Etikettierung
  gemessener Arbeit, keine Schätzung.
- **`backfill: true`** steht in jeder nachgebuchten Zeile. Wer dem Ledger
  misstraut, erkennt die Herkunft an der Zeile selbst.

Damit hat der S1-Estimator sieben klassifizierte Ist-Messungen — darunter
`impl-worktree-S` (21 min), `review-repo-S` (2 min), `spec-vault-S` (2 min),
`gate-vault-S` (11/14 min). Das ist wenig, aber es ist gemessen, und es ist
genau die Grundlage, die Kapitel 8 verlangt: Perzentile aus dem Ledger statt
Bauchwerte.

## Der Karten-Graph

### S1 — R1-F5 · Technische Härtung (5 Karten + 2 Abschluss)

    S1 F5 1/5 Konzept & ADR        esf-architect       dir:VAULT
    S1 F5 2/5 Schätzung            esf-estimator       dir:VAULT     ← Eltern: 1/5
    S1 F5 3/5 Umsetzung            esf-dev-a           worktree:REPO ← Eltern: 2/5
    S1 F5 4/5 Review               esf-reviewer        dir:REPO      ← Eltern: 3/5
    S1 F5 5/5 Merge am Riegel      esf-qa-release      dir:REPO      ← Eltern: 4/5
    Kalibrierung S1                esf-controller      dir:VAULT     ← Eltern: 5/5
    Sprint-Abschluss S1            esf-chief-of-staff  dir:VAULT     ← Eltern: Kalibrierung

### S2 — R1-F1 ∥ R1-F2 (10 Karten)

    S2 F1 1/4 Spezifikation        esf-product-manager dir:VAULT
    S2 F1 2/4 Schätzung            esf-estimator       dir:VAULT     ← 1/4
    S2 F1 3/4 Umsetzung            esf-dev-a           worktree:REPO ← 2/4
    S2 F1 4/4 Review               esf-reviewer        dir:REPO      ← 3/4
    S2 F2 1/4 Spezifikation        esf-product-manager dir:VAULT
    S2 F2 2/4 Schätzung            esf-estimator       dir:VAULT     ← 1/4
    S2 F2 3/4 Umsetzung            esf-dev-b           worktree:REPO ← 2/4
    S2 F2 4/4 Review               esf-reviewer        dir:REPO      ← 3/4
    S2 Merge F1 am Riegel          esf-qa-release      dir:REPO      ← F1 4/4
    S2 Merge F2 am Riegel          esf-qa-release      dir:REPO      ← F2 4/4 **und** Merge F1
    Kalibrierung S2                esf-controller      dir:VAULT     ← Merge F2
    Sprint-Abschluss S2            esf-chief-of-staff  dir:VAULT     ← Kalibrierung S2

### Release

    Release-Abschluss R1           esf-qa-release      dir:REPO      ← Sprint-Abschluss S2
    GATE Release — R1              esf-chief-of-staff  dir:VAULT     ← Release-Abschluss R1

## Fünf Festlegungen, die aus Fehlern des ersten Laufs folgen

1. **Die beiden Merge-Karten sind serialisiert.** `S2 Merge F2` hängt zusätzlich
   an `S2 Merge F1`. Der Riegel merged nach `main` und fährt die volle Unit- und
   E2E-Suite; `mcp-internal-api-url.test.ts` ist nachgewiesen lastempfindlich
   (`import` 52,9 s unter vier Workern gegen 7,3 s allein, `RUN-PROTOKOLL.md`).
   Zwei gleichzeitige Riegel-Läufe produzieren eine Verweigerung ohne Sachgrund
   — und daraus eine Gate-Frage an den CEO, die keine ist.

2. **Ein Branch, ein Worktree — und Nacharbeit läuft im vorhandenen.**
   `feat/esf-r1-f5-…`, `feat/esf-r1-f1-…`, `feat/esf-r1-f2-…`. Der Reviewer
   arbeitet im Hauptbaum (`dir:`) und sieht von dort in `.worktrees/`. Zwei
   Karten auf einem Branch war der harte Ausfall des Probelaufs
   (`fatal: … already used by worktree`).

   **Nachgeschärft am 17.08.2026, weil ich diese Regel selbst gerissen habe.**
   Die Nacharbeitskarte zu R1-F5 wurde mit `worktree:<repo> --branch feat/…`
   angelegt — auf demselben Branch, den die Umsetzungskarte noch als Worktree
   hielt. Drei Läufe endeten `spawn_failed` mit
   `git worktree add failed … on branch feat/esf-r1-f5-api-modularisierung`,
   dann `gave_up`. Die Regel stand zwei Absätze weiter oben in genau dieser
   Datei.

   Der Zusatz, der fehlte: Eine **zweite** Karte auf einem schon belegten Branch
   bekommt `--workspace dir:<pfad-zum-vorhandenen-worktree>`, nicht
   `worktree:`. Sie arbeitet im bestehenden Baum weiter. Das gilt für jede
   Nacharbeit, jede Korrektur und jeden zweiten Anlauf — und es ist der Grund,
   warum die Worktrees nach dem Kartenabschluss stehen bleiben.

3. **Idempotenzschlüssel nach Sprint und Feature**, nicht nach Datum
   (`s1-f5-spec`). Ein Sprint dauert länger als einen Tag; ein datumsbasierter
   Schlüssel legt den Graphen beim zweiten Aufruf doppelt an.

4. **Abschluss-Karten liegen außerhalb des `S<n> `-Namensraums**
   (`Kalibrierung S1`, nicht `S1 Kalibrierung`). Die Sprint-Erkennung in
   `monitor.sh` zählt alle Karten mit dem Präfix `S1 `; läge die
   Abschluss-Karte darin, könnte der Sprint nie „voll" werden, ohne dass sein
   eigener Abschluss schon fertig ist. Der Titel `Sprint-Abschluss S1` und der
   Schlüssel `sprint-abschluss-S1` sind dieselben, die `monitor.sh` selbst
   benutzt — die Doppelanlage fällt damit auf den Idempotenzschlüssel.

5. **Das Gate blockiert genau einmal.** `BLOCK_RECURRENCE_LIMIT = 2` je `kind`;
   eine zweite Blockade derselben Art schiebt die Karte still nach `triage`.
   Real ausgelöst, siehe `RUN-PROTOKOLL.md`. Scheitert die Ausführung der
   CEO-Antwort, wird abgeschlossen und eine **neue** Karte angelegt.

## Die Auflage bindet die Reihenfolge

`roadmap/q1-freigegeben.html` § „Auflage für den Sprint-Zuschnitt":

> Nach dem ERSTEN vollständig abgeschlossenen Feature lässt der esf-controller
> die Kalibrierung laufen und der esf-estimator schätzt die restlichen
> R1-Features neu, **bevor sie starten**.

Deshalb gibt es **zwei Aufrufe** von `create-sprint.sh`, nicht einen. Der Graph
von S2 wird erst angelegt, nachdem `Kalibrierung S1` fertig ist. Ein Skript, das
beide Sprints vorab auslegt, verletzt die eigene CEO-Auflage — und der CEO ist
in diesem Lauf derselbe, der das Skript schreibt. Genau diese Sorte Abweichung
soll `VERIFIKATION.md` einfangen.

`create-sprint.sh 2` prüft die Auflage selbst und verweigert, solange
`Kalibrierung S1` nicht `done` ist.

## Das Schätz-Paar: wo es entsteht und wo es reißen kann

`ledger-sync.sh` liest `estimate` **und** `actual` aus dem
Abschluss-`metadata` **derselben** Karte (`.runs[].metadata`). Die Schätzung
entsteht aber auf einer **anderen** Karte (`esf-estimator`). Nichts in Hermes
trägt sie hinüber. Ohne Verdrahtung landet jede Umsetzungskarte als
`reference_class: "unklassifiziert"`, `estimate: null` im Ledger — man hätte
Istwerte, keine Paare, und ein grüner Check über einem Report ohne Paare.

Die Verdrahtung ist zweiteilig:

- **Vorschrift im Kartentext.** Jede Karte kennt ihre Referenzklasse aus dem
  Kartentext (vom Skript gesetzt, nicht vom Modell erfunden) und trägt sie ins
  Abschluss-`metadata`. Karten hinter dem Estimator bekommen dessen Intervall im
  Handoff-Kontext und kopieren es **wörtlich**.
- **Riegel im Check.** `check-sprint.sh` schlägt fehl, wenn eine
  Umsetzungs-, Review- oder Merge-Karte einen Istwert ohne bezifferte
  Schätzung trägt. Eine Vorschrift ohne Riegel ist bei einem Modell eine Bitte.

## Reihenfolge der Arbeit

| # | Schritt | Token? | Nachweis |
|---|---------|--------|----------|
| 1 | `setup.sh` (idempotent), `restore-phase1.sh --ledger` | nein | 11× `ON DISK = yes`; 7 Backfill-Zeilen im Ledger; Vault-Linter sauber |
| 2 | `create-sprint.sh 1` | nein | 7 Karten auf dem Board |
| 3 | S1 durchtakten (`pump.sh` + `watchdog.sh`) | **ja** | `check-sprint.sh S1` grün |
| 4 | `create-sprint.sh 2` (prüft die Auflage) | nein | 12 Karten; verweigert ohne `Kalibrierung S1` |
| 5 | S2 durchtakten | **ja** | `check-sprint.sh S2` grün |
| 6 | Release-Abschluss + `GATE Release — R1` | **ja** | Gate hält, Vorlage in acht Zeilen |
| 7 | CEO antwortet, Karte führt aus | **ja** | `check-release.sh R1` grün |
| 8 | `check-phase2.sh` | nein | die drei Nachweise aus Kapitel 12 |

Nach jedem Schritt ein Git-Commit in `03/`, damit jeder Zwischenstand
zurückrollbar ist.

## Was hier NICHT umgesetzt wird

Phase 3 (Dauerbetrieb) aus Kapitel 12 — zwei Wochen ohne manuellen Eingriff
sind in einer Sitzung nicht nachweisbar. Der Markt-Eingang bleibt in Phase 2
laut Kapitel 12 ohnehin manuell befüllt (`seed/company/sources/2026-08-17/`).
