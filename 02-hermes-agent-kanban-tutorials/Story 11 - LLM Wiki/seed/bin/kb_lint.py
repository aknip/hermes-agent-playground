#!/usr/bin/env python3
"""kb_lint.py — deterministischer Verifikations-Linter fuer die Wissensbasis.

Diese Datei ist die maschinelle Fassung von wiki/AGENTS.md. Jede Pruefung unten
traegt in ihrer Meldung den Abschnitt, aus dem sie stammt. Wenn AGENTS.md sich
aendert, aendert sich diese Datei mit — nicht umgekehrt.

Warum ueberhaupt Python und nicht eine Skill in Prosa:

    Ein Modell, das seine eigene Arbeit gegen eine Prosa-Regel prueft, prueft
    bei jedem Lauf etwas leicht anderes. Ein Linter, der 14 Regeln als Code
    fuehrt, prueft bei jedem Lauf genau dieselben 14 Regeln. Das ist der
    Unterschied zwischen "wurde geprueft" und "ist geprueft".

Nur Standardbibliothek. Kein Netzwerk, kein Subprozess. Veraendert nichts.

    python3 bin/kb_lint.py wiki
    python3 bin/kb_lint.py wiki --json
    python3 bin/kb_lint.py wiki --today 2026-08-11
    python3 bin/kb_lint.py wiki --strict        # STALE zaehlt als Fehler

Exit-Code:  0 = keine ERROR-Befunde,  1 = mindestens einer,  2 = Aufruffehler.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

# --- Aus AGENTS.md abgeleitete Konstanten. Einzige Stelle zum Nachziehen. ----
PFLICHT_KEYS = ["title", "slug", "updated", "tags", "sources", "version"]
ABSCHNITTE_PFLICHT = ["Kurzfassung", "Details", "Quellen"]
ABSCHNITTE_OPTIONAL = ["Siehe auch"]
MAX_ZEILEN = 120                      # AGENTS.md 2.3
FRESHNESS_TAGE = 180                  # AGENTS.md 5
STATUS_ERLAUBT = {"aktuell", "veraltet", "strittig"}
SLUG_RE = re.compile(r"^[a-z0-9-]+$")
DATUM_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")

SEVERITIES = ("ERROR", "STALE", "PRUNE-VORSCHLAG")


class Befund:
    def __init__(self, sev: str, datei: str, regel: str, text: str,
                 zeile: int | None = None) -> None:
        self.sev, self.datei, self.regel, self.text, self.zeile = (
            sev, datei, regel, text, zeile)

    def as_dict(self) -> dict:
        return {"severity": self.sev, "file": self.datei, "rule": self.regel,
                "line": self.zeile, "message": self.text}

    def __str__(self) -> str:
        ort = f"{self.datei}:{self.zeile}" if self.zeile else self.datei
        return f"{self.sev:<15} {ort:<34} [{self.regel}] {self.text}"


# ---------------------------------------------------------------------------
# Frontmatter
# ---------------------------------------------------------------------------
def frontmatter_lesen(zeilen: list[str]) -> tuple[dict[str, str], int]:
    """Minimal-YAML: flache key: value-Paare zwischen zwei ----Zeilen.

    Absichtlich kein PyYAML — die Wissensbasis darf keine Abhaengigkeit
    brauchen, damit der Linter ueberall laeuft, wo Python laeuft.
    Rueckgabe: (paare, zeilennummer_nach_dem_frontmatter). Ohne Frontmatter
    ist das Paar-Dict leer und die Zeilennummer 0.
    """
    if not zeilen or zeilen[0].strip() != "---":
        return {}, 0
    paare: dict[str, str] = {}
    for i, roh in enumerate(zeilen[1:], start=2):
        if roh.strip() == "---":
            return paare, i
        if ":" in roh and not roh.startswith((" ", "\t", "#")):
            key, _, val = roh.partition(":")
            paare[key.strip()] = val.strip()
    return paare, 0                    # nie geschlossen


def liste_werte(rohwert: str) -> list[str]:
    """`[a, b]` bzw. `a, b` -> ['a','b'].  Leere Liste bei `[]` oder ''."""
    s = rohwert.strip().strip("[]").strip()
    if not s:
        return []
    return [t.strip().strip("'\"") for t in s.split(",") if t.strip()]


# ---------------------------------------------------------------------------
# Die Pruefungen
# ---------------------------------------------------------------------------
def seite_pruefen(pfad: Path, slugs_vorhanden: set[str],
                  heute: dt.date) -> list[Befund]:
    name = f"pages/{pfad.name}"
    befunde: list[Befund] = []
    zeilen = pfad.read_text(encoding="utf-8").splitlines()

    # --- AGENTS.md 2.3 — Groesse -------------------------------------------
    if len(zeilen) > MAX_ZEILEN:
        befunde.append(Befund(
            "ERROR", name, "groesse",
            f"{len(zeilen)} Zeilen, erlaubt sind {MAX_ZEILEN} "
            f"(AGENTS.md 2.3: teilen, nicht kuerzen)"))

    # --- AGENTS.md 2.1 — Frontmatter ---------------------------------------
    fm, body_start = frontmatter_lesen(zeilen)
    if not fm:
        befunde.append(Befund(
            "ERROR", name, "frontmatter",
            "kein YAML-Frontmatter zwischen zwei ---Zeilen (AGENTS.md 2.1)", 1))
        return befunde                 # ohne Frontmatter ist alles Weitere Rauschen

    for key in PFLICHT_KEYS:
        if key not in fm:
            befunde.append(Befund(
                "ERROR", name, "frontmatter-key",
                f"Pflichtschluessel '{key}' fehlt (AGENTS.md 2.1)", 1))

    slug = fm.get("slug", "")
    if slug:
        if not SLUG_RE.match(slug):
            befunde.append(Befund(
                "ERROR", name, "slug-form",
                f"slug '{slug}' entspricht nicht [a-z0-9-]+ (AGENTS.md 2.1)", 1))
        if slug != pfad.stem:
            befunde.append(Befund(
                "ERROR", name, "slug-dateiname",
                f"slug '{slug}' != Dateiname '{pfad.stem}' (AGENTS.md 2.1)", 1))

    if fm.get("title", "").strip() in ("", "''", '""'):
        befunde.append(Befund("ERROR", name, "titel-leer",
                              "title ist leer (AGENTS.md 2.1)", 1))

    for key in ("tags", "sources"):
        if key in fm and not liste_werte(fm[key]):
            befunde.append(Befund(
                "ERROR", name, f"{key}-leer",
                f"{key} ist leer — mindestens ein Eintrag (AGENTS.md 2.1)", 1))

    if "status" in fm and fm["status"] not in STATUS_ERLAUBT:
        befunde.append(Befund(
            "ERROR", name, "status-wert",
            f"status '{fm['status']}' ist keiner von "
            f"{sorted(STATUS_ERLAUBT)} (AGENTS.md 2.1)", 1))

    # --- AGENTS.md 5 — Aktualitaet -----------------------------------------
    updated = fm.get("updated", "")
    if updated:
        if not DATUM_RE.match(updated):
            befunde.append(Befund(
                "ERROR", name, "updated-form",
                f"updated '{updated}' ist nicht YYYY-MM-DD (AGENTS.md 2.1)", 1))
        else:
            try:
                d = dt.date.fromisoformat(updated)
            except ValueError:
                befunde.append(Befund(
                    "ERROR", name, "updated-form",
                    f"updated '{updated}' ist kein gueltiges Datum", 1))
            else:
                alter = (heute - d).days
                if alter > FRESHNESS_TAGE:
                    befunde.append(Befund(
                        "STALE", name, "freshness",
                        f"updated {updated} ist {alter} Tage alt "
                        f"(Grenze {FRESHNESS_TAGE}) — pruefen, nicht loeschen "
                        f"(AGENTS.md 5)", 1))
                if alter < 0:
                    befunde.append(Befund(
                        "ERROR", name, "updated-zukunft",
                        f"updated {updated} liegt in der Zukunft", 1))

    if fm.get("status") == "veraltet":
        befunde.append(Befund(
            "PRUNE-VORSCHLAG", name, "status-veraltet",
            "status: veraltet — Inhalt ersetzen oder Seite entfernen. "
            "Entscheidet ein Mensch (AGENTS.md 6)", 1))

    # --- AGENTS.md 2.2 — Abschnittsreihenfolge -----------------------------
    gefunden: list[tuple[str, int]] = []
    for i, roh in enumerate(zeilen[body_start:], start=body_start + 1):
        if roh.startswith("## "):
            gefunden.append((roh[3:].strip(), i))

    titel_nur = [t for t, _ in gefunden]
    for pflicht in ABSCHNITTE_PFLICHT:
        if pflicht not in titel_nur:
            befunde.append(Befund(
                "ERROR", name, "abschnitt-fehlt",
                f"Pflichtabschnitt '## {pflicht}' fehlt (AGENTS.md 2.2)"))

    erwartet = ABSCHNITTE_PFLICHT + ABSCHNITTE_OPTIONAL
    ist_reihenfolge = [t for t in titel_nur if t in erwartet]
    soll_reihenfolge = [t for t in erwartet if t in titel_nur]
    if ist_reihenfolge != soll_reihenfolge:
        zeile = next((z for t, z in gefunden if t in erwartet), None)
        befunde.append(Befund(
            "ERROR", name, "abschnitt-reihenfolge",
            f"Reihenfolge ist {ist_reihenfolge}, erwartet {soll_reihenfolge} "
            f"(AGENTS.md 2.2)", zeile))

    for t, z in gefunden:
        if t not in erwartet:
            befunde.append(Befund(
                "ERROR", name, "abschnitt-unbekannt",
                f"'## {t}' ist kein erlaubter Abschnitt; erlaubt sind "
                f"{erwartet}, Unterabschnitte als ### (AGENTS.md 2.2)", z))

    # --- AGENTS.md 3 — Wikilinks -------------------------------------------
    for i, roh in enumerate(zeilen, start=1):
        for ziel in WIKILINK_RE.findall(roh):
            ziel = ziel.split("|")[0].strip()
            if ziel not in slugs_vorhanden:
                befunde.append(Befund(
                    "ERROR", name, "toter-link",
                    f"[[{ziel}]] zeigt auf keine Seite unter pages/ — "
                    f"Stub-Links sind Fehler, keine Absichtserklaerung "
                    f"(AGENTS.md 3)", i))

    # --- AGENTS.md 2.2 — 'Siehe auch' enthaelt nur Wikilinks ---------------
    for t, z in gefunden:
        if t != "Siehe auch":
            continue
        naechster = min((zz for _, zz in gefunden if zz > z), default=len(zeilen) + 1)
        for i in range(z + 1, min(naechster, len(zeilen) + 1)):
            inhalt = zeilen[i - 1].strip().lstrip("-* ").strip()
            if inhalt and not WIKILINK_RE.search(inhalt):
                befunde.append(Befund(
                    "ERROR", name, "siehe-auch-form",
                    "'## Siehe auch' enthaelt nur Wikilinks, einer je Zeile "
                    "(AGENTS.md 2.2)", i))
    return befunde


def index_pruefen(index: Path, slugs_vorhanden: set[str]) -> list[Befund]:
    """AGENTS.md 4 — jede Seite genau einmal verlinkt, jeder Link existiert."""
    befunde: list[Befund] = []
    if not index.is_file():
        return [Befund("ERROR", "index.md", "index-fehlt",
                       "index.md fehlt (AGENTS.md 4)")]

    zeilen = index.read_text(encoding="utf-8").splitlines()
    verlinkt: dict[str, list[int]] = {}
    for i, roh in enumerate(zeilen, start=1):
        for ziel in WIKILINK_RE.findall(roh):
            verlinkt.setdefault(ziel.split("|")[0].strip(), []).append(i)

    for ziel, zeilennummern in sorted(verlinkt.items()):
        if ziel not in slugs_vorhanden:
            befunde.append(Befund(
                "ERROR", "index.md", "index-toter-link",
                f"[[{ziel}]] zeigt auf keine Seite unter pages/ (AGENTS.md 4)",
                zeilennummern[0]))
        elif len(zeilennummern) > 1:
            befunde.append(Befund(
                "ERROR", "index.md", "index-doppelt",
                f"[[{ziel}]] ist {len(zeilennummern)}x verlinkt, erlaubt ist "
                f"genau einmal (AGENTS.md 4)", zeilennummern[1]))

    for slug in sorted(slugs_vorhanden - set(verlinkt)):
        befunde.append(Befund(
            "ERROR", "index.md", "waise",
            f"Seite '{slug}' existiert, ist aber nicht aus index.md verlinkt — "
            f"fuer einen Agenten, der ueber den Index einsteigt, gibt es sie "
            f"nicht (AGENTS.md 4)"))
    return befunde


# ---------------------------------------------------------------------------
def linten(wiki: Path, heute: dt.date) -> list[Befund]:
    pages = wiki / "pages"
    if not pages.is_dir():
        return [Befund("ERROR", str(pages), "kein-pages-verzeichnis",
                       f"{pages} existiert nicht")]

    dateien = sorted(pages.glob("*.md"))
    slugs_vorhanden = {p.stem for p in dateien}

    befunde: list[Befund] = []

    # AGENTS.md 2.3 — keine zwei Seiten mit demselben slug. Der Dateiname ist
    # eindeutig, also faellt das nur bei einem slug auf, der auf eine ANDERE
    # Seite zeigt als seine Datei — und genau das prueft slug-dateiname oben.
    # Hier bleibt der Fall, dass zwei Dateien denselben slug DEKLARIEREN.
    deklariert: dict[str, list[str]] = {}
    for p in dateien:
        fm, _ = frontmatter_lesen(p.read_text(encoding="utf-8").splitlines())
        if fm.get("slug"):
            deklariert.setdefault(fm["slug"], []).append(p.name)
    for slug, wo in sorted(deklariert.items()):
        if len(wo) > 1:
            befunde.append(Befund(
                "ERROR", f"pages/{wo[1]}", "slug-doppelt",
                f"slug '{slug}' wird auch in {wo[0]} deklariert (AGENTS.md 2.3)", 1))

    for p in dateien:
        befunde.extend(seite_pruefen(p, slugs_vorhanden, heute))
    befunde.extend(index_pruefen(wiki / "index.md", slugs_vorhanden))

    if not (wiki / "AGENTS.md").is_file():
        befunde.append(Befund("ERROR", "AGENTS.md", "vertrag-fehlt",
                              "AGENTS.md fehlt — ohne Vertrag ist der Linter "
                              "eine Meinung"))
    return befunde


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="kb_lint",
        description="Validiert die Wissensbasis gegen wiki/AGENTS.md. "
                    "Veraendert nichts.")
    ap.add_argument("wiki", help="Pfad auf das wiki/-Verzeichnis")
    ap.add_argument("--json", action="store_true", help="maschinenlesbar")
    ap.add_argument("--today", metavar="YYYY-MM-DD",
                    help="Bezugsdatum fuer die Freshness-Pruefung "
                         "(Standard: heute) — macht Testlaeufe reproduzierbar")
    ap.add_argument("--strict", action="store_true",
                    help="STALE zaehlt als Fehler (Exit 1)")
    args = ap.parse_args(argv)

    wiki = Path(args.wiki).expanduser()
    if not wiki.is_dir():
        print(f"kb_lint: {wiki} ist kein Verzeichnis", file=sys.stderr)
        return 2
    try:
        heute = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
    except ValueError:
        print(f"kb_lint: --today '{args.today}' ist kein YYYY-MM-DD",
              file=sys.stderr)
        return 2

    befunde = linten(wiki, heute)
    zaehler = {s: sum(1 for b in befunde if b.sev == s) for s in SEVERITIES}
    fehler = zaehler["ERROR"] + (zaehler["STALE"] if args.strict else 0)

    if args.json:
        print(json.dumps({
            "wiki": str(wiki), "today": heute.isoformat(), "strict": args.strict,
            "counts": zaehler, "error_count": fehler,
            "findings": [b.as_dict() for b in befunde],
        }, indent=2, ensure_ascii=False))
        return 1 if fehler else 0

    seiten = len(list((wiki / "pages").glob("*.md"))) if (wiki / "pages").is_dir() else 0
    print(f"kb_lint — {wiki}  ({seiten} Seiten, Bezugsdatum {heute})")
    print("=" * 78)
    if befunde:
        for sev in SEVERITIES:
            gruppe = [b for b in befunde if b.sev == sev]
            if gruppe:
                print()
                for b in gruppe:
                    print(f"  {b}")
    else:
        print("\n  keine Befunde")
    print()
    print("-" * 78)
    print("  ".join(f"{s}: {zaehler[s]}" for s in SEVERITIES))
    if fehler:
        print(f"\nFEHLGESCHLAGEN — {fehler} Befund(e), die einen Merge sperren.")
    else:
        print("\nBESTANDEN — keine ERROR-Befunde. Ein Merge ist erlaubt.")
        if zaehler["STALE"] or zaehler["PRUNE-VORSCHLAG"]:
            print("Es liegen Prune-Kandidaten vor. Darueber entscheidet ein "
                  "Mensch (AGENTS.md 6).")
    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
