"""Claude Code CLI as a Hermes model provider.

Weg B aus ``00-hermes-FAQ/Hermes-Claude-Code-Integration.md``, gebaut mit dem MCP-Kniff
aus Weg D: die lokale ``claude``-CLI ist das Modell, Hermes' Werkzeuge erreichen sie als
Schema-only-MCP-Server statt als Text im Prompt.

Wie ``copilot-acp`` ist das hier ein ``external_process``-Provider — er spricht kein
OpenAI-over-HTTP, sondern treibt einen lokalen Subprozess. Die Registrierung läuft ohne
Core-Eingriff: ``providers/__init__.py`` importiert dieses Verzeichnis aus
``$HERMES_HOME/plugins/model-providers/``, und ``hermes_cli/auth.py:264``
(``_register_plugin_provider``) trägt jedes ``external_process``-Profil von selbst in
``PROVIDER_REGISTRY`` ein.
"""

from typing import Any

from providers import register_provider
from providers.base import ProviderProfile


class ClaudeCodeMCPProfile(ProviderProfile):
    """Claude Code CLI — externer Prozess, kein REST-Modellkatalog."""

    def create_client(self, **client_kwargs: Any) -> Any:
        """Den CLI-Treiber bauen statt eines HTTP-Clients."""
        from .client import ClaudeCodeClient

        return ClaudeCodeClient(**client_kwargs)

    def build_api_kwargs_extras(
        self, *, reasoning_config: dict | None = None, **context: Any
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        """Hermes' Reasoning-Stufe als ``reasoning_effort`` an den Client durchreichen.

        Der dokumentierte Weg (``providers/base.py``): was hier im zweiten Element
        landet, kommt als kwarg bei ``chat.completions.create`` an. Der Client bildet es
        auf Claude Codes ``--effort`` ab. Ohne diesen Haken bliebe ``agent.reasoning_effort``
        wirkungslos, weil dieser Client die Transport-Schicht ueberspringt
        (``HERMES_SKIP_TRANSPORT_WRAP``).
        """
        from .bridge import map_effort

        effort = map_effort(reasoning_config)
        return {}, ({"reasoning_effort": effort} if effort else {})

    def fetch_models(
        self, *, api_key: str | None = None, base_url: str | None = None, timeout: float = 8.0
    ) -> list[str] | None:
        """Die CLI hat keinen Modell-Endpunkt; die Auswahl trifft ``--model``."""
        return None


claude_code_mcp = ClaudeCodeMCPProfile(
    name="claude-code-mcp",
    aliases=("claude-code", "claude-cli"),
    display_name="Claude Code CLI (MCP)",
    description="Claude Code CLI als Modell, Hermes-Werkzeuge über Schema-only-MCP",
    api_mode="chat_completions",
    env_vars=(),  # die CLI bringt ihre eigene Anmeldung mit
    # Nicht leer: sonst greift der Plugin-Fallback in hermes_cli/providers.py:211-225
    # nicht und der Provider wäre in /model und --provider „Unknown provider".
    base_url="claude-code://cli",
    auth_type="external_process",
    supports_health_check=False,  # es gibt keinen /models-Endpunkt zum Anpingen
    # Fuer den /model-Picker: die oeffentlichen Aliase der CLI. Voll qualifizierte Namen
    # (claude-opus-5, …) und das [1m]-Suffix fuer 1M-Kontext funktionieren ebenso.
    fallback_models=("sonnet", "opus", "fable", "haiku"),
    process_command="claude",
    # Leer: die Argumentliste hängt am einzelnen Aufruf (Sitzung, Werkzeuge, Modell)
    # und wird in client.py gebaut. Was hier landet, wird angehängt.
    process_args=(),
    process_command_env_vars=("HERMES_CLAUDE_CODE_COMMAND", "CLAUDE_CLI_PATH"),
    process_args_env_var="HERMES_CLAUDE_CODE_ARGS",
)

register_provider(claude_code_mcp)
