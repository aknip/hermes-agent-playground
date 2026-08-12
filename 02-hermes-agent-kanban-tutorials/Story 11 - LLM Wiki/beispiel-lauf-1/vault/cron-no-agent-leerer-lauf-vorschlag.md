# Ingest-Vorschlag: Update — Cron --no-agent: leere Laeufe erzeugen keine Ausgabedatei mehr

**Slug:** `cron-no-agent-leerer-lauf` · **Route:** `update` · **Punkte:** 78/100
**Branch (geplant):** `kb/ingest-cron-no-agent-leerer-lauf`

## 1. Was aufgenommen werden soll

Cron-Jobs mit `--no-agent` schrieben bis v0.20.0 bei leerem stdout eine leere
Ausgabedatei unter `~/.hermes/cron/output/<job-id>/`. Seit dem Fix in v0.20.1
erzeugen leere Laeufe keine Datei mehr. Der Ablageort selbst bleibt bestehen —
die Regel lautet: eine Ausgabedatei entsteht nur, wenn der Lauf etwas nach
stdout geliefert hat. Fuer einen Agenten, der die Seite liest, beantwortet das
die Frage, ob und wann eine Output-Datei zu erwarten ist.

## 2. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `sources/releases/changelog-0.20.1.md` | Behoben → Bulletpunkt Cron, Zeilen 26–28 | „Jobs mit `--no-agent` schrieben bei leerem stdout eine leere Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen keine Datei mehr." |

**Verifikations-Bahn sagt:** bestätigt — offizieller Changelog (v0.20.1,
Release 2026-08-06), hoechste Quellenstufe; der Vorher-Zustand (leere Datei
wird geschrieben) ist mit dem installierten Code von v0.20.0
(`save_job_output()`, `_job_output_dir()`) konsistent.

## 3. Betroffene Seiten

| Seite | Änderung | Warum |
|---|---|---|
| `pages/cron-und-zeitplan.md` | Abschnitt `## Details` ergänzen | Seite nennt unter `### Ablageorte` nur den Pfad `output/<job-id>/`; die Leerlauf-Regel (leerer stdout → keine Datei) fehlt ganz. |

**Index:** unverändert — `[[cron-und-zeitplan]]` existiert bereits.
**Neue Seiten:** keine
**Prune-Kandidaten:** keine

## 4. Was NICHT aufgenommen wird

Der Ablageort `~/.hermes/cron/output/<job-id>/` wird nicht neu geschrieben
(steht bereits in der Seite). Ebenfalls draußen bleibt die Implementierung aus
der empirischen Pruefung des Verifikations-Befunds (`save_job_output()` mit
`mkstemp` + `atomic_replace`, Dateinamensmuster `<zeitstempel>.md`): der
Changelog nennt diese Details nicht, und die Seite soll verdichten, nicht
Code wiedergeben. Es geht ausschliesslich um die beobachtbare Verhaltensregel
vorher/nachher. Der `status` der Seite bleibt `aktuell`; die Version im
Frontmatter kann auf 0.20.1 angehoben werden, falls der Ingestor es fuer
konsistent haelt.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 15/25 | praezises `--no-agent`-Ausgabeverhalten; Seite kennt nur den Ablageort |
| quellenvertrauen | 20/20 | offizieller Changelog 0.20.1, hoechste Quellenstufe |
| themenbezug | 20/25 | Cron-Mechanik, direkt das `--no-agent`-Thema |
| versionsrelevanz | 15/15 | aktueller Patch (0.20.1) |
| klarheitsgewinn | 8/15 | kleine Praezisierung, wenige Agenten betroffen |
| **Summe** | **78/100** | Schwelle 65 |