"""OpenAI-förmiger Client, der Hermes-Anfragen an die Claude-Code-CLI weiterreicht.

Zwei Betriebsarten:

``resident`` (Standard)
    Ein ``claude``-Prozess trägt einen ganzen Hermes-Zug. Werkzeugaufrufe blockieren im
    MCP-Server, bis Hermes das Ergebnis liefert; danach macht dieselbe CLI-Sitzung
    weiter. Der Prompt-Cache bleibt warm, die Sitzung wird nie neu aufgebaut.

``stateless``
    Je ``create()`` ein frischer Prozess mit der ganzen Historie; beim ersten
    Werkzeugaufruf wird abgebrochen (das „break early" aus ``pi-claude-cli``). Teuer,
    aber ohne Zustand — und deshalb der erzwungene Weg für Hermes' Hilfsaufrufe
    (Kompression, Titel, Kanban-Zerlegung), die einmalig und werkzeuglos sind.

Der Client-Vertrag ist derselbe wie bei ``agent/copilot_acp_client.py:241-280``.
"""

from __future__ import annotations

import atexit
import hashlib
import json
import logging
import os
import queue
import shlex
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import uuid
from pathlib import Path
from types import SimpleNamespace
from typing import Any

try:  # im Hermes-Prozess
    from agent.acp_openai_bridge import build_openai_tool_call, completion_to_stream_chunks
except Exception:  # eigenständig (Tests)
    build_openai_tool_call = completion_to_stream_chunks = None  # type: ignore[assignment]

from . import bridge

logger = logging.getLogger(__name__)

CLAUDE_CODE_BASE_URL = "claude-code://cli"

_DEFAULT_MODEL = "sonnet"
# Werkzeug-Budget, nicht Gateway-Budget: terminal.timeout 180 + approvals.timeout 60
# plus Reserve. Die 1800 s aus agent.gateway_timeout wären hier falsch — ein verwaister
# Aufruf hinge eine halbe Stunde, die schlechteste Fehlerform für einen Kanban-Worker.
_DEFAULT_MCP_TIMEOUT_MS = 600_000
# Eigene, kürzere Frist des Plugins: schlägt zu, bevor die harte Wanduhr der CLI greift,
# damit ein verwaister Aufruf schnell und lesbar scheitert.
_DEFAULT_ORPHAN_TIMEOUT_S = 300.0
# Wie lange auf das Eintreffen der MCP-Aufrufe gewartet wird, nachdem das Modell die
# tool_use-Blöcke ausgespielt hat.
_RENDEZVOUS_ARRIVAL_TIMEOUT_S = 60.0

# (mtime der config.yaml, gelesener Wert) — an der mtime aufgehaengt, damit ein
# langlebiger Gateway eine Config-Aenderung mitbekommt statt sie ewig zu cachen.
_PROFILE_EFFORT_CACHE: tuple[float, str] | None = None

_PREAMBLE = (
    "Du bist das Modell hinter einem Hermes-Agent-Profil.",
    "Du hast keine eigenen Werkzeuge — alles, was du tun willst, läuft über die "
    "bereitgestellten Hermes-Werkzeuge (mcp__hermes__*). Der Host führt sie aus und "
    "liefert dir das Ergebnis zurück.",
    "Antworte ohne Werkzeugaufruf, wenn keiner nötig ist.",
)


# ── Konfiguration aus der Umgebung ─────────────────────────────────────────────


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, "").strip() or default


def _env_float(name: str, default: float) -> float:
    try:
        return float(_env(name)) if _env(name) else default
    except ValueError:
        return default


def _socket_dir() -> str:
    """Kurzes Verzeichnis für den Unix-Socket.

    ``AF_UNIX``-Pfade sind auf macOS auf rund 104 Zeichen begrenzt, und das
    ``$TMPDIR`` unter ``/var/folders/...`` frisst davon schon die Hälfte. Deshalb
    ``/tmp``, solange es beschreibbar ist.
    """
    for candidate in ("/tmp", tempfile.gettempdir()):
        if candidate and os.path.isdir(candidate) and os.access(candidate, os.W_OK):
            return candidate
    return tempfile.gettempdir()


