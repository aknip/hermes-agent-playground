"""Passwort-Reset — Startdatei des Tutorials.

Der Engineer-Worker aus Story 3 füllt dieses Modul mit den drei Schritten
des Reset-Flows:

    forgot_password(conn, email)        -> versendet einen Reset-Token
    render_reset_form(conn, token)      -> prüft den Token
    apply_reset(conn, token, new_pw)    -> setzt das neue Passwort

Bewusst leer gelassen.
"""

RESET_TOKEN_TTL_SECONDS = 30 * 60
