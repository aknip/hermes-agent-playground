#!/usr/bin/env python3
"""ESF — Werkzeugkasten des Video-Kanals (AGENTS.md 8).

Unterbefehle, jeder deterministisch und einzeln testbar:

    jobs <vault>                  Dokumente finden, deren Video fehlt oder
                                  aelter ist als das Dokument. Eine Zeile je
                                  Job: <dokument>\t<mp4>\t<vtt>
    extrahiere <dokument> <dir>   titel.txt, skript.txt und saetze.txt (eine
                                  Zeile je Satz) aus dem Dokument ziehen
    vtt <saetze.txt> <sekunden>   WebVTT auf stdout: die Gesamtdauer wird
                                  proportional zur Wortzahl auf die Saetze
                                  verteilt — die Cues passen zum `say`-Audio,
                                  ohne dass eine Sprach-API Zeitmarken liefern
                                  muss
    komposition <template> <ziel> <titel.txt> <saetze.txt> <audio> <sekunden>
                                  die Hyperframes-Vorlage instanziieren:
                                  kopiert das Template und schreibt daten.js

Kein Netz, kein Modell, keine Seiteneffekte ausserhalb der genannten Pfade.
"""
import html
import json
import os
import re
import shutil
import sys

SCOPE = ("analysis", "roadmap", "reports")


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


def sichtbar(html_text):
    t = re.sub(r"<[^>]+>", " ", html_text or "")
    return re.sub(r"\s+", " ", html.unescape(t)).strip()


def saetze(text):
    # Satzgrenzen: . ! ? gefolgt von Leerraum. Abkürzungen sind selten genug,
    # dass ein falsch geteilter Satz nur eine Cue-Grenze verschiebt.
    teile = re.split(r"(?<=[.!?])\s+", text)
    return [t.strip() for t in teile if t.strip()]


def cmd_jobs(vault):
    for ordner in SCOPE:
        wurzel = os.path.join(vault, ordner)
        if not os.path.isdir(wurzel):
            continue
        for dirpath, _, dateien in os.walk(wurzel):
            # e2e-Akten und Video-Ordner sind Ergebnisse, keine Quellen.
            rel_dir = os.path.relpath(dirpath, vault)
            if re.search(r"(^|/)(e2e-|gate-videos)", rel_dir):
                continue
            for d in dateien:
                if not d.endswith(".html"):
                    continue
                pfad = os.path.join(dirpath, d)
                text = open(pfad, encoding="utf-8", errors="replace").read()
                video = meta(text, "esf-video")
                if not video or section(text, "video-skript") is None:
                    continue
                mp4 = os.path.join(dirpath, video)
                vtt = os.path.splitext(mp4)[0] + ".vtt"
                if os.path.exists(mp4) and os.path.getmtime(mp4) >= os.path.getmtime(pfad):
                    continue
                print(f"{pfad}\t{mp4}\t{vtt}")
    return 0


def cmd_extrahiere(dokument, ziel):
    text = open(dokument, encoding="utf-8", errors="replace").read()
    skript_html = section(text, "video-skript")
    if skript_html is None:
        print(f"FEHLER: {dokument} hat keinen Abschnitt 'video-skript'", file=sys.stderr)
        return 1
    skript = sichtbar(skript_html)
    if len(skript.split()) < 20:
        print(f"FEHLER: video-skript hat nur {len(skript.split())} Woerter — kein Sprechertext", file=sys.stderr)
        return 1
    t = re.search(r"<title\b[^>]*>(.*?)</title>", text, re.I | re.S)
    titel = sichtbar(t.group(1)) if t else os.path.basename(dokument)
    titel = re.sub(r"\s*—\s*ESF\s*$", "", titel)
    os.makedirs(ziel, exist_ok=True)
    open(os.path.join(ziel, "titel.txt"), "w", encoding="utf-8").write(titel + "\n")
    open(os.path.join(ziel, "skript.txt"), "w", encoding="utf-8").write(skript + "\n")
    with open(os.path.join(ziel, "saetze.txt"), "w", encoding="utf-8") as f:
        for s in saetze(skript):
            f.write(s + "\n")
    return 0


def ts(sek):
    ms = int(round(sek * 1000))
    return f"{ms//3600000:02d}:{ms%3600000//60000:02d}:{ms%60000//1000:02d}.{ms%1000:03d}"


