# AGENTS.md — der Vertrag des Firmen-Vaults

Dieser Vault ist das Gedächtnis der ESF. Wer hier schreibt, hält sich an diesen
Vertrag; `scripts/vault-lint.py` prüft ihn und zitiert bei jedem Befund den
Abschnitt. Die Rolle, die schreibt, und die Rolle, die prüft, lesen dieselbe
Spezifikation — das ist der Punkt.

## 1 Struktur

    company/
    ├── AGENTS.md              dieser Vertrag
    ├── cadence.yaml           Kadenz-Limits & Autonomie-Horizont
    ├── roadmap/               lebende Roadmap + eingefrorene, freigegebene Stände
    ├── decisions/             ADR-<nr>-<slug>.html
    ├── analysis/              Phase-0-Berichte, fortgeschriebene Bilder
    ├── sources/<datum>/       der Markt-Korpus des Tages (Rohformate)
    ├── specs/                 Feature-Spezifikationen mit Akzeptanzkriterien
    ├── reports/               Sprint-, Release-, Gate-, Controller-Reports
    │   └── e2e-<datum>/       Traces und Screenshots eines Regressionslaufs
    └── ledger/estimates.jsonl jedes (Schätzung, Ist)-Paar, eine Zeile je Objekt

### 1.1 Nichts entsteht außerhalb dieser Ordner

Eine Datei, die woanders landet, findet niemand wieder. Wer ein neues
Verzeichnis braucht, begründet es in einem ADR.

## 2 Format

### 2.1 Dokumentation ist HTML

Alle Doku-Artefakte — Analysen, Roadmap-Stände, ADRs, Spezifikationen,
Journey-Katalog, sämtliche Reports — werden als `.html` abgelegt: im Browser
lesbar, untereinander verlinkbar, direkt als CEO-Vorlage tauglich.

Ausgenommen und bewusst Markdown sind nur die Dateien, deren Werkzeuge es
vorsehen: `AGENTS.md`, `SOUL.md`, `SKILL.md`, die Pläne aus `writing-plans` —
und `cadence.yaml` plus `estimates.jsonl`, die maschinengelesen werden.

Ebenfalls ausgenommen sind **Maschinenprotokolle** unter `reports/`: die
Ausgabe eines Riegel-Laufs, eines Testlaufs, eines Skripts. Sie liegen als
`.txt` oder `.log` und werden **nicht** umformatiert. Sie sind Rohbelege, und
ein Rohbeleg, den jemand für die Darstellung angefasst hat, ist keiner mehr.
Wer sie zitiert, verlinkt sie aus einem `.html`-Report.

### 2.2 Jedes HTML-Dokument trägt einen Kopf

    <!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <title>… — ESF</title>
      <meta name="esf-typ" content="analyse|adr|spec|report|roadmap|katalog">
      <meta name="esf-karte" content="<task-id>">
      <meta name="esf-datum" content="JJJJ-MM-TT">
    </head>

`esf-karte` ist die Karte, die das Dokument erzeugt hat. Ohne sie ist der Weg
vom Dokument zurück zur Entscheidung unterbrochen.

### 2.3 Dateinamen sind Kleinbuchstaben mit Bindestrich

`codebase.html`, `ADR-007-worktree-isolation.html`, `sprint-03-report.html`.
Keine Leerzeichen, keine Umlaute im Dateinamen.

## 3 Inhalt

### 3.1 Jede Behauptung nennt ihren Beleg

Eine Aussage über den Code zitiert `datei.py:123`. Eine Aussage über den Markt
zitiert die Datei unter `sources/<datum>/`. Eine Zahl nennt ihre Messung.
Was keinen Beleg hat, wird als `Annahme` gekennzeichnet — sichtbar, nicht in
einer Fußnote.

Der Maßstab: Ein Leser muss jede Behauptung in unter einer Minute nachprüfen
können.

### 3.2 Zeitstempel schreibt das System, nie das Modell

