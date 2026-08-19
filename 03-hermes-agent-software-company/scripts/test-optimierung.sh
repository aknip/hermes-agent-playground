#!/usr/bin/env bash
#
# ESF — Regressionsnetz der Optimierungsrunde vom 20.08.2026
# =========================================================
#
#   scripts/test-optimierung.sh            alle Faelle
#   scripts/test-optimierung.sh 1 4        nur Fall 1 und 4
#
# MODELLFREI, NETZFREI, KOSTET KEINE TOKEN. Jeder Fall baut sich in einem
# Wegwerf-Verzeichnis eine Miniatur-ESF: ein `hermes` auf dem PATH, das
# Fixtures wiedergibt statt eine echte CLI zu sein, und ein Symlink auf das
# ECHTE zu pruefende Skript — nicht auf eine Kopie. Sonst prueft der Test
# seine eigene Kopie und nicht das, was im Betrieb laeuft.
#
# Jeder Fall belegt genau EINEN Befund aus _NOTES/OPTIMIERUNG.md und ist
# einzeln aufrufbar, damit er VOR dem Fix rot und NACH dem Fix gruen gezeigt
# werden kann. Die Faelle sind voneinander unabhaengig.
#
#   1  monitor.sh ist blind fuer `timed_out` — die einzige Verlustklasse in
#      beispiel-lauf-3 (165 von 541 min)
#   2  pump.sh ruft den Wachhund nie — ein Haenger bei 0 % CPU ist vom Board
#      aus nicht von Arbeit zu unterscheiden
#   3  pump.sh schluckt Dispatcher-Fehler (`>/dev/null 2>&1 || true`)
#   4  pump.sh zeigt abgebrochene Laeufe im Takt nicht
#   5  dump-lauf.sh: die Tabelle widerspricht ihrer eigenen Summe um 17 min
#   6  Keine Zeitgrenze unter 75 min in den kartenlegenden Skripten
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"

ROT=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; ROT=1; }
fall() { printf '\n\033[1mFall %s — %s\033[0m\n' "$1" "$2"; }

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 2; }

WILL="${*:-1 2 3 4 5 6}"
soll() { case " $WILL " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ---------------------------------------------------------------------------
# Der gefaelschte Hermes
# ---------------------------------------------------------------------------
# Er liest sein Verhalten aus $FIX. Damit ist jeder Fall deterministisch: kein
# Board, kein Worker, kein Provider.
fake_hermes() { # zielverzeichnis
    mkdir -p "$1"
    cat > "$1/hermes" <<'EOS'
#!/usr/bin/env bash
: "${FIX:?FIX fehlt}"
args="$*"
id=""
for a in "$@"; do case "$a" in t_*) id="$a" ;; esac; done
case "$args" in
    *"list --json"*)
        cat "$FIX/list.json" ;;
    *" show "*)
        if [ -n "$id" ] && [ -f "$FIX/show-$id.json" ]; then cat "$FIX/show-$id.json"
        else echo '{}'; fi ;;
    *dispatch*)
        if [ -f "$FIX/dispatch-faellt-aus" ]; then
            echo "dispatch: workspace: git worktree add failed for .worktrees/t_aaa1" >&2
            exit 1
        fi ;;
    *" list"*)
        jq -r '.[] | "\(.id)  \(.status)  \(.title)"' "$FIX/list.json" ;;
    *)  : ;;
esac
exit 0
EOS
    chmod +x "$1/hermes"
}

tempdir() { mktemp -d "${TMPDIR:-/tmp}/esf-test-XXXXXX"; }

# ===========================================================================
if soll 1; then
fall 1 "monitor.sh meldet timed_out samt Ueberschuss ueber den Deckel"
# Belegt: VERIFIKATION.md 358 / OPTIMIERUNG.md 1.3 — fuenf gemessene Risse,
# vier davon unter 7 s Ueberschuss. monitor.sh existiert, um stille Ausfaelle
# zu finden, und kannte genau diese Klasse nicht.
T="$(tempdir)"; FIX="$T/fix"; mkdir -p "$FIX" "$T/scripts" "$T/bin"
fake_hermes "$T/bin"
ln -s "$HERE/monitor.sh" "$T/scripts/monitor.sh"
# assign-keys-Attrappe: ohne sie greift monitor.sh nach dem echten Skript und
# damit an die OpenRouter-API. Ein Regressionstest darf nichts kosten.
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/scripts/assign-keys.sh"
chmod +x "$T/scripts/assign-keys.sh"

