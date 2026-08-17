#!/usr/bin/env bash
#
# ESF — Rückbau
# =============
#
#   ./teardown.sh                    alles zurückbauen (fragt nach)
#   ./teardown.sh --keep-profiles    Board und Arbeitskopie weg, Profile bleiben
#   ./teardown.sh --keep-board       Profile und Arbeitskopie weg, Board bleibt
#   ./teardown.sh --yes              nicht nachfragen
#
# Gelöscht werden AUSSCHLIESSLICH Profile, die eine .esf-Markerdatei tragen.
# Profile liegen global in ~/.hermes/profiles/, und ein Teardown, der nach
# Namen löscht, reisst fremde Arbeit mit — das esf--Präfix schützt den
# Namensraum, die Markerdatei schützt das Löschen.
#
# NICHT angetastet wird das Produkt-Repo: Branches, Worktrees und Commits, die
# die ESF dort erzeugt hat, bleiben stehen. Sie sind das Ergebnis, nicht das
# Werkzeug. Was dort aufzuräumen ist, zeigt dieses Skript am Ende an.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
MARKER=".esf"

PROFILE_NAMES=(
    esf-chief-of-staff esf-market-scout esf-market-analyst esf-product-manager
    esf-architect esf-estimator esf-dev-a esf-dev-b esf-reviewer
    esf-qa-release esf-controller
)

KEEP_PROFILES=0; KEEP_BOARD=0; JA=0
for arg in "$@"; do
    case "$arg" in
        --keep-profiles) KEEP_PROFILES=1 ;;
        --keep-board)    KEEP_BOARD=1 ;;
        --yes|-y)        JA=1 ;;
        *) echo "Unbekannte Option '$arg'"; exit 1 ;;
    esac
done

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "Was zurückgebaut wird"
# ---------------------------------------------------------------------------
zu_loeschen=(); geschuetzt=()
for name in "${PROFILE_NAMES[@]}"; do
    verzeichnis="$HOME/.hermes/profiles/$name"
    [ -d "$verzeichnis" ] || continue
    if [ -f "$verzeichnis/$MARKER" ]; then
        zu_loeschen+=("$name")
    else
        geschuetzt+=("$name")
    fi
done

if [ "$KEEP_PROFILES" -eq 1 ]; then
    echo "  Profile:       bleiben (--keep-profiles)"