Modellgeschriebene Datumsangaben waren nachweislich unstimmig. Verlässlich sind
Board-Zeitstempel und Skript-Ausgaben.

### 3.3 Widersprüche werden nebeneinandergestellt, nicht geglättet

Wenn eine neue Erkenntnis einer bestehenden widerspricht, stehen beide da, mit
Datum und Quelle, und es steht dabei, dass eine falsch ist. Ein Vault, der
Widersprüche still zugunsten des Neueren auflöst, wäscht schlechte Information
in eine Quelle der Wahrheit.

## 4 ADRs

Ein ADR hat fünf Abschnitte, alle Pflicht: **Kontext**, **Optionen** (mindestens
zwei, jede mit Konsequenz), **Entscheidung**, **Konsequenzen**, **Revision**
(was müsste passieren, damit wir das neu bewerten).

Die verworfene Option mit ihrer Begründung ist der Teil, der in einem Jahr Wert
hat. Ein ADR ohne verworfene Option ist ein Protokoll, keine Entscheidung.

Nummern werden fortlaufend vergeben und nie wiederverwendet. Ein überholtes ADR
wird nicht gelöscht, sondern bekommt `<meta name="esf-status" content="ersetzt-durch-ADR-nnn">`.

## 5 Reports

Jeder Report beginnt mit dem, was in drei Minuten reicht: was sich geändert hat,
was es gekostet hat, was eine Entscheidung braucht. Details folgen darunter,
jede Behauptung mit Link auf Karte, Lauf oder Commit.

Ein Report, der mit der Methodik anfängt, wird nicht gelesen.

## 6 Das Ledger

`ledger/estimates.jsonl` — eine JSON-Zeile je (Schätzung, Ist)-Paar, nur
angehängt, nie umgeschrieben. Pflichtfelder:

    {"task_id": "...", "reference_class": "...", "profile": "...",
     "estimate": {"wall_minutes": {"p50": 0, "p90": 0}, "confidence": 0.0},
     "actual":   {"wall_minutes": 0, "runs": 1, "standby_overlap": false},
     "at": "JJJJ-MM-TT"}

Fehlende Messwerte stehen als `null`, nicht als Schätzung. `null` ist eine
ehrliche Lücke; eine hineingeschriebene Vermutung vergiftet die Kalibrierung
aller künftigen Schätzungen.

### 6.1 Weitere Dateien unter `ledger/`

`estimates.jsonl` ist die einzige Datei mit vorgeschriebenen Feldern. Daneben
dürfen Messreihen liegen, deren Schema das schreibende Skript festlegt — heute:

    ledger/kosten-je-rolle.jsonl   {at, profile, usage_total, usage_delta}
                                   von scripts/ledger-sync.sh, kumulativer
                                   OpenRouter-Verbrauch je Profil-Key
    ledger/ceo-entscheidungen.jsonl {at, gate, dokument, verb, status,
                                   uebereinstimmung?} von scripts/ceo-tick.sh —
                                   jede Validierung, Ausführung, Eskalation
                                   oder Überholung einer CEO-Entscheidung
    ledger/eskalationen.jsonl      {at, karte, klasse, text, aktion}
                                   von scripts/eskalation.sh — die
                                   Notfall-Leiter, nur angehängt

Für sie gilt nur die **Form**: eine Zeile, ein JSON-Objekt, nur angehängt. Auf
diese Eigenschaft verlässt sich jedes lesende Skript. `vault-lint.py` prüft
deshalb bei ihnen die Form und nicht die Felder — bis zum 17.08.2026 wandte es
das Schema von `estimates.jsonl` auf jede `.jsonl` an und vermisste vier
Pflichtfelder, die dort nichts zu suchen hatten. Ein Prüfer, der mehr verlangt
als der Vertrag hergibt, ist so schädlich wie einer, der zu wenig prüft: Beide
erzeugen Befunde, die niemand mehr liest.

