---
slug: cron-no-agent-leerer-lauf
karte: t_79d63f19
bahn: verifikation
ausgangs_wissensstand: triage (Score 78)
quelle: sources/releases/changelog-0.20.1.md
datierung: 2026-08-11
---

# Verifikation: Cron --no-agent — leere Laeufe erzeugen keine Ausgabedatei mehr

## Kernsatz

Cron-Jobs mit `--no-agent`, die bei leerem stdout keinen Text liefern,
schrieben vor dem Fix eine leere Ausgabedatei nach
`~/.hermes/cron/output/<job-id>/`; seit dem Fix in v0.20.1 erzeugen leere
Laeufe keine Datei mehr.

## Befund

VERIFIZIERT (Quellentreue): Die Aussagenklasse entspricht dem Quelltext
wortgleich — die Formulierung im Item wurde nicht verstaerkt oder abgeschwaecht.

Abschnitt im Quelltext: **Behoben → 4. Bulletpunkt "Cron"**

Zitat (changelog-0.20.1.md, Zeilen 26–28):

> Cron: Jobs mit `--no-agent` schrieben bei leerem stdout eine leere
> Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen
> keine Datei mehr.

Der Kernsatz des Items (Filename: `vault/cron-no-agent-leerer-lauf.md`,
Zeile 3: "Cron --no-agent: leere Laeufe erzeugen keine Ausgabedatei mehr")
und die zu verifizierende Aussagenklasse (Vorher/Nachher) sind beide exakt
im Quelltext enthalten. Kein Detail ist erfunden oder hinzugefuegt; der Ablageort
`~/.hermes/cron/output/<job-id>/` steht wortgleich im Changelog.

## Quellen-Rang

Offizieller Changelog (GitHub Releases), Patch-Release v0.20.1 vom 2026-08-06.
Hoechste Vertrauensstufe fuer Versionsmerkmal-Aussagen.

## Empirische Pruefung (Teil-Verifikation, abweichendes Environment)

Was ich VERIFIZIERT habe an der lokalen Installation
(`~/.hermes/hermes-agent`, v0.20.0, vor dem Fix):

- `cron/jobs.py`, Funktion `save_job_output()` (Zeilen 3048–3076) legt die
  Zieldatei `job_output_dir / "<zeitstempel>.md"` **unbedingt** an —
  `mkstemp` + `atomic_replace` erfolgen ohne Pruefung, ob `output` leer ist.
- `_job_output_dir(job_id)` (Zeile 381) bildet `~/.hermes/cron/output/<job_id>`;
  Ablageort stimmt mit dem Changelog ueberein.
- Teile der Delivery-Schreibpfade sind explizit UTF-8 (z.B.
  `fix(gateway): write cron delivery output files as UTF-8`), was zum Changelog-Typ
  passt.

Was ich daraus INFERIERE: Das in v0.20.0 installierte Verhalten ("leere Datei
wird geschrieben") ist mit der Vorher-Beschreibung des Changelogs konsistent.
Konsistenzpruefung bestanden.

Ich kann den Nachher-Zustand ("leere Laeufe erzeugen keine Datei mehr") lokal
**nicht ausfuehren**: Die installierte Version (v0.20.0) enthaelt den Fix von
v0.20.1 nicht. Das Urteil "VERIFIZIERT" stuetzt sich daher auf den offiziellen
Changelog (Quellen-Rang: hoechste Stufe fuer eben diese Aussagenklasse) plus
Konsistenz der Vorher-Seite am Code. Eine zusaetzliche Laufzeit-Pruefung des
Nachher-Zustands waere erst nach Upgrade auf v0.20.1 moeglich.

## Was die Aussage falsifizieren wuerde

Ein Cron-Job mit `--no-agent` und leerem stdout, der unter v0.20.1 (oder
neuer) dennoch eine Ausgabedatei unter `~/.hermes/cron/output/<job-id>/`
erzeugt. Derzeit liegt kein solcher Widerspruch vor.