"""Gemeinsame Teile zwischen Client und MCP-Server.

Hier liegt alles, was keinen Prozess anfasst: Namensabbildung, Werkzeug-Schnappschuss,
Nachrichtenrendering, Usage-Abbildung und das Rendezvous-Protokoll.
"""

from __future__ import annotations

import hashlib
import json
import os
from typing import Any, Iterable

# Claude Code führt MCP-Werkzeuge als ``mcp__<servername>__<werkzeug>``. Der Server
# meldet den nackten Namen an, das Präfix setzt die CLI selbst (im Probelauf gemessen:
# angemeldet ``hermes_probe``, ausgespielt ``mcp__hermes__hermes_probe``).
MCP_SERVER_NAME = "hermes"
TOOL_PREFIX = f"mcp__{MCP_SERVER_NAME}__"

# Umgebungsvariablen, über die der Client den MCP-Server verdrahtet.
ENV_SOCKET = "HERMES_CC_SOCKET"
ENV_TOOLS = "HERMES_CC_TOOLS"
ENV_DEBUG = "HERMES_CC_DEBUG"

_ROLE_LABELS = {
    "system": "System",
    "user": "User",
    "assistant": "Assistant",
    "tool": "Tool",
}


# ── Namensabbildung ────────────────────────────────────────────────────────────


def mcp_name(bare_name: str) -> str:
    """Nackter Hermes-Name -> so, wie das Modell ihn sieht."""
    return f"{TOOL_PREFIX}{bare_name}"


def bare_name(exposed_name: str) -> str:
    """So, wie das Modell ihn sieht -> nackter Hermes-Name.

    Hermes sucht seine Werkzeuge unter dem nackten Namen; ohne das Abschneiden liefe
    jeder Aufruf ins Leere. Unpräfigierte Namen bleiben unberührt, damit ein
    (theoretisches) eingebautes Werkzeug nicht verstümmelt wird.
    """
    name = str(exposed_name or "")
    return name[len(TOOL_PREFIX):] if name.startswith(TOOL_PREFIX) else name


# ── Werkzeug-Schnappschuss ─────────────────────────────────────────────────────