elif [ ${#zu_loeschen[@]} -eq 0 ]; then
    echo "  Profile:       keine ESF-markierten gefunden"
else
    printf '  Profile:       %s\n' "${zu_loeschen[*]}"
fi
if [ ${#geschuetzt[@]} -gt 0 ]; then
    printf '\033[33m  ⚠ ohne .esf-Marker, bleiben unangetastet: %s\033[0m\n' "${geschuetzt[*]}"
fi

if [ "$KEEP_BOARD" -eq 1 ]; then
    echo "  Board:         bleibt (--keep-board)"
else
    echo "  Board:         $BOARD (inklusive aller Karten und ihrer Historie)"
fi
echo "  Arbeitskopie:  $HERE/workspace/  (seed/ bleibt)"

if [ -f "$HOME/Library/LaunchAgents/ai.hermes.esf.plist" ] || crontab -l 2>/dev/null | grep -q "ESF-"; then
    printf '\033[33m  ⚠ Es sind ESF-Cron-Einträge aktiv. Erst ./install-cron.sh --remove.\033[0m\n'
fi

if [ "$JA" -eq 0 ]; then
    printf '\nFortfahren? [j/N] '
    read -r antwort
    case "$antwort" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
fi

# ---------------------------------------------------------------------------
if [ "$KEEP_BOARD" -eq 0 ]; then
    say "Board"
    # Achtung, beide Flags sind gemessen und nicht geraten:
    #   `boards rm <slug>` ARCHIVIERT nur (nach boards/_archived/); erst
    #   `--delete` entfernt wirklich. Ein `--force` gibt es nicht.
    # Archivieren ist hier bewusst der Default-Wunsch NICHT: Ein Board, das der
    # Teardown liegen lässt, taucht beim nächsten setup.sh als „existiert
    # bereits" wieder auf — mit den Karten des letzten Laufs darin.
    if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
        if hermes kanban boards rm "$BOARD" --delete >/dev/null 2>&1; then
            echo "  $BOARD entfernt (inklusive Karten-Historie)"
        else
            echo "  ⚠ Löschen fehlgeschlagen — von Hand: hermes kanban boards rm $BOARD --delete"
        fi

        # Gemessen: Läuft irgendein `hermes … gateway run`, legt der Daemon das
        # Board-Verzeichnis binnen Sekunden WIEDER an — als leere Hülle. Die
        # Karten und ihre Historie sind trotzdem weg; was zurückbleibt, ist ein
        # Board ohne Inhalt und mit aus dem Slug abgeleitetem Namen.
        # Das ist kein Fehler dieses Skripts, aber es als Erfolg zu melden wäre
        # einer.
        if [ -d "$HOME/.hermes/kanban/boards/$BOARD" ]; then
            printf '\033[33m  ⚠ Das Board-Verzeichnis ist sofort wieder da.\033[0m\n'
            laufend="$(pgrep -fl 'hermes.*gateway run' 2>/dev/null | wc -l | tr -d ' ')"
            printf '     Ursache: %s laufende(r) Gateway-Daemon(en) legen es neu an.\n' "$laufend"
            printf '     Die Karten und ihre Historie sind weg; zurück bleibt eine leere Hülle.\n'
            printf '     Wirklich restlos entfernen:\n'
            printf '       hermes gateway stop && hermes kanban boards rm %s --delete\n' "$BOARD"
            printf '     Für ein erneutes ./setup.sh ist das ohne Belang.\n'
        fi
    else
        echo "  existiert nicht — übersprungen"
    fi
fi

# ---------------------------------------------------------------------------
if [ "$KEEP_PROFILES" -eq 0 ] && [ ${#zu_loeschen[@]} -gt 0 ]; then
    say "Profile"
    # `-y`, nicht `--force`: Mit dem falschen Flag fragt Hermes trotzdem
    # interaktiv nach dem Profilnamen, die Antwort ist leer, und der Befehl
    # meldet „Cancelled." — das anschliessende rm -rf räumt dann zwar das
    # Verzeichnis weg, aber die Löschung lief nie durch Hermes.
    for name in "${zu_loeschen[@]}"; do
        hermes profile delete "$name" -y >/dev/null 2>&1 || true
        rm -rf "$HOME/.hermes/profiles/$name"
        echo "  $name entfernt"
    done
fi

# ---------------------------------------------------------------------------
say "Arbeitskopie"
# ---------------------------------------------------------------------------
if [ -d "$HERE/workspace" ]; then
    rm -rf "$HERE/workspace"
    echo "  workspace/ entfernt (seed/ ist der Master und bleibt)"
else
    echo "  gibt es nicht — übersprungen"
fi
rm -f "$HERE/task-ids.env"

# ---------------------------------------------------------------------------
say "Produkt-Repo: ESF-Hooks zurückbauen"
# ---------------------------------------------------------------------------
# Muss VOR dem Löschen der Arbeitskopie passieren, solange cadence.yaml noch
# gelesen werden kann — und muss überhaupt passieren, sonst zeigt
# core.hooksPath nach dem Teardown auf ein Verzeichnis, das es nicht mehr gibt.
if [ -x "$HERE/scripts/install-repo-hooks.sh" ]; then
    "$HERE/scripts/install-repo-hooks.sh" --remove 2>&1 | sed 's/^/  /'
else
    echo "  install-repo-hooks.sh fehlt — core.hooksPath von Hand prüfen"
fi

# ---------------------------------------------------------------------------
say "Was im Produkt-Repo bleibt"
# ---------------------------------------------------------------------------
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$HERE/seed/company/cadence.yaml" | head -1)"
if [ -d "$REPO/.git" ]; then
    branches="$(git -C "$REPO" branch --list 'feat/*' --format='%(refname:short)' | tr '\n' ' ')"
    worktrees="$(git -C "$REPO" worktree list | tail -n +2 | wc -l | tr -d ' ')"
    echo "  Repo:      $REPO"
    echo "  Branches:  ${branches:-<keine feat/-Branches>}"
    echo "  Worktrees: $worktrees zusätzlich zum Hauptbaum"
    echo
    echo "  Das ist Absicht: Der Rückbau entfernt die Organisation, nicht ihr"
    echo "  Ergebnis. Zum Aufräumen von Hand:"
    echo "    git -C \"$REPO\" worktree list"
    echo "    git -C \"$REPO\" worktree remove <pfad>"
    echo "    git -C \"$REPO\" branch -D <branch>"
fi

printf '\n\033[32m✓ Rückbau abgeschlossen. Neu aufsetzen: ./setup.sh\033[0m\n'
