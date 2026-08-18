#!/usr/bin/env python3
"""
ESF — Vault-Linter
==================

Prueft den Firmen-Vault gegen company/AGENTS.md und zitiert bei jedem Befund
den Abschnitt. Das ist der Riegel hinter dem Vertrag: Eine Regel in einer
SOUL.md gilt, solange das Modell sie liest — dieser Linter gilt immer.

    vault-lint.py <vault-verzeichnis> [--json] [--strict]

Exit 0 = sauber, Exit 1 = ERROR gefunden, Exit 2 = Aufrufproblem.
Mit --strict zaehlen auch WARNs als Fehlschlag.

Getestet mit: Python 3.9+ auf macOS
"""
import argparse
import json
import os
import re
import sys

# AGENTS.md 1 — die Ordner, die es geben darf
ERLAUBTE_ORDNER = {
    "roadmap", "decisions", "analysis", "sources", "specs", "reports", "ledger",
}
# AGENTS.md 2.1 — was bewusst Markdown/YAML bleiben darf, auf oberster Ebene
ERLAUBTE_WURZELDATEIEN = {"AGENTS.md", "cadence.yaml", ".gitignore"}

# AGENTS.md 2.2 — Pflicht-Kopf jedes Dokuments
PFLICHT_META = ("esf-typ", "esf-karte", "esf-datum")
ERLAUBTE_TYPEN = {"analyse", "adr", "spec", "report", "roadmap", "katalog"}

# AGENTS.md 2.3 — Dateinamen
# Endungen duerfen Ziffern tragen (mp4, m4a) — seit AGENTS.md 8 liegen
# Medien-Akten neben ihren Dokumenten.
NAME_OK = re.compile(r"^[a-z0-9][a-z0-9.-]*\.[a-z0-9]+$")
ADR_NAME_OK = re.compile(r"^ADR-\d{3}-[a-z0-9-]+\.html$")

# AGENTS.md 4 — ein ADR hat fuenf Abschnitte
ADR_ABSCHNITTE = ("Kontext", "Optionen", "Entscheidung", "Konsequenzen", "Revision")

# AGENTS.md 6 — Pflichtfelder je Ledger-Zeile
LEDGER_PFLICHT = ("task_id", "reference_class", "profile", "estimate", "actual", "at")

DATUM = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class Befunde:
    def __init__(self):
        self.eintraege = []

    def melde(self, grad, abschnitt, pfad, text):
        self.eintraege.append(
            {"grad": grad, "abschnitt": abschnitt, "datei": pfad, "text": text}
        )

    def error(self, abschnitt, pfad, text):
        self.melde("ERROR", abschnitt, pfad, text)

    def warn(self, abschnitt, pfad, text):
        self.melde("WARN", abschnitt, pfad, text)

    def zaehle(self, grad):
        return sum(1 for e in self.eintraege if e["grad"] == grad)


def meta_werte(text):
    """Die <meta name=… content=…> eines Dokuments, tolerant gegen Attributfolge."""
    gefunden = {}
    for tag in re.findall(r"<meta\b[^>]*>", text, re.I):
        name = re.search(r'name\s*=\s*["\']([^"\']+)["\']', tag, re.I)
        inhalt = re.search(r'content\s*=\s*["\']([^"\']*)["\']', tag, re.I)
        if name:
            gefunden[name.group(1).lower()] = inhalt.group(1) if inhalt else ""
    return gefunden


