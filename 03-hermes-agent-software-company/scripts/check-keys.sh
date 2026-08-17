#!/usr/bin/env bash
#
# ESF — Wirkt ein Key je Profil wirklich?
# =======================================
#
#   scripts/check-keys.sh                      Standard: drei Profile prüfen
#   scripts/check-keys.sh esf-dev-a esf-dev-b  bestimmte Profile prüfen
#
# ---------------------------------------------------------------------------
# Warum es diesen Nachweis überhaupt gibt
# ---------------------------------------------------------------------------
# `hermes -p <profil> config get OPENROUTER_API_KEY` beweist NICHTS. Es liest
# dieselbe Datei, die assign-keys.sh geschrieben hat, und bestätigt damit nur
# sich selbst. Die offene Frage ist eine andere:
#
#   Läuft ein Worker, den der DISPATCHER startet, mit HERMES_HOME auf dem
#   Profilverzeichnis — oder erbt er ~/.hermes vom Gateway-Elternprozess?
#
# Im zweiten Fall wird ~/.hermes/profiles/<profil>/.env nie gelesen, alle elf
# Rollen laufen auf dem Root-Key, und jede Prüfung, die nur die Datei ansieht,
# meldet trotzdem grün. Das ist dieselbe Bauart von Fehler wie ein Merge-
# Riegel, der prüft, ohne zu prüfen.
#
# Der einzige Zeuge ausserhalb der eigenen Dateien ist OpenRouter selbst:
# `GET /api/v1/key` meldet den Verbrauch DES KEYS, mit dem gefragt wird.
#
# Das Verfahren:
#   1. Verbrauch aller elf Keys messen (Nullmessung)
#   2. je Prüf-Profil eine winzige Karte anlegen und den Dispatcher laufen lassen
#   3. erneut messen
#
# Bestanden ist nur, wenn BEIDE Hälften stimmen:
#   · bei jedem geprüften Profil ist der Verbrauch gestiegen
#   · bei jedem NICHT geprüften Profil steht er unverändert
#
# Die zweite Hälfte ist die wichtigere: Sie unterscheidet „jede Rolle hat einen
# eigenen Key" von „irgendein Key hat gearbeitet".
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
DATEI="${ESF_OPENROUTER_KEYFILE:-$HOME/.hermes/esf-openrouter-keys.txt}"
STEMPEL="$(date '+%Y%m%d-%H%M%S')"

