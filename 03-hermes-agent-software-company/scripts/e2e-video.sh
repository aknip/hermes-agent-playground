#!/usr/bin/env bash
#
# ESF — E2E-Läufe als Video aufzeichnen (Playwright)
# ==================================================
#
#   scripts/e2e-video.sh --feature <spec> [<spec> …]   die Journey(s) EINES Features
#   scripts/e2e-video.sh --alle                        die volle Suite
#   scripts/e2e-video.sh --anlass <slug>               benennt die Akte (s.u.)
#   scripts/e2e-video.sh --slowmo <ms>                 ueberstimmt cadence.yaml
#   scripts/e2e-video.sh --nachziehen [<pfad>]         bestehende Akten auf .mp4 ziehen
#   scripts/e2e-video.sh --selbsttest                  offline: Config-Erzeugung + Headless-Wächter
#   scripts/e2e-video.sh --headless-waechter <repo> "<befehl>"   nur der Wächter
#   scripts/e2e-video.sh --dry-run …                   nur zeigen
#
# AUFGEZEICHNET WIRD NACH JEDEM GRÜNEN E2E-LAUF — nicht erst nach einem Merge.
# Jede Stelle, die die Suite laufen lässt, ruft dieses Skript unmittelbar nach
# ihrem grünen Lauf: der Merge-Riegel (vor dem Merge, direkt nach Prüfung 6/6),
# der tägliche Tick, der Onboarding- und der Release-Nachweis. Ein Merge ist
# damit kein Tor mehr vor der Akte, sondern nur noch einer von vier Anlässen.
#
#   reports/e2e-videos/<datum>/<anlass>/   je Test ein .mp4, dazu index.html
#                                          und lauf.txt; bei --alle zusätzlich
#                                          EIN zusammengefügtes alle-journeys.mp4
#
# ZWEI DINGE, DIE EIN VIDEO ERST BRAUCHBAR MACHEN — beide am 19.08.2026
# nachgerüstet, weil die Akten bis dahin nicht nachvollziehbar waren:
#
#   · .mp4 STATT .webm. Playwright kann nur .webm (VP8), und .webm spielt
#     ausserhalb eines Browsers oft gar nicht — nicht in QuickTime, nicht in
#     der macOS-Vorschau, nicht in vielen Editoren. Jedes Einzelvideo wird
#     deshalb nach dem Einsammeln nach H.264/.mp4 umgesetzt; das .webm ist
#     Zwischenprodukt und wird entfernt, sobald die .mp4 steht.
#   · LANGSAMER. `videos.e2e_video_slowmo_ms` legt eine Verzoegerung vor JEDE
#     Playwright-Aktion (launchOptions.slowMo). Ohne sie laeuft die Suite in
#     Maschinen-Geschwindigkeit — 14 Journeys in 1,3 Minuten — und das Video
#     zeigt Spruenge statt Bedienung. Weil slowMo die Tests laenger macht,
#     hebt die abgeleitete Config auch das Test-Zeitlimit an; SIE GILT NUR
#     FUER DEN AUFZEICHNUNGSLAUF. Der Lauf, der ueber den Merge entscheidet,
#     ist ein anderer und bleibt unberuehrt schnell.
#
# `--nachziehen` holt bestehende Akten nach: .webm -> .mp4, gedehnt um
# `videos.e2e_video_tempo`. Dehnen ist NICHT dasselbe wie langsam aufnehmen —
# eine gedehnte Aufnahme zeigt nicht mehr die Zeit, die der Lauf gebraucht hat.
# Der Index einer nachgezogenen Akte weist das aus.
#
# Der <anlass> ist der Grund des Laufs — `tick`, `onboarding`, `release`,
# `riegel-feat-…`, `feature-<spec>`. Er MUSS je Lauf verschieden sein: An einem
# Tag laufen Tick, Riegel und Release-Nachweis grün, und ohne eigenen Ordner
# überschriebe die letzte Akte die drei davor.
#
# Der Pfad reports/e2e-… ist im Vault-Linter und im Vault-.gitignore bereits
# als Akte ausgenommen — Videos sind Ergebnisse, keine Quellen.
#
# HEADLESS IST PFLICHT, dreifach durchgesetzt:
#   · dieses Skript erzeugt eine abgeleitete Playwright-Config mit
#     use.headless=true und video='on' — was in der Repo-Config steht, wird
#     überstimmt;
#   · vorher prüft der Wächter, ob Repo-Config oder e2e_befehl `--headed`
#     oder `headless: false` tragen — dann bricht er ROT ab, denn eine solche
#     Konfiguration hielte jeden Cron- und Riegel-Lauf auf einem Bildschirm
#     fest, den es dort nicht gibt;
#   · merge-riegel.sh und tick.sh führen denselben Wächter vor ihren eigenen
#     E2E-Läufen aus (--headless-waechter).
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
VAULT="$ESF/workspace/company"

