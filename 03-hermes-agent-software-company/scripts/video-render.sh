#!/usr/bin/env bash
#
# ESF — Video-Zusammenfassungen rendern (AGENTS.md 8)
# ===================================================
#
#   scripts/video-render.sh                Dokumente rendern, deren Video fehlt
#   scripts/video-render.sh --auftraege   Ton messen + Designer-Karten anlegen
#   scripts/video-render.sh --gates       dazu: Videos der offenen Gate-Vorlagen
#   scripts/video-render.sh --ohne-lint   Stufe 1 ohne hyperframes lint (Notbetrieb)
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

DRY=0; SELBSTTEST=0; GATES=0; LINT=1; AUFTRAEGE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY=1 ;;
        --selbsttest) SELBSTTEST=1 ;;
        --gates)      GATES=1 ;;
        --auftraege)  AUFTRAEGE=1 ;;
        --ohne-lint)  LINT=0 ;;
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

# Öffentliche npm-Registry für den Hyperframes-Aufruf (siehe render_hyperframes).
NPM_REGISTRY="${ESF_NPM_REGISTRY:-https://registry.npmjs.org}"

# ---------------------------------------------------------------------------
# Die drei deterministischen Stufen, je Job-Verzeichnis
# ---------------------------------------------------------------------------
tts() { # skript.txt ziel.m4a stimme  -> Sekunden auf stdout
    local skript="$1" ziel="$2" stimme="$3" aiff="${2%.m4a}.aiff"
    /usr/bin/say -v "$stimme" -f "$skript" -o "$aiff"
    # -nostdin ist PFLICHT, nicht Kosmetik: Die Job-Schleife unten liest ihre
    # Zeilen von stdin, und ffmpeg liest stdin ebenfalls (Tastaturkommandos).
    # Ohne -nostdin verschluckt es je Aufruf ein Byte der NAECHSTEN Jobzeile —
    # gemessen am 18.08.2026: jede zweite Datei scheiterte an einem Pfad ohne
    # fuehrenden Schraegstrich ("Users/..." statt "/Users/...").
    ffmpeg -nostdin -y -loglevel error -i "$aiff" -c:a aac -b:a 128k "$ziel"
    rm -f "$aiff"
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$ziel"
}

render_hyperframes() { # kompositions-dir ziel.mp4
    # Gemessen gegen Hyperframes 0.8.3 (18.08.2026), nicht mehr geraten:
    #
    #   · Das Positional von `render` ist ein PROJEKTVERZEICHNIS, keine Datei.
    #     Die frühere Fassung rief `render index.html` — das hätte die Datei als
    #     Verzeichnis gelesen. Eine einzelne Datei bräuchte -c/--composition.
    #   · --registry am Aufruf, weil die globale ~/.npmrc alle npm-Aufrufe auf
    #     die Firmen-Registry artifacts.mgm-tp.com umleitet, die von hier nicht
    #     auflösbar ist. Genau daran scheiterte die Probe am 18.08.2026. Der
    #     Schalter gilt NUR für diesen Aufruf — die globale Konfiguration des
    #     Rechners bleibt unangetastet. Überschreibbar per ESF_NPM_REGISTRY.
    #   · HYPERFRAMES_SKIP_SKILLS=1: `render` prüft sonst AI-Skills gegen GitHub.
    #
    # Scheitert der Aufruf, greift der ffmpeg-Rückfall — und rendere_job sagt in
    # der Ausgabe, WELCHER Renderer die Datei erzeugt hat.
    ( cd "$1" \
      && HYPERFRAMES_SKIP_SKILLS=1 npx --yes --registry "$NPM_REGISTRY" \
         hyperframes render . --output "$2" --quiet ) \
        >"$1/render.log" 2>&1 </dev/null
}