PRUEFEN=("$@")
[ ${#PRUEFEN[@]} -gt 0 ] || PRUEFEN=(esf-controller esf-estimator esf-market-scout)

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -r "$DATEI" ] || { echo "FEHLER: Keine Schlüsseldatei unter $DATEI"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault unter $VAULT. Erst ./setup.sh"; exit 1; }

k()   { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein(){ printf '  \033[31m✗\033[0m %s\n' "$*"; }

MESSUNG="$(mktemp -t esf-keys)"
trap 'rm -f "$MESSUNG" "$MESSUNG.vorher" "$MESSUNG.nachher"' EXIT

# Misst den Verbrauch je Profil und schreibt "<profil> <usd>" nach stdout.
# Der Key verlässt diese Funktion nicht.
messen() {
    python3 - "$DATEI" "$ESF/key-zuordnung.txt" <<'PY'
import sys, json, hashlib, urllib.request

datei, zuordnung = sys.argv[1], sys.argv[2]
lines = [l.strip() for l in open(datei) if l.strip()]
keys, i = [], 0
while i < len(lines) - 1:
    if lines[i+1].startswith('sk-or-'):
        keys.append(lines[i+1]); i += 2
    else:
        i += 1

# Die Zuordnung Profil -> Fingerabdruck ist das committete Gedaechtnis; ueber
# sie findet die Messung den richtigen Key, ohne die Reihenfolge erneut zu
# raten.
nach_abdruck = {hashlib.sha256(k.encode()).hexdigest()[:12]: k for k in keys}
try:
    zeilen = [l.split() for l in open(zuordnung) if l.strip() and not l.startswith('#')]
    paare = [(z[0], z[2]) for z in zeilen if len(z) >= 3]
except OSError:
    paare = []

for profil, abdruck in paare:
    key = nach_abdruck.get(abdruck)
    if not key:
        print(f"{profil} FEHLT"); continue
    try:
        req = urllib.request.Request("https://openrouter.ai/api/v1/key",
                                     headers={"Authorization": "Bearer " + key})
        d = json.load(urllib.request.urlopen(req, timeout=25))["data"]
        print(f"{profil} {d.get('usage', 0)}")
    except Exception as e:
        print(f"{profil} FEHLER")
PY
}

# ---------------------------------------------------------------------------
say "1/4  Nullmessung"
# ---------------------------------------------------------------------------
messen > "$MESSUNG.vorher"
awk '{printf "  %-22s %s USD\n", $1, $2}' "$MESSUNG.vorher"

# ---------------------------------------------------------------------------
say "2/4  Prüfkarten anlegen"
# ---------------------------------------------------------------------------
# So klein wie möglich: ein Wort Antwort, keine Dateien, kein Werkzeug. Die
# Karte soll den Key benutzen, sonst nichts. Was sie kostet, ist genau der
# Betrag, den die Messung danach sehen muss.
for profil in "${PRUEFEN[@]}"; do
    id="$(k create "Keyprobe $profil [$STEMPEL]" \
        --assignee "$profil" \
        --workspace "dir:$VAULT" \
        --idempotency-key "keyprobe-$profil-$STEMPEL" \
        --max-retries 1 --max-runtime 5m \
        --body "Dies ist eine Funktionsprüfung der Zugangsdaten, keine Arbeitsaufgabe.

Antworte mit dem einen Wort BEREIT und schliesse die Karte danach ab.

Lege keine Dateien an, ändere nichts, lies nichts. Jeder weitere Schritt
verfälscht die Messung, um die es hier geht." \
        --json | jq -r .id)"
    printf '  %-22s Karte %s\n' "$profil" "$id"
done

# ---------------------------------------------------------------------------
say "3/4  Dispatcher"
# ---------------------------------------------------------------------------
"$ESF/pump.sh" 10 60 | tail -20

# ---------------------------------------------------------------------------
say "4/4  Zweite Messung und Vergleich"
# ---------------------------------------------------------------------------
# ⚠ Der Zähler bei OpenRouter läuft dem Lauf HINTERHER. Gemessen am 17.08.2026:
#   Unmittelbar nach `done` standen alle elf Keys noch auf 0; rund eine Minute
#   später zeigten genau die drei geprüften ihren Verbrauch. Eine Messung ohne
#   Wartezeit meldet also zuverlässig einen Fehlschlag, den es nicht gibt —
#   der erste Lauf dieses Skripts ist genau darauf hereingefallen.
#
#   Deshalb wird gewartet, bis jeder geprüfte Key gestiegen ist, und danach
#   NOCH EINE Runde: Sonst prüft die zweite Hälfte („kein fremder Key wurde
#   belastet") einen Zählerstand, der bloss noch nicht angekommen ist.
warte_bis_gebucht() {
    local runde erwartet_offen
    for runde in $(seq 1 15); do
        messen > "$MESSUNG.nachher"
        erwartet_offen=0
        for p in "${PRUEFEN[@]}"; do
            wert="$(awk -v p="$p" '$1==p {print $2}' "$MESSUNG.nachher")"
            case "$wert" in ""|0|0.0|FEHLER|FEHLT) erwartet_offen=$((erwartet_offen + 1)) ;; esac
        done
        if [ "$erwartet_offen" -eq 0 ]; then
            printf '  gebucht nach etwa %s s — eine Kontrollrunde noch\n' "$(( (runde - 1) * 20 ))"
            python3 -c 'import time; time.sleep(20)'
            messen > "$MESSUNG.nachher"
            return 0
        fi
        printf '  noch %s von %s geprüften Keys ohne Buchung (t+%ss)\n' \
            "$erwartet_offen" "${#PRUEFEN[@]}" "$(( (runde - 1) * 20 ))"
        python3 -c 'import time; time.sleep(20)'
    done
    printf '  \033[33m⚠ nach 5 Minuten immer noch nicht vollständig gebucht\033[0m\n'
    return 1
}
warte_bis_gebucht || true
echo

fehler=0
printf '  %-22s %12s %12s %12s   %s\n' PROFIL VORHER NACHHER DELTA BEFUND
while read -r profil vorher; do
    nachher="$(awk -v p="$profil" '$1==p {print $2}' "$MESSUNG.nachher")"
    geprueft=0
    for p in "${PRUEFEN[@]}"; do [ "$p" = "$profil" ] && geprueft=1; done

    case "$vorher$nachher" in
        *FEHLER*|*FEHLT*)
            printf '  %-22s %12s %12s %12s   \033[31mnicht messbar\033[0m\n' \
                "$profil" "$vorher" "${nachher:-?}" "-"
            fehler=1; continue ;;
    esac

    delta="$(python3 -c "print(round(float('$nachher') - float('$vorher'), 8))")"
    gestiegen="$(python3 -c "print(1 if float('$delta') > 0 else 0)")"

    if [ "$geprueft" -eq 1 ] && [ "$gestiegen" -eq 1 ]; then
        befund=$'\033[32mgearbeitet (erwartet)\033[0m'
    elif [ "$geprueft" -eq 1 ]; then
        befund=$'\033[31mkein Verbrauch — der Key wurde NICHT benutzt\033[0m'; fehler=1
    elif [ "$gestiegen" -eq 1 ]; then
        befund=$'\033[31mVerbrauch ohne Auftrag — keine Trennung\033[0m'; fehler=1
    else
        befund="unberührt (erwartet)"
    fi
    printf '  %-22s %12s %12s %12s   %b\n' "$profil" "$vorher" "$nachher" "$delta" "$befund"
done < "$MESSUNG.vorher"

echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Jede geprüfte Rolle hat ihren eigenen Key benutzt, keine fremde wurde belastet.\033[0m\n'
    printf '  Damit ist die Kostenzurechnung je Rolle belegt, nicht behauptet.\n'
    exit 0
fi
cat <<'EOF'
✗ Die Trennung ist nicht nachgewiesen.

Zwei Ursachen sehen gleich aus und bedeuten Gegenteiliges:

  · Stand oben eine Warnung über nicht vollständig gebuchte Keys, ist das
    vermutlich nur der Nachlauf des OpenRouter-Zählers. Einfach nochmal
    messen: scripts/assign-keys.sh --verbrauch

  · Blieb KEIN Profil-Key stehen, obwohl die Karten `done` sind, hat die
    Profil-.env nicht gewonnen: Der Worker lief mit dem Root-Key aus
    ~/.hermes/.env oder mit dem exportierten OPENROUTER_API_KEY der Shell.
    Dann ist ein Key je Rolle eine Buchhaltung ohne Wirkung — und muss in
    VERIFIKATION.md so stehen.
EOF
exit 1
