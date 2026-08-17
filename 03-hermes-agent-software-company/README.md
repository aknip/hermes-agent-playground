# 03 — Hermes Agent Software Company

**ESF — Enterprise Software Factory**: eine autonom agierende Organisation aus
Hermes-Agenten, die eine bestehende B2B-Software kontinuierlich
weiterentwickelt — Markt- und Wettbewerbsanalyse, lebende Feature-Roadmap,
Sprints und Releases, Qualitätssicherung, Aufwandsschätzung mit
Ist-Kalibrierung. Ein Mensch führt als CEO und entscheidet nur an definierten
Gates.

Dieses Verzeichnis ist zweierlei:

- **[`KONZEPT.html`](KONZEPT.html)** — das vollständige Konzept (im Browser
  öffnen): Rechercheteil, Organisationsmodell, Board-Design, Gate-Mechanik,
  E2E-Suite als Regressionsnetz und lebendes Nutzerhandbuch,
  Superpowers-Skills als Bau-Methodik, OpenRouter mit Kosten-Tracking,
  Hermes-nativer Betrieb, Umsetzungs-Roadmap.
- **die lauffähige Installation** — alles, was die ESF braucht, um auf ein
  beliebiges Git-Repo aufgesetzt und jederzeit wieder entfernt zu werden.
  Gebaut wie die Stories in `02-hermes-agent-kanban-tutorials/`.

Umgesetzt sind **Phase 0 (Gerüst)** und **Phase 1 (Onboarding)** aus Kapitel 12
des Konzepts, gefahren gegen
[`../04-hermes-agent-software-company-test-kaneo`](../04-hermes-agent-software-company-test-kaneo)
(Kaneo v2.19.1). Was dabei gemessen wurde und was Annahme blieb, steht in
[`VERIFIKATION.md`](VERIFIKATION.md); der Lauf selbst in
[`RUN-PROTOKOLL.md`](RUN-PROTOKOLL.md).

## In fünf Minuten

```bash
./setup.sh                      # Board, elf Profile, Skills, Vault  (idempotent)
./probelauf.sh                  # Phase-0-Nachweis: die Dummy-Kette anlegen
./pump.sh                       # takten und zusehen
./gate.sh                       # wenn ein Gate steht: Vorlage lesen, antworten
./probelauf.sh --pruefen        # Nachweis abnehmen

./create-onboarding.sh          # Phase 1: der Analysegraph auf dem Ziel-Repo
./pump.sh
./gate.sh approve <id>          # die Roadmap freigeben
./scripts/check-onboarding.sh   # Phase-1-Nachweis

./install-cron.sh --remove      # immer VOR dem Teardown
./teardown.sh                   # zurückbauen; löscht nur .esf-markierte Profile
```

Vorbedingungen: `hermes` v0.20.0, `jq`, `git`, `python3`, `pnpm`, Docker für
die Testdatenbank des Ziel-Repos. Modell und Provider kommen aus der
Hermes-Root-Konfiguration.

## Was hier liegt

| Datei | Rolle |
|-------|-------|
| `setup.sh` | Board `sw-company`, elf `esf-`-Profile, Skills profil-lokal, Vault. Idempotent, mit drei modellfreien Selbsttests am Ende |
| `teardown.sh` | Rückbau. Löscht **nur** Profile mit `.esf`-Markerdatei; `--keep-profiles`, `--keep-board` |
| `reset-workspace.sh` | `workspace/` frisch aus `seed/`. `--git` zeigt die Vault-Historie |
| `probelauf.sh` | Der Phase-0-Nachweis: Dummy-Kette Spezifikation→Bau→Review→Riegel plus Probe-Gate |
| `create-onboarding.sh` | Der Phase-1-Analysegraph: sechs Karten, zwei Fan-ins, ein Gate |
| `pump.sh` | Manueller Dispatch-Takt (Ersatz fürs Gateway im Testbetrieb) |
| `gate.sh` | **Die CEO-Hülle.** Der einzige legitime Weg, ein Gate zu öffnen |
| `install-cron.sh` | Taktet die vier Betriebs-Skripte. `--remove` vor jedem Teardown |
| `vendor-superpowers.sh` | Wartungswerkzeug: holt die rollenspezifischen Skill-Teilmengen ins Repo |
| `profiles/<name>/` | `SOUL.md` (Modell-Prompt, englisch wie in allen Stories) und `description.txt` (der Decomposer routet darüber) |
| `skills/<profil>/` | Die profil-lokalen Superpowers-Teilmengen, MIT-lizenziert, plus `HERMES-TOOLS.md` |
| `seed/company/` | Der Vault-Master: `AGENTS.md`, `cadence.yaml`, Struktur, Start-Korpus |
| `seed/lint-selbsttest/` | Fixture mit genau neun bekannten Linter-Befunden |
| `seed/quellen.txt` | Die Markt-Quellen, die `fetch-sources.sh` täglich holt |
| `workspace/` | Die Wegwerfkopie — gitignored |
| `scripts/` | Betrieb und Riegel, siehe unten |

