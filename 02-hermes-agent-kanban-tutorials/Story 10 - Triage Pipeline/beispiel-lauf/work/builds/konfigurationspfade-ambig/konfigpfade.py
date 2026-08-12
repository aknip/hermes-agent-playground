#!/usr/bin/env python3
"""konfigpfade — zeigt, welche Konfigdatei gewinnt und welche Werte gelten.

Zweck (Item konfigurationspfade-ambig): Mehrere Kandidaten fuer dieselbe
Konfigdatei (Home, Projekt, unter Windows WSL + Roaming) machen unklar,
welche Datei tatsaechlich wirkt. Dieses Werkzeug

  1. listet alle Kandidatenpfade der Konfigdatei und markiert, welche
     vorhanden sind und welche gewinnt,
  2. gibt die effektiven Werte samt Herkunftsdatei aus,
  3. redigiert Secrets als ***redigiert***.

Nur Standardbibliothek (tomllib ab Python 3.11). Liest Dateien und schreibt
nur nach stdout. Veraendert nichts.

Die Prioritaets-/Suchreihenfolge wird NICHT erfunden, sondern als
kommandozeilen-Eingabe gefuehrt (erlaubt im Auftrag Abschnitt 2/3):
Die Kandidaten-VERZEICHNISSE werden in der Reihenfolge ihres Vorrangs als
Positional-Argumente uebergeben. Der erste Kandidat, in dem die Konfigdatei
existiert, gewinnt; fuer jeden effektiven Wert zaehlt der Kandidat mit dem
hoechsten Vorrang, in dem der Wert definiert ist.

Das Werkzeug haertet keinen absoluten Pfad und keinen ".."-Pfad ein; es
liest nur die Konfigdatei innerhalb der Verzeichnisse, die der Nutzer
explizit als Argumente uebergibt.
"""

import argparse
import os
import re
import sys
import tomllib

DEFAULT_FILE = "config.toml"
REDACTED = "***redigiert***"

# Schlüsseln \"key\" allein ist zu breit; wir prüfen Wortränder.
_SECRET_KEY = re.compile(
    r"(?:^|[\s._-])?("
    r"secret|token|passwd|password|api[-_]?key|apikey|credential"
    r"|bearer|auth(?:orization)?|private[-_]?key|access[-_]?key"
    r"|client[-_]?secret|pwd|passphrase"
    r")(?:$|[\s._-])",
    re.IGNORECASE,
)
# Wertformen, die nach Token/Schluessel aussehen.
_SECRET_VALUE = re.compile(
    r"^(sk-|pk-|ghp_|gho_|ghu_|xox[baprs]-|AKIA|ASIA|eyJ[A-Za-z0-9_-]{8,}\.)",
    re.IGNORECASE,
)


def is_secret_key(key):
    """True, wenn der (flache) Schluesselname auf ein Geheimnis hindeutet."""
    return bool(_SECRET_KEY.search(key))


def looks_like_secret_value(val):
    """True, wenn der Wert nach Token/Passwort/Schluessel aussieht."""
    if not isinstance(val, str):
        return False
    if _SECRET_VALUE.match(val):
        return True
    # JWT-artig: drei Segmente mit Punkten.
    if len(val.split(".")) >= 3 and re.search(r"[A-Za-z0-9_-]{10,}\.", val):
        return True
    # langer, nicht-woerter-artiger String mit Zeichen und Ziffern -> Key.
    if len(val) >= 24 and re.search(r"[^A-Za-z ]", val) and re.search(r"\d", val):
        return True
    return False


def redact_if_secret(key, value):
    """Redigiert den Wert, wenn Schluessel oder Wert nach einem Geheimnis
    aussehen. Naehere Strings (liest nichts anyway) werden nie gedruckt."""
    if is_secret_key(key) or looks_like_secret_value(value):
        return REDACTED
    return value


def flatten(tbl, prefix=""):
    """Flacht verschachtelte TOML-Tabellen zu 'punkt.pfad' = wert ab."""
    out = {}
    for key, val in tbl.items():
        full = f"{prefix}.{key}" if prefix else key
        if isinstance(val, dict):
            out.update(flatten(val, full))
        else:
            out[full] = val
    return out


def load_flattened(path):
    """Liest eine TOML-Datei und liefert (flach, gewinnender_uenze, fehler).

    Rueckgabe: (dict | None, fehlerstr | None). Fehler fuer unparsbare
    Dateien werden gemeldet, nicht abgebrochen.
    """
    try:
        with open(path, "rb") as fh:
            return flatten(tomllib.load(fh)), None
    except FileNotFoundError:
        return None, None
    except Exception as err:  # TOMLDecodeError u.a.
        return None, str(err)


def collect_candidates(dirs, fname):
    """Baut die Kandidatenliste in Prioritaetsreihenfolge.

    Jeder Eintrag: (pfad, vorhanden, fehler). Der 'Gewinner' ist der erste
    Eintrag mit vorhanden=True.
    """
    cands = []
    for d in dirs:
        path = os.path.join(d, fname)
        present = os.path.isfile(path)
        cands.append((path, present, None))
    return cands


def effective_values(cands):
    """Merges die vorhandenen Kandidaten in Prioritaetsreihenfolge.

    Fuer jeden flachen Schluessel gewinnt der Wert aus dem Kandidaten mit
    dem hoechsten Vorrang, der ihn definiert. Rueckgabe: {key: (wert, pfad)}.
    """
    merged = {}
    for path, present, _ in cands:
        if not present:
            continue
        data, _parse_err = load_flattened(path)
        if data is None:
            continue
        for key, val in data.items():
            if key not in merged:
                merged[key] = (val, path)
    return merged


def print_report(cands, fname, merged):
    print("Konfigdatei: %s" % fname)
    print("Kandidatein-Reihenfolge = Prioritaet (erste vorhandene Datei gewinnt).")
    print()
    print("Kandidatenpfade:")
    winner = None
    for i, (path, present, _err) in enumerate(cands, 1):
        if present:
            tag = "GEWINNT" if winner is None else "vorhanden"
            if winner is None:
                winner = path
        else:
            tag = "nicht vorhanden"
        print("  [%d] %s   -- %s" % (i, path, tag))
    if winner is None:
        print()
        print("Effektive Werte: keine Konfigdatei gefunden.")
        return
    print()
    print("Effektive Werte (Herkunft = gewinnende Datei je Wert):")
    for key in sorted(merged):
        val, src = merged[key]
        shown = redact_if_secret(key, val)
        print("  %s = %s   (aus: %s)" % (key, shown, src))


def parse_args(argv):
    p = argparse.ArgumentParser(
        prog="konfigpfade",
        description=(
            "Zeigt Kandidatenpfade, effektive Werte samt Herkunft und "
            "redigiert Secrets. Veraendert nichts."
        ),
    )
    p.add_argument(
        "-f", "--file", default=DEFAULT_FILE,
        help="Name der Konfigdatei (Standard: %(default)s)",
    )
    p.add_argument(
        "dirs", nargs="+",
        help="Kandidaten-Verzeichnisse in Prioritaetsreihenfolge (hoeher=gewinnt).",
    )
    args = p.parse_args(argv)
    if not args.dirs:
        p.error("mindestens ein Kandidaten-Verzeichnis angeben")
    return args


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    cands = collect_candidates(args.dirs, args.file)
    merged = effective_values(cands)
    print_report(cands, args.file, merged)
    return 0


if __name__ == "__main__":
    sys.exit(main())