Wer eine neue Messreihe anlegt, nennt sie hier — mit Schema und schreibendem
Skript. Eine Datei im Ledger, deren Herkunft niemand kennt, ist keine Messung.

## 7 Gates öffnet nie ein Worker — die drei Autoritätsebenen

Das Worker-Werkzeug `kanban_unblock` ist für jedes Profil tabu — auf jeder
Karte, aus jedem Grund. Auch für `esf-ceo`. `monitor.sh` meldet jedes
Unblock-Ereignis ohne gültiges Verb-Präfix als Verstoß.

Seit Phase 3 ist die Führung zweistufig; wer welches Gate öffnet, steht in
`cadence.yaml` unter `fuehrung:`:

- **Supervisor (Mensch).** Beantwortet das Roadmap-Gate (nicht delegierbar)
  und jeden Notfall, den `scripts/eskalation.sh` meldet. Sein Werkzeug ist
  `gate.sh` — direkt, wie in den Phasen 0–2.
- **`esf-ceo` (Profil).** Entscheidet Release-, Irreversibel- und
  Budget-Gates — aber nie durch einen Unblock: Er schreibt ein
  **Entscheidungsdokument** (`reports/ceo-entscheid-<gate-id>.html`, Metas
  `esf-gate` und `esf-verb`, vier Pflichtabschnitte `vorlage` · `messung` ·
  `begruendung` · `antwort`). `scripts/ceo-lint.py` validiert es, und erst
  `scripts/ceo-tick.sh` führt es über `gate.sh --von esf-ceo` aus.
  Irreversibel-Entscheidungen warten zusätzlich die Einspruchsfrist
  (`irreversibel_einspruch_stunden`) ab. Das Verb `escalate` öffnet nichts —
  es übergibt das Gate dem Supervisor.
- **Code.** Validiert, führt aus, journaliert (`ledger/ceo-entscheidungen.jsonl`,
  `ledger/eskalationen.jsonl`) und definiert den Notfall
  (`scripts/eskalation.sh`). Kein Modell öffnet ein Gate; kein Mensch muss
  eines öffnen, das kein Roadmap-Gate und kein Notfall ist.

Im Modus `ceo_modus: schatten` schreibt `esf-ceo` seine Dokumente, aber
ausgeführt wird nichts — der Supervisor antwortet wie bisher, und der
Vergleich der beiden Antworten ist die Messgröße, an der die Umstellung auf
`live` hängt.

## 8 Video-Zusammenfassungen

Jedes Dokument, das für CEO oder Supervisor geschrieben wird — alles unter
`analysis/`, `roadmap/` und `reports/` (ausgenommen Maschinenprotokolle und
die `e2e-`/`gate-videos`-Akten) — trägt eine **Video-Zusammenfassung**:
Sprecher-Audio, dazu optional einblendbare Untertitel. Wer das Dokument
schreibt, liefert den **Sprechertext**; gerendert wird deterministisch von
`scripts/video-render.sh` (Hyperframes, https://hyperframes.heygen.com — mit
gemessenem ffmpeg-Rückfall). Kein Modell rendert, kein Skript textet.

Drei Bausteine, alle drei Pflicht (`vault-lint.py` prüft die Konsistenz):

1. **Das Meta** im Kopf, benannt nach dem Dokument — die Namenskonvention
   trägt die Zuordnung:

       <meta name="esf-video" content="<dokument-basisname>.mp4">

2. **Der Sprechertext** als eigener Abschnitt, 120–220 Wörter gesprochene
   Sprache. Die ersten zwei Sätze tragen Kernaussage und Empfehlung; jede
   Zahl darin steht auch im Dokument; keine Dateipfade, keine IDs vorlesen:

       <section id="video-skript"><p>…</p></section>

