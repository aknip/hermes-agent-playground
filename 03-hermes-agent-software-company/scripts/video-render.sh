#!/usr/bin/env bash
#
# ESF — Video-Zusammenfassungen rendern (AGENTS.md 8)
# ===================================================
#
#   scripts/video-render.sh                Dokumente rendern, deren Video fehlt
#   scripts/video-render.sh --gates       dazu: Videos der offenen Gate-Vorlagen
#   scripts/video-render.sh --dry-run     nur zeigen
#   scripts/video-render.sh --selbsttest  offline: Extraktion, VTT, Komposition,
#                                         und — wenn say+ffmpeg da sind — ein
#                                         ECHTES Probe-Video über den Rückfallpfad
#
# Arbeitsteilung (AGENTS.md 8): Die SCHREIBENDE Rolle liefert den Sprechertext
# als <section id="video-skript"> und bettet das Video-Element mit fester
# Namenskonvention ein. DIESES Skript macht daraus Ton, Untertitel und Bild:
#
#   1. Sprechertext -> Audio          macOS `say` (Stimme aus cadence.yaml),
#                                     dann ffmpeg nach .m4a
#   2. gemessene Audiodauer -> .vtt   Cues proportional zur Wortzahl je Satz —
#                                     dieselbe Zeitquelle wie die Komposition
#   3. Komposition -> .mp4            primär `npx hyperframes render`
#                                     (templates/hyperframes-zusammenfassung/,
#                                     Annahme bis zum ersten echten Lauf);
#                                     Rückfall: ffmpeg-Titelkarte + Audio —
#                                     der Pfad, der ohne Netz nachweisbar ist
#
# Kein Modell in diesem Skript: Der Sprechertext ist Modell-Arbeit und steht
# im Dokument; alles ab hier ist deterministisch. Ein Dokument ohne
# video-skript wird nicht "kreativ ergänzt", sondern ausgelassen — die Lücke
# meldet der Vault-Linter (WARN, AGENTS.md 8).
#
# Gate-Vorlagen (--gates) brauchen nicht einmal Modell-Arbeit: Der Blockgrund
# IST der Sprechertext. Ausgabe nach reports/gate-videos/<id>.mp4 + .vtt.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
TEMPLATE="$ESF/templates/hyperframes-zusammenfassung"
WERKZEUG="$HERE/video-werkzeug.py"

DRY=0; SELBSTTEST=0; GATES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY=1 ;;
        --selbsttest) SELBSTTEST=1 ;;
        --gates)      GATES=1 ;;
        *) echo "Unbekannte Option '$arg'"; exit 2 ;;
    esac
done

say_()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" 2>/dev/null \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

STIMME_DEFAULT="Anna"

# ---------------------------------------------------------------------------
# Die drei deterministischen Stufen, je Job-Verzeichnis
# ---------------------------------------------------------------------------
tts() { # skript.txt ziel.m4a stimme  -> Sekunden auf stdout
    local skript="$1" ziel="$2" stimme="$3" aiff="${2%.m4a}.aiff"
    /usr/bin/say -v "$stimme" -f "$skript" -o "$aiff"
    ffmpeg -y -loglevel error -i "$aiff" -c:a aac -b:a 128k "$ziel"
    rm -f "$aiff"
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$ziel"
}

render_hyperframes() { # kompositions-dir ziel.mp4
    # Annahme (VERIFIKATION.md): CLI-Konvention aus der Hyperframes-Doku,
    # gegen v?.?.? nie gemessen. Scheitert der Aufruf, greift der Rückfall.
    ( cd "$1" && npx --yes hyperframes render index.html --output "$2" ) \
        >"$1/render.log" 2>&1
}

render_ffmpeg() { # job-dir ziel.mp4 audio dauer
    # Der Rückfallpfad: Titelkarte + Sprecher-Audio. Bewusst schlicht — er
    # existiert, damit der Video-Kanal nicht an einer ungemessenen
    # Fremd-Konvention hängt. drawtext liest den Titel aus einer DATEI
    # (textfile=), weil Titel Doppelpunkte und Anführungszeichen tragen.
    local dir="$1" ziel="$2" audio="$3" dauer="$4"
    local font="/System/Library/Fonts/Helvetica.ttc"
    [ -f "$font" ] || font="/System/Library/Fonts/Supplemental/Arial.ttf"
    ffmpeg -y -loglevel error \
        -f lavfi -i "color=c=0x101418:s=1280x720:d=$dauer" \
        -i "$audio" \
        -vf "drawtext=textfile='$dir/titel.txt':fontfile='$font':fontcolor=0xe8eaed:fontsize=40:x=(w-text_w)/2:y=(h-text_h)/2-40,drawtext=text='ESF · Video-Zusammenfassung':fontfile='$font':fontcolor=0x9aa0a6:fontsize=20:x=(w-text_w)/2:y=h-120" \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$ziel"
}

