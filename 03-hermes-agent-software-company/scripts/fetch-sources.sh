#!/usr/bin/env bash
#
# ESF — Markt-Quellen holen und normalisieren
# ===========================================
#
#   scripts/fetch-sources.sh [<zielverzeichnis>] [--seed]
#
# Holt jede Zeile aus seed/quellen.txt per curl und legt sie NORMALISIERT unter
# company/sources/<datum>/ ab. Von tick.sh aufgerufen, aber auch einzeln
# brauchbar — etwa um den Startkorpus für Phase 1 zu erzeugen (--seed schreibt
# nach seed/ statt in die Arbeitskopie).
#
# Warum normalisieren und nicht roh ablegen:
#
#   Ein GitHub-Releases-Endpunkt liefert 2 MB JSON, eine Changelog-Seite 1,7 MB
#   HTML mit Skripten und Styles. Ein Modell kann damit nichts anfangen — es
#   liest die ersten Kilobyte und hält sie für das Ganze. Das ist schlimmer als
#   keine Quelle, weil es aussieht wie eine Auswertung.
#
#   Normalisiert wird deshalb VOR dem Ablegen, und zwar deterministisch: Ein
#   Skript kürzt nachvollziehbar, ein Modell würde interpretieren. Was
#   weggelassen wurde, steht als Zeile in der Datei.
#
# Eine Quelle, die nicht antwortet, hinterlässt eine <name>.fehler-Datei.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
QUELLEN="$ESF/seed/quellen.txt"
HEUTE="$(date '+%Y-%m-%d')"

SEED=0
ZIEL=""
for arg in "$@"; do
    case "$arg" in
        --seed) SEED=1 ;;
        *)      ZIEL="$arg" ;;
    esac
done
if [ -z "$ZIEL" ]; then
    if [ "$SEED" -eq 1 ]; then ZIEL="$ESF/seed/company/sources/$HEUTE"
    else ZIEL="$ESF/workspace/company/sources/$HEUTE"; fi
fi

[ -f "$QUELLEN" ] || { echo "FEHLER: $QUELLEN fehlt."; exit 1; }
command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
mkdir -p "$ZIEL"

# Wie viele Releases je Projekt und wie viel Text je Release überleben.
# Bewusst knapp: Der Scout soll erkennen, was sich geändert hat, nicht ein
# Changelog auswendig lernen.
MAX_RELEASES=12
MAX_TEXT=1200