render_ffmpeg() { # job-dir ziel.mp4 audio dauer
    # Der Rückfallpfad: Titelkarte + Sprecher-Audio. Bewusst schlicht — er
    # existiert, damit der Video-Kanal nicht an einer ungemessenen
    # Fremd-Konvention hängt. drawtext liest den Titel aus einer DATEI
    # (textfile=), weil Titel Doppelpunkte und Anführungszeichen tragen.
    local dir="$1" ziel="$2" audio="$3" dauer="$4"
    local font="/System/Library/Fonts/Helvetica.ttc"
    [ -f "$font" ] || font="/System/Library/Fonts/Supplemental/Arial.ttf"
    ffmpeg -nostdin -y -loglevel error \
        -f lavfi -i "color=c=0x101418:s=1280x720:d=$dauer" \
        -i "$audio" \
        -vf "drawtext=textfile='$dir/titel.txt':fontfile='$font':fontcolor=0xe8eaed:fontsize=40:x=(w-text_w)/2:y=(h-text_h)/2-40,drawtext=text='ESF · Video-Zusammenfassung':fontfile='$font':fontcolor=0x9aa0a6:fontsize=20:x=(w-text_w)/2:y=h-120" \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$ziel"
}

komp_dir_von() { printf '%s.komposition' "${1%.html}"; }