rendere_job() { # dokument mp4 vtt titel-oder-leer skript-oder-leer
    local dok="$1" mp4="$2" vtt="$3" stimme
    stimme="$(cad stimme)"; stimme="${stimme:-$STIMME_DEFAULT}"
    local job; job="$(mktemp -d "${TMPDIR:-/tmp}/esf-video.XXXXXX")"

    if [ -n "${4:-}" ]; then
        printf '%s\n' "$4" > "$job/titel.txt"
        printf '%s\n' "$5" > "$job/skript.txt"
        python3 - "$job" <<'PY'
import re, sys
job = sys.argv[1]
text = open(f"{job}/skript.txt", encoding="utf-8").read().strip()
saetze = [t.strip() for t in re.split(r"(?<=[.!?])\s+", text) if t.strip()]
open(f"{job}/saetze.txt", "w", encoding="utf-8").write("\n".join(saetze) + "\n")
PY
    else
        python3 "$WERKZEUG" extrahiere "$dok" "$job" || { rm -rf "$job"; return 1; }
    fi

    local dauer
    dauer="$(tts "$job/skript.txt" "$job/audio.m4a" "$stimme")" || { rm -rf "$job"; return 1; }
    python3 "$WERKZEUG" vtt "$job/saetze.txt" "$dauer" > "$vtt"

    local renderer="ffmpeg-rueckfall"
    if command -v npx >/dev/null && [ -d "$TEMPLATE" ]; then
        python3 "$WERKZEUG" komposition "$TEMPLATE" "$job/comp" \
            "$job/titel.txt" "$job/saetze.txt" "$job/audio.m4a" "$dauer"
        if render_hyperframes "$job/comp" "$mp4" && [ -s "$mp4" ]; then
            renderer="hyperframes"
        fi
    fi
    if [ "$renderer" = "ffmpeg-rueckfall" ]; then
        render_ffmpeg "$job" "$mp4" "$job/audio.m4a" "$dauer" || { rm -rf "$job"; return 1; }
    fi
    ok "$(basename "$mp4")  (${dauer%%.*}s, $renderer, Untertitel: $(basename "$vtt"))"
    rm -rf "$job"
}

# ---------------------------------------------------------------------------
# Selbsttest — kein Board, kein Netz erforderlich; misst den Rückfallpfad echt
# ---------------------------------------------------------------------------
if [ "$SELBSTTEST" -eq 1 ]; then
    say_ "video-render Selbsttest"
    fehler=0
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/esf-video-test.XXXXXX")"

    cat > "$tmp/probe.html" <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<title>Probe-Report — ESF</title>
