# Strikt getrennte Setups: Profile vs. eigene Root

**Stand:** 14.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11)**
in `~/.hermes/hermes-agent/` — nicht an der im Repo festgeschriebenen v0.20.0.

**Ausgangsfrage:** Kann man Hermes Agent in mehreren Setups (verfügbare Profile,
Skills etc.) starten, die strikt voneinander getrennt sind?

Nachgetragen am 14.09.2026: eine Schritt-für-Schritt-Anleitung für CLI **und**
Desktop-App unter einer eigenen Root, was dabei parallel weiterlaufen darf, und
wie man eine laufende Installation vollständig stoppt.

---

## Kurzantwort

Ja, in **zwei Stufen** — und die beiden genannten Dinge fallen auf verschiedene Seiten:
Skills sind pro Profil getrennt, die Profilliste selbst ist es nicht.

| Stufe | Schalter | trennt |
|---|---|---|
| Profil | `hermes -p <name> …` | Konfiguration, Skills, Sitzungen, Gedächtnis, Zustand |
| **Root** | `HERMES_HOME=/pfad/außerhalb/~/.hermes` | zusätzlich Kanban, Profilregistry, Credentials |

## Die Grenze ist die Root, nicht das Profil

`get_default_hermes_root()` (`hermes_constants.py:166`) entscheidet alles: liegt
`HERMES_HOME` irgendwo **unter** dem nativen `~/.hermes` — auch
`~/.hermes/profiles/<name>` — fällt die Root auf `~/.hermes` zurück. Liegt es
**außerhalb**, ist es selbst die Root. Alles „shared by design" hängt an dieser Root.

Real gemessen (drei Aufrufe der Resolver-Funktionen mit gesetztem `HERMES_HOME`,
ohne CLI und ohne Schreibzugriff):

| `HERMES_HOME` | root | kanban.db | profiles | skills |
|---|---|---|---|---|
| `~/.hermes` | `~/.hermes` | `~/.hermes/kanban.db` | `~/.hermes/profiles` | `~/.hermes/skills` |
| `~/.hermes/profiles/developer` | `~/.hermes` ⚠ | `~/.hermes/kanban.db` ⚠ | `~/.hermes/profiles` ⚠ | `…/developer/skills` ✅ |
| `/tmp/rootA` | `/tmp/rootA` | `/tmp/rootA/kanban.db` | `/tmp/rootA/profiles` | `/tmp/rootA/skills` |

Die dritte Zeile wurde unter einem längeren Temp-Pfad gemessen und hier als
`/tmp/rootA` gekürzt; die Auflösung ist für jeden Pfad außerhalb `~/.hermes` gleich.
Reproduzierbar mit:

```bash
cd ~/.hermes/hermes-agent
HERMES_HOME=/tmp/rootA venv/bin/python -c "
import hermes_constants as hc
from hermes_cli import kanban_db as kb, profiles as pf
print(hc.get_hermes_home(), hc.get_default_hermes_root(),
      kb.kanban_db_path(), pf._get_profiles_root(), hc.get_skills_dir(), sep='\n')"
```

## Stufe 1: Profile

`hermes_cli/profiles.py:1` nennt das selbst „Profile management for multiple
isolated Hermes instances".

**Eigen pro Profil** (alles unter `HERMES_HOME`, das bei `-p` auf
`~/.hermes/profiles/<name>` zeigt): `config.yaml` (`hermes_constants.py:1133`),
`.env` (`:1143`), `skills/` (`:1138`), `SOUL.md`, `memories/`, `sessions/`,
`state.db`, `plugins/`, `hooks/`, `cron/`, `vault/`, `workspace/`, `home/`
(Verzeichnisliste: `profiles.py:29`).

