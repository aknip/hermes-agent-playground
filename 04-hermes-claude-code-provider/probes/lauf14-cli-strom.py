#!/usr/bin/env python3
"""Lauf 14a/14b: den rohen stream-json der Claude-Code-CLI beobachten.

Beantwortet zwei Fragen, die sich am Hermes-Client nicht beantworten lassen, weil der
nach dem ersten Halt zurueckkehrt:

  14a  Wie verteilt die CLI mehrere ``tool_use``-Bloecke einer Antwort auf Ereignisse,
       und in welcher Reihenfolge stellt sie sie dem MCP-Server zu?
  14b  Was macht sie mit einem Aufruf auf ein Werkzeug, das sie nicht erlauben darf?

Aufbau wie im Plugin: schema-only MCP-Server (``plugin/mcp_server.py``) plus ein
Rendezvous, das hier aber sofort selbst antwortet — kein Hermes im Spiel.

⚠ Kostet echte Modell-Token (ein kurzer ``sonnet``-Zug je Aufruf, rund 0,01–0,02 USD).

    python3 probes/lauf14-cli-strom.py            # 14a: vier Aufrufe in einem Zug
    python3 probes/lauf14-cli-strom.py --denied   # 14b: ein nicht erlaubtes Werkzeug
"""
import json, os, socket, subprocess, sys, tempfile, threading, time
from pathlib import Path

PLUGIN = str(Path(__file__).resolve().parent.parent / "plugin")
sys.path.insert(0, PLUGIN)
import bridge  # noqa: E402

DENIED = "--denied" in sys.argv          # probe_gamma anmelden, aber nicht erlauben
DELAY = float(os.environ.get("PROBE_DELAY", "2.0"))   # so lange "rechnet" Hermes
MODEL = os.environ.get("PROBE_MODEL", "sonnet")

tmp = tempfile.mkdtemp(prefix="hcc-probe-", dir="/tmp")
sock_path = os.path.join(tmp, "rv.sock")
T0 = time.monotonic()


def stamp(msg):
    print(f"{time.monotonic() - T0:6.2f}s  {msg}", flush=True)


srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sock_path)
srv.listen(16)


def handle(conn):
    request = bridge.recv_line(conn)
    if not request:
        conn.close()
        return
    stamp(f"RENDEZVOUS an: {request['call_id']} {request['name']} "
          f"{json.dumps(request.get('arguments'))}")
    time.sleep(DELAY)
    bridge.send_line(conn, {"content": f"Ergebnis fuer {request['name']}", "is_error": False})
    stamp(f"RENDEZVOUS beantwortet: {request['call_id']}")
    conn.close()


def serve():
    while True:
        try:
            conn, _ = srv.accept()
        except Exception:
            return
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


threading.Thread(target=serve, daemon=True).start()

NAMES = ["probe_alpha", "probe_beta"] + (["probe_gamma"] if DENIED else [])
Path(f"{tmp}/tools.json").write_text(json.dumps([
    {"name": n, "description": f"Liefert einen Wert ({n[-1].upper()}).",
     "inputSchema": {"type": "object", "properties": {"text": {"type": "string"}},
                     "required": ["text"]}} for n in NAMES]))
Path(f"{tmp}/mcp.json").write_text(json.dumps({"mcpServers": {bridge.MCP_SERVER_NAME: {
    "type": "stdio", "command": "python3", "args": [f"{PLUGIN}/mcp_server.py"],
    "env": {bridge.ENV_SOCKET: sock_path, bridge.ENV_TOOLS: f"{tmp}/tools.json",
            bridge.ENV_CALL_DEADLINE: "300"},
    "timeout": 600000}}}))
Path(f"{tmp}/system.txt").write_text(
    "Du bist ein Testlaeufer. Du hast keine eigenen Werkzeuge; alles laeuft ueber die "
    "bereitgestellten mcp__hermes__-Werkzeuge.")

# probe_gamma bleibt aus --allowedTools draussen: die CLI muss den Aufruf selbst abweisen.
argv = ["claude", "-p", "--output-format", "stream-json", "--verbose", "--model", MODEL,
        "--tools", "", "--mcp-config", f"{tmp}/mcp.json", "--strict-mcp-config",
        "--permission-prompts", "none", "--disable-slash-commands", "--setting-sources", "",
        "--allowedTools", "mcp__hermes__probe_alpha", "mcp__hermes__probe_beta",
        "--system-prompt-file", f"{tmp}/system.txt"]
prompt = ("Rufe genau einmal das Werkzeug probe_gamma mit text='G' auf."
          if DENIED else
          "Ich brauche vier unabhaengige Werte. Rufe ALLE VIER Aufrufe GLEICHZEITIG in "
          "einem einzigen Zug aus (sie haengen nicht voneinander ab): probe_alpha(text='A'), "
          "probe_alpha(text='B'), probe_beta(text='C'), probe_beta(text='D').")

proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, text=True, bufsize=1, cwd=tmp)
proc.stdin.write(prompt)
proc.stdin.close()

for line in proc.stdout:
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
    except Exception:
        stamp(f"unparsbar: {line[:120]}")
        continue
    kind = event.get("type")
    if kind == "assistant":
        blocks = [b for b in (event.get("message") or {}).get("content") or []
                  if isinstance(b, dict)]
        stamp(f"EVENT assistant  {len(blocks)} Block/Bloecke: "
              + str([(b.get("type"), b.get("name") or (b.get("text") or "")[:40])
                     for b in blocks]))
    elif kind == "user":
        for block in (event.get("message") or {}).get("content") or []:
            if isinstance(block, dict):
                stamp(f"EVENT user block={json.dumps(block)[:700]}")
    elif kind == "system":
        stamp(f"EVENT system/{event.get('subtype')} tools={event.get('tools')}")
    elif kind == "result":
        stamp(f"EVENT result subtype={event.get('subtype')} turns={event.get('num_turns')}")

proc.wait()
stamp(f"Prozess beendet, Code {proc.returncode}")
if err := proc.stderr.read().strip():
    stamp("stderr: " + err[:500])
