# Bot Mode und Kanban: Arbeiten Bots im Board zusammen?

**Stand:** 14.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11,
upstream `b6b53c69`)** in `~/.hermes/hermes-agent/` — nicht an der im Repo
festgeschriebenen v0.20.0. Bot Mode ist erst seit Desktop 0.20.3 gebündelt.
Reine Code-Analyse plus Online-Recherche, **kein protokollierter Lauf**.

**Ausgangsfrage:** Ich weise per Kanban-Board eine Karte einem Bot zu, dessen
Profil anweist, die Arbeit gemeinsam mit anderen Bots zu erledigen. Läuft diese
Bot-Zusammenarbeit dann auch im Board — oder nur im Bot-Chat? Muss ich sie in
der Karte einfordern, im Profil/Skill definieren, oder reicht die Mitgliedschaft
in einer Bot-Gruppe?

---

## Kurzantwort

**Nein — die Bot-zu-Bot-Zusammenarbeit läuft ausschließlich im Bot-Chat.**
Ein Kanban-Worker bekommt weder das `message_agent`-Tool noch den Teammate-Roster,
egal ob die Karte es fordert, `SOUL.md` es anweist oder der Bot in einer Gruppe
sitzt. Alle drei Varianten scheitern am selben Gate: dem Session-Titel `"Bot Chat"`.

Zusammenarbeit *innerhalb* des Boards gibt es trotzdem — über einen anderen,
eingebauten Weg: **`kanban_create`** (Kind-Karten mit anderem Assignee).

| Variante | Wirkung im Kanban-Worker |
|---|---|
| In der **Karte** einfordern | Worker liest die Anweisung, hat aber kein `message_agent` und keinen Roster — er kann nur Kanban-Mittel oder die Shell nutzen. |
| Im **Profil / SOUL.md / Skill** definieren | `SOUL.md` wird in jeder Session geladen (`agent/system_prompt.py:489-494`), das Tool fehlt trotzdem. Legacy-Protokolltext in `SOUL.md` wird sogar gestrippt (`agent/prompt_builder.py:1476`). |
| **Gruppenmitgliedschaft** | Wirkungslos außerhalb des Raums. Ein Worker postet nicht in Gruppen und wird von ihnen nicht geweckt. |

## Warum: das Gate im Quellcode

**1. `message_agent` hängt am Session-Titel** — `tools/bot_mode_dm.py:113-124`:

```python
def message_agent_authorized(agent):
    ...
    return _session_title(agent) == BOT_CHAT_TITLE and is_bot_mode_managed(_agent_home(agent))
```

`BOT_CHAT_TITLE = "Bot Chat"` (`tools/bot_mode_probe.py:31`). Das Tool steht in
keiner Registry und keinem Toolset; es wird pro Turn injiziert
(`agent/turn_context.py:956-958` → `ensure_message_agent_tool`). Ein Aufruf aus
einer anderen Session wird beim Dispatch erneut geprüft und abgewiesen
(`bot_mode_dm.py:187-189`): *„message_agent is only available in a Bot Mode
'Bot Chat' session. This session is not one; do not retry."*

**2. Auch Roster und Handoff-Protokoll im System-Prompt sind titelgebunden** —
`agent/system_prompt.py:315-327`: `_bot_mode_parts` fügt Teammate-Liste und
Anweisungen nur ein, wenn `_title == BOT_CHAT_TITLE`. Ein Kanban-Worker weiß
nicht einmal, wer seine Teammates sind.

**3. Kanban-Worker laufen nie im Bot Chat** — `hermes_cli/kanban_db_dispatch.py:2096-2133`
baut den Worker-Befehl:

```
hermes -p <profil> --cli --accept-hooks [--skills …] [--toolsets …] chat -q "work kanban task <id>" [-Q]
```

Kein `-c "Bot Chat"`. Der Bot-Chat-Zustellweg sieht dagegen so aus
(`tools/bot_relay.py:79`):

