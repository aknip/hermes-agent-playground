#!/usr/bin/env python3
"""Schema-only-MCP-Server: meldet Hermes' Werkzeuge an und führt keines davon aus.

Der Kniff (von ``pi-claude-cli`` übernommen, dort „schema-only server"): Claude Code
bekommt die Werkzeuge über seinen *nativen* Kanal — strukturierte Definitionen statt
Text-im-Prompt und Regex-Rückparsing wie in ``agent/acp_openai_bridge.py``.

Der Unterschied zu Pi: Pi bricht die CLI nach dem Vorschlag ab („break early") und baut
die Sitzung später neu auf — teuer, ``pi-claude-bridge`` misst dafür ~58 % Cache-Verlust.
Hier **blockiert** ``tools/call`` stattdessen am Rendezvous, bis Hermes das Ergebnis
geliefert hat. Claude Code wartet im Werkzeugaufruf und macht danach im selben Prozess
weiter; die Sitzung wird nie neu gebaut.

Läuft als eigener Prozess, gestartet von Claude Code über ``--mcp-config``. Redet
ausschließlich JSON-RPC über stdio — **nichts** außer Protokollrahmen darf nach stdout.
"""

from __future__ import annotations

import json
import os
import socket
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bridge  # noqa: E402  (nach dem sys.path-Eingriff)

PROTOCOL_VERSION = "2025-06-18"

# Jeder ``tools/call`` läuft in einem eigenen Thread, also muss stdout serialisiert
# werden — zwei halbe JSON-Zeilen ineinander wären Protokollbruch.
_STDOUT_LOCK = threading.Lock()


def _send(payload: dict) -> None:
    with _STDOUT_LOCK:
        try:
            sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            # Claude Code ist weg — nichts mehr zu melden.
            pass


def _result(msg_id, result) -> None:
    _send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def _error(msg_id, code: int, message: str) -> None:
    _send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def _load_tools() -> list[dict]:
    path = os.environ.get(bridge.ENV_TOOLS, "").strip()
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception as exc:
        bridge.debug_log(f"[mcp] Werkzeugliste unlesbar: {exc}")
        return []


def _call_id(params: dict) -> str:
    """Claude Codes ``toolUseId`` aus ``_meta`` — der Schlüssel des Rendezvous.

    Die CLI liefert ihn frei Haus (im Probelauf gemessen: ``_meta``-Eintrag
    ``claudecode/toolUseId``, identisch mit der ``tool_use.id`` im stream-json). Damit
    muss der Client die Aufrufe nicht selbst zuordnen. Fehlt er, springt eine
    Ersatzkennung ein, damit paralleles Aufrufen nicht kollidiert.
    """
    meta = params.get("_meta") or {}
    for key in ("claudecode/toolUseId", "toolUseId"):
        value = meta.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return f"cc_{int(time.time() * 1000)}_{os.getpid()}"


def _dispatch_to_host(call_id: str, name: str, arguments) -> tuple[str, bool]:
    """Den Werkzeugaufruf an Hermes reichen und auf das Ergebnis warten.

    Hier wird blockiert — das ist der Kniff. Aber nicht unbegrenzt: stirbt der
    Hermes-Prozess, stirbt sein Wachhund mit (Daemon-Thread), und dann hinge dieser
    Aufruf nur noch an Claude Codes harter Wanduhr. Die eigene Frist liegt darunter.
    """
    path = os.environ.get(bridge.ENV_SOCKET, "").strip()
    if not path:
        return "Hermes-Rendezvous ist nicht konfiguriert (HERMES_CC_SOCKET fehlt).", True
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        deadline = os.environ.get(bridge.ENV_CALL_DEADLINE, "").strip()
        if deadline:
            try:
                sock.settimeout(float(deadline))
            except ValueError:
                pass
        sock.connect(path)
        bridge.send_line(sock, {"call_id": call_id, "name": name, "arguments": arguments})
        reply = bridge.recv_line(sock)
        if reply is None:
            return ("Hermes hat die Verbindung geschlossen, ohne ein Ergebnis zu liefern. "
                    "Der Aufruf wurde nicht ausgeführt."), True
        return str(reply.get("content", "")), bool(reply.get("is_error"))
    except socket.timeout:
        return ("Hermes hat innerhalb der Frist nicht geantwortet; der Aufruf wurde nicht "
                "ausgeführt. Brich den Zug ab, statt das Ergebnis zu erfinden."), True
    except Exception as exc:
        return f"Hermes-Rendezvous fehlgeschlagen: {exc}", True
    finally:
        try:
            sock.close()
        except Exception:
            pass


def _handle_call(msg_id, params: dict) -> None:
    """Einen ``tools/call`` abwickeln — blockiert bis Hermes geantwortet hat."""
    name = str(params.get("name") or "")
    call_id = _call_id(params)
    bridge.debug_log(f"[mcp] call {call_id} {name}")
    content, is_error = _dispatch_to_host(call_id, name, params.get("arguments") or {})
    bridge.debug_log(f"[mcp] done {call_id} is_error={is_error}")
    _result(msg_id, {"content": [{"type": "text", "text": content}], "isError": is_error})


def main() -> None:
    tools = _load_tools()
    bridge.debug_log(f"[mcp] Start, {len(tools)} Werkzeuge angemeldet")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            continue

        msg_id, method = msg.get("id"), msg.get("method")
        params = msg.get("params") or {}

        if method == "initialize":
            _result(msg_id, {
                "protocolVersion": params.get("protocolVersion", PROTOCOL_VERSION),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": bridge.MCP_SERVER_NAME, "version": "0.1.0"},
            })
        elif method == "tools/list":
            _result(msg_id, {"tools": tools})
        elif method == "tools/call":
            # In einem eigenen Thread: der Aufruf blockiert, bis Hermes liefert, und
            # währenddessen muss die Leseschleife weiterlaufen. Sonst erreicht ein
            # zweiter, paralleler Werkzeugaufruf den Host erst, wenn der erste fertig
            # ist — Claude Code spielt Werkzeuge aber regelmäßig parallel aus.
            threading.Thread(target=_handle_call, args=(msg_id, params), daemon=True).start()
        elif msg_id is not None:
            _error(msg_id, -32601, f"Methode '{method}' wird nicht unterstützt.")
        # Benachrichtigungen (ohne id) werden bewusst still verworfen.


if __name__ == "__main__":
    main()
