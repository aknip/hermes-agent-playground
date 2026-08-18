#!/usr/bin/env bash
#
# ESF — Ein OpenRouter-Key je Profil, aus einer Schlüsseldatei
# ============================================================
#
#   scripts/assign-keys.sh [--file <pfad>]   Keys zuordnen und eintragen
#   scripts/assign-keys.sh --pruefen         nur prüfen, ohne Geheimnisse
#   scripts/assign-keys.sh --verbrauch       Verbrauch je Rolle bei OpenRouter
#   scripts/assign-keys.sh --entfernen       Keys aus den Profilen löschen
#
# Der Unterschied zu scripts/provision-keys.sh: dort werden Keys über die
# Provisioning-API ERZEUGT (braucht OPENROUTER_PROVISIONING_KEY), hier werden
# bereits vorhandene ZUGEORDNET. Beide Wege enden am selben Ort — einem
# eigenen OPENROUTER_API_KEY je Profil.
#
# ---------------------------------------------------------------------------
# Warum das überhaupt funktioniert, und woran es hängt
# ---------------------------------------------------------------------------
# Ein Profil ist eine eigene HERMES_HOME. `hermes -p <profil> config set
# OPENROUTER_API_KEY <wert>` landet deshalb nicht in ~/.hermes/.env, sondern in
# ~/.hermes/profiles/<profil>/.env — belegt an
# hermes_cli/config.py:1153 (`_is_env_config_key` schickt jeden Namen auf
# `_API_KEY` in die .env) und config.py:5087 (die .env-Abzweigung in
# `set_config_value`).
#
# Dass diese Datei die exportierte Shell-Variable SCHLÄGT, steht in
# hermes_cli/env_loader.py:496:
#
#     _load_dotenv_with_fallback(user_env, override=True)
#
# `override=True` ist der ganze Mechanismus. Ohne ihn gewönne das
# OPENROUTER_API_KEY aus der Shell, und alle elf Profile führen auf denselben
# Key — sichtbar an nichts.
#
# ⚠ Genau deshalb ist `config get` KEIN Nachweis: es liest dieselbe Datei, die
#   dieses Skript geschrieben hat, und bestätigt nur sich selbst. Der Nachweis
#   ist der Verbrauchszähler bei OpenRouter nach einem echten Lauf — siehe
#   `--verbrauch` und VERIFIKATION.md.
#
# ---------------------------------------------------------------------------
# Was hier NICHT passiert
# ---------------------------------------------------------------------------
# Ein Limit setzen. Gemessen am 17.08.2026: die elf Keys der Schlüsseldatei
# haben `limit: null`, also KEINEN USD-Deckel. Ein Key je Rolle bringt damit
# die Kostenzurechnung, aber nicht die Kostenbremse. Wer den Deckel will,
# setzt ihn bei OpenRouter je Key — über die API geht das nur mit einem
# Provisioning-Key (scripts/provision-keys.sh --limit).
#
# ---------------------------------------------------------------------------
# Format der Schlüsseldatei
# ---------------------------------------------------------------------------
#   <name>
#   sk-or-v1-…
#   <name>
#   sk-or-v1-…
#   …
#
# Leerzeilen egal. Die Namen sind Beschriftung: zugeordnet wird nach
# REIHENFOLGE — der n-te Key geht an das n-te Profil aus PROFILE_NAMES. Diese
# Zuordnung ist in key-zuordnung.txt festgehalten (mit Fingerabdruck statt
# Geheimnis) und damit reproduzierbar.
#
# Standardort ist openrouter-keys.txt im ESF-Verzeichnis. Die Datei wird NIE
# committet: Sie ist doppelt gitignored — im Playground (`*openrouter-keys*.txt`)
# und in der .gitignore dieses Verzeichnisses, damit der Schutz auch eine Kopie
# überlebt. Rechte: chmod 600.
#
# Wem ein Geheimnis im Arbeitsbaum trotzdem zu nah am `git add` liegt, legt es
# nach ~/.hermes/esf-openrouter-keys.txt (wird ebenfalls gefunden, darf ein
# Symlink sein) oder setzt $ESF_OPENROUTER_KEYFILE bzw. --file.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
ZUORDNUNG="$ESF/key-zuordnung.txt"