```
hermes -p <profil> chat --in ~ -c "Bot Chat" --create-if-missing -Q --query-file <tmp>
```

Worker-Sessions werden außerdem mit `source = 'kanban'` markiert
(`hermes_state.py:1471-1483`) und aus den normalen Session-Listen ausgeblendet.

**4. Gruppen-Chats sind nutzergetriebene Räume.** Runden werden durch
*Nutzer*-Nachrichten ausgelöst (max. 3 Runden, 10 Nachrichten pro Sendung;
`website/docs/user-guide/bot-mode.md:100-102`). Mitglieder-Sessions heißen
`Group: <room_id>` (`tui_gateway/hosted_room_driver.py:6`, `:907`). Es gibt
**kein Agent-Tool**, das in einen Raum postet — `groups.send` existiert nur als
JSON-RPC-Methode (`tui_gateway/methods_groups.py:17-21`) und wird in `tools/`,
`agent/` und `model_tools.py` nirgends aufgerufen. Gruppenmitgliedschaft ist
UI-/Gateway-Metadatum (`ui_meta['hermes-bots']`), kein Verhaltensauslöser.

Die mitgelieferte Doku sagt es an einer Stelle selbst
(`website/docs/user-guide/bot-mode.md:115`): *„The tool exists **only** in
canonical Bot Chat sessions on Bot-Mode-managed installs; regular chats,
group-room member sessions, and CLI sessions never see it."*

## Was stattdessen funktioniert

1. **Kanban-native Zusammenarbeit: `kanban_create`**
   (`tools/kanban_tools_schemas.py:352-420`). Jeder Worker hat das
   Kanban-Toolset automatisch, sobald `HERMES_KANBAN_TASK` gesetzt ist. Er kann
   Kind-Karten mit anderem `assignee` anlegen und per `parents` verketten
   (Fan-out/Fan-in); der Dispatcher startet die anderen Profile beim nächsten
   Tick. Das ist die vorgesehene „Bot-Zusammenarbeit im Board" — asynchron über
   Karten und `kanban_comment`, nicht über Chat. Genau dieses Muster nutzen die
   Stories 6 und 9 in `02-hermes-agent-kanban-tutorials/` (`planner`/`reviewer`).

2. **`delegate_task`** für kurze Teilantworten innerhalb eines Worker-Laufs —
   ein Subagent, kein Bot (`website/docs/user-guide/features/kanban.md:85-106`).

3. **Zweistufig — „Bot Mode = the team, Kanban = the work":** Ein
   Orchestrator-Bot arbeitet im Bot Chat (mit `message_agent`), zerlegt das
   Vorhaben und legt per `kanban_create` Karten an; die Ausführung läuft dann
   rein über das Board. So beschreibt es auch der Community-Vergleich (s. Quellen).

4. **Shell-Umweg (nicht empfohlen, nicht verifiziert):** Ein Worker mit
   Terminal-Toolset *könnte* den Bot-Chat-Zustellbefehl aus Punkt 3 oben selbst
   ausführen und so eine Nachricht in den Bot Chat eines anderen Bots werfen.
   Ohne Roster-Validierung, ohne Attribution, und die Antwort landet im Bot Chat
   des Empfängers — nicht beim Worker. Nur aus dem Code abgeleitet, nicht
   gelaufen; gehört nicht in ein Tutorial.

---

## Umgekehrt: Kann eine Karte einen Gruppen-Chat starten?

**Ausgangsfrage:** Kann eine Kanban-Karte (z. B. per Hermes-CLI) einen
Bot-Gruppen-Chat initiieren, etwa um von einer Expertengruppe eine Beurteilung
zu bekommen?

### Kurzantwort