### Die Skripte in `scripts/`

| Skript | Takt | Aufgabe |
|--------|------|---------|
| `tick.sh` | Cron 07:00 | Selbst-Übersprung (drei Bedingungen), Markt-Fetch, täglicher E2E-Regressionslauf, fällige Karten mit Datums-Idempotenzschlüssel |
| `monitor.sh` | stündlich | Liest das **Ereignis-Log**, nicht `diagnostics`: `respawn_guarded`, `block_loop_detected`, `crashed`, Karten in `triage`, Unblocks ohne `gate.sh`-Verb. Dazu OpenRouter-Restguthaben und die Abschluss-Erkennung |
| `report-gates.sh` | Cron 18:00 | Der Gate-Report als HTML — der verlässliche Weg zum CEO |
| `ledger-sync.sh` | Cron 23:30 | Wanduhrzeiten aus dem Board, Kosten aus OpenRouter, jedes (Schätzung, Ist)-Paar ins Ledger |
| `merge-riegel.sh` | je Merge | Sechs Prüfungen; merged oder verweigert. **Kein Modell merged** |
| `vault-lint.py` | je Schreibvorgang | Setzt `company/AGENTS.md` durch und zitiert bei jedem Befund den Abschnitt |
| `fetch-sources.sh` | vom Tick | Holt die Quellen und **normalisiert deterministisch**, bevor sie im Korpus landen |
| `check-onboarding.sh`<br>`check-daily.sh` | je Ebene | Deterministische Endzustands-Checks — Code entscheidet, ob etwas fertig ist |
| `provision-keys.sh` | einmalig | Ein OpenRouter-Key je Profil mit USD-Limit. **Annahme**, siehe `VERIFIKATION.md` |

## Die elf Profile

Alle tragen das Präfix `esf-`; Profile liegen global in `~/.hermes/profiles/`,
und das Präfix plus die `.esf`-Markerdatei hält den Namensraum sauber und
schützt fremde Profile vor dem Teardown.

| Profil | Auftrag | Tier | Skills |
|--------|---------|------|--------|
| `esf-chief-of-staff` | Sprint-Planung, Kartengraphen, Gate-Vorlagen, Sprint-Abschluss | hoch | writing-plans · dispatching-parallel-agents · brainstorming |
| `esf-market-scout` | Den Tages-Korpus sichten, normalisieren, deduplizieren | günstig | — |
| `esf-market-analyst` | Signale scoren, Feature-Hypothesen, Subtraktions-Sichtung | hoch | — |
| `esf-product-manager` | Spezifikationen mit Akzeptanzkriterien | hoch | brainstorming · verification-before-completion |
| `esf-architect` | Konzepte, ADRs, Schnittstellenverträge für parallele Arbeit | hoch | writing-plans · dispatching-parallel-agents · brainstorming |
| `esf-estimator` | Referenzklasse, Intervallschätzung, Konfidenz — nur aus dem Ledger | mittel | — |
| `esf-dev-a`, `esf-dev-b` | Features in eigenen Worktrees umsetzen, mit Tests | hoch | test-driven-development · executing-plans · systematic-debugging · using-git-worktrees · receiving-code-review |
| `esf-reviewer` | Fan-in-Review, führt fremde Tests selbst aus | hoch | requesting-code-review · verification-before-completion |
| `esf-qa-release` | Eigner der E2E-Suite, Merge-Gate, Release-Paket | mittel | verification-before-completion · systematic-debugging · finishing-a-development-branch |
| `esf-controller` | Schätzgüte, Kosten, Velocity, CEO-Report | mittel | — |