# Gesucht wird in dieser Reihenfolge; der erste Treffer gewinnt.
#   1. openrouter-keys.txt HIER im ESF-Verzeichnis — der Standardort seit dem
#      17.08.2026. Er hält alles, was die ESF braucht, an einem Ort; die Datei
#      ist doppelt gitignored (hier und im Playground) und mit chmod 600
#      abgelegt.
#   2. ~/.hermes/esf-openrouter-keys.txt — für alle, denen ein Geheimnis im
#      Arbeitsbaum eines Repos zu nah am `git add` liegt. Nachvollziehbar; der
#      Preis ist, dass die ESF dann nicht mehr aus einem Verzeichnis heraus
#      vollständig ist.
STANDARD_ORTE=(
    "$ESF/openrouter-keys.txt"
    "$HOME/.hermes/esf-openrouter-keys.txt"
)
STANDARD_DATEI="${STANDARD_ORTE[0]}"
for ort in "${STANDARD_ORTE[@]}"; do
    if [ -r "$ort" ]; then STANDARD_DATEI="$ort"; break; fi
done

# esf-ceo steht am ENDE: zugeordnet wird nach Reihenfolge, und die elf Keys
# der Phasen 0–2 behalten so ihre Rollen — die Verbrauchszahlen bleiben über
# den Rundlauf vergleichbar. Ein ZWÖLFTER Key (für esf-ceo) ist optional:
# fehlt er, läuft die Führungsrolle auf dem Root-Key, und genau das wird
# gelb gesagt — die Kosten der Führung wären dann nicht zurechenbar, was
# Phase 2 als blinden Fleck benannt hat.
PROFILE_NAMES=(
    esf-chief-of-staff esf-market-scout esf-market-analyst esf-product-manager
    esf-architect esf-estimator esf-dev-a esf-dev-b esf-reviewer
    esf-qa-release esf-controller esf-ceo
)
# Profile, die ohne eigenen Key laufen DÜRFEN (gelb statt rot):
OPTIONAL_OHNE_KEY="esf-ceo"

DATEI="${ESF_OPENROUTER_KEYFILE:-$STANDARD_DATEI}"
AKTION="zuordnen"

while [ $# -gt 0 ]; do
    case "$1" in
        --file)      shift; DATEI="${1:?--file braucht einen Pfad}" ;;
        --pruefen)   AKTION="pruefen" ;;
        --verbrauch) AKTION="verbrauch" ;;
        --entfernen) AKTION="entfernen" ;;
        *) echo "Unbekannte Option '$1'"; exit 2 ;;
    esac
    shift
done

ok()      { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein()    { printf '  \033[31m✗\033[0m %s\n' "$*"; }
say()     { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Fingerabdruck statt Geheimnis: 12 Hex-Zeichen aus sha256. Genug, um zwei
# Keys zu unterscheiden und eine Zuordnung wiederzuerkennen; nichts, woraus
# sich ein Key rekonstruieren liesse.
fingerabdruck() { printf '%s' "$1" | shasum -a 256 | cut -c1-12; }

# ---------------------------------------------------------------------------
# Prüfen — braucht die Schlüsseldatei NICHT
# ---------------------------------------------------------------------------
if [ "$AKTION" = "pruefen" ]; then
    say "Ein Key je Profil — Prüfung"
    fehler=0
    abdruecke=""
    for name in "${PROFILE_NAMES[@]}"; do
        env_datei="$HOME/.hermes/profiles/$name/.env"
        if [ ! -f "$env_datei" ]; then
            case " $OPTIONAL_OHNE_KEY " in
                *" $name "*)
                    printf '  \033[33m⚠\033[0m %s — keine .env (Root-Key); erlaubt, siehe oben\n' "$name"
                    continue ;;
            esac
            nein "$name — keine .env"; fehler=1; continue
        fi
        wert="$(sed -n 's/^OPENROUTER_API_KEY=//p' "$env_datei" | tail -1 | tr -d "\"'")"
        if [ -z "$wert" ]; then
            case " $OPTIONAL_OHNE_KEY " in
                *" $name "*)
                    printf '  \033[33m⚠\033[0m %s — ohne eigenen Key (Root-Key); erlaubt, aber die Kosten der Führung sind dann nicht zurechenbar\n' "$name"
                    continue ;;
            esac
            nein "$name — .env definiert kein OPENROUTER_API_KEY"
            printf '      Dieses Profil fällt auf den Root-Key zurück. Lautlos.\n'
            fehler=1; continue
        fi
        ab="$(fingerabdruck "$wert")"
        abdruecke="$abdruecke$ab
