# Strikt getrennte Setups: Profile vs. eigene Root

**Stand:** 14.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11)**
in `~/.hermes/hermes-agent/` — nicht an der im Repo festgeschriebenen v0.20.0.

**Ausgangsfrage:** Kann man Hermes Agent in mehreren Setups (verfügbare Profile,
Skills etc.) starten, die strikt voneinander getrennt sind?

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
HERMES_HOME=/tmp/rootA python3 -c "
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
