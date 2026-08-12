# Ingest-Vorschlag: Update — Profile install: description aus distribution.yaml in profile.yaml uebernehmen

**Slug:** `profile-install-description` · **Route:** `update` · **Punkte:** 70/100
**Branch (geplant):** `kb/ingest-profile-install-description`

## 1. Was aufgenommen werden soll

`hermes profile install` aus einem lokalen Verzeichnis uebernimmt seit 0.20.2 die
`description` aus einer `distribution.yaml` in die `profile.yaml` des
installierten Profils. Vor dem Fix blieb diese `description` leer. Weil der
Kanban-Decomposer Karten ueber die Profilbeschreibung routet (nicht ueber den
Namen), blieb ein so installiertes Profil fuer ihn unsichtbar. Der Fix stellt
also die Decomposer-Sichtbarkeit per Install wieder her: eine installierte
Distribution bringt damit neben der `config.yaml` (sofort dispatchable) auch die
`description` mit, die den Decomposer-Routing-Ausgang entscheidet.

## 2. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `sources/releases/changelog-0.20.2.md` | „Behoben" / „Profile" (Zeilen 22–25) | „`hermes profile install` aus einem lokalen Verzeichnis übernahm die `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über die Beschreibung routet. Behoben." |

**Verifikations-Bahn sagt:** verifiziert — der „davor"-Zustand (leere
`description`) ist empirisch gegen die lokal installierte v0.20.0 nachgewiesen;
die Fix-Wirkung selbst ist offiziell changelog-belegt, aber nicht lokal im
Verhalten gesehen (Installation ist noch v0.20.0, Stand 2026-08-11).

## 3. Betroffene Seiten

| Seite | Änderung | Warum |
|---|---|---|
| `pages/profile-system.md` | Abschnitt `### Verteilen` ergänzen | Die Install-Stelle erwähnt nur das Mitbringen der `config.yaml`; die `description`-Uebernahme in `profile.yaml` fehlt dort. |

**Index:** unverändert (`profile-system` ist bereits verlinkt)
**Neue Seiten:** keine
**Prune-Kandidaten:** keine

## 4. Was NICHT aufgenommen wird

Der Changelog nennt noch zwei weitere Fixes und zwei Aenderungen (Block-Schleifen,
`kanban_create` im Worker, `kanban stats`, `dispatch_stale_timeout_seconds`),
die dieses Item nicht betreffen und hier bewusst draussen bleiben. Ebenso wird
die bestehende Seite nicht umgeschrieben: Die Aussage „weil eine Distribution
eine `config.yaml` mitbringt, ist ein so installiertes Profil sofort
dispatchbar" bleibt unangetastet — Dispatchbarkeit und Decomposer-Sichtbarkeit
sind zwei getrennte Mechanismen, die der Ingest als solche nebeneinanderstehen
lässt, statt sie zu vermischen.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 12/25 | Bugfix-Detail; Routing-Prinzip steht schon, nur die Install-Uebernahme fehlt. |
| quellenvertrauen | 18/20 | offizieller Changelog 0.20.2, davor-Zustand zusaetzlich empirisch belegt. |
| themenbezug | 20/25 | Profile-System; Folgewirkung auf Decomposer-Routing. |
| versionsrelevanz | 12/15 | aktueller Patch 0.20.2, aber Nischenfehler. |
| klarheitsgewinn | 8/15 | schmaler Gewinn; knapp ueber der Schwelle. |
| **Summe** | **70/100** | Schwelle 65 |