def pruefe_dokument(pfad, rel, b):
    try:
        text = open(pfad, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as fehler:
        b.error("2.1", rel, f"nicht lesbar: {fehler}")
        return

    if not text.lstrip().lower().startswith("<!doctype html"):
        b.error("2.2", rel, "fehlender <!doctype html> am Dateianfang")

    meta = meta_werte(text)
    for schluessel in PFLICHT_META:
        if schluessel not in meta:
            b.error("2.2", rel, f"Pflicht-Meta <meta name=\"{schluessel}\"> fehlt")

    typ = meta.get("esf-typ")
    if typ and typ not in ERLAUBTE_TYPEN:
        b.error("2.2", rel, f"esf-typ '{typ}' ist keiner von {sorted(ERLAUBTE_TYPEN)}")

    datum = meta.get("esf-datum")
    if datum and not DATUM.match(datum):
        b.error("2.2", rel, f"esf-datum '{datum}' ist nicht JJJJ-MM-TT")

    karte = meta.get("esf-karte")
    if karte is not None and not karte.strip():
        b.error("2.2", rel, "esf-karte ist leer — der Weg zurueck zur Entscheidung fehlt")

    if not re.search(r"<title\b[^>]*>\s*\S", text, re.I):
        b.warn("2.2", rel, "kein <title> — im Browser nicht wiederzuerkennen")

    # AGENTS.md 8 — Video-Zusammenfassung: Meta und Skript-Abschnitt gehoeren
    # zusammen. Nur eines von beiden ist der Fehler, der spaeter keiner mehr
    # zu sein scheint: ein Meta ohne Skript rendert nie, ein Skript ohne Meta
    # wird nie gefunden. Das VIDEO selbst darf fehlen — es entsteht asynchron
    # durch scripts/video-render.sh.
    oberster_ordner = rel.replace("\\", "/").split("/")[0]
    hat_video_meta = "esf-video" in meta
    hat_skript = re.search(
        r'<section\b[^>]*\bid\s*=\s*["\']video-skript["\']', text, re.I) is not None
    if hat_video_meta != hat_skript:
        fehlt = "der Abschnitt video-skript" if hat_video_meta else "das Meta esf-video"
        b.error("8", rel, f"Video-Zusammenfassung unvollstaendig — {fehlt} fehlt")
    if hat_video_meta:
        erwartet = os.path.splitext(os.path.basename(rel))[0] + ".mp4"
        if meta.get("esf-video") != erwartet:
            b.error("8", rel, f"esf-video muss '{erwartet}' heissen (Namenskonvention traegt die Zuordnung)")
    elif oberster_ordner in ("analysis", "roadmap", "reports"):
        # WARN, nicht ERROR: Dokumente aus den Phasen 0-2 tragen noch keine
        # Skripte, und restore-phase1.sh spielt sie unveraendert zurueck.
        b.warn("8", rel, "keine Video-Zusammenfassung (video-skript + esf-video) — AGENTS.md 8")

    # AGENTS.md 4 — ADRs tragen fuenf Abschnitte
    if os.path.basename(rel).startswith("ADR-"):
        sichtbar = re.sub(r"<[^>]+>", " ", text)
        for abschnitt in ADR_ABSCHNITTE:
            if not re.search(rf"\b{abschnitt}\b", sichtbar, re.I):
                b.error("4", rel, f"ADR ohne Abschnitt '{abschnitt}'")


def pruefe_ledger(pfad, rel, b):
    try:
        zeilen = open(pfad, encoding="utf-8").read().splitlines()
    except OSError as fehler:
        b.error("6", rel, f"nicht lesbar: {fehler}")
        return
    for nr, zeile in enumerate(zeilen, 1):
        if not zeile.strip():
            continue
        try:
            objekt = json.loads(zeile)
        except json.JSONDecodeError as fehler:
            b.error("6", f"{rel}:{nr}", f"keine gueltige JSON-Zeile: {fehler}")
            continue
        if not isinstance(objekt, dict):
            b.error("6", f"{rel}:{nr}", "Zeile ist kein JSON-Objekt")
            continue
        for feld in LEDGER_PFLICHT:
            if feld not in objekt:
                b.error("6", f"{rel}:{nr}", f"Pflichtfeld '{feld}' fehlt")
        # Eine hineingeschriebene Vermutung ist schlimmer als eine Luecke.
        ist = objekt.get("actual")
        if isinstance(ist, dict) and "wall_minutes" not in ist:
            b.error("6", f"{rel}:{nr}", "actual ohne wall_minutes (null ist erlaubt, Weglassen nicht)")


def pruefe_jsonl_form(pfad, rel, b):
    """Jede andere .jsonl unter ledger/: nur die FORM, nicht das Schema.

    Die Datei muss zeilenweise gueltiges JSON mit Objekten sein — das ist die
    Eigenschaft, auf die sich jedes lesende Skript verlaesst (jq -s, grep auf
    ein Feld). Welche Felder darin stehen, legt das schreibende Skript fest;
    AGENTS.md 6 schreibt es nur fuer estimates.jsonl vor.
    """
    try:
        zeilen = open(pfad, encoding="utf-8").read().splitlines()
    except OSError as fehler:
        b.error("6", rel, f"nicht lesbar: {fehler}")
        return
    for nr, zeile in enumerate(zeilen, 1):
        if not zeile.strip():
            continue
        try:
            objekt = json.loads(zeile)
        except json.JSONDecodeError as fehler:
            b.error("6", f"{rel}:{nr}", f"keine gueltige JSON-Zeile: {fehler}")
            continue
        if not isinstance(objekt, dict):
            b.error("6", f"{rel}:{nr}", "Zeile ist kein JSON-Objekt")


def pruefe_vault(wurzel, b):
    if not os.path.isdir(wurzel):
        print(f"FEHLER: '{wurzel}' ist kein Verzeichnis.", file=sys.stderr)
        return 2

    # AGENTS.md 1.1 — keine Datei ausserhalb der bekannten Ordner
    for eintrag in sorted(os.listdir(wurzel)):
        if eintrag.startswith("."):
            continue
        voll = os.path.join(wurzel, eintrag)
        if os.path.isdir(voll):
            if eintrag not in ERLAUBTE_ORDNER:
                b.error("1.1", eintrag + "/", "unbekanntes Verzeichnis — ein neuer Ordner braucht ein ADR")
        elif eintrag not in ERLAUBTE_WURZELDATEIEN:
            b.error("1.1", eintrag, "Datei liegt ausserhalb der bekannten Ordner")

    for ordner, unterordner, dateien in os.walk(wurzel):
        unterordner[:] = [u for u in unterordner if not u.startswith(".")]
        for datei in sorted(dateien):
            if datei.startswith("."):
                continue
            pfad = os.path.join(ordner, datei)
            rel = os.path.relpath(pfad, wurzel)
            oberster = rel.split(os.sep)[0]

            if oberster == "ledger":
                # AGENTS.md 6 spezifiziert GENAU EINE Datei: estimates.jsonl.
                # Ihr Pflichtfeld-Schema auf jede .jsonl unter ledger/
                # anzuwenden war eine Uebergriffigkeit des Pruefers — real
                # aufgefallen am 17.08.2026, als ledger-sync.sh die
                # kosten-je-rolle.jsonl anlegte (Schema {at, profile,
                # usage_total, usage_delta}) und der Linter vier Pflichtfelder
                # je Zeile vermisste, die dort nichts zu suchen haben. Der
                # Sprint-Report von S1 trug den Befund als offenen Punkt.
                #
                # Ein Pruefer, der mehr verlangt als der Vertrag hergibt, ist
                # so schaedlich wie einer, der zu wenig prueft: Beide erzeugen
                # Befunde, die niemand mehr liest.
                if datei == "estimates.jsonl":
                    pruefe_ledger(pfad, rel, b)
                elif datei.endswith(".jsonl"):
                    pruefe_jsonl_form(pfad, rel, b)
                continue

            # sources/ ist der Rohkorpus — Fremdformate sind dort der Zweck.
            if oberster == "sources":
                continue

            # reports/e2e-<datum>/ sind Traces und Screenshots, keine Dokumente.
            if re.match(r"^reports[/\\]e2e-", rel):
                continue

            # <basisname>.komposition/ ist das ARBEITSVERZEICHNIS des Video-Kanals
            # (AGENTS.md 8.1): index.html ist eine Hyperframes-Szene, kein
            # Vault-Dokument — sie traegt keinen Dokumentkopf und soll keinen
            # tragen. Geprueft wird sie von `video-werkzeug.py pruefe` und
            # `hyperframes lint`, nicht von hier. Ohne diese Ausnahme melden die
            # drei Pflicht-Metas als ERROR und blockieren den Vault.
            if re.search(r"(^|[/\\])[^/\\]+\.komposition([/\\]|$)", rel):
                continue

            # AGENTS.md 2.1 — Maschinenprotokolle unter reports/ (Riegel-Läufe,
            # Testausgaben) bleiben Rohtext. Ein Rohbeleg, den jemand fürs
            # Format angefasst hat, ist keiner mehr.
            if oberster == "reports" and datei.endswith((".txt", ".log")):
                continue

            if oberster not in ERLAUBTE_ORDNER:
                continue  # oben schon gemeldet

            if not NAME_OK.match(datei) and not ADR_NAME_OK.match(datei):
                b.error("2.3", rel, "Dateiname: nur Kleinbuchstaben, Ziffern und Bindestriche (ADR-nnn-… ausgenommen)")

            if datei.endswith(".html"):
                pruefe_dokument(pfad, rel, b)
            elif datei.endswith((".md", ".txt")):
                b.error("2.1", rel, "Doku-Artefakte sind .html — Markdown nur fuer AGENTS/SOUL/SKILL/Plaene")
            elif datei.endswith((".mp4", ".webm", ".m4a", ".vtt")):
                # AGENTS.md 8: Video-Zusammenfassungen und ihre Untertitel sind
                # Render-Akten neben ihrem Dokument — erlaubt, nicht geprueft.
                pass
            elif not datei.endswith((".yaml", ".yml", ".json", ".jsonl")):
                b.warn("2.1", rel, "unerwartete Dateiendung im Vault")

            if datei.endswith(".html") and oberster == "decisions" and not ADR_NAME_OK.match(datei):
                b.error("4", rel, "ADR-Dateiname muss ADR-nnn-slug.html sein")
    return 0


def main():
    p = argparse.ArgumentParser(description="ESF-Vault gegen AGENTS.md pruefen")
    p.add_argument("vault", help="Pfad zum company/-Verzeichnis")
    p.add_argument("--json", action="store_true", help="Befunde als JSON ausgeben")
    p.add_argument("--strict", action="store_true", help="WARN zaehlt wie ERROR")
    args = p.parse_args()

    b = Befunde()
    rc = pruefe_vault(args.vault, b)
    if rc == 2:
        return 2

    if args.json:
        print(json.dumps(b.eintraege, ensure_ascii=False, indent=2))
    else:
        for e in b.eintraege:
            print(f"{e['grad']:5}  AGENTS.md {e['abschnitt']:4}  {e['datei']}: {e['text']}")
        fehler, warnungen = b.zaehle("ERROR"), b.zaehle("WARN")
        print(f"\n{fehler} ERROR, {warnungen} WARN in {args.vault}")

    if b.zaehle("ERROR") or (args.strict and b.zaehle("WARN")):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
