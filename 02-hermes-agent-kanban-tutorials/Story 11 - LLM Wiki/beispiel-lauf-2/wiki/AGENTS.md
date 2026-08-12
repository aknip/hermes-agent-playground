# AGENTS.md — der Vertrag dieser Wissensbasis

Diese Datei ist die **einzige autoritative Quelle** für Form und Pflege dieser
Knowledge Base. Sie hat drei Leser, und alle drei sind verbindlich an sie
gebunden:

| Leser | Was er mit dieser Datei tut |
|---|---|
| **Ingestor** (`kb-ingestor`) | schreibt Seiten **genau** nach Abschnitt 2 und 3 |
| **Linter** (`bin/kb_lint.py`) | validiert **maschinell** gegen Abschnitt 2, 3, 4 und 5 |
| **Orchestrator** (`kb-orchestrator`) | führt den Ablauf aus Abschnitt 7 |

> Widersprechen sich diese Datei und das Urteil eines Agenten, **gewinnt diese
> Datei**. Widersprechen sich diese Datei und `bin/kb_lint.py`, ist der Linter
> falsch und muss nachgezogen werden — nicht die Datei.

---

## 1. Wofür diese Wissensbasis da ist

Sie ist **für Agenten geschrieben, nicht für Menschen**. Ein Agent, der eine
Frage zu Hermes Agent hat, soll sie hier in einem Lesevorgang beantwortet
finden — ohne die Originaldokumentation, ohne Changelogs, ohne Websuche.

Daraus folgt jede Regel unten:

- **Kurz vor vollständig.** Eine Seite, die niemand ganz liest, ist eine Seite,
  die halb gelesen falsch verstanden wird. Deshalb die Zeilengrenze.
- **Verdichtet, nicht kopiert.** Ingest heißt lesen, zusammenfassen, einordnen.
  Ein hierher kopierter Changelog-Absatz ist **kein** Ingest.
- **Datiert und mit Quelle.** Ohne `updated` und `sources` ist eine Aussage
  nicht überprüfbar und damit für einen Agenten wertlos.
- **Verlinkt statt wiederholt.** Derselbe Sachverhalt steht an **einer** Stelle.

---

## 2. Seitenformat

Jede Datei unter `pages/` ist eine Seite. Jede Seite beginnt mit einem
YAML-Frontmatter zwischen zwei `---`-Zeilen.

### 2.1 Pflichtschlüssel im Frontmatter

| Schlüssel | Form | Regel |
|---|---|---|
| `title` | Text | nicht leer |
| `slug` | `[a-z0-9-]+` | **muss dem Dateinamen ohne `.md` entsprechen** |
| `updated` | `YYYY-MM-DD` | Datum der letzten inhaltlichen Änderung |
| `tags` | Liste in `[…]` | mindestens ein Tag |
| `sources` | Liste in `[…]` | mindestens eine Quelle; Dateiname aus `sources/` oder URL |
| `version` | Text | die Hermes-Version, auf die sich die Seite bezieht, oder `unbestimmt` |

Ein weiterer Schlüssel ist erlaubt, aber nicht Pflicht:

| `status` | `aktuell` \| `veraltet` \| `strittig` | fehlt = `aktuell` |

### 2.2 Abschnittsreihenfolge

Genau diese vier `##`-Abschnitte, **in dieser Reihenfolge**:

```
## Kurzfassung      Pflicht.  3–6 Sätze. Beantwortet die Seite in sich.
## Details          Pflicht.  Die Substanz. Listen und Tabellen bevorzugt.
## Quellen          Pflicht.  Woher es kommt, mit Datum.
## Siehe auch       optional. Nur Wikilinks, einer je Zeile.
```

Weitere `###`-Unterabschnitte innerhalb von `## Details` sind frei.

### 2.3 Grenzen

- **Höchstens 120 Zeilen** je Seite. Wird eine Seite länger, wird sie
  **geteilt** — nicht gekürzt bis sie passt.
- Keine zwei Seiten mit demselben `slug`.

---

## 3. Verlinkung

- Innerhalb der Wissensbasis wird **ausschließlich** mit `[[slug]]` verlinkt,
  nie mit relativen Pfaden.
- Ein `[[slug]]` **muss** auf eine existierende Datei `pages/<slug>.md`
  zeigen. Ein Link auf eine noch nicht geschriebene Seite ist ein **Stub-Link**
  und ein Linter-Fehler — keine Absichtserklärung.
- Externe Links sind normale Markdown-Links und stehen nur unter `## Quellen`.

---

## 4. Der Index

`index.md` ist das Inhaltsverzeichnis und wird **maschinell geprüft**:

- Jede Datei unter `pages/` ist **genau einmal** aus `index.md` als `[[slug]]`
  verlinkt.
