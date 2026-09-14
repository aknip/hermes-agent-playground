#!/usr/bin/env bash
#
# Hermes mit eigenem Root-Verzeichnis starten
# ===========================================
#
# Interaktiv, zwei Schritte:
#   1. die laufenden Gateways der Standard-Installation beenden (y/n)
#   2. Hermes mit HERMES_HOME=<eigener Pfad> starten (Pfad editierbar)
#
# Das Skript aendert nichts an ~/.hermes ausser dem, was in Schritt 1
# ausdruecklich bestaetigt wird. Die neue Root wird angelegt, falls sie fehlt.
#
# Hintergrund und Quellenangaben: ../00-hermes-FAQ/Hermes-Custom-Root.md
#
# Geprueft an Hermes Agent v0.21.2 (2026.9.11) auf macOS, Bash 3.2
#
set -euo pipefail

DEFAULT_ROOT="$HOME/hermes-test"
# Standard-Root der Installation (hermes_constants.py:51). Checkout, venv und
# node liegen immer dort, auch bei eigener Root (siehe FAQ, "Zwei Einschraenkungen").
NATIVE_HOME="$HOME/.hermes"
CHECKOUT="$NATIVE_HOME/hermes-agent"
PACKAGED_APP="$CHECKOUT/apps/desktop/release/mac-arm64/Hermes.app"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  \033[33m! %s\033[0m\n' "$*"; }
die()  { printf '\n\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }

# y/n-Frage. $1 = Text, $2 = Vorgabe (y oder n). "j" gilt wie "y".
ask_yn() {
    local prompt="$1" default="${2:-n}" reply hint
    case "$default" in y) hint="[Y/n]" ;; *) hint="[y/N]" ;; esac
    while true; do
        read -r -p "  $prompt $hint " reply || die "Eingabe abgebrochen."
        [ -n "$reply" ] || reply="$default"
        case "$reply" in
            [yYjJ]*) return 0 ;;
            [nN]*)   return 1 ;;
            *)       warn "Bitte y oder n." ;;
        esac
    done
}

# Profilname aus einer Zeile von `hermes gateway list`: "  <marker> <name> ..."
gw_profile_from_line() {
    # Wortsplitting ist hier gewollt; in einer Funktion bleiben $1/$2 lokal.
    # shellcheck disable=SC2086
    set -- $1
    printf '%s\n' "${2:-}"
}

# ---------------------------------------------------------------------------
say "Vorbedingungen"
# ---------------------------------------------------------------------------
[ -t 0 ] || die "Das Skript ist interaktiv und braucht ein Terminal."
command -v hermes >/dev/null || die "'hermes' nicht im PATH."
info "$(hermes --version 2>/dev/null | head -1)"

if [ -n "${HERMES_HOME:-}" ]; then
    warn "HERMES_HOME ist in dieser Shell bereits gesetzt: $HERMES_HOME"
    warn "Schritt 1 spricht trotzdem die Standard-Root an: $NATIVE_HOME"
fi

# ---------------------------------------------------------------------------
say "1/2  Laufende Gateways der Standard-Installation ($NATIVE_HOME)"
# ---------------------------------------------------------------------------
# Ohne HERMES_HOME, damit die Liste die Standard-Installation zeigt und nicht
# eine bereits gesetzte Custom-Root.
GW_LIST="$(env -u HERMES_HOME hermes gateway list 2>/dev/null || true)"

if [ -z "$GW_LIST" ]; then
    warn "'hermes gateway list' lieferte keine Ausgabe - Schritt uebersprungen."
else
    printf '%s\n' "$GW_LIST" | sed 's/^/  /'
fi

RUNNING=""
RUNNING_COUNT=0
while IFS= read -r line; do
    case "$line" in
        *"✓"*) ;;
        *) continue ;;
    esac
    name="$(gw_profile_from_line "$line")"
    [ -n "$name" ] || continue
    RUNNING="$RUNNING $name"
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
done <<EOF
$GW_LIST
EOF

if [ "$RUNNING_COUNT" -eq 0 ]; then
    info "Kein laufender Gateway gefunden - nichts zu beenden."
else
    echo
    info "Laufend: $RUNNING_COUNT Gateway(s) ->$RUNNING"
    # Die Desktop-App haelt eigene Backend-Prozesse offen. Sie werden hier
    # nicht angefasst; wer wirklich alles stoppen will, beendet sie zuerst.
    if pgrep -f "Hermes.app/Contents/MacOS/Hermes" >/dev/null 2>&1; then
        warn "Die Desktop-App laeuft und haelt eigene Backend-Prozesse."
        warn "Zum vollstaendigen Stoppen zuerst die App beenden (Cmd+Q)."
    fi
    # Eine sticky Profilwahl wuerde 'hermes gateway stop' ohne -p umlenken.
    if [ -f "$NATIVE_HOME/active_profile" ]; then
        warn "Sticky Profil aktiv: $(cat "$NATIVE_HOME/active_profile")"
        warn "'hermes gateway stop' ohne -p trifft dieses Profil, nicht 'default'."
    fi
    echo
    if ask_yn "Diese Gateways jetzt beenden?" n; then
        for name in $RUNNING; do
            if [ "$name" = "default" ]; then
                info "stoppe: default"
                env -u HERMES_HOME hermes gateway stop || warn "default: Stopp fehlgeschlagen"
            else
                info "stoppe: $name"
                env -u HERMES_HOME hermes -p "$name" gateway stop || warn "$name: Stopp fehlgeschlagen"
            fi
        done
        echo
        info "Stand danach:"
        env -u HERMES_HOME hermes gateway list 2>/dev/null | sed 's/^/  /' || true
        echo
        info "Hinweis: die launchd-Definitionen bleiben liegen (RunAtLoad)."
        info "Nach dem naechsten Login laufen die Gateways wieder."
        info "Dauerhaft entfernen: hermes [-p <profil>] gateway uninstall"
    else
        info "uebersprungen - die Gateways laufen weiter."
    fi