Die vier ohne Skills sind Absicht: Ihre Arbeit ist Erkennen, Bewerten und
Messen, nicht Bauen. Ihre Präzision wohnt in der `SOUL.md`.

**In diesem Lauf zeigen alle drei Tiers auf `deepseek/deepseek-v4-flash-0731`.**
Die Struktur bleibt: `ESF_MODELL_HOCH=… ./setup.sh` differenziert sie ohne
Umbau.

## Die vier Gates

Nur hier ist der Mensch gefragt. Ein Gate ist eine **blockierte Karte** — der
einzige Mechanismus in v0.20.0, der den Dispatcher nachweislich anhält.

| Gate | Wann | Verben |
|------|------|--------|
| Roadmap | je Quartals-Abschluss, bei Kurswechsel — nicht delegierbar | `approve` · `modify` · `shelve` |
| Release | je Release-Abschluss (inhaltsgetrieben) | `approve` · `modify` · `shelve` |
| Irreversibel | Feature-Entfernung, Breaking Change, Migration | `approve` · `modify` · `shelve` |
| Budget | Ist über 150 % der P90-Schätzung | `continue` · `cut` · `stop` |

Drei Regeln, die aus der Mechanik folgen und nicht aus Geschmack:

- **Jede Entscheidung bekommt ihre eigene Karte.** `BLOCK_RECURRENCE_LIMIT = 2`
  ist hart kodiert und zählt je Blockgrund-Art; eine stehende
  „CEO-Freigaben"-Karte wäre nach der zweiten Frage still in `triage`
  verschwunden.
- **Gate-Karten werden angelegt, solange ihr Elternteil noch offen ist** —
  sonst startet der Dispatcher sie zwischen `create` und `block`.
- **Höchstens drei Fragen pro Tageslauf** (`gate_fragen_pro_tag` in
  `cadence.yaml`). Ein Gate mit zwölf wartenden Karten wird nicht sorgfältiger
  beantwortet, sondern durchgewinkt.

Und: **kein Agent öffnet je ein Gate.** Das Worker-Werkzeug `kanban_unblock`
ist per SOUL verboten, `gate.sh` setzt vor jede Antwort ein validiertes Verb,
und `monitor.sh` meldet jedes Unblock-Ereignis ohne dieses Muster als
Governance-Verstoss.

## Auf ein anderes Repo aufsetzen

Ein einziger Ort ist produktspezifisch: der Abschnitt `produkt:` in
`seed/company/cadence.yaml` (Pfad, Branch-Präfix, E2E-Verzeichnis, E2E-Befehl
und dessen Vorbedingung). Dazu die Quellenliste in `seed/quellen.txt`. Danach
`./reset-workspace.sh && ./setup.sh`.

Was das Ziel-Repo mitbringen muss: eine eigene Git-Historie (die ESF arbeitet in
Branches und Worktrees), einen Testbefehl, der auf dem Ausgangsstand grün ist,
und ein `AGENTS.md` mit der Definition of Done.

## Vorsicht

- **`teardown.sh` löscht das Board mit seiner ganzen Historie.** Karten,
  Blockgründe, Kommentar-Threads und Abschluss-`metadata` sind das Protokoll
  der Organisation — sichern, bevor man zurückbaut.
- **`install-cron.sh` legt echte Cron-Jobs an.** Vor jedem Teardown
  `--remove`, sonst laufen die Skripte gegen ein Board, das es nicht mehr gibt.
- **Das Produkt-Repo bleibt beim Teardown unangetastet.** Branches, Worktrees
  und Commits sind das Ergebnis, nicht das Werkzeug; `teardown.sh` zeigt am
  Ende, was aufzuräumen wäre.
