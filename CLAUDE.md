# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Was das hier ist

Tutorials und Recherche zu [Hermes Agent](https://hermes-agent.nousresearch.com)
— kein Softwareprojekt: kein Build, kein Linter, keine Tests. Das Produkt sind
Markdown-Dokumente plus Bash-Skripte, die die externe `hermes`-CLI ansteuern.
Alles ist auf **v0.20.0 (2026.8.3) unter macOS** festgeschrieben. Repo-Sprache
ist Deutsch — neue Inhalte ebenfalls.

Schwerpunkt ist `02-hermes-agent-kanban-tutorials/` mit elf eigenständigen
Stories; Übersicht im dortigen `README.md`, Befehlsreferenz in `TUTORIAL.md`.
`03-hermes-agent-software-company/` ist ein leerer Platzhalter.

## ⚠ Die Story-Skripte nicht zur Verifikation ausführen

Sie schreiben in `~/.hermes/` (globale Profile und Boards), starten echte Worker
und kosten Modell-Tokens. Eine Doku-Änderung rechtfertigt keinen Lauf.

`teardown.sh` löscht globale Profile **anhand ihres Namens**, und Namen
kollidieren zwischen Stories (`backend-dev` in 1/3/4, `reviewer` in 3/9,
`planner` in 6/9) — im Zweifel `--keep-profiles` empfehlen. `install-cron.sh`
(Stories 5, 7, 10, 11) legt echte Cron-Jobs an; vor dem Teardown `--remove`.

## Der Verifikationsvertrag

Jede Aussage ist belegt — am lokalen Quellcode der installierten Version
(`~/.hermes/hermes-agent/`, zitiert als `datei.py:123`) oder an einem
protokollierten Lauf („Real gemessen"). Die Online-Doku ist keine Quelle.
Was dadurch nicht gedeckt ist, gehört in die Tabelle „Was ich **nicht**
verifiziert habe" in `VERIFIKATION.md` — nicht als Tatsache ins Tutorial.

## Story-Invarianten

Alle elf Stories sind gleich gebaut (`setup.sh`, `create-tasks.sh`, `pump.sh`,
`teardown.sh`, `profiles/`, `seed/`, `workspace/`) und einzeln durchspielbar;
ein übergreifendes Setup gibt es bewusst nicht.

- **`seed/` ist der Master, `workspace/` die Wegwerfkopie** (gitignored, ebenso
  `task-ids*.env`). Worker überschreiben auch Startdateien — ohne die Trennung
  wäre eine Story nur einmal durchführbar.
- **Ein Profil ist nur dispatchbar, wenn `~/.hermes/profiles/<name>/config.yaml`
  existiert.** `hermes profile create` legt sie nicht an; jedes `setup.sh`
  überträgt deshalb alle vier Modell-Schlüssel (`model.default`, `.provider`,
  `.base_url`, `.api_mode`) per `hermes -p <profil> config set` und prüft danach
  mit `hermes kanban --board <slug> assignees` auf `ON DISK = yes`.
- `setup.sh` bleibt idempotent.

## v0.20.0-Eigenheiten, die die Skripte berücksichtigen

- `hermes kanban show <id>` **ohne `--json` bricht ab** — alle Skripte benutzen
  `show --json`.
- Bei `block` ist der Grund **positional**; `--reason` gibt es nur bei `unblock`.
- `--initial-status blocked` ist **kein** menschliches Tor (kein
  `blocked`-Ereignis, wird mitbefördert).
- `BLOCK_RECURRENCE_LIMIT = 2` gilt **pro `kind`** und ist kein
  Konfigurationsschlüssel — zwei Tore brauchen zwei `kind` oder zwei Karten.
