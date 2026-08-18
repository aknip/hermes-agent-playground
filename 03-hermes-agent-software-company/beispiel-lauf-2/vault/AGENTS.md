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

Für sie gilt nur die **Form**: eine Zeile, ein JSON-Objekt, nur angehängt. Auf
diese Eigenschaft verlässt sich jedes lesende Skript. `vault-lint.py` prüft
deshalb bei ihnen die Form und nicht die Felder — bis zum 17.08.2026 wandte es
das Schema von `estimates.jsonl` auf jede `.jsonl` an und vermisste vier
Pflichtfelder, die dort nichts zu suchen hatten. Ein Prüfer, der mehr verlangt
als der Vertrag hergibt, ist so schädlich wie einer, der zu wenig prüft: Beide
erzeugen Befunde, die niemand mehr liest.

Wer eine neue Messreihe anlegt, nennt sie hier — mit Schema und schreibendem
Skript. Eine Datei im Ledger, deren Herkunft niemand kennt, ist keine Messung.

## 7 Gates öffnet nur der Mensch

Das Worker-Werkzeug `kanban_unblock` ist für jedes Profil tabu — auf jeder
Karte, aus jedem Grund. Der einzige legitime Weg ist `gate.sh` in Menschenhand.
`monitor.sh` meldet jedes Unblock-Ereignis ohne gültiges Verb-Präfix als
Verstoß.