```bash
hermes profile create <name>                 # neu, mit gebündelten Skills
hermes profile create <name> --no-skills     # leeres Profil, ohne Skill-Sync
hermes profile create <name> --clone         # config.yaml, .env, SOUL.md, Skills übernehmen
hermes profile create <name> --clone-all     # Vollkopie ohne Historie und Messaging-Kanäle
hermes -p <name> chat                        # einmalig aktivieren
hermes profile use <name>                    # sticky (schreibt <root>/active_profile, main.py:526)
```

## Was Profile bewusst *nicht* trennen

Genau hier bricht „strikt":

- **Die Profilliste selbst.** `_get_profiles_root()` (`profiles.py:132`) ist
  HOME-verankert statt `HERMES_HOME`-verankert, „so `coder profile list` sees all
  profiles". `hermes -p a profile list` sieht also auch `b`. `AGENTS.md:273` nennt
  das ausdrücklich Absicht, keinen Bug.
- **Das Kanban-Board.** `kanban_home()` (`kanban_db.py:382`): „Shared across
  profiles **BY DESIGN**: resolving through the active profile's HERMES_HOME would
  fork the board per profile and break the dispatcher/worker handoff." Für die
  Stories in `02-hermes-agent-kanban-tutorials/` heißt das: alle Profile arbeiten
  auf demselben `~/.hermes/kanban.db`.
- **Credentials.** `_global_auth_file_path()` (`auth.py:485`): erst die
  profil-eigene `auth.json`, dann Fallback auf die der Root. Ohne eigene Datei
  teilen sich die Profile die Zugänge.
- **Der Gateway-Prozess.** Per Default eigener Socket und eigene PID unter
  `HERMES_HOME` (`gateway/control_socket.py:4`, `gateway/status.py:158`) — aber
  der Multiplexer kann einen Prozess mehrere Profile bedienen lassen
  (`gateway_multiplex_served.py:1`, `GATEWAY_MULTIPLEX_PROFILES`).
  Prozess-Isolation ist der Default, keine Eigenschaft.
- **Die sticky Profilwahl.** `hermes profile use` schreibt `<root>/active_profile`,
  und `main.py:526` liest die Datei in jeder späteren Shell ohne `-p`. Ein
  vermeintlich „frisches" Terminal erbt damit die Auswahl — dieselbe Klasse
  Überraschung wie die Punkte darüber.

## Stufe 2: Eigene Root

Die strikte Variante — eigene Profilregistry, eigenes Kanban, eigene Skills,
eigene Credentials:

```bash
export HERMES_HOME=/pfad/außerhalb/von/~/.hermes
hermes profile create backend-dev --no-alias   # legt <root>/profiles/backend-dev an
hermes -p backend-dev chat
```

Innerhalb einer solchen Root funktioniert die Profil-Mechanik unverändert:
`profiles.py:138` deckt „Docker/custom deployments (e.g. `/opt/data`)" explizit ab.

`--no-alias` ist hier kein Detail: `_get_wrapper_dir()` (`profiles.py:149`) ist fest
`~/.local/bin`, unabhängig von `HERMES_HOME`. Ohne das Flag schreibt eine Custom-Root
also ein Wrapper-Skript nach außen — und dessen Inhalt ist
`exec hermes -p <profil> "$@"` (`profiles.py:339`) **ohne** `HERMES_HOME`. Aus einer
Shell ohne die Variable zeigt der Wrapper damit auf `~/.hermes/profiles/<profil>`,
nicht auf die Custom-Root.

Feingranularer geht es auch einzeln, ohne die Root zu verschieben:

| Variable | Wirkung | Quelle |
|---|---|---|
| `HERMES_KANBAN_HOME` | Board-Root abkoppeln | `kanban_db.py:382` |
| `HERMES_KANBAN_DB` | einzelne DB-Datei pinnen (nutzt der Dispatcher für Worker) | `kanban_db.py:490` |
| `HERMES_BUNDLED_SKILLS` | gebündelte Skills umbiegen | `hermes_constants.py:310` |
| `HERMES_OPTIONAL_SKILLS` | optionale Skills umbiegen | `hermes_constants.py:300` |

