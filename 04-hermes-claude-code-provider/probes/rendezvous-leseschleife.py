"""Offline-Test der Leseschleife: die drei Fälle, ohne CLI und ohne Modell.

A) tool_use -> Aufruf kommt am Rendezvous an            -> Werkzeugaufruf an Hermes
B) tool_use -> die CLI beantwortet ihn selbst (Abweisung) -> weiterlesen, Nachbesserung
C) tool_use -> nichts passiert                          -> lesbarer Fehler nach der Frist
"""
import importlib.util, socket, sys, threading, time, types
from pathlib import Path

PLUGIN = str(Path(__file__).resolve().parent.parent / "plugin")
pkg = types.ModuleType("hccplugin"); pkg.__path__ = [PLUGIN]; sys.modules["hccplugin"] = pkg
def _load(name):
    spec = importlib.util.spec_from_file_location(f"hccplugin.{name}", f"{PLUGIN}/{name}.py")
    mod = importlib.util.module_from_spec(spec); sys.modules[f"hccplugin.{name}"] = mod
    setattr(pkg, name, mod); spec.loader.exec_module(mod); return mod
bridge = _load("bridge"); client = _load("client")
client._RENDEZVOUS_ARRIVAL_TIMEOUT_S = 2.0   # Frist kurz halten

def tool_use(cid, name):
    return {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": cid,
            "name": bridge.mcp_name(name), "input": {"x": 1}}]}}
def cli_answer(cid, text):
    return {"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": cid, "is_error": True, "content": text}]}}
def finished(text="fertig"):
    return {"type": "result", "subtype": "success", "result": text, "usage": {}}

def park(session, cid, name):
    """Tut, was der MCP-Server tut: den Aufruf am Rendezvous abstellen."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(session.rendezvous.path)
    bridge.send_line(sock, {"call_id": cid, "name": name, "arguments": {}})
    return sock

c = client.ClaudeCodeClient()
fails = 0

def case(label, events, arrivals, expect, dead_proc=False, delay=0.0):
    global fails
    session = client._Session(tools_fp="x", workdir="/tmp")
    try:
        if dead_proc:
            # Prozess bereits beendet, Lesethread hinkt hinterher.
            session.proc = types.SimpleNamespace(poll=lambda: 0, stdout=None, stderr=None)
        if delay:
            threading.Timer(delay, lambda: [session.events.put(e) for e in events]).start()
        else:
            for ev in events:
                session.events.put(ev)
        for cid, name, delay in arrivals:
            threading.Timer(delay, park, args=(session, cid, name)).start()
        t0 = time.time()
        try:
            out = c._read_turn(session, timeout=15.0)
            got = (out["stop"], [str(b.get("id")) for b in out.get("calls", [])])
        except Exception as exc:
            got = ("error", type(exc).__name__)
        ok = got == expect
        fails += 0 if ok else 1
        print(f"{'OK  ' if ok else 'FEHL'} {label}: {got}  ({time.time()-t0:.1f}s)"
              f"{'' if ok else f'  erwartet {expect}'}")
    finally:
        session.close()

case("A  Ankunft",
     [tool_use("id1", "terminal")], [("id1", "terminal", 0.1)],
     ("tool_calls", ["id1"]))

case("B  von der CLI abgewiesen, Modell bessert nach",
     [tool_use("id1", "mcp__gbrain__takes_search"),
      cli_answer("id1", "Permission for this tool use was denied."),
      tool_use("id2", "tool_describe")],
     [("id2", "tool_describe", 0.3)],
     ("tool_calls", ["id2"]))

case("C  echter Stillstand",
     [tool_use("id1", "terminal")], [],
     ("error", "RuntimeError"))

case("D  abgewiesen, danach nur noch Text",
     [tool_use("id1", "mcp__gbrain__takes_search"),
      cli_answer("id1", "denied"), finished("Ich konnte das Werkzeug nicht aufrufen.")],
     [],
     ("result", []))

case("E  Prozess beendet, Strom hinkt hinterher",
     [finished("fertig")], [], ("result", []), dead_proc=True, delay=0.3)

case("F  Prozess beendet, Strom bleibt leer",
     [], [], ("error", "RuntimeError"), dead_proc=True)

client.shutdown_all_sessions()
print("ALLE GRÜN" if not fails else f"{fails} FEHLSCHLAG/FEHLSCHLÄGE")
sys.exit(1 if fails else 0)