# Der Auftrag ist der Vertrag zwischen Code und Designer (AGENTS.md 8.1): Code
# misst Ton und Dauer, der Designer gestaltet dagegen. Deshalb wird das Audio
# EINMAL erzeugt und danach wiederverwendet — würde der Renderlauf neu vertonen,
# wanderte die Dauer minimal und die Komposition des Designers wäre plötzlich
# "falsch", ohne dass er etwas getan hat.
schreibe_auftrag() { # komp-dir dokument titel dauer saetze.txt
    python3 - "$1" "$2" "$3" "$4" "$5" "$VAULT" <<'PYJOB'
import json, os, re, sys
komp, dok, titel, dauer, saetze_datei, vault = sys.argv[1:7]
dauer = float(dauer)
zeilen = [z.strip() for z in open(saetze_datei, encoding="utf-8") if z.strip()]
gew = [max(1, len(z.split())) for z in zeilen]
ges = sum(gew) or 1
starts, t = [], 0.0
for g in gew:
    starts.append(round(t, 3))
    t += dauer * g / ges
grenzen = starts + [round(dauer, 3)]
cues = [{"text": z, "start": starts[i], "dauer": round(grenzen[i + 1] - starts[i], 3)}
        for i, z in enumerate(zeilen)]
typ = ""
if dok:
    try:
        h = open(dok, encoding="utf-8").read()
        m = re.search(r'<meta\s+name="esf-typ"\s+content="([^"]*)"', h)
        typ = m.group(1) if m else ""
    except OSError:
        pass
json.dump({"dokument": os.path.relpath(dok, vault) if dok else "",
           "titel": titel, "typ": typ, "dauer": round(dauer, 3),
           "audio": "audio.m4a", "cues": cues},
          open(os.path.join(komp, "auftrag.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=2)
PYJOB
}

# Stufe 1 der Leiter: die individuelle Komposition des esf-video-designer.
# Gerendert wird sie nur, wenn BEIDE Tore grün sind — das Struktur- und
# Auftragstor (video-werkzeug.py pruefe) und der Framework-Linter. Ein Modell
# entscheidet hier über die Form, nie darüber, ob das Ergebnis brauchbar ist.
komposition_taugt() { # komp-dir
    python3 "$WERKZEUG" pruefe "$1" "$1/auftrag.json" || return 1
    [ "$LINT" -eq 0 ] && return 0
    if ( cd "$1" && HYPERFRAMES_SKIP_SKILLS=1 npx --yes --registry "$NPM_REGISTRY" \
         hyperframes lint . ) >"$1/lint.log" 2>&1 </dev/null; then
        return 0
    fi
    warn "hyperframes lint rot — siehe $(basename "$1")/lint.log"
    return 1
}

rendere_job() { # dokument mp4 vtt titel-oder-leer skript-oder-leer
    local dok="$1" mp4="$2" vtt="$3" stimme
    stimme="$(cad stimme)"; stimme="${stimme:-$STIMME_DEFAULT}"
    local job; job="$(mktemp -d "${TMPDIR:-/tmp}/esf-video.XXXXXX")"

    if [ -n "${4:-}" ]; then
        printf '%s\n' "$4" > "$job/titel.txt"
        printf '%s\n' "$5" > "$job/skript.txt"
        python3 - "$job" <<'PYJOB'
import re, sys
job = sys.argv[1]
text = open(f"{job}/skript.txt", encoding="utf-8").read().strip()
saetze = [t.strip() for t in re.split(r"(?<=[.!?])\s+", text) if t.strip()]
open(f"{job}/saetze.txt", "w", encoding="utf-8").write("\n".join(saetze) + "\n")
PYJOB
    else
        python3 "$WERKZEUG" extrahiere "$dok" "$job" || { rm -rf "$job"; return 1; }
    fi

    # Vorhandenen Auftrag WIEDERVERWENDEN statt neu zu vertonen (siehe oben).
    local komp="" dauer=""
    [ -n "$dok" ] && komp="$(komp_dir_von "$dok")"
    if [ -n "$komp" ] && [ -f "$komp/auftrag.json" ] && [ -s "$komp/audio.m4a" ]; then
        dauer="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["dauer"])' \
                 "$komp/auftrag.json")"
        cp "$komp/audio.m4a" "$job/audio.m4a"
    else
        dauer="$(tts "$job/skript.txt" "$job/audio.m4a" "$stimme")" || { rm -rf "$job"; return 1; }
    fi
    python3 "$WERKZEUG" vtt "$job/saetze.txt" "$dauer" > "$vtt"

    local renderer="ffmpeg-rueckfall"
    # Stufe 1 — individuell
    if [ -n "$komp" ] && [ -f "$komp/index.html" ] && command -v npx >/dev/null; then
        cp -f "$job/audio.m4a" "$komp/audio.m4a"
        [ -f "$komp/auftrag.json" ] || schreibe_auftrag "$komp" "$dok" \
            "$(cat "$job/titel.txt")" "$dauer" "$job/saetze.txt"
        if komposition_taugt "$komp" && render_hyperframes "$komp" "$mp4" && [ -s "$mp4" ]; then
            renderer="komposition(esf-video-designer)"
        else
            warn "Komposition abgewiesen — es gilt die generische Vorlage"
        fi
    fi
    # Stufe 2 — generisch
    if [ "$renderer" = "ffmpeg-rueckfall" ] && command -v npx >/dev/null && [ -d "$TEMPLATE" ]; then
        python3 "$WERKZEUG" komposition "$TEMPLATE" "$job/comp" \
            "$job/titel.txt" "$job/saetze.txt" "$job/audio.m4a" "$dauer"
        if render_hyperframes "$job/comp" "$mp4" && [ -s "$mp4" ]; then
            renderer="vorlage(generisch)"
        fi
    fi
    # Stufe 3 — trägt ohne Chrome und ohne Netz
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

    # (c) Komposition instanziieren — geprüft werden die Pflichten, die
    #     `hyperframes lint` gegen 0.8.3 durchsetzt. Sie müssen STATISCH im
    #     HTML stehen: der Linter liest das Dokument, bevor JS läuft.
    if python3 "$WERKZEUG" komposition "$TEMPLATE" "$tmp/comp" \
         "$tmp/job/titel.txt" "$tmp/job/saetze.txt" "$tmp/probe.vtt" 20 \
       && grep -q 'data-composition-id="esf"' "$tmp/comp/index.html" \
       && grep -q 'data-duration="20' "$tmp/comp/index.html" \
       && grep -q 'data-width="1920"' "$tmp/comp/index.html" \
       && grep -q '__timelines\["esf"\]' "$tmp/comp/index.html" \
       && grep -qE '<audio[^>]+src="audio\.' "$tmp/comp/index.html" \
       && [ "$(grep -c 'class="cue clip"' "$tmp/comp/index.html")" -eq 5 ] \
       && python3 -c "import re,sys
h=open(sys.argv[1],encoding='utf-8').read()
# HTML-Kommentare RAUS, bevor auf Wanduhr-Aufrufe geprueft wird: der
# Vorlagen-Kommentar NENNT performance.now und requestAnimationFrame, um zu
# erklaeren, warum sie verboten sind. Ein naives grep schlaegt daran an.
sys.exit(1 if re.search(r'performance\.now|requestAnimationFrame',
                        re.sub(r'<!--.*?-->', '', h, flags=re.S)) else 0)" "$tmp/comp/index.html" \
       && ! grep -qE '__[A-Z_]+__' "$tmp/comp/index.html"; then
        ok "Komposition: Root-Attribute, Timeline-Registrierung, Audio-src, 5 Clips, keine Wanduhr, keine offenen Platzhalter"
    else
        nein "Komposition fehlgeschlagen"; fehler=1
    fi

    # (c2) Das Tor vor der MODELL-geschriebenen Komposition (AGENTS.md 8.1).
    #      Ein Tor, das nur den guten Fall kennt, ist keins — deshalb wird hier
    #      der gute Fall UND ein verfälschter geprüft. Die Dauer ist der Fall,
    #      der wirklich weh tut: eine Komposition mit falschem data-duration
    #      rendert anstandslos, nur läuft dann das Bild aus dem Ton.
    python3 - "$tmp/comp" 20 <<'PYST'
import json, sys
json.dump({"dokument": "", "titel": "Probe", "typ": "report",
           "dauer": float(sys.argv[2]), "audio": "audio.vtt", "cues": []},
          open(sys.argv[1] + "/auftrag.json", "w", encoding="utf-8"))
PYST
    if python3 "$WERKZEUG" pruefe "$tmp/comp" "$tmp/comp/auftrag.json" >/dev/null 2>&1; then
        gut=1
    else
        gut=0
    fi
    sed 's/data-duration="20\.0"/data-duration="41.0"/' "$tmp/comp/index.html" > "$tmp/comp/falsch.html"
    mv "$tmp/comp/index.html" "$tmp/comp/echt.html"
    mv "$tmp/comp/falsch.html" "$tmp/comp/index.html"
    if python3 "$WERKZEUG" pruefe "$tmp/comp" "$tmp/comp/auftrag.json" >/dev/null 2>&1; then
        schlecht=1
    else
        schlecht=0
    fi
    mv -f "$tmp/comp/echt.html" "$tmp/comp/index.html"
    if [ "$gut" -eq 1 ] && [ "$schlecht" -eq 0 ]; then
        ok "Kompositions-Tor: gültige Komposition passiert, verfälschte Dauer wird abgewiesen"
    else
        nein "Kompositions-Tor unzuverlässig (gut=$gut, verfälscht-durchgelassen=$schlecht)"; fehler=1
    fi

    # (d) Der Rückfallpfad, ECHT — nur wenn die Werkzeuge da sind
    if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null && [ -x /usr/bin/say ]; then
        if rendere_job "$tmp/probe.html" "$tmp/probe.mp4" "$tmp/probe2.vtt" \
           && [ -s "$tmp/probe.mp4" ]; then
            d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp/probe.mp4")"
            # WELCHER Renderer es war, entscheidet die Auflösung: der
            # ffmpeg-Rückfall zeichnet eine 1280x720-Titelkarte, eine
            # Hyperframes-Komposition ist 1920x1080. Die Zeile darf nicht
            # "Rückfall" behaupten, wenn Hyperframes gerendert hat — vorher
            # tat sie das und war damit falsch.
            aufl="$(ffprobe -v error -select_streams v:0 \
                    -show_entries stream=width,height -of csv=p=0:s=x "$tmp/probe.mp4")"
            case "$aufl" in
                1920x1080) ok "Render real gemessen: probe.mp4, ${d%%.*}s, $aufl (Hyperframes-Komposition)" ;;
                1280x720)  ok "Render real gemessen: probe.mp4, ${d%%.*}s, $aufl (ffmpeg-Rückfall)" ;;
                *)         warn "probe.mp4 gerendert (${d%%.*}s), aber unerwartete Auflösung $aufl" ;;
            esac
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

# ---------------------------------------------------------------------------
# Aufträge: Ton und Auftrag vorbereiten, dann je Dokument eine Designer-Karte
# ---------------------------------------------------------------------------
# Die Reihenfolge ist der ganze Trick. Erst messen, dann gestalten lassen:
# Das Audio entsteht HIER, seine Dauer wird hier gemessen und in auftrag.json
# festgeschrieben. Der esf-video-designer gestaltet danach gegen eine feste
# Zeitachse — er kann sie nicht mehr verschieben, nur bespielen.
if [ "$AUFTRAEGE" -eq 1 ]; then
    command -v hermes >/dev/null || { echo "FEHLER: 'hermes' fehlt"; exit 1; }
    command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
    say_ "Video-Aufträge$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
    k() { hermes kanban --board "$BOARD" "$@"; }
    stimme="$(cad stimme)"; stimme="${stimme:-$STIMME_DEFAULT}"
    offen="$(k list --json 2>/dev/null | jq -r \
        '.[] | select(.assignee=="esf-video-designer")
             | select(.status!="done" and .status!="cancelled") | .title' || true)"
    anzahl=0
    while IFS=$'\t' read -r dok mp4 vtt; do
        [ -n "$dok" ] || continue
        komp="$(komp_dir_von "$dok")"
        rel="${dok#$VAULT/}"
        titel_karte="Video-Komposition — $rel"
        # Schon gestaltet und tragfähig? Dann kein neuer Auftrag.
        if [ -f "$komp/index.html" ] && python3 "$WERKZEUG" pruefe "$komp" "$komp/auftrag.json" >/dev/null 2>&1; then
            echo "  $rel — Komposition liegt und trägt"
            continue
        fi
        if printf '%s\n' "$offen" | grep -qxF "$titel_karte"; then
            echo "  $rel — Karte ist offen"
            continue
        fi
        if [ "$DRY" -eq 1 ]; then
            ok "würde beauftragen: ${komp#$VAULT/}"
            anzahl=$((anzahl + 1)); continue
        fi
        mkdir -p "$komp"
        job="$(mktemp -d "${TMPDIR:-/tmp}/esf-auftrag.XXXXXX")"
        if ! python3 "$WERKZEUG" extrahiere "$dok" "$job"; then
            nein "$rel — kein Sprechertext, kein Auftrag"; rm -rf "$job"; continue
        fi
        if ! dauer="$(tts "$job/skript.txt" "$komp/audio.m4a" "$stimme")"; then
            nein "$rel — Vertonung fehlgeschlagen"; rm -rf "$job"; continue
        fi
        schreibe_auftrag "$komp" "$dok" "$(cat "$job/titel.txt")" "$dauer" "$job/saetze.txt"
        python3 "$WERKZEUG" vtt "$job/saetze.txt" "$dauer" > "$vtt"
        rm -rf "$job"
        # Die Referenz mitgeben: ein bekannt-guter Aufbau, den er übertreffen soll.
        cp -f "$TEMPLATE/index.html" "$komp/referenz-generisch.html" 2>/dev/null || true
        cp -f "$TEMPLATE/hyperframes.json" "$komp/hyperframes.json" 2>/dev/null || true
        k create "$titel_karte" \
            --assignee esf-video-designer \
            --workspace "dir:$komp" \
            --idempotency-key "video-komposition-$(printf '%s' "$rel" | tr -c 'a-zA-Z0-9' '-')" \
            --max-retries 2 --max-runtime 30m \
            --body "Gestalte die Video-Zusammenfassung von $rel.

DEIN ARBEITSVERZEICHNIS ist dieses Kompositionsverzeichnis. Dort liegen:

    auftrag.json              die Bindung: Titel, Typ, GEMESSENE Dauer, Cues
    audio.m4a                 die fertige Vertonung — nicht neu kodieren
    referenz-generisch.html   ein bekannt-guter Aufbau (die generische Vorlage)
    hyperframes.json          die Projektdatei

DEIN ERGEBNIS ist index.html in diesem Verzeichnis.

DAS DOKUMENT, das du vertonst, liegt unter
    $dok
Lies es. Die Form folgt seinem Inhalt: Scores als Rangbalken, eine Modulkarte
als Struktur, ein Schätzintervall als Intervall. Jede Zahl, die du zeigst, steht
schon im Dokument — du visualisierst, du rechnest nicht.

GEBUNDEN bist du an auftrag.json: 'dauer' IST dein root data-duration, auf die
Millisekunde. Die Cues sind die Zeitachse der Sprache; gestalte auf ihren Takt.

FERTIG bist du, wenn beide Tore grün sind — führe sie selbst aus:
    npx --registry https://registry.npmjs.org hyperframes lint .
    python3 $WERKZEUG pruefe . auftrag.json

Der Skill esf-video-komposition nennt die sieben Prüfungen und zwei gemessene
Fallen (keine Opacity-Tweens auf Clips; Clip-Grenzen aus EINER Rundungsreihe).
Rufe deine hyperframes-Skills auf, BEVOR du schreibst.

Wird die Komposition abgewiesen, rendert die ESF die generische Vorlage — dein
Auftrag ist dann nicht erfüllt, aber der Kanal bleibt heil.

metadata: das lint-Ergebnis, deine Gestaltungsentscheidung und was du aus dem
Dokument abgeleitet hast." >/dev/null && ok "beauftragt: $rel"
        anzahl=$((anzahl + 1))
    done < <(python3 "$WERKZEUG" jobs "$VAULT")
    [ "$anzahl" -eq 0 ] && echo "  keine offenen Kompositionen"
    exit 0
fi

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
