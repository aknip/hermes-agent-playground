#!/usr/bin/env python3
"""ESF — Sprecher-Audio über OpenRouter (AGENTS.md 8).

    tts-openrouter.py <text-datei> <ziel.wav> [--modell M] [--stimme V] [--profil P]

Warum nicht lokal: `hyperframes tts` bringt Kokoro-82M mit und wäre der
naheliegende lokale Weg — aber Kokoro kennt **kein Deutsch** (Sprachliste
gemessen an 0.8.3: en-us, en-gb, es, fr-fr, hi, it, pt-br, ja, zh). macOS
liefert für de_DE nur die alte Kompaktstimme „Anna" plus Spaßstimmen; die
Premium-Stimmen brauchen einen GUI-Download. Also OpenRouter — KEIN neuer
Cloud-Service, sondern derselbe Provider, über den die ganze ESF ohnehin läuft.
Abgerechnet wird über den Key des Video-Profils, damit die Kosten des Kanals
dort auftauchen, wo sie entstehen.

Zwei Eigenheiten, beide gemessen am 18.08.2026:

  1. Audio-Ausgabe verlangt `stream: true` — ohne kommt HTTP 400
     „Audio output requires stream: true". Die Chunks liegen base64-kodiert in
     delta.audio.data.
  2. Ein Sprachmodell ist KEIN TTS-Gerät: es kann umformulieren, kürzen oder
     kommentieren. Genau das wäre hier fatal, denn die `.vtt`-Cues entstehen aus
     den SÄTZEN DES DOKUMENTS und der gemessenen Dauer. Weicht das Gesprochene
     ab, driften Untertitel und Bild. Deshalb vergleicht dieses Skript das
     mitgelieferte Transkript mit dem Eingabetext und verweigert die Datei,
     wenn die Abweichung zu groß ist — der Aufrufer fällt dann auf `say`
     zurück, das wörtlich liest.
"""
import argparse
import base64
import difflib
import json
import os
import re
import struct
import sys
import urllib.error
import urllib.request

RATE, KANAELE, BITS = 24000, 1, 16   # pcm16 der OpenAI-Audio-Modelle
MINDEST_AEHNLICHKEIT = 0.92


def key_lesen(profil):
    env = os.path.expanduser("~/.hermes/profiles/%s/.env" % profil)
    if os.path.isfile(env):
        for zeile in open(env, encoding="utf-8"):
            m = re.match(r"\s*OPENROUTER_API_KEY\s*=\s*[\"']?([^\"'\s]+)", zeile)
            if m:
                return m.group(1)
    # Rückfall: Root-Konfiguration der Maschine
    for ort in ("~/.hermes/.env", "~/.hermes/config.yaml"):
        p = os.path.expanduser(ort)
        if os.path.isfile(p):
            for zeile in open(p, encoding="utf-8", errors="replace"):
                m = re.search(r"OPENROUTER_API_KEY\s*[:=]\s*[\"']?([^\"'\s]+)", zeile)
                if m:
                    return m.group(1)
    return None