cat > "$FIX/list.json" <<'EOS'
[{"id":"t_aaa1","status":"running","title":"Onboarding 4/6 — E2E-Suite"}]
EOS
cat > "$FIX/show-t_aaa1.json" <<'EOS'
{"task":{"id":"t_aaa1","title":"Onboarding 4/6 — E2E-Suite"},
 "events":[{"kind":"spawned"},{"kind":"timed_out"},{"kind":"spawned"}],
 "runs":[{"outcome":"timed_out","error":"elapsed 5406s > limit 5400s"},
         {"outcome":"completed","error":null}],
 "comments":[]}
EOS

aus="$(cd "$T" && FIX="$FIX" PATH="$T/bin:$PATH" OPENROUTER_API_KEY="" \
        "$T/scripts/monitor.sh" --json 2>&1)"
texte="$(printf '%s' "$aus" | jq -r '.[]?.text' 2>/dev/null || true)"

printf '%s\n' "$texte" | grep -q 'timed_out' \
    && ok "timed_out wird gemeldet" \
    || nein "timed_out NICHT gemeldet — der Monitor ist blind fuer die Klasse"
printf '%s\n' "$texte" | grep -q '6 s' \
    && ok "der Ueberschuss (6 s) steht im Befund" \
    || nein "kein Ueberschuss im Befund — 6 s ueber 5400 s ist nicht von einem echten Haenger zu unterscheiden"
printf '%s\n' "$texte" | grep -qi 'Deckel' \
    && ok "der Befund nennt die Handlung (Deckel anheben)" \
    || nein "der Befund sagt nicht, was zu tun ist"
rm -rf "$T"
fi

# ===========================================================================
if soll 2; then
fall 2 "pump.sh ruft den Wachhund im Takt"
# Belegt: VERIFIKATION.md 185 — 16 min bei 0 % CPU, vom Board aus nicht von
# Arbeit zu unterscheiden. watchdog.sh kann das erkennen, wurde aber von
# keinem Skript aufgerufen.
T="$(tempdir)"; FIX="$T/fix"; mkdir -p "$FIX" "$T/scripts" "$T/bin"
fake_hermes "$T/bin"
ln -s "$ESF/pump.sh" "$T/pump.sh"
cat > "$T/scripts/watchdog.sh" <<EOS
#!/usr/bin/env bash
echo "AUFGERUFEN \$*" >> "$T/wachhund.log"
exit 0
EOS
chmod +x "$T/scripts/watchdog.sh"
cat > "$FIX/list.json" <<'EOS'
[{"id":"t_aaa1","status":"running","title":"S1 F1 3/5 — Umsetzung"}]
EOS
cat > "$FIX/show-t_aaa1.json" <<'EOS'
{"task":{"id":"t_aaa1"},"events":[],"runs":[{"outcome":null}],"comments":[]}
EOS

FIX="$FIX" PATH="$T/bin:$PATH" ESF_WACHHUND_TAKT=1 \
    "$T/pump.sh" 0 2 >"$T/pump.aus" 2>&1 || true

[ -f "$T/wachhund.log" ] \
    && ok "der Wachhund wurde aufgerufen ($(grep -c . "$T/wachhund.log")x in 2 Ticks)" \
    || nein "der Wachhund wurde NIE aufgerufen — ein Haenger laeuft bis --max-runtime durch"
grep -qi 'wachhund\|haenger\|hänger' "$T/pump.aus" \
    && ok "die Pumpe sagt, dass sie geprueft hat" \
    || nein "die Pumpe schweigt ueber die Pruefung — eine unsichtbare Pruefung ist keine"
rm -rf "$T"
fi

# ===========================================================================
if soll 3; then
fall 3 "pump.sh meldet einen fehlgeschlagenen Dispatch"
# Belegt: OPTIMIERUNG.md 1.3 — 1x spawn_failed und 1x gave_up mit
# 'git worktree add failed' in beispiel-lauf-2. Die Pumpe fuhr
# `dispatch >/dev/null 2>&1 || true`: der Fehlertext existierte nie.
T="$(tempdir)"; FIX="$T/fix"; mkdir -p "$FIX" "$T/scripts" "$T/bin"
fake_hermes "$T/bin"
ln -s "$ESF/pump.sh" "$T/pump.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/scripts/watchdog.sh"
chmod +x "$T/scripts/watchdog.sh"
touch "$FIX/dispatch-faellt-aus"
cat > "$FIX/list.json" <<'EOS'
[{"id":"t_aaa1","status":"ready","title":"S1 F1 3/5 — Umsetzung"}]
EOS
cat > "$FIX/show-t_aaa1.json" <<'EOS'
{"task":{"id":"t_aaa1"},"events":[],"runs":[],"comments":[]}
EOS