def _profile_reasoning_effort() -> str:
    """``agent.reasoning_effort`` aus der config.yaml des aktiven Profils.

    Rueckfall fuer den Fall, dass Hermes den Wert nicht als ``reasoning_effort``-kwarg
    durchreicht (der Weg ueber ``build_api_kwargs_extras`` haengt am Aufrufpfad).

    Gemerkt wird an der mtime der Datei, nicht auf Dauer: der Gateway laeuft tagelang,
    und ein ``config set agent.reasoning_effort`` soll auf dem naechsten Zug greifen,
    nicht erst nach einem Neustart. Der ``stat``-Aufruf je Zug ist dafuer billig genug.
    """
    global _PROFILE_EFFORT_CACHE
    try:
        from hermes_constants import get_hermes_home

        path = get_hermes_home() / "config.yaml"
        mtime = path.stat().st_mtime
    except Exception as exc:
        logger.debug("claude-code: config.yaml nicht erreichbar: %s", exc)
        return _PROFILE_EFFORT_CACHE[1] if _PROFILE_EFFORT_CACHE else ""

    if _PROFILE_EFFORT_CACHE is not None and _PROFILE_EFFORT_CACHE[0] == mtime:
        return _PROFILE_EFFORT_CACHE[1]

    value = ""
    try:
        import yaml

        cfg = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        value = str((cfg.get("agent") or {}).get("reasoning_effort") or "")
    except Exception as exc:
        logger.debug("claude-code: reasoning_effort nicht aus der config.yaml lesbar: %s", exc)
    _PROFILE_EFFORT_CACHE = (mtime, value)
    return value


def _resolve_model(requested: Any) -> str:
    """Welches Modell die CLI fahren soll.

    Vorrang hat, was **Hermes** uebergibt (``model.default`` des Profils, ``/model``,
    und die Karten-Uebersteuerung ``hermes kanban set-model``). Die Umgebungsvariable
    ist nur der Rueckfall — sonst wuerde ein gesetztes ``HERMES_CLAUDE_CODE_MODEL``
    jede Profilaenderung still schlucken.
    """
    return bridge.map_model(requested) or _env("HERMES_CLAUDE_CODE_MODEL") or _DEFAULT_MODEL


def _resolve_effort(requested: Any) -> str:
    """Welche Denktiefe die CLI fahren soll (``--effort``), oder "" fuer ihre Vorgabe.

    Reihenfolge wie beim Modell: Hermes zuerst (``agent.reasoning_effort``, per-Modell
    uebersteuerbar), dann die Umgebungsvariable, dann die config.yaml als Rueckfall.
    """
    return (bridge.map_effort(requested)
            or bridge.map_effort(_env("HERMES_CLAUDE_CODE_EFFORT"))
            or bridge.map_effort(_profile_reasoning_effort()))


def _resolve_command() -> str:
    return (_env("HERMES_CLAUDE_CODE_COMMAND")
            or _env("CLAUDE_CLI_PATH")
            or shutil.which("claude")
            or "claude")


def _subprocess_env() -> dict[str, str]:
    """Umgebung für das Kind — ``HOME`` muss stimmen, sonst findet es ``~/.claude`` nicht.

    Übernommen aus ``agent/copilot_acp_client.py:103-125``: der zentrale Helfer entfernt
    weiterhin Tier-1-Geheimnisse, die Anmeldung der CLI hängt allein an ``HOME``.
    """
    try:
        from hermes_constants import apply_subprocess_home_env
        from tools.environments.local import hermes_subprocess_env

        env = hermes_subprocess_env(inherit_credentials=True)
    except Exception:
        env, apply_subprocess_home_env = dict(os.environ), None  # type: ignore[assignment]
    home = os.environ.get("HOME", "").strip() or os.path.expanduser("~")
    if home and home != "~":
        env["HOME"] = home
    if apply_subprocess_home_env is not None:
        try:
            apply_subprocess_home_env(env)
        except Exception:
            pass
    return env


# ── Rendezvous ─────────────────────────────────────────────────────────────────