say_() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" 2>/dev/null \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

# Der Anlass wird ein Verzeichnisname, und Anlässe tragen Zeichen, die keiner
# sein dürfen: Branch-Namen enthalten '/' (cadence branch_praefix: feat/), und
# ein '/' im Anlass legte die Akte eine Ebene tiefer als der Index sie sucht.
# Dieselbe Ersetzung benutzt video-render.sh für seine Idempotenz-Schlüssel.
slug() {
    local s
    s="$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-' | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
    printf '%s' "${s:-lauf}"
}

# Jeder grüne Lauf bekommt SEINE Akte — auch der zweite mit demselben Anlass.
# Zwei Fälle gäbe es sonst: ein Nachweis, der nach einem Befund erneut läuft,
# und zwei Anlässe, die nach dem Slug zufällig gleich heissen (Branch
# 'feat/x-feature' gegen das Feature-Video von 'feat/x'). Beide überschrieben
# stillschweigend die ältere Aufzeichnung; still ist hier das Problem.
eindeutig() { # basispfad -> freier Pfad auf stdout
    local basis="$1" n=2
    [ -e "$basis" ] || { printf '%s' "$basis"; return; }
    while [ -e "$basis-$n" ]; do n=$((n + 1)); done
    printf '%s' "$basis-$n"
}

# ---------------------------------------------------------------------------
# Der Headless-Wächter. Exit 0 = sauber, 1 = Verstoss (Befund auf stdout).
# ---------------------------------------------------------------------------
headless_waechter() { # repo befehl
    local repo="$1"
    local befehl="${2:-}" befund=0
    if printf '%s' "$befehl" | grep -qE -- '--headed'; then
        echo "HEADLESS-VERSTOSS: e2e_befehl enthält --headed: $befehl"
        befund=1
    fi
    local cfg
    for cfg in "$repo"/playwright.config.* "$repo"/playwright*.config.*; do
        [ -f "$cfg" ] || continue
        case "$cfg" in *.esf-video*) continue ;; esac
        if grep -nE 'headless[[:space:]]*:[[:space:]]*false' "$cfg" /dev/null; then
            echo "HEADLESS-VERSTOSS: $(basename "$cfg") setzt headless: false"
            befund=1
        fi
    done
    return "$befund"
}

# Die abgeleitete Config: erbt ALLES aus der Repo-Config und überstimmt genau
# drei Dinge. Sie wird zur Laufzeit ins Repo geschrieben (Playwright löst
# relative Pfade gegen die Config-Datei auf) und danach entfernt.
schreibe_video_config() { # repo [slowmo_ms] -> Pfad auf stdout
    # Zwei local-Zeilen: Bash 3.2 wertet in `local a="$1" b="$a"` das $a der
    # zweiten Zuweisung unter set -u nicht verlässlich aus.
    local repo="$1"
    local slowmo="${2:-0}"
    local cfg="$repo/.esf-video.playwright.config.ts"
    # Das Zeitlimit MUSS mit slowMo mitwachsen. Playwrights Vorgabe sind 30 s
    # je Test; eine Journey mit 40 Aktionen kostet bei 350 ms allein 14 s
    # zusätzlich, und ein Test, der in sein Limit läuft, liefert ein
    # abgeschnittenes Video statt eines langsamen. 5 Minuten je Test sind für
    # einen Aufzeichnungslauf grosszügig und kosten nichts, solange sie nicht
    # erreicht werden.
    cat > "$cfg" <<TS
// erzeugt von scripts/e2e-video.sh — nach dem Lauf wieder entfernt.
// Erbt die Projekt-Config und überstimmt genau fünf Dinge:
// Video an, headless erzwungen, eigenes Ergebnisverzeichnis, slowMo, Zeitlimit.
//
// Die Größe steht ausdrücklich dabei: Playwright zeichnet sonst in seiner
// Vorgabe 800x450 auf und skaliert den 1280x720-Viewport von Desktop Chrome
// herunter — real gemessen am 18.08.2026. Für ein Regressionsvideo reicht das,
// für ein lesbares Nutzerhandbuch nicht. 1280x720 ist der Viewport selbst,
// also 1:1 statt heruntergerechnet.
import base from "./playwright.config";
import { defineConfig } from "@playwright/test";

export default defineConfig({
  ...(base as object),
  timeout: 300000,
  use: {
    ...((base as { use?: object }).use ?? {}),
    video: { mode: "on", size: { width: 1280, height: 720 } },
    headless: true,
    launchOptions: {
      ...((base as { use?: { launchOptions?: object } }).use?.launchOptions ?? {}),
      slowMo: $slowmo,
    },
  },
  outputDir: "./.esf-video-results",
});
TS
    printf '%s' "$cfg"
}