- Jeder `[[slug]]` in `index.md` zeigt auf eine existierende Seite.

Eine Seite, die es gibt und die der Index nicht kennt, ist eine **Waise** —
für einen Agenten, der über den Index einsteigt, existiert sie nicht.

---

## 5. Aktualität (Freshness)

- `updated` darf höchstens **180 Tage** alt sein. Danach ist die Seite
  **überprüfungsbedürftig** (Linter: `STALE`).
- `STALE` heißt **nicht** „löschen". Es heißt: jemand muss nachsehen, ob die
  Aussage noch stimmt. Ergebnis ist entweder ein neues `updated` oder ein
  Prune-Vorschlag.
- Eine Aussage, die nachweislich nicht mehr stimmt, bekommt `status: veraltet`
  und wird beim nächsten Ingest **ersetzt**, nicht ergänzt.

---

## 6. Was Prune ist und wer es entscheidet

**Prune** ist das Entfernen von Wissen: eine Seite löschen, einen Abschnitt
streichen, eine falsche Aussage tilgen.

> **Prune entscheidet immer ein Mensch.** Kein Agent löscht Wissen aus dieser
> Wissensbasis auf eigene Rechnung — auch nicht, wenn der Linter es vorschlägt
> und die Begründung überzeugend ist.

Der Linter darf Prune **vorschlagen** (`PRUNE-VORSCHLAG` in seinem Bericht).
Der Ingestor darf ihn **vorbereiten** (im Branch, nicht in `main`). Wirksam
wird er erst durch die Freigabe am zweiten Tor.

Der Grund ist asymmetrisch: eine überflüssige Seite kostet ein paar Zeilen
Kontext. Eine gelöschte richtige Seite ist weg, und niemand merkt, dass die
Antwort fehlt.

---

## 7. Der automatisierte Ablauf

```
sources/releases     ─▶ Scout ─┐
sources/transcripts  ─▶ Scout ─┤
                               ├─▶ Triage: gegen die Wissensbasis deduplizieren,
                               │   nach Rubrik bewerten (Schwelle in ingest.yaml)
                               │        │
                               │        ├─ unter der Schwelle: geshelved. Ende.
                               │        ▼
                               │   je Item zwei Recherche-Bahnen (parallel):
                               │     verifikation      — stimmt es, ist die Quelle belastbar?
                               │     seiten-abgleich   — welche Seiten sind betroffen?
                               │        ▼
                               │   Route: neue-seite | update | konflikt | shelve
                               │        ▼
                               │   ╔═══════════════════════════════════════╗
                               │   ║  TOR 1  approve | shelve | modify     ║
                               │   ╚═══════════════════════════════════════╝
                               │        ▼
                               │   Ingest: Branch anlegen, Seiten schreiben,
                               │           Index und Log nachziehen
                               │        ▼
                               │   Lint: bin/kb_lint.py, Befunde beheben,
                               │         Prune-Vorschläge sammeln
                               │        ▼
                               │   ╔═══════════════════════════════════════╗
                               │   ║  TOR 2  merge | merge-ohne-prune |    ║
                               │   ║         discard                       ║
                               │   ╚═══════════════════════════════════════╝
                               │        ▼
                               └── Commit + Merge nach main (bin/kb_git.py)
```

### 7.1 Zwei Grenzen, die der Ablauf nie überschreitet

**Die Rohquellen unter `sources/` werden nie angefasst.** Sie liegen
**außerhalb** dieses Git-Repositorys. Ein falscher Ingest ist damit immer
zurücknehmbar: `git` stellt die Wissensbasis her, `sources/` ist unversehrt.

**Jeder Ingest lebt auf einem eigenen Branch.** In `main` landet nur, was
beide Tore passiert hat **und** was `bin/kb_lint.py` fehlerfrei validiert.
`bin/kb_git.py merge` weist einen Merge ab, dessen Lint fehlschlägt — das ist
kein Ratschlag, das ist ein Riegel.

### 7.2 Was ein Ingest in das Log schreibt

Jeder Ingest hängt einen Absatz an `log/ingest-log.md` an:

```markdown
## <YYYY-MM-DD> · <slug> · <route> · <score>/100
- **Branch:** `kb/ingest-<slug>`
- **Entscheidung Tor 1:** <verb> — <wortlaut>
- **Entscheidung Tor 2:** <verb> — <wortlaut>
- **Seiten:** <geschrieben> / <geändert> / <geprunt>
- **Quellen:** <dateien aus sources/>
```

Das Log ist die Antwort auf „warum steht das hier?" — und die einzige Stelle,
an der eine menschliche Entscheidung dauerhaft im Repository steht.