class _Rendezvous:
    """Unix-Socket, an dem die geparkten Werkzeugaufrufe des MCP-Servers hängen."""

    def __init__(self, path: str) -> None:
        self.path = path
        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(path)
        self._server.listen(16)
        self._lock = threading.Lock()
        self._arrived = threading.Condition(self._lock)
        self.pending: dict[str, socket.socket] = {}
        self._closed = False
        threading.Thread(target=self._accept_loop, daemon=True).start()

    def _accept_loop(self) -> None:
        while not self._closed:
            try:
                conn, _ = self._server.accept()
            except Exception:
                return
            threading.Thread(target=self._intake, args=(conn,), daemon=True).start()

    def _intake(self, conn: socket.socket) -> None:
        request = bridge.recv_line(conn)
        if not request:
            conn.close()
            return
        call_id = str(request.get("call_id") or "")
        with self._arrived:
            self.pending[call_id] = conn
            self._arrived.notify_all()

    def wait_for(self, call_ids: list[str], timeout: float) -> bool:
        """Warten, bis alle genannten Aufrufe geparkt sind."""
        deadline = time.monotonic() + timeout
        with self._arrived:
            while not all(cid in self.pending for cid in call_ids):
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return False
                self._arrived.wait(remaining)
        return True

    def answer(self, call_id: str, content: str, is_error: bool = False) -> bool:
        with self._lock:
            conn = self.pending.pop(call_id, None)
        if conn is None:
            return False
        try:
            bridge.send_line(conn, {"content": content, "is_error": is_error})
            return True
        except Exception:
            return False
        finally:
            try:
                conn.close()
            except Exception:
                pass

    def close(self) -> None:
        self._closed = True
        with self._lock:
            conns, self.pending = list(self.pending.values()), {}
        for conn in conns:
            try:
                bridge.send_line(conn, {
                    "content": "Hermes hat die Sitzung beendet; der Aufruf wurde nicht ausgeführt.",
                    "is_error": True})
            except Exception:
                pass
            try:
                conn.close()
            except Exception:
                pass
        for closer in (self._server.close, lambda: os.unlink(self.path)):
            try:
                closer()
            except Exception:
                pass


# ── Sitzung ────────────────────────────────────────────────────────────────────


class _Session:
    """Ein laufender ``claude``-Prozess samt Rendezvous und Stream-Leser."""

    def __init__(self, *, tools_fp: str, workdir: str) -> None:
        self.uuid = str(uuid.uuid4())
        self.tools_fp = tools_fp
        self.workdir = workdir
        self.tmpdir = tempfile.mkdtemp(prefix="hcc-", dir=_socket_dir())
        self.rendezvous = _Rendezvous(os.path.join(self.tmpdir, "rv.sock"))
        self.proc: subprocess.Popen[str] | None = None
        self.events: queue.Queue[dict[str, Any]] = queue.Queue()
        self.stderr_tail: list[str] = []
        self.history_len = 0
        self.prefix_sig = ""
        self.parked: list[str] = []
        self.turn_started = False
        self.logged_model = ""
        self._closed = False
        self._watchdog: threading.Timer | None = None

    # -- Wachhund gegen verwaiste Prozesse ------------------------------------

    def touch(self) -> None:
        """Wachhund neu stellen. Kommt Hermes nicht zurück, wird aufgeräumt."""
        self.cancel_watchdog()
        timeout = _env_float("HERMES_CLAUDE_CODE_ORPHAN_TIMEOUT", _DEFAULT_ORPHAN_TIMEOUT_S)
        self._watchdog = threading.Timer(timeout, self._on_orphan)
        self._watchdog.daemon = True
        self._watchdog.start()

    def cancel_watchdog(self) -> None:
        if self._watchdog is not None:
            self._watchdog.cancel()
            self._watchdog = None

    def _on_orphan(self) -> None:
        logger.warning(
            "claude-code: Sitzung %s verwaist (Hermes kam nicht zurück) — wird abgeräumt.",
            self.uuid)
        _drop_session_object(self)

    # -- Prozess ---------------------------------------------------------------

    def spawn(self, argv: list[str], prompt: str) -> None:
        bridge.debug_log(f"[client] spawn {shlex.join(argv)}")
        self.proc = subprocess.Popen(
            argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", errors="replace", bufsize=1,
            cwd=self.workdir, env=_subprocess_env(),
        )
        threading.Thread(target=self._pump_stdout, daemon=True).start()
        threading.Thread(target=self._pump_stderr, daemon=True).start()
        # Der Prompt geht über stdin, nicht als Argument: eine lange Hermes-Historie
        # sprengt sonst ARG_MAX (macOS: 1 MiB).
        try:
            assert self.proc.stdin is not None
            self.proc.stdin.write(prompt)
            self.proc.stdin.close()
        except Exception as exc:
            raise RuntimeError(f"Prompt konnte nicht an die CLI übergeben werden: {exc}") from exc
        self.turn_started = True

    def _pump_stdout(self) -> None:
        for line in self.proc.stdout or ():
            line = line.strip()
            if not line:
                continue
            try:
                self.events.put(json.loads(line))
            except Exception:
                bridge.debug_log(f"[client] unparsbar: {line[:200]}")
        self.events.put({"type": "__eof__"})

    def _pump_stderr(self) -> None:
        for line in self.proc.stderr or ():
            self.stderr_tail.append(line.rstrip("\n"))
            del self.stderr_tail[:-40]

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        self.cancel_watchdog()
        self.rendezvous.close()
        proc = self.proc
        if proc is not None and proc.poll() is None:
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
        try:
            shutil.rmtree(self.tmpdir, ignore_errors=True)
        except Exception:
            pass