def normalisieren(text):
    """Für den Vergleich: Ziffern und Zahlwörter sind NICHT unterscheidbar.

    Das Transkript schreibt „19", wo der Text „neunzehn" sagt — gesprochen ist
    beides gleich. Verglichen wird deshalb auf Wortebene ohne Satzzeichen und
    ohne Ziffern/Zahlwörter, die sonst falschen Alarm auslösen.
    """
    t = text.lower()
    t = re.sub(r"[^\wäöüß\s]", " ", t)
    zahlwoerter = ("null eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf "
                   "dreizehn vierzehn fünfzehn sechzehn siebzehn achtzehn neunzehn zwanzig "
                   "dreißig vierzig fünfzig hundert tausend prozent komma punkte punkt").split()
    woerter = [w for w in t.split() if not w.isdigit() and w not in zahlwoerter]
    return woerter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("textdatei")
    ap.add_argument("ziel")
    ap.add_argument("--modell", default=os.environ.get("ESF_TTS_MODELL", "openai/gpt-audio"))
    ap.add_argument("--stimme", default=os.environ.get("ESF_TTS_STIMME", "alloy"))
    ap.add_argument("--profil", default=os.environ.get("ESF_TTS_PROFIL", "esf-video-designer"))
    a = ap.parse_args()

    text = open(a.textdatei, encoding="utf-8").read().strip()
    if not text:
        print("FEHLER: leerer Sprechertext", file=sys.stderr)
        return 2
    key = key_lesen(a.profil)
    if not key:
        print("FEHLER: kein OPENROUTER_API_KEY (Profil %s)" % a.profil, file=sys.stderr)
        return 3

    koerper = {
        "model": a.modell,
        "modalities": ["text", "audio"],
        "audio": {"voice": a.stimme, "format": "pcm16"},
        "stream": True,
        "messages": [
            {"role": "system",
             "content": "Du bist ein professioneller Sprecher fuer Unternehmensvideos. "
                        "Lies den Text des Nutzers WORTWOERTLICH auf Hochdeutsch vor: "
                        "sachlich, ruhig, gleichmaessiges Tempo. Fuege nichts hinzu, "
                        "lasse nichts weg, kommentiere nicht, stelle keine Rueckfragen."},
            {"role": "user", "content": text},
        ],
    }
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(koerper).encode(),
        headers={"Authorization": "Bearer " + key,
                 "Content-Type": "application/json",
                 "Accept": "text/event-stream"},
    )
    stuecke, transkript, usage = [], [], {}
    try:
        with urllib.request.urlopen(req, timeout=900) as r:
            for rohzeile in r:
                zeile = rohzeile.decode("utf-8", "replace").strip()
                if not zeile.startswith("data:"):
                    continue
                nutz = zeile[5:].strip()
                if nutz in ("", "[DONE]"):
                    continue
                try:
                    ev = json.loads(nutz)
                except json.JSONDecodeError:
                    continue
                if ev.get("usage"):
                    usage = ev["usage"]
                for w in ev.get("choices") or []:
                    stueck = (w.get("delta") or {}).get("audio") or {}
                    if stueck.get("data"):
                        stuecke.append(base64.b64decode(stueck["data"]))
                    if stueck.get("transcript"):
                        transkript.append(stueck["transcript"])
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
        detail = e.read().decode()[:300] if hasattr(e, "read") else str(e)
        print("FEHLER: OpenRouter — %s" % detail, file=sys.stderr)
        return 4

    if not stuecke:
        print("FEHLER: kein Audio im Stream", file=sys.stderr)
        return 5

    # Wörtlichkeit prüfen, BEVOR die Datei als gültig gilt.
    gesprochen = "".join(transkript).strip()
    if gesprochen:
        soll, ist = normalisieren(text), normalisieren(gesprochen)
        aehnlich = difflib.SequenceMatcher(None, soll, ist).ratio()
        if aehnlich < MINDEST_AEHNLICHKEIT:
            print("FEHLER: Transkript weicht vom Sprechertext ab "
                  "(Wortaehnlichkeit %.3f < %.2f) — das Modell hat nicht woertlich "
                  "gelesen, die Untertitel wuerden driften"
                  % (aehnlich, MINDEST_AEHNLICHKEIT), file=sys.stderr)
            return 6
    else:
        aehnlich = None

    pcm = b"".join(stuecke)
    blockaus = KANAELE * BITS // 8
    kopf = (b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " +
            struct.pack("<IHHIIHH", 16, 1, KANAELE, RATE, RATE * blockaus,
                        blockaus, BITS) +
            b"data" + struct.pack("<I", len(pcm)))
    with open(a.ziel, "wb") as f:
        f.write(kopf + pcm)

    dauer = len(pcm) / (RATE * blockaus)
    teile = ["%s/%s" % (a.modell.split("/")[-1], a.stimme), "%.2fs" % dauer]
    if aehnlich is not None:
        teile.append("woertlich %.3f" % aehnlich)
    if usage.get("cost") is not None:
        teile.append("$%.4f" % float(usage["cost"]))
    print("  ".join(teile), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
