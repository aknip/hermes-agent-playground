#!/usr/bin/env bash
#
# ESF — E2E-Läufe als Video aufzeichnen (Playwright)
# ==================================================
#
#   scripts/e2e-video.sh --feature <spec> [<spec> …]   die Journey(s) EINES Features
#   scripts/e2e-video.sh --alle                        die volle Suite
#   scripts/e2e-video.sh --anlass <slug>               benennt die Akte (s.u.)
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
#   reports/e2e-videos/<datum>/<anlass>/   je Test ein .webm (Playwright
#                                          zeichnet je Test), dazu index.html
#                                          und lauf.txt; steht ffmpeg bereit,
#                                          bei --alle zusätzlich EIN
#                                          zusammengefügtes alle-journeys.mp4
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
schreibe_video_config() { # repo -> Pfad auf stdout
    # Zwei local-Zeilen: Bash 3.2 wertet in `local a="$1" b="$a"` das $a der
    # zweiten Zuweisung unter set -u nicht verlässlich aus.
    local repo="$1"
    local cfg="$repo/.esf-video.playwright.config.ts"
    cat > "$cfg" <<'TS'
// erzeugt von scripts/e2e-video.sh — nach dem Lauf wieder entfernt.
// Erbt die Projekt-Config und überstimmt genau drei Dinge:
// Video an, headless erzwungen, eigenes Ergebnisverzeichnis.
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
  use: {
    ...((base as { use?: object }).use ?? {}),
    video: { mode: "on", size: { width: 1280, height: 720 } },
    headless: true,
  },
  outputDir: "./.esf-video-results",
});
TS
    printf '%s' "$cfg"
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
    cfg="$(schreibe_video_config "$tmp")"
    if headless_waechter "$tmp" "" >/dev/null \
       && grep -q 'mode: "on"' "$cfg" && grep -q 'width: 1280, height: 720' "$cfg" \
       && grep -q 'headless: true' "$cfg"; then
        ok "abgeleitete Config: video an in 1280x720, headless erzwungen, vom Wächter ignoriert"
    else nein "abgeleitete Config fehlerhaft"; fehler=1; fi

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

    rm -rf "$tmp"
    exit "$fehler"
fi

if [ "${1:-}" = "--headless-waechter" ]; then
    headless_waechter "${2:?Repo-Pfad fehlt}" "${3:-}"
    exit $?
fi

# ---------------------------------------------------------------------------
# Aufzeichnen
# ---------------------------------------------------------------------------
MODUS=""; DRY=0; ANLASS=""; SPECS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --feature) MODUS=feature ;;
        --alle)    MODUS=alle ;;
        --anlass)  shift; ANLASS="${1:-}" ;;
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

CFG="$(schreibe_video_config "$REPO")"
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
anzahl=0
while IFS= read -r -d '' webm; do
    name="$(basename "$(dirname "$webm")").webm"
    cp "$webm" "$ZIEL/$name"
    anzahl=$((anzahl + 1))
done < <(find "$REPO/.esf-video-results" -name '*.webm' -print0 2>/dev/null)

if [ "$anzahl" -eq 0 ]; then
    nein "kein einziges Video — hat die Repo-Config 'video' hart überstimmt?"
    exit 1
fi
ok "$anzahl Video(s) eingesammelt"

# Index — und, wenn ffmpeg da ist, EIN Gesamtvideo für den Suiten-Lauf.
{
    printf '<!doctype html>\n<html lang="de"><head><meta charset="utf-8"><title>E2E-Videos %s</title></head><body>\n' "$HEUTE"
    printf '<h1>E2E-Videos — %s (%s)</h1>\n<p>Playwright, headless, video=on. Exit des Laufs: %s. Log: <a href="lauf.txt">lauf.txt</a></p>\n' "$HEUTE" "$MODUS" "$rc"
    for v in "$ZIEL"/*.webm; do
        [ -f "$v" ] || continue
        printf '<h2>%s</h2>\n<video controls preload="metadata" width="960" src="%s"></video>\n' \
            "$(basename "$v" .webm)" "$(basename "$v")"
    done
    printf '</body></html>\n'
} > "$ZIEL/index.html"

if [ "$MODUS" = "alle" ] && command -v ffmpeg >/dev/null && [ "$anzahl" -gt 1 ]; then
    liste="$ZIEL/.concat.txt"
    : > "$liste"
    for v in "$ZIEL"/*.webm; do printf "file '%s'\n" "$v" >> "$liste"; done
    if ffmpeg -y -loglevel error -f concat -safe 0 -i "$liste" \
        -c:v libx264 -pix_fmt yuv420p -r 25 "$ZIEL/alle-journeys.mp4"; then
        ok "Gesamtvideo: alle-journeys.mp4"
    else
        warn "Zusammenfügen scheiterte — die Einzelvideos stehen trotzdem"
    fi
    rm -f "$liste"
fi

[ "$rc" -eq 0 ] && ok "Lauf grün — Akte: ${ZIEL#$VAULT/}" \
                || { nein "Lauf ROT (Exit $rc) — die Videos zeigen, wo. Akte: ${ZIEL#$VAULT/}"; exit "$rc"; }