def cmd_vtt(saetze_datei, dauer):
    zeilen = [z.strip() for z in open(saetze_datei, encoding="utf-8") if z.strip()]
    if not zeilen:
        print("FEHLER: keine Saetze", file=sys.stderr)
        return 1
    dauer = float(dauer)
    gewichte = [max(1, len(z.split())) for z in zeilen]
    gesamt = sum(gewichte)
    print("WEBVTT\n")
    t = 0.0
    for i, (z, g) in enumerate(zip(zeilen, gewichte), 1):
        anteil = dauer * g / gesamt
        print(i)
        print(f"{ts(t)} --> {ts(min(t + anteil, dauer))}")
        print(z)
        print()
        t += anteil
    return 0


def cmd_komposition(template, ziel, titel_datei, saetze_datei, audio, dauer):
    """Instanziiert die Hyperframes-Vorlage fuer EINEN Job.

    Die Root-Attribute und die Clips muessen STATISCH im HTML stehen: `hyperframes
    lint` liest das Dokument, bevor JavaScript laeuft, und der Renderer setzt die
    Timeline je Frame auf die Zielzeit. Eine frueher hier erzeugte daten.js, die
    das Bild zur Laufzeit aufbaute, war genau deshalb ungueltig (gemessen gegen
    0.8.3: root_missing_dimensions, missing_timeline_registry, media_missing_src).
    """
    if os.path.exists(ziel):
        shutil.rmtree(ziel)
    shutil.copytree(template, ziel)
    audio_name = "audio" + os.path.splitext(audio)[1]
    shutil.copy(audio, os.path.join(ziel, audio_name))

    titel = open(titel_datei, encoding="utf-8").read().strip()
    zeilen = [z.strip() for z in open(saetze_datei, encoding="utf-8") if z.strip()]
    dauer = float(dauer)

    # Dieselbe Gewichtung wie cmd_vtt: die gemessene Gesamtdauer proportional
    # zur Wortzahl je Satz. Bild und Untertitel teilen damit EINE Zeitquelle.
    gewichte = [max(1, len(z.split())) for z in zeilen]
    gesamt = sum(gewichte)
    # Grenzen aus GERUNDETEN Startwerten ableiten: rundet man Start und Dauer
    # unabhaengig, ueberlappen benachbarte Clips um eine Millisekunde und
    # `hyperframes lint` meldet overlapping_clips_same_track (gemessen 0.8.3).
    starts, t = [], 0.0
    for g in gewichte:
        starts.append(round(t, 3))
        t += dauer * g / gesamt
    grenzen = starts + [round(dauer, 3)]
    cues = [(z, starts[i], round(grenzen[i + 1] - starts[i], 3))
            for i, z in enumerate(zeilen)]

    clips = []
    for i, (text, start, laenge) in enumerate(cues):
        clips.append(
            '  <div class="cue clip" id="cue{i}" data-start="{s}" '
            'data-duration="{d}" data-track-index="1">{t}</div>'.format(
                i=i, s=start, d=laenge, t=html.escape(text)))

    # KEINE Opacity-Tweens auf Clips: Hyperframes verwaltet deren Sichtbarkeit
    # selbst (gemessen: gsap_exit_missing_hard_kill, wenn man ihm hineinregiert).
    tweens = []

    index = os.path.join(ziel, "index.html")
    text = open(index, encoding="utf-8").read()
    for platzhalter, wert in (
        ("__DAUER__", repr(round(dauer, 3))),
        ("__AUDIO__", audio_name),
        ("__TITEL__", html.escape(titel)),
        ("__CUE_CLIPS__", "\n".join(clips)),
        ("__CUE_TWEENS__", "\n".join(tweens)),
    ):
        text = text.replace(platzhalter, wert)
    if "__" in re.sub(r"__timelines", "", text):
        offen = set(re.findall(r"__[A-Z_]+__", text))
        if offen:
            print("Platzhalter nicht ersetzt: " + ", ".join(sorted(offen)), file=sys.stderr)
            return 1
    open(index, "w", encoding="utf-8").write(text)
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, args = sys.argv[1], sys.argv[2:]
    try:
        if cmd == "jobs" and len(args) == 1:
            return cmd_jobs(args[0])
        if cmd == "extrahiere" and len(args) == 2:
            return cmd_extrahiere(*args)
        if cmd == "vtt" and len(args) == 2:
            return cmd_vtt(*args)
        if cmd == "komposition" and len(args) == 6:
            return cmd_komposition(*args)
    except OSError as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        return 2
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