# ---------------------------------------------------------------------------
# .webm -> .mp4. Playwright kann nur .webm; ausserhalb eines Browsers spielt
# das oft nicht. Optional gedehnt (setpts) — nur fuer `--nachziehen`.
# Exit 0 = die .mp4 steht, Exit 1 = sie steht nicht (Quelle bleibt liegen).
# ---------------------------------------------------------------------------
# WARUM ueberall -nostdin: ffmpeg liest ohne dieses Flag von stdin. Steht der
# Aufruf in einer `while read`-Schleife, die ihre Zeilen aus einem Prozess
# bezieht, frisst ffmpeg den Rest dieser Liste — die Schleife bricht dann still
# ab. Real am 19.08.2026: `--nachziehen` bearbeitete 8 von 18 Akten und meldete
# dabei Exit 0. Nichts war rot; es fehlte nur die Haelfte.
nach_mp4() { # quelle.webm ziel.mp4 [tempo]
    local quelle="$1" ziel="$2" tempo="${3:-1}"
    command -v ffmpeg >/dev/null || return 1
    if [ "$tempo" = "1" ] || [ -z "$tempo" ]; then
        ffmpeg -nostdin -y -loglevel error -i "$quelle" -an \
            -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -r 25 "$ziel" || return 1
    else
        # setpts dehnt die Zeitstempel; -r 25 rechnet danach auf konstante
        # 25 fps zurueck, sonst haetten Spieler mit der variablen Bildrate zu
        # kaempfen. -an, weil Playwright ohne Ton aufzeichnet.
        ffmpeg -nostdin -y -loglevel error -i "$quelle" -an -filter:v "setpts=$tempo*PTS" \
            -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -r 25 "$ziel" || return 1
    fi
    [ -s "$ziel" ] || return 1
}