## Schritt für Schritt: eine zweite Root aufsetzen

Für die CLI genügt `HERMES_HOME`. Die Desktop-App braucht drei weitere Angaben —
und sie wird **nicht** über `/Applications/Hermes.app` gestartet: das Bundle dort
ist der Tauri-Installer (`Info.plist`: `com.nousresearch.hermes.setup`), und eine
aus dem Finder gestartete App erbt ohnehin keine Shell-Variablen.

**1. Root anlegen und konfigurieren**

```bash
export HERMES_HOME=~/hermes-test        # irgendwo außerhalb von ~/.hermes
hermes setup
```

`hermes setup` schreibt nach `get_hermes_home()` (`setup.py:664`), also in die neue
Root. Alternativ `config.yaml`, `.env` und `auth.json` aus `~/.hermes` kopieren.
Der erste Lauf synchronisiert die gebündelten Skills im Vordergrund
(`hermes_cli/main.py:1568`).

**2. Auflösung prüfen** — der Python-Einzeiler aus „Die Grenze ist die Root, nicht
das Profil", mit dem eigenen Pfad statt `/tmp/rootA`. Alle vier Zeilen müssen
unter der neuen Root liegen.

**3. CLI benutzen**

```bash
export HERMES_HOME=~/hermes-test
hermes chat
hermes profile create backend-dev --no-alias
hermes -p backend-dev chat
```

`--no-alias` wie in Stufe 2 beschrieben. Die Variable muss in **jeder** Shell
gesetzt sein, sonst landet man wieder in `~/.hermes`.

**4. Desktop starten**

```bash
export HERMES_HOME=~/hermes-test
export HERMES_DESKTOP_USER_DATA_DIR=~/hermes-test/desktop-userdata
hermes desktop --skip-build --hermes-root ~/.hermes/hermes-agent
```

Warum alle vier Angaben nötig sind:

| Angabe | Warum | Quelle |
|---|---|---|
| `HERMES_HOME` | liest der Electron-Hauptprozess direkt und reicht sie an das Python-Backend weiter; Logs wandern nach `<root>/logs/desktop.log` | `main.ts:789`, `:2628`, `:884` |
| `--hermes-root` | Desktop sucht den Checkout unter `<HERMES_HOME>/hermes-agent`, den es in der neuen Root nicht gibt; ohne das Flag greift es auf das `hermes` im PATH zurück oder startet den Erstinstallations-Bootstrap | `main.ts:838`, `:5047-5155`, Flag: `subcommands/gui.py:29` |
| `--skip-build` | der Build-Stempel liegt unter `<HERMES_HOME>/desktop-build-stamp.json` und fehlt in der neuen Root, `hermes desktop` würde die Electron-App neu bauen | `main_desktop.py:42-45`, `:112` |
| `HERMES_DESKTOP_USER_DATA_DIR` | trennt die Electron-eigenen Daten unter `~/Library/Application Support/Hermes` — darunter `active-profile.json`, dessen Profil Desktop als `--profile` an den Backend-Start hängt und das in der neuen Root nicht existiert (die CLI bricht dann ab) | `main.ts:474-480`, `:12969-12973`, `main.py:539-547` |

`HERMES_HOME` gewinnt weiterhin gegenüber dem User-Data-Pfad (`main.ts:789-795`).

**5. Zurück zum Standard** — neue Shell öffnen oder beide Variablen `unset`en.
An `~/.hermes` ändert sich nichts.

## Parallelbetrieb: vorher nichts beenden

Eine zweite Root läuft neben der bestehenden Installation, sofern die beiden
Vorkehrungen aus Schritt 4 greifen. Sie sind dort nicht Komfort, sondern
Bedingung:

- **Eigenes User-Data-Verzeichnis.** Electron legt seine Instanzsperre dort ab
  (`SingletonLock`). Ohne eigenes Verzeichnis beendet sich die zweite Instanz
  sofort (`main.ts:18040`).