"
        erwartet=""
        [ -f "$ZUORDNUNG" ] && erwartet="$(awk -v p="$name" '$1==p {print $3}' "$ZUORDNUNG")"
        if [ -n "$erwartet" ] && [ "$erwartet" != "$ab" ]; then
            nein "$name — Fingerabdruck $ab, laut key-zuordnung.txt erwartet $erwartet"
            fehler=1
        else
            ok "$(printf '%-22s %s' "$name" "$ab")"
        fi
    done

    verschieden="$(printf '%s' "$abdruecke" | grep -c . || true)"
    eindeutig="$(printf '%s' "$abdruecke" | sort -u | grep -c . || true)"
    echo
    if [ "$verschieden" -eq 0 ]; then
        nein "kein einziges Profil hat einen eigenen Key"
        fehler=1
    elif [ "$verschieden" -ne "$eindeutig" ]; then
        nein "$verschieden Keys, davon nur $eindeutig verschiedene — Rollen teilen sich Keys"
        printf '      Eine Kostenzurechnung je Rolle ist damit nicht möglich.\n'
        fehler=1
    else
        ok "$eindeutig Profile, $eindeutig verschiedene Keys"
    fi
    exit "$fehler"
fi

# ---------------------------------------------------------------------------
# Entfernen — braucht die Schlüsseldatei ebenfalls nicht
# ---------------------------------------------------------------------------
if [ "$AKTION" = "entfernen" ]; then
    say "Keys aus den Profilen entfernen"
    for name in "${PROFILE_NAMES[@]}"; do
        [ -d "$HOME/.hermes/profiles/$name" ] || continue
        hermes -p "$name" config unset OPENROUTER_API_KEY >/dev/null 2>&1 || true
        echo "  $name"
    done
    printf '\nDie Profile laufen jetzt wieder auf dem Root-Key.\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Ab hier wird die Schlüsseldatei gebraucht
# ---------------------------------------------------------------------------
if [ ! -r "$DATEI" ]; then
    cat >&2 <<EOF

  Keine Schlüsseldatei unter: $DATEI

  Ohne sie läuft die ganze Flotte auf dem einen Root-Key aus
  ~/.hermes/.env — das funktioniert, aber:

    · keine Kostenzurechnung je Rolle (das Ledger schreibt cost_usd: null)
    · ein Zwischenfall bei einer Rolle trifft alle elf

  Abhilfe, eins von dreien:
    export ESF_OPENROUTER_KEYFILE=/pfad/zur/datei
    ln -s /pfad/zur/datei $STANDARD_DATEI
    scripts/assign-keys.sh --file /pfad/zur/datei

EOF
    exit 1
fi

# Rechte prüfen, aber nicht stillschweigend reparieren: die Datei gehört dem
# Menschen, nicht diesem Skript.
rechte="$(stat -f '%Lp' "$DATEI" 2>/dev/null || stat -c '%a' "$DATEI" 2>/dev/null || echo '?')"
case "$rechte" in
    600|400|""|"?") ;;
    *) printf '\033[33m  ⚠ %s ist mit %s lesbar — chmod 600 empfohlen\033[0m\n' "$DATEI" "$rechte" ;;
esac

# Paare einlesen: eine Namenszeile, darunter die Keyzeile.
namen=(); keys=()
vorige=""
while IFS= read -r zeile || [ -n "$zeile" ]; do
    zeile="$(printf '%s' "$zeile" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$zeile" ] || continue
    case "$zeile" in
        sk-or-*) namen+=("${vorige:-<ohne Namen>}"); keys+=("$zeile"); vorige="" ;;
        \#*)     ;;
        *)       vorige="$zeile" ;;
    esac
done < "$DATEI"

# Erlaubt sind GENAU so viele Keys wie Profile — oder einer weniger: dann
# bleibt das letzte Profil (esf-ceo) ohne eigenen Key. Jede andere Zahl ist
# ein Fehler, denn die Zuordnung geht nach Reihenfolge und ein Versatz würde
# still alle Rollen verschieben.
if [ "${#keys[@]}" -ne "${#PROFILE_NAMES[@]}" ] \
   && [ "${#keys[@]}" -ne "$(( ${#PROFILE_NAMES[@]} - 1 ))" ]; then
    printf '\n\033[31mFEHLER:\033[0m %s Key(s) in der Datei, aber %s Profile (%s ohne CEO).\n' \
        "${#keys[@]}" "${#PROFILE_NAMES[@]}" "$(( ${#PROFILE_NAMES[@]} - 1 ))" >&2
    printf 'Die Zuordnung geht nach Reihenfolge und muss deshalb aufgehen.\n' >&2
    exit 1
fi

# Doppelte Keys sind der Fehler, der eine Kostenzurechnung lautlos entwertet.
if [ "$(printf '%s\n' "${keys[@]}" | sort -u | wc -l | tr -d ' ')" -ne "${#keys[@]}" ]; then
    printf '\n\033[31mFEHLER:\033[0m Die Datei enthält denselben Key mehrfach.\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