3. **Das Video-Element** im Dokument, mit Untertitel-Spur (nicht `default` —
   die Untertitel sind zuschaltbar, nicht eingebrannt):

       <figure class="esf-video">
         <video controls preload="metadata" width="100%" src="<basisname>.mp4">
           <track kind="subtitles" srclang="de" label="Untertitel" src="<basisname>.vtt">
         </video>
         <figcaption>Video-Zusammenfassung; Untertitel zuschaltbar. Gerendert von scripts/video-render.sh.</figcaption>
       </figure>

Die `.mp4`/`.m4a` sind **Akten, keine Quellen** — sie entstehen reproduzierbar
aus dem Sprechertext, liegen neben dem Dokument und sind vom Vault-Git
ausgenommen (wie die `e2e-`-Traces). Die `.vtt` ist Text und wird committet;
ihre Cue-Zeiten entstehen aus der **gemessenen** Audiodauer, proportional zur
Wortzahl je Satz — Bild, Ton und Untertitel teilen eine Zeitquelle.

Gate-Vorlagen brauchen keinen eigenen Sprechertext: Der Blockgrund **ist** die
Vorlage, `video-render.sh --gates` liest ihn vom Board und legt das Video
unter `reports/gate-videos/` ab.

## 8.1 Die individuelle Komposition

Wie ein Video **aussieht**, entscheidet nicht diese Datei und nicht eine feste
Vorlage, sondern `esf-video-designer` — je Dokument neu, aus dessen Inhalt. Ein
Marktbericht mit Scores gehört als Rangbalken ins Bild, eine Modulkarte als
Struktur, ein Schätzintervall als Intervall. Was ein Video zeigt, muss im
Dokument stehen: die Rolle **visualisiert, sie rechnet nicht**.

Die Arbeitsteilung bleibt dieselbe wie überall in der ESF — nur eine Ebene
höher. Nicht mehr „das Modell textet, Code rendert", sondern:

> **Das Modell textet, ein Modell gestaltet, Code misst und entscheidet.**

Neben dem Dokument liegt dafür ein Verzeichnis `<basisname>.komposition/`:

    auftrag.json    von Code geschrieben: Titel, Typ, GEMESSENE Dauer, Cues
    audio.m4a       die Vertonung, EINMAL erzeugt
    index.html      das Ergebnis des Designers
    lint.log        das Urteil des Framework-Linters

**Die Reihenfolge ist der Determinismus.** `video-render.sh --auftraege`
vertont zuerst und misst die Dauer, dann erst wird gestaltet. Der Designer
bekommt eine feste Zeitachse, die er bespielt, aber nicht verschieben kann:
`auftrag.json`s `dauer` **ist** sein `data-duration`, auf 50 ms genau. Beim
Rendern wird dasselbe Audio wiederverwendet, nicht neu erzeugt — sonst wanderte
die Dauer und seine Komposition wäre plötzlich falsch, ohne dass er etwas getan
hat.

**Zwei Tore, beide maschinell**, und beide müssen grün sein, bevor gerendert
wird:

1. `scripts/video-werkzeug.py pruefe` — gehört die Komposition zu *diesem*
   Auftrag? Root-Attribute, Dauer-Gleichheit, Timeline-Registrierung,
   `<audio src>` auf die Auftragsdatei, keine Wanduhr-Aufrufe, keine Fremd-URLs
   außer dem gepinnten GSAP-Tag.
2. `hyperframes lint` — hält sie den Framework-Vertrag? Null Fehler.

**Was die Tore nicht können:** prüfen, ob eine gezeigte Zahl stimmt. Das ist
Inhalt, nicht Struktur; dafür haftet die Rolle, und der Beleg ist das Dokument.

**Die Leiter fällt nach unten, nie aus.** Wird die Komposition abgewiesen,
rendert die ESF die generische Vorlage; fehlt Chrome oder Netz, die
ffmpeg-Titelkarte. Ein abgewiesener Entwurf kostet Gestaltung, nie das Video —
und `video-render.sh` nennt in seiner Ausgabe je Datei, welche Stufe gegriffen
hat. Eine still auf Stufe 2 gerutschte Organisation wäre schlimmer als eine
laute.