- **`--skip-build`.** Ein Build räumt das `release/mac-arm64/Hermes.app` weg, aus
  dem die laufende Instanz gerade läuft. Der Aufräumer, der vorher laufende
  Prozesse beendet, greift nur unter Windows (`main_desktop.py:632-640`).

Die laufende Instanz wird von der neuen nicht angefasst: der Aufräumer für
verwaiste Backends liest nur die Liste im eigenen User-Data-Verzeichnis und
verschont jeden Prozess mit lebendem Electron-Elternprozess
(`backend-ownership.ts:254-272`). Der Gateway hängt an `HERMES_HOME`, jede Root
bekommt eigene `gateway.pid`, `gateway.lock` und `gateway.sock`
(`gateway/status.py:158`). Den Port vergibt das Betriebssystem (`--port 0`).

**Die Ausnahme: kein Update während des Parallelbetriebs.** Beide Instanzen laufen
aus demselben Checkout (siehe „Zwei Einschränkungen" a), und die Schutzsperre
dagegen ist root-lokal — `updateHandoffConflict(HERMES_HOME)` (`main.ts:4083`).
Die zweite Root sieht den Marker der ersten nicht. Also erst beide beenden, dann
`hermes update`, dann neu starten.

## Die laufende Installation vollständig stoppen

Zwei voneinander unabhängige Dinge: die Desktop-App mit ihren Backend-Prozessen
und die Gateways unter launchd. `hermes gateway list` zeigt letztere. Real
gemessen auf dem Arbeitsrechner (14.09.2026):

```
Gateways:
  ✓ default (current)        — PID 57541
  ✗ claude-dev               — not running
  ✓ developer                — PID 10811
  ✗ my-test-bot              — not running
  ✓ summarizer               — PID 80055
```

Dazu die Desktop-App mit drei eigenen `serve`-Backends. Ein Profil kann damit
**zwei** Prozesse haben: einen launchd-Gateway und ein Desktop-Backend.

**1. Desktop-App beenden** (Cmd+Q). Sie fährt ihre Backends geordnet herunter,
SIGTERM mit Eskalation auf SIGKILL (`pool-stop.ts`); bei laufender Arbeit fragt
sie nach und bietet „Keep Running" (`main.ts:18244`). Zuerst die App, sonst
startet sie neue Backends, während die Gateways gestoppt werden.

**2. Gateways stoppen** — ein Befehl pro Profil, weil das launchd-Label
profilgebunden ist (`gateway.py:3548-3551`). Einen Sammelschalter gibt es nicht.
Der Aufruf ohne `-p` trifft das *aktive* Profil, nicht zwingend `default`: eine
sticky Auswahl aus `hermes profile use` gilt auch hier (`main.py:526`).

```bash
hermes gateway stop
hermes -p developer gateway stop
hermes -p summarizer gateway stop
```

Ein `kill` reicht nicht: die Agents stehen auf `KeepAlive = true` (gemessen in
`~/Library/LaunchAgents/ai.hermes.gateway*.plist`), der Prozess käme sofort
zurück. Der Befehl macht deshalb ein `launchctl bootout`, wartet bis zu zehn
Sekunden auf den sauberen Ausstieg und schickt nach fünf Sekunden SIGKILL nach
(`gateway.py:4151-4166`).

**Vollständig heißt: nur bis zum nächsten Login.** Die Plists bleiben liegen und
haben `RunAtLoad = true`. Wer sie dauerhaft los sein will, entfernt die
Definition statt sie nur zu entladen (`gateway.py:4089-4098`):

```bash
hermes gateway uninstall
hermes -p developer gateway uninstall
hermes -p summarizer gateway uninstall
```

Zurück geht es mit `hermes gateway install` pro Profil.

**3. Prüfen**

```bash
hermes gateway list
ps -Ao pid,ppid,command | grep -E "hermes_cli|Hermes.app" | grep -v grep
```

Überlebt ein einzelner `serve`-Prozess das Beenden der App, kann er einzeln
beendet werden — `pool-stop.ts` nennt genau diesen Fall als historisches Problem.

## Empfehlung

Profile für Rollen-Trennung, die sich ein Board teilen **soll** — das ist der Fall
in den Kanban-Stories, wo Dispatcher und Worker über dasselbe Board sprechen
müssen. Separate `HERMES_HOME`-Roots für Setups, die sich wirklich nichts teilen
dürfen.

Eine Warnung für dieses Repo: `teardown.sh` der Stories löscht globale Profile
anhand ihres Namens — und *welche* Registry das trifft, hängt an der Shell. Ohne
gesetztes `HERMES_HOME` ist es `~/.hermes/profiles`; mit exportierter Custom-Root
ist es deren `profiles/` (`profiles.py:132` + `:138`). Eine zweite Root schützt also
nicht automatisch, sie verschiebt nur das Ziel. Im Zweifel `--keep-profiles`.

## Zwei Einschränkungen

**a) Eine eigene Root trennt Daten, nicht Code.** Der Checkout `hermes-agent/`,
`bin/` und `node_modules` liegen an der Default-Root und sind von Clones
ausgenommen (`profiles.py:_CLONE_ALL_DEFAULT_EXCLUDE_ROOT`). Es bleibt eine
Installation und ein Binary.