normalisiere_releases() { # <rohdatei> <zieldatei> <projekt>
    local roh="$1" ziel="$2" projekt="$3"
    local anzahl
    anzahl="$(jq 'if type=="array" then length else 0 end' "$roh" 2>/dev/null || echo 0)"
    if [ "$anzahl" -eq 0 ]; then
        printf '# %s\n\nDie API lieferte kein Release-Array (leer oder Fehlerobjekt).\nRohantwort (gekürzt):\n\n%s\n' \
            "$projekt" "$(head -c 500 "$roh")" > "$ziel"
        return
    fi
    {
        printf '# %s — Releases\n\n' "$projekt"
        printf 'Quelle: GitHub Releases API. %s Releases geliefert, die neuesten %s stehen unten.\n' \
            "$anzahl" "$MAX_RELEASES"
        printf 'Je Release sind die ersten %s Zeichen der Beschreibung übernommen; längere sind mit […] markiert.\n\n' \
            "$MAX_TEXT"
        jq -r --argjson n "$MAX_RELEASES" --argjson t "$MAX_TEXT" '
            .[0:$n][] |
            "## \(.tag_name // .name // "ohne Tag")\n" +
            "Veröffentlicht: \(.published_at // "unbekannt")\n" +
            "Titel: \(.name // "—")\n\n" +
            ((.body // "(keine Beschreibung)")
             | if (length > $t) then (.[0:$t] + "\n\n[…]") else . end) +
            "\n"' "$roh"
    } > "$ziel"
}

normalisiere_html() { # <rohdatei> <zieldatei> <titel>
    local roh="$1" ziel="$2" titel="$3"
    {
        printf '# %s\n\n' "$titel"
        printf 'Quelle: HTML-Seite, auf sichtbaren Text reduziert (Skripte, Styles und\n'
        printf 'Auszeichnung entfernt). Roh waren es %s Byte.\n\n' "$(wc -c < "$roh" | tr -d ' ')"
        # Skripte und Styles ganz raus, dann Tags entfernen, dann Leerzeilen falten.
        python3 - "$roh" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
text = re.sub(r"(?is)<(script|style|noscript|svg)\b.*?</\1>", " ", text)
text = re.sub(r"(?is)<!--.*?-->", " ", text)
text = re.sub(r"(?i)<(br|/p|/div|/li|/h[1-6])\s*/?>", "\n", text)
text = re.sub(r"<[^>]+>", " ", text)
for roh, ersatz in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"),
                    ("&gt;", ">"), ("&quot;", '"'), ("&#39;", "'")):
    text = text.replace(roh, ersatz)
zeilen = [z.strip() for z in text.splitlines()]
zeilen = [z for z in zeilen if len(z) > 2]
# Aufeinanderfolgende Dubletten sind Navigationsrauschen.
sauber, vorher = [], None
for z in zeilen:
    if z != vorher:
        sauber.append(z)
    vorher = z
ganz = "\n".join(sauber)
GRENZE = 60_000
if len(ganz) > GRENZE:
    ganz = ganz[:GRENZE] + f"\n\n[… nach {GRENZE} Zeichen abgeschnitten]"
print(ganz)
PY
    } > "$ziel"
}

printf '\nQuellen -> %s\n\n' "$ZIEL"
geholt=0; fehlgeschlagen=0
ROH="$(mktemp -d)"
trap 'rm -rf "$ROH"' EXIT

while IFS='|' read -r name url; do
    case "$name" in ''|'#'*) continue ;; esac
    name="$(printf '%s' "$name" | tr -d ' ')"
    url="$(printf '%s' "$url" | tr -d ' ')"
    [ -n "$url" ] || continue

    if ! curl -fsSL --max-time 30 -H 'User-Agent: esf-market-scout' "$url" -o "$ROH/$name" 2>/dev/null; then
        printf 'FEHLGESCHLAGEN %s\nURL: %s\nZeit: %s\n\nDiese Quelle hat heute nicht geantwortet. Sie fehlt im Tagesbild,\nund das ist hier vermerkt statt verschwiegen.\n' \
            "$name" "$url" "$(date '+%Y-%m-%d %H:%M:%S')" > "$ZIEL/${name%.*}.fehler"
        printf '  ✗ %-26s nicht erreichbar\n' "$name"
        fehlgeschlagen=$((fehlgeschlagen + 1))
        continue
    fi

    projekt="$(printf '%s' "$name" | sed 's/-releases\.json$//; s/\.html$//; s/-/ /g')"
    case "$name" in
        *-releases.json) ziel="$ZIEL/${name%.json}.md"; normalisiere_releases "$ROH/$name" "$ziel" "$projekt" ;;
        *.html)          ziel="$ZIEL/${name%.html}.md"; normalisiere_html     "$ROH/$name" "$ziel" "$projekt" ;;
        *)               ziel="$ZIEL/$name";            cp "$ROH/$name" "$ziel" ;;
    esac

    roh_kb=$(( $(wc -c < "$ROH/$name") / 1024 ))
    neu_kb=$(( $(wc -c < "$ziel") / 1024 ))
    printf '  ✓ %-26s %5s KB -> %4s KB\n' "$(basename "$ziel")" "$roh_kb" "$neu_kb"
    geholt=$((geholt + 1))
done < "$QUELLEN"

printf '\n%s geholt, %s fehlgeschlagen — %s\n' "$geholt" "$fehlgeschlagen" "$(du -sh "$ZIEL" | cut -f1)"