# ── Modulweite Sitzungstabelle ─────────────────────────────────────────────────
#
# Bewusst NICHT am Client: Hermes baut Clients unterwegs neu (Stream-Retry-Aufräumen,
# Credential-Rotation, Fallback-Restore, switch_model — siehe die Kommentare in
# agent/agent_runtime_helpers.py:1700-1760). Ein frischer Client mit leerer Tabelle
# würde den geparkten claude-Prozess verwaisen lassen; hier hängt er sich wieder an.

_SESSIONS: dict[str, _Session] = {}
_SESSIONS_LOCK = threading.Lock()


def _drop_session_object(session: _Session) -> None:
    with _SESSIONS_LOCK:
        for key, value in list(_SESSIONS.items()):
            if value is session:
                del _SESSIONS[key]
    session.close()


def _drop_session(key: str) -> None:
    with _SESSIONS_LOCK:
        session = _SESSIONS.pop(key, None)
    if session is not None:
        session.close()


def shutdown_all_sessions() -> None:
    """Alle Sitzungen abräumen (Test- und Rückbaupfad, sowie beim Prozessende)."""
    with _SESSIONS_LOCK:
        sessions = list(_SESSIONS.values())
        _SESSIONS.clear()
    for session in sessions:
        session.close()


# Beim normalen Ende des Hermes-Prozesses die Kinder mitnehmen. Bei SIGKILL greift das
# nicht — dafür hat der MCP-Server seine eigene Frist (ENV_CALL_DEADLINE).
atexit.register(shutdown_all_sessions)


# ── Nachrichten-Signaturen ─────────────────────────────────────────────────────


def _signature(messages: list[dict[str, Any]]) -> str:
    payload = json.dumps(
        [(m.get("role"), bridge.render_content(m.get("content")),
          str(m.get("tool_call_id") or ""), json.dumps(m.get("tool_calls") or [], default=str))
         for m in messages if isinstance(m, dict)],
        ensure_ascii=False,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:32]


def _tool_results(tail: list[dict[str, Any]]) -> dict[str, str]:
    """``tool_call_id -> Inhalt`` aus dem Nachrichtenschwanz."""
    out: dict[str, str] = {}
    for message in tail:
        if isinstance(message, dict) and str(message.get("role") or "") == "tool":
            call_id = str(message.get("tool_call_id") or "")
            if call_id:
                out[call_id] = bridge.render_content(message.get("content"))
    return out


# ── Client ─────────────────────────────────────────────────────────────────────