**b) `HERMES_HOME` unter `~/.hermes`, aber nicht als Profil** (etwa
`~/.hermes/mein-setup`) bringt nichts: die Root fällt auf `~/.hermes` zurück,
Kanban und Profilregistry bleiben geteilt. Außerhalb legen, sonst gilt Stufe 1.

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Container-Grade-Isolation (Prozess, Netz, Dateisystem gegen einen bösartigen Worker) | nur Pfadauflösung gelesen und gemessen, kein Sandbox-Codepfad |
| Verhalten des Gateway-Multiplexers im Lauf | `gateway_multiplex_served.py` nur gelesen, kein Lauf mit `GATEWAY_MULTIPLEX_PROFILES` |
| Ob ein Worker-Dispatch über eine Custom-Root vollständig durchläuft | kein protokollierter Lauf; `HERMES_KANBAN_DB` wird laut `kanban_db_dispatch.py` in Worker injiziert, ungetestet |
| Vollständigkeit der Liste profil-eigener Verzeichnisse | `_PROFILE_DIRS` plus Verzeichnis-Listing eines Profils, keine erschöpfende Codesuche |
| Verhalten unter Windows (`%LOCALAPPDATA%\hermes`) | nur macOS-Pfad gemessen (`hermes_constants.py:48`) |
| `hermes profile create` unter einer Custom-Root | nicht ausgeführt — der Befehl schreibt globale Profile, siehe `CLAUDE.md`; nur die Resolver gemessen und `profiles.py` gelesen |
| Die Schritt-für-Schritt-Anleitung als Ganzes | weder `hermes setup` noch `hermes desktop` unter einer Custom-Root ausgeführt; beide starten Prozesse und schreiben außerhalb des Repos. Alle Aussagen aus dem Quelltext |
| Paralleler Betrieb zweier Desktop-Instanzen | kein Lauf; nur Instanzsperre, `backend-ownership.ts` und die Gateway-Pfadauflösung gelesen |
| Start über `/Applications/Hermes.app` mit `launchctl setenv HERMES_HOME` | ungetestet — der Installer liest die Variable laut Binary-Strings, der Terminalweg ist aber der belegte |
| Desktop-Onboarding in einer Root ohne konfigurierten Provider | nicht angesehen; deshalb `hermes setup` als Schritt 1 |
| `hermes gateway stop` / `uninstall` | nicht ausgeführt — nur `hermes gateway list` (lesend) sowie `gateway.py` und die Plists gelesen |
