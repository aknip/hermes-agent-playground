#!/usr/bin/env bash
#
# ESF — gemeinsame Schaetzungs-Aufloesung
# ======================================
#
# Wird von scripts/ledger-sync.sh und scripts/budget-wache.sh eingebunden:
#
#     . "$HERE/lib-schaetzung.sh"
#
# Der Aufrufer muss vorher BOARD gesetzt und k() definiert haben:
#
#     k() { hermes kanban --board "$BOARD" "$@"; }
#
# WARUM EINE GEMEINSAME DATEI und nicht zwei Kopien: Zwei Pruefungen, die
# dasselbe FAST gleich tun, sind die naechste Fassung des Fehlers, den sie
# verhindern sollen — derselbe Satz steht im Kartentext des
# Palette-Keydown-Guards (19.08.2026), und dort war er richtig. Die
# Aufloesung ueber die Karten-ID ist Bedingung 2a des Roadmap-Gates R2; sie
# darf nicht an zwei Stellen auseinanderlaufen.
#

# ---------------------------------------------------------------------------
# Die Schaetzung beim Schaetzer holen (Bedingung 2a/2b, Roadmap-Gate R2)
# ---------------------------------------------------------------------------
# Eingabe : das Karten-JSON und die Karten-ID
# Ausgabe : das estimate-Objekt auf stdout, oder leer, wenn es gar keinen
#           Schaetzer-Elternteil gibt (dann ist nichts zu holen — S1 hatte den
#           zweiten Elternteil noch nicht, und Spezifikationskarten laufen VOR
#           dem Schaetzer).
# Exit    : 0 = in Ordnung, 1 = es GIBT einen Schaetzer, aber er traegt fuer
#           diese Karte nichts. Das ist der laute Fall aus Bedingung 2b: Ein
#           Aufloesungsweg, der bei fehlendem Anker stumm ein null einsetzt,
#           waere schlimmer als die Kopie, die er ersetzt.
#
# normalisiert() macht aus "S3 F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan"
# und aus dem Schluessel "S3 F1 3/5 Umsetzung" vergleichbare Ketten. Der
# Praefix-Weg ist ausdruecklich der RUECKFALL fuer Altbestaende; er greift nur,
# wenn er EINDEUTIG ist. Zwei passende Schluessel sind ein Abbruch, keine
# Auswahl — raten waere hier genau der stille Fehler, den 2b verbietet.
normalisiert() { printf '%s' "$1" | tr 'A-ZÄÖÜ' 'a-zäöü' | tr -cd 'a-z0-9'; }

schaetzer_aufloesen() { # karten-json karten-id
    local karte="$1" kid="$2"
    local titel eltern e emeta ejson treffer schluessel kandidaten n
    titel="$(printf '%s' "$karte" | jq -r '.task.title // ""')"
    eltern="$(printf '%s' "$karte" | jq -r '.parents[]? // empty')"
    [ -n "$eltern" ] || return 0

    for e in $eltern; do
        ejson="$(k show "$e" --json 2>/dev/null || echo '{}')"
        emeta="$(printf '%s' "$ejson" | jq -c '[.runs[]?.metadata // empty] | last // {}')"
        printf '%s' "$emeta" | jq -e 'has("estimates")' >/dev/null 2>&1 || continue

        # 1. Der saubere Weg: die Karten-ID als Schluessel.
        treffer="$(printf '%s' "$emeta" | jq -c --arg i "$kid" '.estimates[$i] // empty')"
        if [ -n "$treffer" ]; then printf '%s' "$treffer"; return 0; fi

        # 2. Rueckfall: ein Schluessel, dessen normalisierte Form Praefix des
        #    normalisierten Kartentitels ist — und zwar genau einer.
        kandidaten=""
        while IFS= read -r schluessel; do
            [ -n "$schluessel" ] || continue
            case "$(normalisiert "$titel")" in
                "$(normalisiert "$schluessel")"*) kandidaten="$kandidaten$schluessel
" ;;
            esac
        done < <(printf '%s' "$emeta" | jq -r '.estimates | keys[]?')
        n="$(printf '%s' "$kandidaten" | grep -c . || true)"
        if [ "${n:-0}" -eq 1 ]; then
            schluessel="$(printf '%s' "$kandidaten" | head -1)"
            printf '%s' "$emeta" | jq -c --arg s "$schluessel" '.estimates[$s]'
            return 0
        fi
        if [ "${n:-0}" -gt 1 ]; then
            printf 'Mehrdeutig: %s Schluessel des Schaetzers %s passen auf "%s":\n%s' \
                "$n" "$e" "$titel" "$kandidaten"
            return 1
        fi

        # Es GIBT einen Schaetzer, und er kennt diese Karte nicht.
        printf 'Schaetzer %s traegt keine Schaetzung fuer %s ("%s").\nSeine Schluessel:\n%s\n' \
            "$e" "$kid" "$titel" \
            "$(printf '%s' "$emeta" | jq -r '.estimates | keys[]? | "  " + .')"
        return 1
    done
    return 0
}
