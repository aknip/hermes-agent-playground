#!/usr/bin/env bash
#
# ESF — Die sieben Betriebs-Skripte takten
# =========================================
#
#   ./install-cron.sh            einrichten
#   ./install-cron.sh --remove   zurückbauen
#   ./install-cron.sh --list     zeigen, was eingetragen ist
#
#   tick.sh          07:00 täglich   Herzschlag: Fetch, E2E, fällige Karten
#   monitor.sh       stündlich :00   stille Ausfälle + Abschluss-Erkennung
#   eskalation.sh    stündlich :15   die Notfall-Leiter (Phase 3)
#   ceo-tick.sh      stündlich :30   Entscheidungskarten + Executor (Phase 3)
#   video-render.sh  stündlich :45   Video-Zusammenfassungen + Gate-Videos (AGENTS.md 8)
#   report-gates.sh  18:00 täglich   der Report, über den der Supervisor erfährt
#   ledger-sync.sh   23:30 täglich   Wanduhrzeiten und Kosten ins Ledger
#
# ⚠ Erst NACH dem Phase-0-Probelauf ausführen. Ein Cron-Eintrag auf einem
#   Gerüst, das noch nicht durchgelaufen ist, produziert Karten, die niemand
#   erwartet — und der Tick zieht jedes Mal eine ganze Pipeline nach sich.
#
# ⚠ Vor jedem ./teardown.sh: erst ./install-cron.sh --remove. Sonst laufen die
#   Skripte gegen ein Board, das es nicht mehr gibt.
#
# Beschleunigung kommt NICHT aus mehr Ticks. Der Dispatcher arbeitet offene
# Karten ohnehin kontinuierlich ab; der tägliche Tick ist nur für den
# Markt-Eingang da, und die Abschluss-Erkennung im stündlichen Monitor ist ein
# tokenfreier jq-Check.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKE="# ESF-"
LOG="$HERE/workspace/cron.log"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

aktuelle_crontab() { crontab -l 2>/dev/null || true; }

case "${1:-}" in
--list)
    say "ESF-Einträge in der crontab"
    aktuelle_crontab | grep "$MARKE" || echo "  keine"
    exit 0 ;;

--remove)
    say "ESF-Einträge entfernen"
    if ! aktuelle_crontab | grep -q "$MARKE"; then
        echo "  keine vorhanden"
        exit 0
    fi
    aktuelle_crontab | grep -v "$MARKE" | crontab -
    echo "  entfernt"
    aktuelle_crontab | grep "$MARKE" >/dev/null 2>&1 \
        && { echo "  ⚠ es sind noch welche da"; exit 1; }
    echo "  Kontrolle: keine ESF-Zeile mehr in der crontab"
    exit 0 ;;
esac

# ---------------------------------------------------------------------------
say "Vorbedingungen"
# ---------------------------------------------------------------------------
[ -d "$HERE/workspace/company" ] || {
    echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }

if aktuelle_crontab | grep -q "$MARKE"; then
    echo "  ESF-Einträge existieren bereits — sie werden ersetzt."
fi

# Die Skripte laufen ohne Login-Shell. PATH und die Umgebung, die Hermes und
# pnpm brauchen, müssen deshalb in die crontab.
HERMES_BIN="$(command -v hermes)"
PFAD="$(dirname "$HERMES_BIN"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
echo "  hermes: $HERMES_BIN"
echo "  PATH:   $PFAD"
echo "  Log:    $LOG"

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    printf '\033[33m  ⚠ OPENROUTER_API_KEY ist in dieser Shell nicht gesetzt.\033[0m\n'
    printf '    monitor.sh kann dann kein Restguthaben prüfen — und ein Key am\n'
    printf '    Limit sieht aus wie eine Karte, die einfach nicht startet.\n'
fi

# ---------------------------------------------------------------------------
say "Einrichten"
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG")"
{
    aktuelle_crontab | grep -v "$MARKE"
    cat <<EOF
${MARKE}PATH
PATH=$PFAD
${MARKE}tick — Herzschlag, tokenfrei
0 7 * * *   cd "$HERE" && ./scripts/tick.sh >> "$LOG" 2>&1
${MARKE}monitor — stille Ausfälle und Abschluss-Erkennung
0 * * * *   cd "$HERE" && ./scripts/monitor.sh >> "$LOG" 2>&1
${MARKE}eskalation — die Notfall-Leiter: Code entscheidet, was ein Notfall ist
15 * * * *  cd "$HERE" && ./scripts/eskalation.sh >> "$LOG" 2>&1
${MARKE}ceo-tick — Entscheidungskarten für esf-ceo, Validierung, Ausführung
30 * * * *  cd "$HERE" && ./scripts/ceo-tick.sh >> "$LOG" 2>&1
${MARKE}video-render — Sprecher-Videos der Dokumente und offenen Gate-Vorlagen
45 * * * *  cd "$HERE" && ./scripts/video-render.sh --gates >> "$LOG" 2>&1
${MARKE}report-gates — der Weg zum Supervisor
0 18 * * *  cd "$HERE" && ./scripts/report-gates.sh >> "$LOG" 2>&1
${MARKE}ledger-sync — Messwerte ins Ledger
30 23 * * * cd "$HERE" && ./scripts/ledger-sync.sh >> "$LOG" 2>&1
EOF
} | crontab -

say "Eingetragen"
crontab -l | grep -A1 "$MARKE" | grep -v '^--$'

cat <<EOF

$(printf '\033[32m✓ Getaktet.\033[0m')

Von Hand auslösen, ohne auf die Uhr zu warten:
  ./scripts/tick.sh --dry-run
  ./scripts/monitor.sh
  ./scripts/eskalation.sh --dry-run
  ./scripts/ceo-tick.sh --dry-run
  ./scripts/video-render.sh --dry-run --gates
  ./scripts/report-gates.sh
  ./scripts/ledger-sync.sh --dry-run

Was gelaufen ist:  tail -f $LOG
Rückbau:           ./install-cron.sh --remove   ← VOR jedem ./teardown.sh
EOF