# ---------------------------------------------------------------------------
# Selbsttest — offline
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--selbsttest" ]; then
    say_ "e2e-video Selbsttest (offline)"
    fehler=0
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/esf-e2e-test.XXXXXX")"

    # (a) saubere Lage passiert den Wächter
    printf 'export default { use: { baseURL: "http://x" } }\n' > "$tmp/playwright.config.ts"
    if headless_waechter "$tmp" "pnpm exec playwright test" >/dev/null; then
        ok "Wächter: saubere Config passiert"
    else nein "Wächter meldet fälschlich"; fehler=1; fi

    # (b) headless: false wird gefangen
    printf 'export default { use: { headless: false } }\n' > "$tmp/playwright.config.ts"
    if headless_waechter "$tmp" "pnpm exec playwright test" >/dev/null; then
        nein "Wächter übersieht headless: false"; fehler=1
    else ok "Wächter fängt headless: false"; fi

    # (c) --headed im Befehl wird gefangen
    printf 'export default {}\n' > "$tmp/playwright.config.ts"
    if headless_waechter "$tmp" "pnpm exec playwright test --headed" >/dev/null; then
        nein "Wächter übersieht --headed"; fehler=1
    else ok "Wächter fängt --headed"; fi

    # (d) die eigene abgeleitete Config wird NICHT als Verstoss gelesen
    cfg="$(schreibe_video_config "$tmp" 350)"
    if headless_waechter "$tmp" "" >/dev/null \
       && grep -q 'mode: "on"' "$cfg" && grep -q 'width: 1280, height: 720' "$cfg" \
       && grep -q 'headless: true' "$cfg" \
       && grep -q 'slowMo: 350' "$cfg" && grep -q 'timeout: 300000' "$cfg"; then
        ok "abgeleitete Config: video an in 1280x720, headless, slowMo 350 ms, Zeitlimit 300 s"
    else nein "abgeleitete Config fehlerhaft"; fehler=1; fi

    # (d2) ohne Parameter bleibt slowMo 0 — der Aufrufer entscheidet, nicht die
    #      Vorgabe. Sonst verlangsamte eine vergessene Zeile jeden Lauf.
    if grep -q 'slowMo: 0' "$(schreibe_video_config "$tmp")"; then
        ok "ohne Parameter: slowMo 0"
    else nein "Vorgabe von slowMo ist nicht 0"; fehler=1; fi

    # (f) zwei Läufe mit demselben Anlass überschreiben einander nicht
    mkdir -p "$tmp/2026-08-18/tick"
    e1="$(eindeutig "$tmp/2026-08-18/tick")"
    mkdir -p "$e1"
    e2="$(eindeutig "$tmp/2026-08-18/tick")"
    if [ "$e1" = "$tmp/2026-08-18/tick-2" ] && [ "$e2" = "$tmp/2026-08-18/tick-3" ]; then
        ok "zweiter Lauf gleichen Anlasses bekommt eine eigene Akte (tick-2, tick-3)"
    else nein "Akten überschreiben einander: '$e1' / '$e2'"; fehler=1; fi

    # (e) der Anlass wird ein tragfähiger Verzeichnisname — hier zählt der
    #     Branch-Fall, denn 'feat/xy' legte die Akte sonst eine Ebene tiefer.
    if [ "$(slug 'riegel-feat/kanban-spalten')" = "riegel-feat-kanban-spalten" ] \
       && [ "$(slug '///')" = "lauf" ] && [ "$(slug 'tick')" = "tick" ]; then
        ok "Anlass-Slug: '/' ersetzt, Leerfall aufgefangen"
    else nein "Anlass-Slug unbrauchbar: $(slug 'riegel-feat/kanban-spalten')"; fehler=1; fi

    # (g) nach_mp4 setzt wirklich um — und die Dehnung dehnt wirklich.
    #     Offline, ohne Repo und ohne Playwright: ffmpeg erzeugt sich seine
    #     Quelle selbst. Ohne diesen Fall waere die einzige Pruefung der
    #     Umsetzung ein echter E2E-Lauf, und der ist kein Selbsttest.
    if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
        ffmpeg -nostdin -y -loglevel error -f lavfi -i testsrc=duration=2:size=320x180:rate=25 \
            -c:v libvpx -b:v 200k "$tmp/probe.webm" 2>/dev/null
        # In MILLISEKUNDEN vergleichen, nicht in abgeschnittenen Sekunden:
        # 2,00 s mit Faktor 2 ergeben 3,96 s (der letzte Frame traegt seine
        # eigene Dauer), und `cut -d. -f1` machte daraus eine 3. Der erste
        # Anlauf dieses Falls ist genau daran gescheitert — am Test, nicht am
        # Code. Toleranz deshalb 1,9x statt 2,0x.
        ms() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null \
               | awk '{printf "%d", $1 * 1000}'; }
        d_quelle="$(ms "$tmp/probe.webm")"
        if nach_mp4 "$tmp/probe.webm" "$tmp/glatt.mp4" && nach_mp4 "$tmp/probe.webm" "$tmp/gedehnt.mp4" 2; then
            d_glatt="$(ms "$tmp/glatt.mp4")"
            d_dehn="$(ms "$tmp/gedehnt.mp4")"
            codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$tmp/glatt.mp4")"
            if [ "$codec" = "h264" ] \
               && [ "${d_glatt:-0}" -ge $(( ${d_quelle:-0} * 9 / 10 )) ] \
               && [ "${d_glatt:-0}" -le $(( ${d_quelle:-0} * 11 / 10 )) ] \
               && [ "${d_dehn:-0}" -ge $(( ${d_quelle:-0} * 19 / 10 )) ]; then
                ok "nach_mp4: H.264, ungedehnt ${d_glatt} ms ~ Quelle ${d_quelle} ms, Faktor 2 -> ${d_dehn} ms"
            else
                nein "nach_mp4 falsch: codec=$codec quelle=${d_quelle}ms glatt=${d_glatt}ms gedehnt=${d_dehn}ms"; fehler=1
            fi
        else nein "nach_mp4 scheiterte"; fehler=1; fi
    else
        printf '    (ffmpeg/ffprobe fehlen — Umsetzung nicht geprüft)\n'
    fi

    # (h) Die Schleifen-Wache. nach_mp4 wird in `while read`-Schleifen gerufen,
    #     die ihre Zeilen aus `find` beziehen. Ohne -nostdin frisst ffmpeg diese
    #     Liste und die Schleife bricht nach dem ersten Durchlauf ab — ohne
    #     Fehler, mit Exit 0. Genau so sind am 19.08.2026 10 von 18 Akten
    #     uebersprungen worden. Drei Quellen reichen als Nachweis: ohne das
    #     Flag ueberlebt genau eine.
    if command -v ffmpeg >/dev/null; then
        mkdir -p "$tmp/schleife"
        for i in 1 2 3; do
            ffmpeg -nostdin -y -loglevel error -f lavfi \
                -i "testsrc=duration=1:size=160x90:rate=10" \
                -c:v libvpx -b:v 100k "$tmp/schleife/v$i.webm" 2>/dev/null
        done
        gezaehlt=0
        while IFS= read -r w; do
            nach_mp4 "$w" "${w%.webm}.mp4" && gezaehlt=$((gezaehlt + 1))
        done < <(find "$tmp/schleife" -name '*.webm' | sort)
        if [ "$gezaehlt" -eq 3 ]; then
            ok "Schleifen-Wache: alle 3 Quellen umgesetzt (ffmpeg frisst stdin nicht)"
        else
            nein "Schleifen-Wache: nur $gezaehlt von 3 — fehlt irgendwo -nostdin?"; fehler=1
        fi
    fi

    rm -rf "$tmp"
    exit "$fehler"