def tool_snapshot(tools: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
    """Hermes' OpenAI-``tools`` -> MCP-``tools/list``-Einträge (nackte Namen).

    Fehlerhafte Einträge werden übersprungen statt den Zug zu sprengen.
    """
    out: list[dict[str, Any]] = []
    for tool in tools or []:
        fn = tool.get("function") if isinstance(tool, dict) else None
        if not isinstance(fn, dict):
            continue
        name = str(fn.get("name") or "").strip()
        if not name:
            continue
        params = fn.get("parameters")
        if not isinstance(params, dict) or not params:
            # MCP verlangt ein Objekt-Schema; ein leeres Schema ist zulässig.
            params = {"type": "object", "properties": {}}
        out.append({
            "name": name,
            "description": str(fn.get("description") or ""),
            "inputSchema": params,
        })
    return out


def tools_fingerprint(snapshot: list[dict[str, Any]]) -> str:
    """Stabiler Fingerabdruck des Werkzeugsatzes.

    Ändert er sich (``tool_search``, ``disabled_toolsets``), wird die Sitzung verworfen —
    ein laufender ``claude``-Prozess hat seine Werkzeugliste beim Start gelesen.
    """
    # Nur Zeichenketten sortieren: Tupel mit Dicts darin knallen beim Vergleich,
    # sobald zwei Werkzeuge denselben Namen tragen.
    rows = sorted(
        (t["name"], t["description"], json.dumps(t["inputSchema"], sort_keys=True, default=str))
        for t in snapshot
    )
    return hashlib.sha256(json.dumps(rows, ensure_ascii=False).encode("utf-8")).hexdigest()[:16]


def allowed_tools_args(snapshot: list[dict[str, Any]]) -> list[str]:
    """``--allowedTools``-Werte, damit in ``-p`` nichts still verweigert wird."""
    return [mcp_name(t["name"]) for t in snapshot]


# ── Nachrichtenrendering ───────────────────────────────────────────────────────


def render_content(content: Any) -> str:
    """Beliebigen OpenAI-Nachrichteninhalt zu Text verflachen."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, dict):
        if isinstance(content.get("text"), str):
            return content["text"].strip()
        if isinstance(content.get("content"), str):
            return content["content"].strip()
        return json.dumps(content, ensure_ascii=False)
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
        return "\n".join(p for p in parts if p.strip()).strip()
    return str(content).strip()


def split_system(messages: list[dict[str, Any]]) -> tuple[str, list[dict[str, Any]]]:
    """``(System-Prompt, restliche Nachrichten)``.

    Der System-Prompt geht als ``--system-prompt`` an die CLI, nicht ins Transkript:
    so sieht Claude Code Hermes' Persona dort, wo ein System-Prompt hingehört.
    """
    system_parts: list[str] = []
    rest: list[dict[str, Any]] = []
    for message in messages or []:
        if not isinstance(message, dict):
            continue
        if str(message.get("role") or "").lower() == "system":
            if text := render_content(message.get("content")):
                system_parts.append(text)
        else:
            rest.append(message)
    return "\n\n".join(system_parts).strip(), rest


def render_transcript(messages: Iterable[dict[str, Any]]) -> str:
    """Nachrichten als lesbares Transkript für den Prompt der CLI."""
    lines: list[str] = []
    for message in messages:
        if not isinstance(message, dict):
            continue
        role = str(message.get("role") or "unknown").lower()
        label = _ROLE_LABELS.get(role, "Context")
        if role == "assistant" and message.get("tool_calls"):
            calls = []
            for call in message["tool_calls"] or []:
                fn = (call or {}).get("function") or {}
                calls.append(f"{bare_name(fn.get('name', ''))}({fn.get('arguments', '')})")
            if calls:
                lines.append(f"{label} (Werkzeugaufrufe):\n" + "\n".join(calls))
        if role == "tool":
            name = bare_name(str(message.get("name") or ""))
            lines.append(f"Tool [{name}]:\n{render_content(message.get('content'))}")
            continue
        if text := render_content(message.get("content")):
            lines.append(f"{label}:\n{text}")
    return "\n\n".join(lines)


# ── Usage-Abbildung ────────────────────────────────────────────────────────────


def map_usage(raw: dict[str, Any] | None) -> dict[str, int]:
    """``result.usage`` der CLI -> OpenAI-Form.

    Die CLI meldet Eingabe-Token getrennt nach frisch / Cache-Erzeugung / Cache-Treffer.
    Hermes erwartet eine Gesamtsumme plus ``cached_tokens``; ohne das Aufaddieren
    meldete der Client fast null Eingabe-Token und Hermes' Kompressionsschwelle
    (``compression.threshold: 0.5``) würde nie greifen.
    """
    raw = raw or {}
    fresh = int(raw.get("input_tokens") or 0)
    cache_read = int(raw.get("cache_read_input_tokens") or 0)
    cache_write = int(raw.get("cache_creation_input_tokens") or 0)
    completion = int(raw.get("output_tokens") or 0)
    prompt = fresh + cache_read + cache_write
    return {
        "prompt_tokens": prompt,
        "completion_tokens": completion,
        "total_tokens": prompt + completion,
        "cached_tokens": cache_read,
    }


# ── Rendezvous-Protokoll ───────────────────────────────────────────────────────
#
# Eine Zeile JSON je Richtung über einen Unix-Socket:
#   MCP-Server -> Client : {"call_id", "name", "arguments"}
#   Client -> MCP-Server : {"content", "is_error"}
# Der Server blockiert dazwischen — das ist der ganze Kniff: Claude Code wartet im
# Werkzeugaufruf, statt die Sitzung abzubrechen.


def send_line(sock, payload: dict[str, Any]) -> None:
    sock.sendall((json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8"))


def recv_line(sock) -> dict[str, Any] | None:
    """Eine JSON-Zeile lesen; ``None`` wenn die Gegenseite zumacht."""
    buf = bytearray()
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            return None
        buf.extend(chunk)
        if b"\n" in buf:
            line, _, _ = bytes(buf).partition(b"\n")
            try:
                return json.loads(line.decode("utf-8"))
            except Exception:
                return None


def debug_log(message: str) -> None:
    """Diagnose nur, wenn ausdrücklich eingeschaltet — der Strom enthält Prompt-Inhalte.

    Beide Namen, damit Client (``HERMES_CLAUDE_CODE_DEBUG``, im Hermes-Prozess gesetzt)
    und MCP-Server (``HERMES_CC_SOCKET``-Nachbar, ins Kind durchgereicht) in dieselbe
    Datei schreiben.
    """
    path = (os.environ.get(ENV_DEBUG, "").strip()
            or os.environ.get("HERMES_CLAUDE_CODE_DEBUG", "").strip())
    if not path:
        return
    try:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(message.rstrip("\n") + "\n")
    except Exception:
        pass