FIX="$FIX" PATH="$T/bin:$PATH" ESF_WACHHUND_TAKT=99 \
    "$T/pump.sh" 0 2 >"$T/pump.aus" 2>&1 || true

grep -q 'worktree add failed' "$T/pump.aus" \
    && ok "der Fehlertext des Dispatchers steht in der Ausgabe" \
    || nein "der Dispatcher-Fehler ist verschluckt — die Pumpe tickt ins Leere weiter"
grep -qi 'dispatch' "$T/pump.aus" \
    && ok "die Pumpe benennt den fehlgeschlagenen Dispatch" \
    || nein "die Pumpe benennt den Fehler nicht"
rm -rf "$T"
fi

# ===========================================================================
if soll 4; then
fall 4 "pump.sh meldet abgebrochene Laeufe im Takt"
# Belegt: OPTIMIERUNG.md 1.1 — rund ein Drittel aller Kartenzeit brennt in
# Laeufen ohne Ergebnis. Eine Karte, die ihre Retries verbrennt, sieht im
# Lagebild der Pumpe aus wie 'running'. Genau diese vier Klassen muss
# BLOCK 4 fuer den Validierungslauf mit 0 belegen.
T="$(tempdir)"; FIX="$T/fix"; mkdir -p "$FIX" "$T/scripts" "$T/bin"
fake_hermes "$T/bin"
ln -s "$ESF/pump.sh" "$T/pump.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/scripts/watchdog.sh"
chmod +x "$T/scripts/watchdog.sh"
cat > "$FIX/list.json" <<'EOS'
[{"id":"t_aaa1","status":"running","title":"S1 F1 3/5 — Umsetzung"},
 {"id":"t_bbb2","status":"running","title":"S1 F1 4/5 — Review"}]
EOS
cat > "$FIX/show-t_aaa1.json" <<'EOS'
{"task":{"id":"t_aaa1"},
 "events":[{"kind":"timed_out"},{"kind":"crashed"}],
 "runs":[{"outcome":"timed_out","error":"elapsed 5406s > limit 5400s"},
         {"outcome":"crashed","error":"pid 4711 not alive"},
         {"outcome":null,"error":null}],
 "comments":[]}
EOS
cat > "$FIX/show-t_bbb2.json" <<'EOS'
{"task":{"id":"t_bbb2"},"events":[],"runs":[{"outcome":null}],"comments":[]}
EOS

FIX="$FIX" PATH="$T/bin:$PATH" ESF_WACHHUND_TAKT=99 ESF_LAGE_TAKT=1 \
    "$T/pump.sh" 0 2 >"$T/pump.aus" 2>&1 || true

# Nur die Zeilen des Abbruch-Berichts, nicht die Kartenliste, die die Pumpe am
# Ende ohnehin ausgibt — sonst zaehlte jede Karten-ID als Treffer.
bericht="$(grep -i 'abgebrochen' "$T/pump.aus" || true)"
printf '%s\n' "$bericht" | grep -q 'timed_out' \
    && ok "timed_out erscheint im Abbruch-Bericht" \
    || nein "timed_out erscheint NICHT — die Karte sieht aus wie Arbeit"
printf '%s\n' "$bericht" | grep -q 'crashed' \
    && ok "crashed erscheint im Abbruch-Bericht" \
    || nein "crashed erscheint NICHT"
printf '%s\n' "$bericht" | grep -q 't_aaa1' \
    && ok "die betroffene Karte wird namentlich genannt" \
    || nein "keine Karten-ID im Bericht — eine Zahl ohne Karte ist nicht nachpruefbar"
printf '%s\n' "$bericht" | grep -q 't_bbb2' \
    && nein "die gesunde Karte wird mitgemeldet — Fehlalarm" \
    || ok "die gesunde Karte wird nicht gemeldet"
rm -rf "$T"
fi