fi

# ---------------------------------------------------------------------------
say "2/2  Hermes mit eigener Root starten"
# ---------------------------------------------------------------------------
read -r -p "  Root-Verzeichnis [$DEFAULT_ROOT]: " ROOT || die "Eingabe abgebrochen."
[ -n "$ROOT" ] || ROOT="$DEFAULT_ROOT"

# Tilde aufloesen und relative Pfade absolut machen.
case "$ROOT" in
    "~")    ROOT="$HOME" ;;
    "~/"*)  ROOT="$HOME/${ROOT#\~/}" ;;
esac
case "$ROOT" in
    /*) ;;
    *)  ROOT="$PWD/$ROOT" ;;
esac
ROOT="${ROOT%/}"

# Eine Root unterhalb von ~/.hermes bringt nichts: get_default_hermes_root()
# faellt auf ~/.hermes zurueck, Kanban und Profilregistry bleiben geteilt
# (hermes_constants.py:165-181, FAQ "Zwei Einschraenkungen" b).
case "$ROOT/" in
    "$NATIVE_HOME"/*)
        die "$ROOT liegt unter $NATIVE_HOME. Die Root faellt dann auf $NATIVE_HOME zurueck. Bitte einen Pfad ausserhalb waehlen."
        ;;
esac

if [ -d "$ROOT" ]; then
    info "Root existiert: $ROOT"
else
    mkdir -p "$ROOT"
    info "Root angelegt: $ROOT"
fi

# Ohne config.yaml ist die Root unkonfiguriert; `hermes setup` schreibt sie
# nach get_hermes_home() (setup.py:664), also in genau diese Root.
if [ ! -f "$ROOT/config.yaml" ]; then
    echo
    warn "In $ROOT liegt keine config.yaml - die Root ist noch unkonfiguriert."
    if ask_yn "Jetzt 'hermes setup' fuer diese Root ausfuehren?" y; then
        HERMES_HOME="$ROOT" hermes setup
    else
        info "Ohne Konfiguration meldet Hermes 'no API keys or providers found'."
        info "Nachholen: HERMES_HOME=$ROOT hermes setup"
    fi
fi

echo
info "Was soll gestartet werden?"
info "  1) CLI-Chat      - hermes chat"
info "  2) Desktop-App   - hermes desktop"
info "  3) nur eine Shell mit gesetztem HERMES_HOME"
# Solange nachfragen, bis die Eingabe gueltig ist: ein Abbruch hier waere
# besonders aergerlich, weil Schritt 1 die Gateways schon gestoppt haben kann.
while true; do
    read -r -p "  Auswahl [1]: " CHOICE || die "Eingabe abgebrochen."
    CHOICE="$(printf '%s' "$CHOICE" | tr -d '[:space:]')"
    [ -n "$CHOICE" ] || CHOICE=1
    case "$CHOICE" in
        1|2|3) break ;;
        *) warn "Bitte 1, 2 oder 3." ;;
    esac
done

export HERMES_HOME="$ROOT"

case "$CHOICE" in
    1)
        say "Starte CLI-Chat mit HERMES_HOME=$ROOT"
        exec hermes chat
        ;;
    2)
        # Desktop sucht den Checkout unter <HERMES_HOME>/hermes-agent (main.ts:838)
        # und den Build-Stempel unter <HERMES_HOME> (main_desktop.py:42-45). Beides
        # fehlt in einer frischen Root, deshalb --hermes-root und --skip-build.
        [ -d "$CHECKOUT" ] || die "Checkout nicht gefunden: $CHECKOUT"
        [ -d "$PACKAGED_APP" ] || die "Gebaute App nicht gefunden: $PACKAGED_APP
Einmalig ohne Custom-Root bauen lassen:  hermes desktop"
        # Eigenes User-Data-Verzeichnis: trennt die Electron-Instanzsperre und
        # active-profile.json von der laufenden App (main.ts:474-480, :12969-12973).
        export HERMES_DESKTOP_USER_DATA_DIR="$ROOT/desktop-userdata"
        say "Starte Desktop mit HERMES_HOME=$ROOT"
        info "User-Data: $HERMES_DESKTOP_USER_DATA_DIR"
        info "Checkout:  $CHECKOUT"
        warn "Kein 'hermes update' ausfuehren, solange eine zweite Instanz laeuft."
        exec hermes desktop --skip-build --hermes-root "$CHECKOUT"
        ;;
    3)
        say "Neue Shell mit HERMES_HOME=$ROOT"
        info "Mit 'exit' zurueck in die Ausgangs-Shell."
        exec "${SHELL:-/bin/bash}"
        ;;
esac
