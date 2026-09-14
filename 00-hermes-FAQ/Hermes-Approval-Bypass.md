# Bestätigungsabfragen pauschal abschalten („--dangerously-skip-permissions" für Hermes)

**Stand:** 13.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11)**
in `~/.hermes/hermes-agent/` — nicht an der im Repo festgeschriebenen v0.20.0.

**Ausgangsfrage:** Kann man die Rückfragen bei der Ausführung eines Profils
(Code-Ausführung, gefährliche Shell-Befehle) einmalig und pauschal wegschalten?

---

## Kurzantwort

Ja, drei Stufen — plus ein harter Rest, der sich **nicht** abschalten lässt.

| Stufe | Befehl | Reichweite |
|---|---|---|
| pro Lauf | `hermes -p <profil> --yolo chat` | dieser Prozess |
| pro Sitzung | `/yolo` | diese Sitzung, überlebt `--resume` |
| **dauerhaft** | `hermes -p <profil> config set approvals.mode off` | dieses Profil, persistent |

`--yolo` ist das direkte Gegenstück zu Claude Codes `--dangerously-skip-permissions`:
„Bypass all dangerous command approval prompts (use at your own risk)"
— `hermes_cli/_parser.py:161`. `/yolo` ist der Sitzungs-Toggle (`cli.py:3197`,
persistiert über `hermes_state_sessions.py:726`).

## `approvals.mode` — die drei Werte

`hermes_cli/approval_mode.py:17`

| Wert | Verhalten |
|---|---|
| `manual` | immer fragen |
| `smart` | Guardian-LLM genehmigt risikoarme Befehle automatisch, eskaliert den Rest (Hermes-Default, `config_defaults.py:1553`) |
| `off` | identisch zu `--yolo` |

`/approvals` ohne Argument zeigt den effektiven Modus, `/approvals off` setzt ihn
aus der Sitzung heraus. Die Datei ist profil-scoped: `hermes -p <profil> config set`
schreibt nach `~/.hermes/profiles/<profil>/config.yaml`.

## Mittelweg statt Holzhammer

`mode: smart` plus gezielte Allowlist. Hermes baut sie aus der eigenen Historie:

```bash
hermes -p <profil> approvals suggest       # schlaegt command_allowlist-Eintraege vor
hermes -p <profil> approvals test '<cmd>'  # Trockenlauf, fuehrt nichts aus
```

## Zwei Einschränkungen

**a) Harte Untergrenze.** Hardline-Blocks und eigene `approvals.deny`-Globs greifen
**vor** jedem Bypass: „not even with --yolo, /yolo, approvals.mode=off, or cron
approve mode" — `tools/approval_floors.py:50,103`. Diese Befehle werden nicht
gefragt, sondern blockiert.

**b) `mode: off` ist nicht ganz so scharf wie `--yolo`.** Bei Shell-Befehlen
(`tools/approval.py:1080`) und `execute_code` (`:1158`) sind beide gleichwertig.
Das allgemeine Tool-/Datei-Schreib-Gate prüft aber nur `_yolo_active()`
(`tools/approval.py:888`) — und das umfasst ausschließlich die beiden Yolo-Quellen,
nicht `mode: off`. Für lückenlos: `--yolo`.

## Nicht vom Yolo-Flag erfasst

| Rückfrage | Schalter |
|---|---|
| Shell-Hooks | `--accept-hooks` / `HERMES_ACCEPT_HOOKS=1` / `hooks_auto_accept: true` (`_parser.py:155`) |
| `/reload-mcp` | `approvals.mcp_reload_confirm` |
| `/clear`, `/new`, `/reset`, `/undo` | `approvals.destructive_slash_confirm` |
| Computer-Use | `computer_use.permission_mode` (`config_defaults.py:2282`; `unrestricted` ist dort bewusst **nicht** erlaubt) |

## Für die Kanban-Stories irrelevant

`hermes kanban dispatch` startet Worker als
`hermes -p <profil> --cli … chat -q "work kanban task <id>"`
(`hermes_cli/kanban_db_dispatch.py:2126,2180`) — eine Single-Query-Session.
Dort fragt Hermes **nie**, sondern entscheidet stumm nach
`approvals.single_query_mode` (Default `deny` = blockieren). Die Rückfragen
stammen aus dem interaktiven `chat`, nicht aus dem Pump.

Umgekehrt: blockieren Worker zu viel, ist der Hebel
`approvals.single_query_mode: approve` bzw. für die Cron-Stories (5, 7, 10, 11)
`approvals.cron_mode: approve`. Defaults aller drei Unattended-Schlüssel
(`cron_mode`, `single_query_mode`, `unattended_mode`): `deny`
(`config_defaults.py:1543-1545`).

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Verhalten von `mode: smart` im Lauf | Guardian-LLM nicht ausgeführt, nur Codepfad gelesen (`tools/approval_smart.py`) |
| Ob `--yolo` wirklich *jede* Rückfrage im Praxislauf abschaltet | kein protokollierter Lauf, nur Gate-Lektüre |
| Vollständigkeit der Hardline-Liste | `approval_floors.py` nur auszugsweise gelesen |