# ===========================================================================
if soll 5; then
fall 5 "dump-lauf.sh: die Laufzeiten-Tabelle stimmt mit ihrer eigenen Summe"
# Belegt: OPTIMIERUNG.md 1.7 — in beiden gesicherten Akten weicht die
# Summenzeile um exakt 17 min von der Spaltensumme ab (je Karte `floor`,
# Summe aus Sekunden). Die Fixture ist so gebaut, dass sie den Fehler
# maximal sichtbar macht: drei Karten mit je 59 Sekunden Rest.
T="$(tempdir)"; mkdir -p "$T"
cat > "$T/board.json" <<'EOS'
{"board":"sw-company","gesichert_am":"2026-08-20T00:00:00+0200","karten":[
 {"task":{"id":"t_aaa1","assignee":"esf-dev-a","title":"Karte A"},
  "runs":[{"started_at":1000,"ended_at":1659}]},
 {"task":{"id":"t_bbb2","assignee":"esf-dev-b","title":"Karte B"},
  "runs":[{"started_at":2000,"ended_at":2659}]},
 {"task":{"id":"t_ccc3","assignee":"esf-reviewer","title":"Karte C"},
  "runs":[{"started_at":3000,"ended_at":3659}]}]}
EOS
# 3 x 659 s = 1977 s = 32,95 min. Je Karte floor(10,98) = 10  ->  Spalte 30.
# Aus Sekunden gerechnet: floor(32,95) = 32. Differenz 2 min bei 3 Karten.
aus="$("$HERE/dump-lauf.sh" --nur-laufzeiten "$T/board.json" 2>&1)" || true

if printf '%s' "$aus" | grep -q 'KARTE .*PROFIL .*MINUTEN'; then
    ok "--nur-laufzeiten liefert die Tabelle"
    spalte="$(printf '%s\n' "$aus" | awk '/^t_/{s+=$3} END{print s+0}')"
    summe="$(printf '%s\n' "$aus" | sed -n 's/^Summe Kartenzeit: \([0-9]*\) .*/\1/p')"
    if [ -n "$summe" ] && [ "$spalte" = "$summe" ]; then
        ok "Spaltensumme ($spalte) = Summenzeile ($summe) — nachrechenbar"
    else
        nein "Spaltensumme ($spalte) != Summenzeile (${summe:-fehlt}) — die Tabelle widerlegt ihre eigene Summe"
    fi
    printf '%s\n' "$aus" | grep -q 'Sekunden' \
        && ok "die genaue Sekundenzahl steht daneben (Rundungsverlust benannt)" \
        || nein "der Rundungsverlust wird nicht benannt"
else
    nein "--nur-laufzeiten gibt es nicht — die Arithmetik ist nicht pruefbar, ohne einen Lauf zu fahren"
    nein "(Folgepruefung Spaltensumme = Summenzeile nicht ausfuehrbar)"
    nein "(Folgepruefung Sekundenzahl nicht ausfuehrbar)"
fi
rm -rf "$T"
fi

# ===========================================================================
if soll 6; then
fall 6 "keine Zeitgrenze unter 75 min in den kartenlegenden Skripten"
# Belegt: OPTIMIERUNG.md 1.3/1.4 — sechs Risse, Ueberschuss 4-26 s, jeder
# kostete den ganzen Lauf. Nach dem dritten Riss wurde entschieden: KEIN
# Deckel liegt mehr nahe an der erwarteten Dauer (create-sprint.sh 97-135).
# Die Entscheidung stand als Kommentar da und wurde von nichts erzwungen.
#
# Ausnahme, namentlich: check-keys.sh legt eine WEGWERF-Probekarte an, die
# nichts als eine Zeile schreibt (5m). Sie steht hier, damit die Ausnahme
# sichtbar ist und niemand sie stillschweigend erweitert.
AUSNAHME="scripts/check-keys.sh"
gefunden=0
while IFS= read -r treffer; do
    datei="${treffer%%:*}"
    case "$datei" in "$AUSNAHME") continue ;; esac
    nein "$treffer"
    gefunden=$((gefunden + 1))
done < <(cd "$ESF" && grep -rn -- '--max-runtime' \
            create-*.sh probelauf.sh restore-phase1.sh scripts/*.sh 2>/dev/null \
         | grep -E -- '--max-runtime ([1-9]|[1-6][0-9]|7[0-4])m')
if [ "$gefunden" -eq 0 ]; then
    ok "kein Deckel unter 75 min (Ausnahme: $AUSNAHME, Probekarte 5m)"
else
    nein "$gefunden Deckel unter 75 min — jeder davon ist ein Riss, der auf seinen Anlass wartet"
fi
fi

# ===========================================================================
echo
if [ "$ROT" -eq 0 ]; then
    printf '\033[32m✓ Regressionsnetz gruen (Faelle: %s)\033[0m\n' "$WILL"
    exit 0
fi
printf '\033[31m✗ Regressionsnetz ROT (Faelle: %s)\033[0m\n' "$WILL"
exit 1