<meta name="esf-typ" content="report">
<meta name="esf-karte" content="t_selbsttest">
<meta name="esf-datum" content="2026-08-18">
<meta name="esf-video" content="probe.mp4">
</head><body>
<h1>Probe</h1>
<section id="video-skript"><p>Dies ist der Selbsttest des Video-Kanals der
Enterprise Software Factory. Er prüft drei Stufen. Erstens die Extraktion des
Sprechertexts aus dem Dokument. Zweitens die Untertitel, deren Zeitmarken aus
der gemessenen Audiodauer entstehen. Drittens das gerenderte Video selbst.</p></section>
</body></html>
HTML

    # (a) Extraktion
    if python3 "$WERKZEUG" extrahiere "$tmp/probe.html" "$tmp/job" \
       && [ "$(grep -c . "$tmp/job/saetze.txt")" -eq 5 ]; then
        ok "Extraktion: Titel + 5 Sätze"
    else
        nein "Extraktion fehlgeschlagen"; fehler=1
    fi

    # (b) VTT aus fester Dauer — deterministisch prüfbar
    if python3 "$WERKZEUG" vtt "$tmp/job/saetze.txt" 20 > "$tmp/probe.vtt" \
       && head -1 "$tmp/probe.vtt" | grep -q '^WEBVTT' \
       && [ "$(grep -c ' --> ' "$tmp/probe.vtt")" -eq 5 ] \
       && grep -q '00:00:20.000$' "$tmp/probe.vtt"; then
        ok "VTT: 5 Cues, Ende exakt bei 20s"
    else
        nein "VTT fehlerhaft"; fehler=1
    fi

    # (c) Komposition instanziieren
    if python3 "$WERKZEUG" komposition "$TEMPLATE" "$tmp/comp" \
         "$tmp/job/titel.txt" "$tmp/job/saetze.txt" "$tmp/probe.vtt" 20 \
       && grep -q 'window.ESF_DATEN' "$tmp/comp/daten.js" \
       && python3 -c "import json,re;s=open('$tmp/comp/daten.js').read();json.loads(re.search(r'= (.*);',s,re.S).group(1))"; then
        ok "Komposition: Template kopiert, daten.js ist gültiges JSON"
    else
        nein "Komposition fehlgeschlagen"; fehler=1
    fi

    # (d) Der Rückfallpfad, ECHT — nur wenn die Werkzeuge da sind
    if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null && [ -x /usr/bin/say ]; then
        if rendere_job "$tmp/probe.html" "$tmp/probe.mp4" "$tmp/probe2.vtt" \
           && [ -s "$tmp/probe.mp4" ]; then
            d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp/probe.mp4")"
            ok "Rückfallpfad real gerendert: probe.mp4, ${d%%.*}s"
        else
            nein "Rückfallpfad scheiterte"; fehler=1
        fi
    else
        warn "say/ffmpeg fehlen — Rückfallpfad nicht messbar auf dieser Maschine"
    fi

    rm -rf "$tmp"
    exit "$fehler"
fi

# ---------------------------------------------------------------------------
# Normalbetrieb
# ---------------------------------------------------------------------------
[ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT — erst ./setup.sh"; exit 1; }
schalter="$(cad zusammenfassungen)"
if [ "${schalter:-an}" = "aus" ]; then
    echo "videos.zusammenfassungen: aus — nichts zu tun"; exit 0
fi
for w in ffmpeg ffprobe python3; do
    command -v "$w" >/dev/null || { echo "FEHLER: '$w' fehlt — der Video-Kanal braucht ffmpeg."; exit 1; }
done
[ -x /usr/bin/say ] || { echo "FEHLER: /usr/bin/say fehlt — das Sprecher-Audio kommt (bis eine bessere Stimme gemessen ist) von macOS `say`."; exit 1; }

say_ "Video-Zusammenfassungen$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
anzahl=0
while IFS=$'\t' read -r dok mp4 vtt; do
    [ -n "$dok" ] || continue
    if [ "$DRY" -eq 1 ]; then
        ok "würde rendern: ${mp4#$VAULT/}  (aus ${dok#$VAULT/})"
    else
        rendere_job "$dok" "$mp4" "$vtt" || nein "Render fehlgeschlagen: ${dok#$VAULT/}"
    fi
    anzahl=$((anzahl + 1))
done < <(python3 "$WERKZEUG" jobs "$VAULT")
[ "$anzahl" -eq 0 ] && echo "  alle Dokument-Videos aktuell"

# ---------------------------------------------------------------------------
# Offene Gate-Vorlagen: der Blockgrund ist der Sprechertext
# ---------------------------------------------------------------------------
if [ "$GATES" -eq 1 ]; then
    command -v hermes >/dev/null || { echo "FEHLER: 'hermes' fehlt"; exit 1; }
    command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
    say_ "Gate-Vorlagen$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
    mkdir -p "$VAULT/reports/gate-videos"
    k() { hermes kanban --board "$BOARD" "$@"; }
    liste="$(k list --json 2>/dev/null || echo '[]')"
    for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="blocked") | select(.title|startswith("GATE ")) | .id'); do
        kleinid="$(printf '%s' "$id" | tr 'A-Z_' 'a-z-')"
        mp4="$VAULT/reports/gate-videos/$kleinid.mp4"
        [ -f "$mp4" ] && { echo "  $id — Video liegt schon"; continue; }
        titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
        grund="$(k show "$id" --json 2>/dev/null \
            | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // ""')"
        [ -n "$grund" ] || { warn "$id ohne Blockgrund — keine Vorlage, kein Video"; continue; }
        if [ "$DRY" -eq 1 ]; then
            ok "würde rendern: reports/gate-videos/$kleinid.mp4"
        else
            rendere_job "" "$mp4" "${mp4%.mp4}.vtt" "$titel" "$grund" \
                || nein "Render fehlgeschlagen: $id"
        fi
    done
fi