if [ "$AKTION" = "verbrauch" ]; then
# ---------------------------------------------------------------------------
    # Der Punkt, der scripts/provision-keys.sh widerlegt: GET /api/v1/key
    # authentifiziert sich mit dem Key SELBST. Für den Verbrauch je Rolle
    # braucht es also KEINEN Provisioning-Key — nur die Keys, die ohnehin in
    # den Profilen stehen.
    say "Verbrauch je Rolle bei OpenRouter"
    printf '  %-22s %12s %12s\n' PROFIL "USD" "LIMIT"
    summe=0
    for i in "${!keys[@]}"; do
        antwort="$(curl -fsS https://openrouter.ai/api/v1/key \
                    -H "Authorization: Bearer ${keys[$i]}" 2>/dev/null || echo '{}')"
        nutzung="$(printf '%s' "$antwort" | jq -r '.data.usage // "?"')"
        limit="$(printf '%s' "$antwort" | jq -r '.data.limit // "kein"')"
        printf '  %-22s %12s %12s\n' "${PROFILE_NAMES[$i]}" "$nutzung" "$limit"
        case "$nutzung" in ?*[0-9]*) summe="$(printf '%s + %s\n' "$summe" "$nutzung" | bc -l 2>/dev/null || echo "$summe")" ;; esac
    done
    printf '  %-22s %12s\n' "SUMME" "$summe"
    exit 0
fi

# ---------------------------------------------------------------------------
say "Ein Key je Profil zuordnen"
# ---------------------------------------------------------------------------
printf '  Quelle: %s (%s Keys)\n\n' "$DATEI" "${#keys[@]}"

# Die Zuordnungstabelle wird bei jedem Lauf neu geschrieben — sie ist das
# Gedächtnis, das die Schlüsseldatei nicht hat, und sie ist der Massstab, an
# dem --pruefen später misst.
{
    printf '# ESF — welcher Key gehört zu welchem Profil\n'
    printf '#\n'
    printf '# Erzeugt von scripts/assign-keys.sh. Zugeordnet wird nach Reihenfolge:\n'
    printf '# der n-te Key der Schlüsseldatei geht an das n-te Profil.\n'
    printf '#\n'
    printf '# Die dritte Spalte ist ein Fingerabdruck (sha256, 12 Zeichen), kein\n'
    printf '# Geheimnis. Er reicht, um eine Zuordnung wiederzuerkennen und zwei Keys\n'
    printf '# zu unterscheiden — mehr soll er nicht können.\n'
    printf '#\n'
    printf '# %-20s %-24s %s\n' PROFIL "NAME-IN-DER-DATEI" FINGERABDRUCK
} > "$ZUORDNUNG"

fehler=0
if [ "${#keys[@]}" -lt "${#PROFILE_NAMES[@]}" ]; then
    printf '\033[33m  ⚠ %s Keys für %s Profile — %s läuft auf dem Root-Key.\033[0m\n' \
        "${#keys[@]}" "${#PROFILE_NAMES[@]}" "${PROFILE_NAMES[$(( ${#PROFILE_NAMES[@]} - 1 ))]}"
fi
for i in "${!keys[@]}"; do
    name="${PROFILE_NAMES[$i]}"
    key="${keys[$i]}"
    ab="$(fingerabdruck "$key")"

    if [ ! -d "$HOME/.hermes/profiles/$name" ]; then
        nein "$name — Profil gibt es nicht. Erst ./setup.sh"
        fehler=1
        continue
    fi

    # `hermes config set` statt eines direkten Schreibens in die .env: der Weg
    # räumt zusätzlich auf (credential_lifecycle.py:213 zieht config.yaml-
    # Spiegel des alten Wertes nach und hebt unterdrückte Pool-Quellen wieder
    # auf). Preis dafür ist, dass der Key kurz in der Prozessliste steht; er
    # kommt aus einer Datei, nicht aus der Shell-Historie.
    if hermes -p "$name" config set OPENROUTER_API_KEY "$key" >/dev/null 2>&1; then
        ok "$(printf '%-22s <- %-20s %s' "$name" "${namen[$i]}" "$ab")"
    else
        nein "$name — 'config set' schlug fehl"
        fehler=1
    fi
    printf '  %-20s %-24s %s\n' "$name" "${namen[$i]}" "$ab" >> "$ZUORDNUNG"
done

echo
"$HERE/assign-keys.sh" --pruefen || fehler=1

cat <<EOF

Die Zuordnung steht in key-zuordnung.txt (ohne Geheimnisse, gehört ins Repo).
Die Keys stehen in ~/.hermes/profiles/<profil>/.env und verschwinden mit
./teardown.sh — nach jedem Neuaufbau also erneut zuordnen. ./setup.sh macht
das von selbst, wenn es die Schlüsseldatei findet.

Verbrauch je Rolle:  scripts/assign-keys.sh --verbrauch
EOF

exit "$fehler"