**Technisch ja, aber nicht per `hermes`-CLI und nicht aus der Karte selbst.**
Es gibt kein `hermes groups …`-Subcommand. Gruppen-Chats werden ausschließlich
über JSON-RPC-Methoden `groups.*` gesteuert, die das Backend (`hermes serve` /
`hermes dashboard`) auf einem WebSocket anbietet. Ein Worker mit Terminal-Tool
*könnte* ein Skript ausführen, das den Raum anlegt, die Frage postet und die
Antworten per Polling abholt — ein Eigenbau ohne Hermes-Unterstützung, nur aus
dem Code abgeleitet, nicht gelaufen.

Für „Beurteilung von einer Expertengruppe" ist der kanban-native Weg (unten)
einfacher und robuster.

### Belege

**Kein CLI.** `hermes_cli/subcommands/` enthält kein `groups`; `hermes peer`
spricht nur `/v1/runs` und `/v1/capabilities`
(`hermes_cli/subcommands/peer.py:193,286,326`). Die Doku nennt die Methoden nur
als JSON-RPC für Operator-Recovery (`website/docs/user-guide/bot-mode.md:187-191`).

**Die RPC-Schnittstelle** — `tui_gateway/methods_groups.py:19-23`:
`groups.capabilities, list, create, state, send, rename, log, disband, stop,
retry, approve, …`

| Methode | Parameter | Quelle |
|---|---|---|
| `groups.create` | `room_id`, `name`, `members` — 2–6 Einträge, je `{member_id, profile, handle}`; nur **lokale** Profile, Cross-Gateway-Felder werden abgewiesen | `methods_groups.py:359-367`, `gateway/hosted_room_discussion.py:222-267` |
| `groups.send` | `room_id`, `event_id`, `payload` = **exakt** `{text, thread_id}`; Actor ist serverseitig immer `user` | `methods_groups.py:383-397`, `discussion.py:49,187-192` |
| `groups.state` | `room_id` → Raum + `driver_status` | `methods_groups.py:369-381` |
| `groups.log` | `room_id`, `since_seq`, `limit` → monotone Ereignisliste | `methods_groups.py:485-491` |

**Transport und Auth.** Route `/api/ws` (`hermes_cli/web_routers/chat_ws.py:561`),
newline-delimited JSON-RPC wie über stdio (`tui_gateway/ws.py:1-4`). Backend-Port
default 9119 (`hermes_cli/subcommands/dashboard.py:18`). Im Loopback-Modus
authentifiziert `?token=<_SESSION_TOKEN>` (`hermes_cli/web_server_chat.py`,
`_ws_auth_reason`); der Token kommt aus `HERMES_DASHBOARD_SESSION_TOKEN` oder
ist pro Start zufällig und nur in die Web-UI injiziert
(`hermes_cli/web_server.py:305-312`). Ein Skript muss das Backend also selbst mit
gesetztem Token starten.

**Läuft ohne Desktop.** Der Raum-Treiber startet im Backend-Prozess
(`web_server.py:180`) und im Messaging-Gateway (`gateway/run_startup.py:671`);
Doku: „Rooms keep running when you close the Desktop" (`bot-mode.md:105`).
Aber: `hermes gateway` alleine exponiert die `groups.*`-RPCs **nicht**
(`gateway/` importiert `tui_gateway.ws` nirgends) — es braucht `hermes serve`
oder `hermes dashboard`.

**Ablauf einer Beurteilung.** `groups.create` → `groups.send` mit der Frage →
der Treiber startet Runden: Runde 0 alle (oder die @-erwähnten) Mitglieder,
Folgerunden nur explizit erwähnte; Ende bei stiller Runde oder nach 3 Runden /
10 Nachrichten (`discussion.py:625-649`, Konstanten `:23-26`). Jedes Mitglied
bekommt einen festen Prompt: „reply only when you have something new … otherwise
exactly `(pass)`" (`discussion.py:507-520`). Die Beurteilung liegt danach als
`message.member`-Events im Log; `turn.settled` mit `passed: true/false` markiert
jeden Zug (`gateway/hosted_rooms.py:50-56`). Es gibt **keinen Rückkanal** zum
Aufrufer — der Worker muss `groups.log` pollen, bis `groups.state.driver_status`
idle meldet.

