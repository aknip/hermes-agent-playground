#!/usr/bin/env bash
#
# ESF — Der Gate-Report
# =====================
#
#   scripts/report-gates.sh [--stdout]
#
# Cron 18:00. Der verlässliche Weg, auf dem der CEO erfährt, dass er gebraucht
# wird. Push-Benachrichtigung wäre schöner, ist aber in v0.20.0 unverifiziert —
# dieser Report ist belegt.
#
# Enthält alles, was ein Tageslauf an Entscheidungsbedarf hinterlassen hat:
# wartende Gates mit Vorlage und Alter, Karten in `triage` (denn nichts in
# Hermes warnt davor), Monitor-Befunde, Budget-Stand. Schreibt nach
# reports/gate-<datum>.html und enthält den Abschluss-Check des Tageslaufs.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"
ZIEL="$VAULT/reports/gate-$HEUTE.html"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT/reports" ] || mkdir -p "$VAULT/reports"
k() { hermes kanban --board "$BOARD" "$@"; }

liste="$(k list --json 2>/dev/null || echo '[]')"
deckel="$(sed -n 's/^gate_fragen_pro_tag:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
deckel="${deckel:-3}"

# HTML-Sonderzeichen entschärfen — Blockgründe sind Modelltext.
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

{
cat <<EOF
<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>Gate-Report $HEUTE — ESF</title>
  <meta name="esf-typ" content="report">
  <meta name="esf-karte" content="report-gates.sh">
  <meta name="esf-datum" content="$HEUTE">
  <style>
    body{font:16px/1.6 -apple-system,system-ui,sans-serif;max-width:52rem;margin:2rem auto;padding:0 1rem}
    .gate{border-left:4px solid #d97706;padding:.5rem 0 .5rem 1rem;margin:1.5rem 0}
    .fehler{border-left-color:#dc2626}
    pre{background:#f6f6f6;padding:.75rem;overflow-x:auto;white-space:pre-wrap;font-size:14px}
    .meta{color:#666;font-size:14px}
    table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ddd;padding:.4rem;text-align:left}
  </style>
</head>
<body>
<h1>Gate-Report $HEUTE</h1>
<p class="meta">Erzeugt $(date '+%Y-%m-%d %H:%M:%S') von <code>report-gates.sh</code>.
Aufmerksamkeits-Deckel: $deckel Fragen pro Tageslauf.</p>
EOF

# --- 1. Wartende Gates -----------------------------------------------------
ids="$(printf '%s' "$liste" | jq -r '.[] | select(.status=="blocked") | .id')"
anzahl="$(printf '%s\n' "$ids" | grep -c . || true)"

echo "<h2>Wartende Entscheidungen ($anzahl)</h2>"
if [ "$anzahl" -eq 0 ]; then
    echo "<p>Keine. Die Organisation läuft.</p>"
else
    [ "$anzahl" -gt "$deckel" ] && cat <<EOF
<p><strong>⚠ $anzahl Gates bei einem Deckel von $deckel.</strong> Die überzähligen
sind unten als <em>zurückgestellt</em> markiert und werden morgen zuerst
vorgelegt. Ein Gate mit zwölf wartenden Karten wird nicht sorgfältiger
beantwortet, sondern durchgewinkt.</p>
EOF
    nr=0
    for id in $ids; do
        nr=$((nr + 1))
        titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title' | esc)"
        seit="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .updated_at // .created_at // ""')"
        grund="$(k show "$id" --json 2>/dev/null \
                 | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // "(keine Vorlage hinterlegt — das ist ein Mangel der Karte)"' | esc)"
        zurueck=""
        [ "$nr" -gt "$deckel" ] && zurueck=" <em>(zurückgestellt auf morgen)</em>"
        cat <<EOF
<div class="gate">
  <h3>$id — $titel$zurueck</h3>
  <p class="meta">wartet seit $seit</p>
  <pre>$grund</pre>
  <p><code>./gate.sh</code> zeigt die gültigen Verben dieser Gate-Art.</p>
</div>
EOF
    done
fi

# --- 2. Still gekippte Karten ----------------------------------------------
triage="$(printf '%s' "$liste" | jq -r '.[] | select(.status=="triage") | "\(.id)|\(.title)"')"
echo "<h2>Karten in der Triage</h2>"
if [ -z "$triage" ]; then
    echo "<p>Keine.</p>"
else
    cat <<'EOF'
<p class="fehler"><strong>Diese Karten fragen niemanden mehr.</strong> Hermes
routet eine Karte nach <code>triage</code>, wenn sie zweimal mit derselben
Block-Art blockiert wurde — ohne Warnung. Nur diese handgeschriebene Prüfung
macht sie sichtbar.</p>
<table><tr><th>Karte</th><th>Titel</th></tr>
EOF
    printf '%s\n' "$triage" | while IFS='|' read -r id titel; do
        printf '<tr><td>%s</td><td>%s</td></tr>\n' "$id" "$(printf '%s' "$titel" | esc)"
    done
    echo "</table>"
fi

# --- 3. Monitor-Befunde ----------------------------------------------------
echo "<h2>Monitor</h2><pre>"
"$HERE/monitor.sh" 2>&1 | esc || true
echo "</pre>"

# --- 4. Abschluss-Check des Tageslaufs -------------------------------------
echo "<h2>Abschluss-Check Tageslauf</h2><pre>"
"$HERE/check-daily.sh" 2>&1 | esc || true
echo "</pre>"

# --- 5. Lage ---------------------------------------------------------------
echo "<h2>Board</h2><pre>"
printf '%s' "$liste" | jq -r 'group_by(.status) | map("\(.[0].status): \(length)") | join("\n")' | esc
echo "</pre>"

echo "</body></html>"
} > "$ZIEL"

echo "Gate-Report: $ZIEL"
[ "${1:-}" = "--stdout" ] && cat "$ZIEL"

# Der Report ist eine Vault-Datei und hält sich an AGENTS.md.
python3 "$ESF/scripts/vault-lint.py" "$VAULT" >/dev/null 2>&1 \
    || echo "⚠ Der Vault-Linter beanstandet etwas — python3 scripts/vault-lint.py workspace/company"
exit 0