class ClaudeCodeClient:
    """Minimale OpenAI-Client-Fassade für die Claude-Code-CLI."""

    # Für agent/auxiliary_client.py:1822 und :4336 — dieser Client treibt einen
    # Subprozess über stdio, ist also bereits vollständig: nie durch einen
    # Wire-Adapter nachrouten, und so wie er ist async-sicher.
    HERMES_SKIP_TRANSPORT_WRAP = True
    HERMES_SKIP_ASYNC_WRAP = True

    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        default_headers: dict[str, str] | None = None,
        command: str | None = None,
        args: list[str] | None = None,
        **_: Any,
    ) -> None:
        self.api_key = api_key or "claude-code-mcp"
        self.base_url = base_url or CLAUDE_CODE_BASE_URL
        self._default_headers = dict(default_headers or {})
        self._command = command or _resolve_command()
        self._extra_args = list(args or []) + shlex.split(_env("HERMES_CLAUDE_CODE_ARGS"))
        self._workdir = str(Path(_env("HERMES_CLAUDE_CODE_CWD") or os.getcwd()).resolve())
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create_chat_completion))
        self.is_closed = False

    def close(self) -> None:
        # Räumt bewusst KEINE Sitzungen ab: Hermes baut Clients mitten im Zug neu,
        # und ein geparkter claude-Prozess muss das überleben. Sitzungen enden am
        # Zugende, bei Nichtpassung oder durch den Wachhund.
        self.is_closed = True

    # -- Argumentliste ---------------------------------------------------------

    def _build_argv(self, session: _Session, *, model: str, snapshot: list[dict[str, Any]],
                    system_prompt: str, resume: str | None, effort: str = "") -> list[str]:
        mcp_config = os.path.join(session.tmpdir, "mcp.json")
        tools_file = os.path.join(session.tmpdir, "tools.json")
        Path(tools_file).write_text(json.dumps(snapshot, ensure_ascii=False), encoding="utf-8")

        server_dir = os.path.dirname(os.path.abspath(__file__))
        env_block = {
            bridge.ENV_SOCKET: session.rendezvous.path,
            bridge.ENV_TOOLS: tools_file,
        }
        if debug := _env("HERMES_CLAUDE_CODE_DEBUG"):
            env_block[bridge.ENV_DEBUG] = debug
        # Eigene Frist des MCP-Servers, knapp über der des Wachhunds: stirbt der
        # Hermes-Prozess, stirbt der Wachhund mit (Daemon-Thread) — dann ist das hier
        # das Einzige, was den geparkten Aufruf noch löst, bevor Claude Codes harte
        # Wanduhr greift.
        env_block[bridge.ENV_CALL_DEADLINE] = str(int(
            _env_float("HERMES_CLAUDE_CODE_ORPHAN_TIMEOUT", _DEFAULT_ORPHAN_TIMEOUT_S) + 30))
        timeout_ms = int(_env_float("HERMES_CLAUDE_CODE_MCP_TIMEOUT_MS", _DEFAULT_MCP_TIMEOUT_MS))
        Path(mcp_config).write_text(json.dumps({"mcpServers": {bridge.MCP_SERVER_NAME: {
            "type": "stdio",
            "command": _env("HERMES_CLAUDE_CODE_PYTHON") or "python3",
            "args": [os.path.join(server_dir, "mcp_server.py")],
            "env": env_block,
            "timeout": timeout_ms,
        }}}, ensure_ascii=False), encoding="utf-8")

        argv = [self._command, "-p",
                "--output-format", "stream-json", "--verbose",
                "--model", model,
                *(["--effort", effort] if effort else []),
                # Claude Code bekommt KEINE eigenen Werkzeuge: alles läuft über Hermes.
                # Das löst die Werkzeugkollision, vor der agent/acp_openai_bridge.py
                # warnt, an der Wurzel — ohne die dort nötige allowlist.
                "--tools", "",
                "--mcp-config", mcp_config, "--strict-mcp-config",
                "--permission-prompts", "none",
                "--disable-slash-commands",
                # Fremde Hooks/Einstellungen des Nutzers bleiben draußen.
                "--setting-sources", ""]

        if resume:
            argv += ["--resume", resume]
        else:
            argv += ["--session-id", session.uuid]

        if allowed := bridge.allowed_tools_args(snapshot):
            argv += ["--allowedTools", *allowed]

        if system_prompt:
            # Über Datei, nicht über argv: Hermes' System-Prompt (Skills, Gedächtnis)
            # ist regelmäßig zu groß für ARG_MAX.
            sp_file = os.path.join(session.tmpdir, "system.txt")
            Path(sp_file).write_text(system_prompt, encoding="utf-8")
            flag = ("--append-system-prompt-file"
                    if _env("HERMES_CLAUDE_CODE_SYSTEM_PROMPT_MODE", "replace") == "append"
                    else "--system-prompt-file")
            argv += [flag, sp_file]

        if budget := _env("HERMES_CLAUDE_CODE_BUDGET_USD"):
            argv += ["--max-budget-usd", budget]

        return argv + self._extra_args

    # -- Antwortbau ------------------------------------------------------------

    @staticmethod
    def _completion(*, model: str, text: str, tool_calls: list[Any], usage: dict[str, int],
                    finish_reason: str) -> Any:
        message = SimpleNamespace(
            content=text or None, tool_calls=tool_calls or None,
            reasoning=None, reasoning_content=None, reasoning_details=None)
        return SimpleNamespace(
            choices=[SimpleNamespace(index=0, message=message, finish_reason=finish_reason)],
            usage=SimpleNamespace(
                prompt_tokens=usage["prompt_tokens"],
                completion_tokens=usage["completion_tokens"],
                total_tokens=usage["total_tokens"],
                prompt_tokens_details=SimpleNamespace(cached_tokens=usage["cached_tokens"]),
            ),
            model=model,
        )

    # -- Stream lesen ----------------------------------------------------------

    def _read_turn(self, session: _Session, *, timeout: float) -> dict[str, Any]:
        """Bis zum nächsten Halt lesen.

        Halt ist entweder ein Satz Werkzeugaufrufe (dann sind sie am Rendezvous geparkt)
        oder das Abschlussereignis der CLI.
        """
        deadline = time.monotonic() + timeout
        text_parts: list[str] = []

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Zeitüberschreitung beim Warten auf die Claude-Code-CLI.")
            try:
                event = session.events.get(timeout=min(remaining, 1.0))
            except queue.Empty:
                if session.proc is not None and session.proc.poll() is not None:
                    # Prozess ist weg und der Strom leer.
                    raise RuntimeError(self._exit_error(session))
                continue

            kind = event.get("type")

            if kind == "__eof__":
                raise RuntimeError(self._exit_error(session))

            if kind == "system" and event.get("subtype") == "init":
                # Das ``model`` im init-Ereignis ist die SITZUNGSkonfiguration und traegt
                # ein ``[1m]``-Suffix; das ``model`` im assistant-Ereignis ist die nackte
                # Wire-ID (``claude-opus-5``). Wer nur letzteres protokolliert, haelt ein
                # aktives 1M-Fenster faelschlich fuer verloren.
                bridge.debug_log(f"[client] Sitzungsmodell: {event.get('model')!r} "
                                 f"tools={event.get('tools')} mcp={event.get('mcp_servers')}")
                continue

            if kind == "assistant":
                message = event.get("message") or {}
                if not session.logged_model and (used := message.get("model")):
                    session.logged_model = str(used)
                    bridge.debug_log(f"[client] Wire-Modell: {used}")
                content = message.get("content") or []
                calls = []
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "text":
                        text_parts.append(str(block.get("text") or ""))
                    elif block.get("type") == "tool_use":
                        calls.append(block)
                if calls:
                    return {"stop": "tool_calls", "calls": calls,
                            "text": "\n".join(t for t in text_parts if t.strip())}
                continue

            if kind == "result":
                subtype = str(event.get("subtype") or "")
                if subtype != "success":
                    # error_max_turns, error_during_execution, Budgetstopp …
                    raise RuntimeError(
                        f"Die Claude-Code-CLI brach ab ({subtype or 'unbekannt'}): "
                        f"{str(event.get('result') or '').strip() or '(ohne Meldung)'}")
                return {"stop": "result", "event": event,
                        "text": str(event.get("result") or "").strip()
                                or "\n".join(t for t in text_parts if t.strip())}

    @staticmethod
    def _exit_error(session: _Session) -> str:
        code = session.proc.poll() if session.proc is not None else None
        tail = "\n".join(session.stderr_tail).strip()
        return (f"Die Claude-Code-CLI endete unerwartet (Code {code})."
                + (f"\n{tail}" if tail else ""))

    # -- Kernpfad --------------------------------------------------------------

    def _create_chat_completion(
        self, *, model: str | None = None, messages: list[dict[str, Any]] | None = None,
        timeout: float | None = None, tools: list[dict[str, Any]] | None = None,
        tool_choice: Any = None, stream: bool = False,
        reasoning_effort: Any = None, reasoning: Any = None, **_: Any,
    ) -> Any:
        messages = list(messages or [])
        snapshot = bridge.tool_snapshot(tools)
        # Was Hermes uebergibt, gewinnt: model.default des Profils, /model, und die
        # Karten-Uebersteuerung `hermes kanban set-model`.
        model_name = _resolve_model(model)
        effort = _resolve_effort(reasoning_effort if reasoning_effort is not None else reasoning)
        wall = float(timeout) if isinstance(timeout, (int, float)) else 1800.0

        # Hilfsaufrufe (Kompression, Titel, Kanban-Zerlegung) sind einmalig und
        # werkzeuglos — sie laufen erzwungen stateless und fassen die Sitzungstabelle
        # nicht an. Sonst entstünde eine Überschneidung, die erst unter Kompression
        # sichtbar wird.
        mode = _env("HERMES_CLAUDE_CODE_MODE", "resident")
        if mode != "resident" or not snapshot:
            completion = self._run_stateless(
                messages, snapshot=snapshot, model=model_name, timeout=wall, effort=effort)
        else:
            completion = self._run_resident(
                messages, snapshot=snapshot, model=model_name, timeout=wall, effort=effort)

        if stream and completion_to_stream_chunks is not None:
            return completion_to_stream_chunks(completion)
        return completion

    # -- Betriebsart „stateless" ----------------------------------------------

    def _run_stateless(self, messages: list[dict[str, Any]], *, snapshot: list[dict[str, Any]],
                       model: str, timeout: float, effort: str = "") -> Any:
        system_prompt, rest = bridge.split_system(messages)
        session = _Session(tools_fp=bridge.tools_fingerprint(snapshot), workdir=self._workdir)
        try:
            argv = self._build_argv(session, model=model, snapshot=snapshot,
                                    system_prompt=self._system_text(system_prompt), resume=None,
                                    effort=effort)
            session.spawn(argv, self._prompt_text(rest))
            outcome = self._read_turn(session, timeout=timeout)
            if outcome["stop"] == "tool_calls":
                # Break early: der Prozess wird verworfen, der Aufruf geht an Hermes.
                calls = [self._to_openai_call(block) for block in outcome["calls"]]
                return self._completion(
                    model=model, text=outcome["text"], tool_calls=calls,
                    usage=bridge.map_usage(None), finish_reason="tool_calls")
            event = outcome["event"]
            return self._completion(
                model=model, text=outcome["text"], tool_calls=[],
                usage=bridge.map_usage(event.get("usage")), finish_reason="stop")
        finally:
            session.close()

    # -- Betriebsart „resident" ------------------------------------------------

    def _run_resident(self, messages: list[dict[str, Any]], *, snapshot: list[dict[str, Any]],
                      model: str, timeout: float, effort: str = "") -> Any:
        tools_fp = bridge.tools_fingerprint(snapshot)
        session = self._match_session(messages, tools_fp)

        if session is not None:
            tail = messages[session.history_len:]
            results = _tool_results(tail)
            for call_id in session.parked:
                session.rendezvous.answer(call_id, results.get(call_id, ""),
                                          is_error=call_id not in results)
            session.parked = []
        else:
            system_prompt, rest = bridge.split_system(messages)
            session = _Session(tools_fp=tools_fp, workdir=self._workdir)
            argv = self._build_argv(session, model=model, snapshot=snapshot,
                                    system_prompt=self._system_text(system_prompt), resume=None,
                                    effort=effort)
            session.spawn(argv, self._prompt_text(rest))

        session.cancel_watchdog()
        try:
            outcome = self._read_turn(session, timeout=timeout)
        except Exception:
            _drop_session_object(session)
            raise

        if outcome["stop"] == "tool_calls":
            blocks = outcome["calls"]
            call_ids = [str(b.get("id") or "") for b in blocks]
            if not session.rendezvous.wait_for(call_ids, _RENDEZVOUS_ARRIVAL_TIMEOUT_S):
                _drop_session_object(session)
                raise RuntimeError(
                    "Die Werkzeugaufrufe der CLI sind nicht am Rendezvous angekommen.")
            session.parked = call_ids
            session.history_len = len(messages)
            session.prefix_sig = _signature(messages)
            with _SESSIONS_LOCK:
                _SESSIONS[session.prefix_sig] = session
            session.touch()
            return self._completion(
                model=model, text=outcome["text"],
                tool_calls=[self._to_openai_call(b) for b in blocks],
                usage=bridge.map_usage(None), finish_reason="tool_calls")

        event = outcome["event"]
        _drop_session_object(session)  # der Zug ist zu Ende, der Prozess läuft aus
        return self._completion(
            model=model, text=outcome["text"], tool_calls=[],
            usage=bridge.map_usage(event.get("usage")), finish_reason="stop")

    @staticmethod
    def _match_session(messages: list[dict[str, Any]], tools_fp: str) -> _Session | None:
        """Die Sitzung finden, die genau diese Historie fortsetzt — oder nichts."""
        with _SESSIONS_LOCK:
            candidates = list(_SESSIONS.items())
        for key, session in candidates:
            # Erst die Zugehörigkeit prüfen, dann verwerfen: ein Abräumen nach
            # Werkzeug-Fingerabdruck allein würde die Sitzungen *anderer* Gespräche
            # mit anderem Toolset mit abräumen.
            if len(messages) <= session.history_len:
                continue
            if _signature(messages[:session.history_len]) != session.prefix_sig:
                continue
            if session.tools_fp != tools_fp:
                # Unsere Sitzung, aber der Werkzeugsatz hat sich geändert
                # (tool_search, disabled_toolsets): der laufende Prozess hat seine
                # Liste beim Start gelesen und kennt die neue nicht.
                _drop_session(key)
                continue
            results = _tool_results(messages[session.history_len:])
            if set(results) != set(session.parked):
                # Kompression, Retry oder ein neuer Nutzerzug: nicht fortsetzbar.
                _drop_session(key)
                continue
            with _SESSIONS_LOCK:
                _SESSIONS.pop(key, None)
            return session
        return None

    # -- Hilfsmittel -----------------------------------------------------------

    @staticmethod
    def _system_text(hermes_system: str) -> str:
        return "\n\n".join([*_PREAMBLE, hermes_system]) if hermes_system else "\n\n".join(_PREAMBLE)

    @staticmethod
    def _prompt_text(rest: list[dict[str, Any]]) -> str:
        transcript = bridge.render_transcript(rest)
        return (transcript + "\n\nSetze das Gespräch ab der letzten Anfrage fort."
                if transcript else "Fahre fort.")

    @staticmethod
    def _to_openai_call(block: dict[str, Any]) -> Any:
        """``tool_use``-Block der CLI -> OpenAI-Werkzeugaufruf mit nacktem Namen.

        Ohne das Abschneiden des ``mcp__hermes__``-Präfixes fände Hermes das Werkzeug
        nicht — es sucht unter dem nackten Namen.
        """
        name = bridge.bare_name(str(block.get("name") or ""))
        arguments = json.dumps(block.get("input") or {}, ensure_ascii=False)
        call_id = str(block.get("id") or "") or f"cc_{uuid.uuid4().hex[:12]}"
        if build_openai_tool_call is not None:
            return build_openai_tool_call(call_id=call_id, name=name, arguments=arguments)
        return SimpleNamespace(id=call_id, type="function",
                               function=SimpleNamespace(name=name, arguments=arguments))
