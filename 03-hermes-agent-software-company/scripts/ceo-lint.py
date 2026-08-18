#!/usr/bin/env python3
"""ESF — Riegel für CEO-Entscheidungsdokumente (AGENTS.md 7).

    scripts/ceo-lint.py <dokument.html> [--gate-art release|irreversibel|budget|roadmap]

Validiert ein Entscheidungsdokument von esf-ceo deterministisch. Bei Erfolg
stehen auf stdout maschinenlesbare Zeilen (VERB=…, GATE=…, ANTWORT=…), bei
Befunden ERROR-Zeilen im Stil von vault-lint.py — jede zitiert den Abschnitt
des Vertrags, den sie durchsetzt. Exit 0 = gültig, 1 = Befunde, 2 = Aufruf.

Warum ein eigener Riegel und nicht der Vault-Linter: vault-lint.py prüft die
Form JEDES Dokuments; hier hängt eine AUSFÜHRUNG dran (gate.sh). Ein Gate darf
sich nur öffnen, wenn Verb, Gate-Bezug, Messbeleg und Begründung nachweisbar
DA sind. Der Riegel prüft Anwesenheit, nicht Wahrheit — die Wahrheit der
Messungen sichert nur, dass die Checks selbst Code sind.
"""
import re
import sys

VERBEN_ENTSCHEIDUNG = {"approve", "modify", "shelve"}
VERBEN_BUDGET = {"continue", "cut", "stop"}
ALLE_VERBEN = VERBEN_ENTSCHEIDUNG | VERBEN_BUDGET | {"escalate"}
BEGRUENDUNGSPFLICHT = {"modify", "shelve", "cut", "stop", "escalate"}
PFLICHT_SECTIONS = ("vorlage", "messung", "begruendung", "antwort")
GATE_ID = re.compile(r"^t_[0-9a-f]{6,}$")


def meta(text, name):
    for tag in re.findall(r"<meta\b[^>]*>", text, re.I):
        m = re.search(r'name\s*=\s*["\']([^"\']+)["\']', tag, re.I)
        c = re.search(r'content\s*=\s*["\']([^"\']*)["\']', tag, re.I)
        if m and m.group(1).lower() == name:
            return c.group(1) if c else ""
    return None


def section(text, sid):
    m = re.search(
        rf'<section\b[^>]*\bid\s*=\s*["\']{sid}["\'][^>]*>(.*?)</section>',
        text, re.I | re.S)
    return m.group(1) if m else None


def sichtbar(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html or "")).strip()


def main():
    args = [a for a in sys.argv[1:]]
    gate_art = None
    if "--gate-art" in args:
        i = args.index("--gate-art")
        try:
            gate_art = args[i + 1]
        except IndexError:
            print("FEHLER: --gate-art braucht einen Wert", file=sys.stderr)
            return 2
        del args[i:i + 2]
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        text = open(args[0], encoding="utf-8", errors="replace").read()
    except OSError as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        return 2

    fehler = []

    def error(abschnitt, txt):
        fehler.append(f"ERROR [{abschnitt}] {txt}")

    verb = (meta(text, "esf-verb") or "").strip().lower()
    gate = (meta(text, "esf-gate") or "").strip()

    if not verb:
        error("7", "Meta esf-verb fehlt — ohne Verb ist das Dokument keine Entscheidung")
    elif verb not in ALLE_VERBEN:
        error("7", f"esf-verb '{verb}' ist keins der Verben "
                   f"{sorted(ALLE_VERBEN)}")
    if not gate:
        error("7", "Meta esf-gate fehlt — die Entscheidung nennt ihr Gate nicht")
    elif not GATE_ID.match(gate):
        error("7", f"esf-gate '{gate}' ist keine Karten-ID (t_…)")

    # Verb gegen Gate-Art: das Budget-Vokabular gilt nur am Budget-Gate,
    # umgekehrt genauso. escalate gilt überall; am Roadmap-Gate gilt NUR
    # escalate — das Roadmap-Gate gehört dem Supervisor.
    if verb in ALLE_VERBEN and gate_art:
        if gate_art == "roadmap" and verb != "escalate":
            error("7", "das Roadmap-Gate ist nicht delegierbar — für esf-ceo gilt dort nur escalate")
        elif gate_art == "budget" and verb in VERBEN_ENTSCHEIDUNG:
            error("7", f"'{verb}' gilt an einem Budget-Gate nicht (continue|cut|stop|escalate)")
        elif gate_art in ("release", "irreversibel") and verb in VERBEN_BUDGET:
            error("7", f"'{verb}' gilt an einem {gate_art}-Gate nicht (approve|modify|shelve|escalate)")

    for sid in PFLICHT_SECTIONS:
        inhalt = section(text, sid)
        if inhalt is None:
            error("7", f"Pflichtabschnitt <section id=\"{sid}\"> fehlt")
            continue
        if len(sichtbar(inhalt)) < 40 and not (sid == "antwort" and verb == "approve"):
            error("7", f"Abschnitt '{sid}' ist mit {len(sichtbar(inhalt))} Zeichen zu dünn")

    # Der Messbeleg ist der Kern: mindestens ein <pre>-Block mit einer selbst
    # ausgeführten Prüfung. Ein Dokument, dessen Messung nur Prosa ist, hat
    # die Vorlage zitiert statt nachgemessen.
    messung = section(text, "messung")
    if messung is not None and not re.search(r"<pre\b", messung, re.I):
        error("7", "Abschnitt 'messung' enthält keinen <pre>-Block — "
                   "Befehl und Ausgabe der eigenen Prüfung sind Pflicht")

    if verb in BEGRUENDUNGSPFLICHT:
        antwort = sichtbar(section(text, "antwort"))
        if len(antwort) < 40:
            error("7", f"'{verb}' braucht einen Antworttext (Abschnitt 'antwort', "
                       f"gefunden: {len(antwort)} Zeichen)")

    if fehler:
        for f in fehler:
            print(f)
        print(f"{len(fehler)} ERROR")
        return 1

    antwort = sichtbar(section(text, "antwort"))
    print(f"VERB={verb}")
    print(f"GATE={gate}")
    print(f"ANTWORT={antwort[:400]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