fi

# ---------------------------------------------------------------------------
# --nachziehen: bestehende Akten auf .mp4 ziehen
# ---------------------------------------------------------------------------
# Aufzeichnungen, die es schon gibt, lassen sich nicht nachtraeglich langsamer
# AUFNEHMEN — nur langsamer ABSPIELEN. Das ist kein Ersatz und wird deshalb
# nicht stillschweigend gemacht: Jede nachgezogene Akte bekommt einen Index,
# der die Dehnung ausweist, und eine Datei DEHNUNG.txt als Rohbeleg.
if [ "${1:-}" = "--nachziehen" ]; then
    [ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT"; exit 1; }
    command -v ffmpeg >/dev/null || { echo "FEHLER: ffmpeg fehlt (brew install ffmpeg)"; exit 1; }
    TEMPO="$(cad e2e_video_tempo)"; TEMPO="${TEMPO:-2.5}"
    WURZEL="${2:-$VAULT/reports/e2e-videos}"
    [ -d "$WURZEL" ] || { echo "FEHLER: kein Verzeichnis: $WURZEL"; exit 1; }
    say_ "Nachziehen: .webm -> .mp4, gedehnt um Faktor $TEMPO"
    echo "  Wurzel: ${WURZEL#$VAULT/}"

    akten=0; umgesetzt=0; misslungen=0
    while IFS= read -r akte; do
        # Eine Akte ist ein Verzeichnis, in dem mindestens ein .webm liegt.
        ls "$akte"/*.webm >/dev/null 2>&1 || continue
        akten=$((akten + 1))
        printf '\n  %s\n' "${akte#$WURZEL/}"
        for w in "$akte"/*.webm; do
            [ -f "$w" ] || continue
            ziel="${w%.webm}.mp4"
            if nach_mp4 "$w" "$ziel" "$TEMPO"; then
                rm -f "$w"
                umgesetzt=$((umgesetzt + 1))
                printf '    ✓ %s\n' "$(basename "$ziel")"
            else
                misslungen=$((misslungen + 1))
                printf '    ✗ %s — .webm bleibt liegen\n' "$(basename "$w")"
            fi
        done

        # Gesamtvideo neu bauen, wenn die Akte eins hatte oder mehr als eins
        # enthaelt — sonst zeigte es weiter die ungedehnte Fassung.
        einzel="$(ls "$akte"/*.mp4 2>/dev/null | grep -v '/alle-journeys\.mp4$' | wc -l | tr -d ' ')"
        if [ "${einzel:-0}" -gt 1 ]; then
            liste="$akte/.concat.txt"; : > "$liste"
            for v in "$akte"/*.mp4; do
                [ -f "$v" ] || continue
                case "$(basename "$v")" in alle-journeys.mp4) continue ;; esac
                printf "file '%s'\n" "$v" >> "$liste"
            done
            ffmpeg -nostdin -y -loglevel error -f concat -safe 0 -i "$liste" \
                -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -r 25 \
                "$akte/alle-journeys.mp4" >/dev/null 2>&1 \
                && printf '    ✓ alle-journeys.mp4 neu gebaut\n' \
                || printf '    ✗ alle-journeys.mp4 scheiterte\n'
            rm -f "$liste"
        fi

        # Der Rohbeleg der Dehnung — damit niemand die Laufzeit im Video fuer
        # die Laufzeit des Tests haelt.
        {
            printf 'Diese Akte wurde am %s nachgezogen.\n\n' "$(date '+%Y-%m-%d %H:%M')"
            printf '  Quelle:   Playwright .webm (VP8), aufgezeichnet in Maschinen-Geschwindigkeit\n'
            printf '  Umsetzung: ffmpeg -filter:v "setpts=%s*PTS" -c:v libx264 -r 25\n\n' "$TEMPO"
            printf 'WAS DAS HEISST: Die Videos laufen um den Faktor %s langsamer als der\n' "$TEMPO"
            printf 'Test. Die im Video sichtbare Dauer ist NICHT die Dauer des Laufs.\n'
            printf 'Wer echte Zeiten braucht, nimmt lauf.txt.\n\n'
            printf 'Neue Akten brauchen das nicht: Sie werden mit launchOptions.slowMo\n'
            printf 'aufgezeichnet und zeigen ihre echte Dauer.\n'
        } > "$akte/DEHNUNG.txt"

        # Index neu, mit dem Hinweis
        {
            printf '<!doctype html>\n<html lang="de"><head><meta charset="utf-8"><title>E2E-Videos (nachgezogen)</title></head><body>\n'
            printf '<h1>E2E-Videos — %s</h1>\n' "$(basename "$akte")"
            printf '<p style="background:#fff8dc;border-left:4px solid #e0c000;padding:.6rem .9rem">\n'
            printf '<strong>Nachgezogen, nicht neu aufgezeichnet.</strong> Diese Akte stammt aus einem Lauf\n'
            printf 'ohne Verzoegerung; die Videos sind nachtraeglich um den Faktor %s gedehnt (ffmpeg setpts).\n' "$TEMPO"
            printf 'Die sichtbare Dauer ist deshalb <em>nicht</em> die Dauer des Laufs — dafuer\n'
            printf '<a href="lauf.txt">lauf.txt</a>. Beleg: <a href="DEHNUNG.txt">DEHNUNG.txt</a>.</p>\n'
            for v in "$akte"/*.mp4 "$akte"/*.webm; do
                [ -f "$v" ] || continue
                case "$(basename "$v")" in alle-journeys.mp4) continue ;; esac
                printf '<h2>%s</h2>\n<video controls preload="metadata" width="960" src="%s"></video>\n' \
                    "$(basename "$v" | sed -e 's/\.mp4$//' -e 's/\.webm$//')" "$(basename "$v")"
            done
            if [ -f "$akte/alle-journeys.mp4" ]; then
                printf '<h2>alle Journeys am Stueck</h2>\n<video controls preload="metadata" width="960" src="alle-journeys.mp4"></video>\n'
            fi
            printf '</body></html>\n'
        } > "$akte/index.html"
    done < <(find "$WURZEL" -type d | sort)

    printf '\n'
    ok "$akten Akte(n), $umgesetzt Video(s) nach .mp4 gedehnt"
    [ "$misslungen" -gt 0 ] && { nein "$misslungen misslungen"; exit 1; }
    exit 0
fi

if [ "${1:-}" = "--headless-waechter" ]; then
    headless_waechter "${2:?Repo-Pfad fehlt}" "${3:-}"
    exit $?
fi

# ---------------------------------------------------------------------------
# Aufzeichnen
# ---------------------------------------------------------------------------
MODUS=""; DRY=0; ANLASS=""; SLOWMO_CLI=""; SPECS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --feature) MODUS=feature ;;
        --alle)    MODUS=alle ;;
        --anlass)  shift; ANLASS="${1:-}" ;;
        --slowmo)  shift; SLOWMO_CLI="${1:-}" ;;
        --dry-run) DRY=1 ;;
        -*)        echo "Unbekannte Option '$1'"; exit 2 ;;
        *)         SPECS+=("$1") ;;
    esac
    shift
done
[ -n "$MODUS" ] || { echo "Aufruf: e2e-video.sh --feature <spec>… | --alle [--anlass <slug>] | --selbsttest"; exit 2; }
[ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT — erst ./setup.sh"; exit 1; }

schalter="$(cad e2e_aufzeichnung)"
if [ "${schalter:-an}" = "aus" ]; then
    echo "videos.e2e_aufzeichnung: aus — nichts zu tun"; exit 0
fi

REPO="$(cad repo)"
E2E_VORBED="$(cad e2e_vorbedingung)"
# --slowmo schlaegt cadence.yaml. Der Wert ist eine Messgroesse, keine
# Glaubensfrage: Wie langsam ein Video laufen MUSS, damit man es nachvollziehen
# kann, findet man durch Messen. Der Schalter ist da, damit das ohne Bearbeiten
# der cadence.yaml geht — was gemessen gut war, wandert danach dorthin.
SLOWMO="${SLOWMO_CLI:-$(cad e2e_video_slowmo_ms)}"; SLOWMO="${SLOWMO:-0}"
case "$SLOWMO" in
    ''|*[!0-9]*) warn "videos.e2e_video_slowmo_ms ist keine Zahl ('$SLOWMO') — 0 angenommen"; SLOWMO=0 ;;
esac
[ -d "$REPO" ] || { echo "FEHLER: Produkt-Repo '$REPO' fehlt"; exit 1; }

say_ "Headless-Wächter"
if ! headless_waechter "$REPO" "$(cad e2e_befehl)" | sed 's/^/  /'; then
    nein "Headless-Pflicht verletzt — erst die Konfiguration bereinigen, dann aufzeichnen."
    exit 1
fi
ok "sauber"

HEUTE="$(date +%F)"
if [ "$MODUS" = "feature" ]; then
    [ "${#SPECS[@]}" -gt 0 ] || { echo "FEHLER: --feature braucht mindestens einen Spec."; exit 1; }
    [ -n "$ANLASS" ] || ANLASS="feature-$(basename "${SPECS[0]%%.spec.ts}")"
else
    [ -n "$ANLASS" ] || ANLASS="alle"
fi
ZIEL="$(eindeutig "$VAULT/reports/e2e-videos/$HEUTE/$(slug "$ANLASS")")"

if [ "$DRY" -eq 1 ]; then
    ok "würde aufzeichnen nach ${ZIEL#$VAULT/} (Playwright video=on, headless erzwungen)"
    exit 0
fi

command -v pnpm >/dev/null || { echo "FEHLER: 'pnpm' fehlt"; exit 1; }
say_ "Aufzeichnen: $MODUS → ${ZIEL#$VAULT/}"
[ -n "$E2E_VORBED" ] && { ( cd "$REPO" && eval "$E2E_VORBED" ) >/dev/null 2>&1 || true; }

CFG="$(schreibe_video_config "$REPO" "$SLOWMO")"
[ "$SLOWMO" -gt 0 ] && ok "$SLOWMO ms Verzoegerung vor jeder Aktion (nur dieser Lauf)" \
                    || warn "ohne Verzoegerung — das Video laeuft in Maschinen-Geschwindigkeit"
aufraeumen() { rm -f "$CFG"; rm -rf "$REPO/.esf-video-results"; }
trap aufraeumen EXIT

set +e
( cd "$REPO" && pnpm exec playwright test --config "$(basename "$CFG")" \
    ${SPECS[@]+"${SPECS[@]}"} ) > /tmp/esf-e2e-video.$$ 2>&1
rc=$?
set -e
grep -E '[0-9]+ (passed|failed|skipped)' /tmp/esf-e2e-video.$$ | tail -2 | sed 's/^/  /' || true

mkdir -p "$ZIEL"
cp /tmp/esf-e2e-video.$$ "$ZIEL/lauf.txt"; rm -f /tmp/esf-e2e-video.$$

# Playwright legt je Test ein Verzeichnis mit video.webm an. Einsammeln und
# nach dem Testverzeichnis benennen — der Name IST die Zuordnung.
anzahl=0; roh=0
while IFS= read -r -d '' webm; do
    name="$(basename "$(dirname "$webm")")"
    if nach_mp4 "$webm" "$ZIEL/$name.mp4"; then
        anzahl=$((anzahl + 1))
    else
        # Ohne ffmpeg (oder wenn es scheitert) ist ein .webm besser als nichts.
        # Es bleibt dann liegen und der Index verlinkt es — sichtbar als
        # Ausnahme, nicht stillschweigend.
        cp "$webm" "$ZIEL/$name.webm"
        roh=$((roh + 1))
    fi
done < <(find "$REPO/.esf-video-results" -name '*.webm' -print0 2>/dev/null)

if [ $((anzahl + roh)) -eq 0 ]; then
    nein "kein einziges Video — hat die Repo-Config 'video' hart überstimmt?"
    exit 1
fi
ok "$anzahl Video(s) als .mp4 eingesammelt$( [ "$roh" -gt 0 ] && printf ', %s als .webm (ffmpeg fehlt oder scheiterte)' "$roh")"
[ "$roh" -gt 0 ] && warn "$roh Video(s) blieben .webm — ausserhalb eines Browsers oft nicht abspielbar"

# Index — und, wenn ffmpeg da ist, EIN Gesamtvideo für den Suiten-Lauf.
{
    printf '<!doctype html>\n<html lang="de"><head><meta charset="utf-8"><title>E2E-Videos %s</title></head><body>\n' "$HEUTE"
    printf '<h1>E2E-Videos — %s (%s)</h1>\n' "$HEUTE" "$MODUS"
    printf '<p>Playwright, headless, video=on, 1280x720. Exit des Laufs: %s. Log: <a href="lauf.txt">lauf.txt</a></p>\n' "$rc"
    printf '<p><strong>Aufgezeichnet mit %s ms Verzoegerung vor jeder Aktion</strong> (launchOptions.slowMo, cadence videos.e2e_video_slowmo_ms). Die Videos zeigen damit die echte Dauer DIESES Laufs — sie sind nicht nachtraeglich gedehnt.</p>\n' "$SLOWMO"
    for v in "$ZIEL"/*.mp4 "$ZIEL"/*.webm; do
        [ -f "$v" ] || continue
        case "$(basename "$v")" in alle-journeys.mp4) continue ;; esac
        printf '<h2>%s</h2>\n<video controls preload="metadata" width="960" src="%s"></video>\n' \
            "$(basename "$v" | sed -e 's/\.mp4$//' -e 's/\.webm$//')" "$(basename "$v")"
    done
    printf '</body></html>\n'
} > "$ZIEL/index.html"

if [ "$MODUS" = "alle" ] && command -v ffmpeg >/dev/null && [ "$anzahl" -gt 1 ]; then
    liste="$ZIEL/.concat.txt"
    : > "$liste"
    for v in "$ZIEL"/*.mp4; do
        [ -f "$v" ] || continue
        case "$(basename "$v")" in alle-journeys.mp4) continue ;; esac
        printf "file '%s'\n" "$v" >> "$liste"
    done
    if ffmpeg -nostdin -y -loglevel error -f concat -safe 0 -i "$liste" \
        -c:v libx264 -pix_fmt yuv420p -r 25 "$ZIEL/alle-journeys.mp4"; then
        ok "Gesamtvideo: alle-journeys.mp4"
    else
        warn "Zusammenfügen scheiterte — die Einzelvideos stehen trotzdem"
    fi
    rm -f "$liste"
fi

[ "$rc" -eq 0 ] && ok "Lauf grün — Akte: ${ZIEL#$VAULT/}" \
                || { nein "Lauf ROT (Exit $rc) — die Videos zeigen, wo. Akte: ${ZIEL#$VAULT/}"; exit "$rc"; }