### Praktische Grenzen

- Die Mitglieder arbeiten in versteckten `Group: <room_id>`-Sessions ihres
  Profils — **ohne Kanban-Kontext**, ohne Workspace, ohne `message_agent`. Sie
  sehen nur, was im `text` steht.
- Der Worker braucht Terminal-Tool, einen WebSocket-Client (z. B. Python
  `websockets`) und ein laufendes Backend mit bekanntem Token. Das
  Dashboard-Extra (uvicorn) muss installiert sein.
- Die Methoden sind Desktop-/Operator-API ohne Stabilitätszusage.

### Empfehlung: das Board ist bereits die Expertengruppe

Dasselbe Muster liefert Kanban ohne RPC-Bastelei
(`tools/kanban_tools_schemas.py:352-420`):

1. Der Worker legt per `kanban_create` je eine Karte pro Experten-Profil an
   (`assignee=…`, `body` = zu beurteilende Sache).
2. Eine Synthese-Karte mit `parents=[alle Experten-IDs]` bleibt in `todo`, bis
   alle `done` sind, und wird dann automatisch `ready`.
3. Der Synthesizer liest die Experten-Ergebnisse (Kommentare/Attachments) und
   schreibt die Beurteilung.

Parallel statt serieller Runden, jede Stimme eine nachvollziehbare Karte;
Stories 6 und 9 machen strukturell schon dasselbe. Wer echten Bot-Dialog will
(Experten reagieren aufeinander), setzt einen Orchestrator-Bot im Bot Chat ein,
der die Gruppe in der Desktop-UI hat und am Ende `kanban_create` aufruft — nicht
die Karte.

---

## Was ich **nicht** verifiziert habe

| Aussage | Status |
|---|---|
| Shell-Umweg (Punkt 4 oben) funktioniert tatsächlich | nur aus `bot_relay.py:79` abgeleitet, kein Lauf |
| `groups.create`/`send`/`log` per WebSocket-Skript aus einem Worker heraus | Parameter und Auth aus dem Code, kein Lauf; kein Client-Skript geschrieben |
| Ob `hermes serve` auf dem Repo-Stand v0.20.0 den Raum-Treiber schon startet | nur v0.21.2 gelesen |
| Verhalten des Desktop-Relays über mehrere Maschinen | nur Doku, kein Code gelesen |
| Ob Bot Mode in v0.20.0 (Repo-Stand) überhaupt enthalten ist | nicht geprüft; Doku nennt Desktop 0.20.3 |

## Quellen

- Lokaler Quelltext: `tools/bot_mode_dm.py`, `tools/bot_mode_probe.py`,
  `tools/bot_relay.py`, `agent/system_prompt.py`, `agent/turn_context.py`,
  `hermes_cli/kanban_db_dispatch.py`, `tools/kanban_tools_schemas.py`,
  `tui_gateway/methods_groups.py`, `tui_gateway/hosted_room_driver.py`,
  `tui_gateway/ws.py`, `gateway/hosted_room_discussion.py`,
  `gateway/hosted_rooms.py`, `gateway/run_startup.py`,
  `hermes_cli/web_server.py`, `hermes_cli/web_server_chat.py`,
  `hermes_cli/web_routers/chat_ws.py`, `hermes_cli/subcommands/peer.py`
- [Bot Mode – Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode)
- [Hermes Agent Bot Mode vs Kanban (dev.to)](https://dev.to/vivek_shetye/hermes-agent-bot-mode-vs-kanban-when-to-use-each-and-why-i-use-both-2che)
- [Hermes Bot Mode: A Team of AI Agents That Hand Off Work (dev.to)](https://dev.to/vivek_shetye/hermes-bot-mode-i-built-a-team-of-ai-agents-that-hand-off-work-to-each-other-a49)
- [Nous Research Ships Bot Mode (MarkTechPost)](https://www.marktechpost.com/2026/08/17/nous-research-hermes-bot-mode/)
