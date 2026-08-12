---
slug: profile-install-description-verifikation
karte: t_dc066ba9
item: profile-install-description
quelle: changelog-0.20.2.md
baehne: verifikation
datum: 2026-08-11
---

# Verifikation: profile install uebernimmt description aus distribution.yaml

## Kernsatz

`hermes profile install` aus einem lokalen Verzeichnis uebernimmt die
`description` aus `distribution.yaml` in `profile.yaml`; davor blieb ein
installiertes Profil fuer den Kanban-Decomposer unsichtbar, weil dieser ueber
die Beschreibung routet.

## Verdict

**verifiziert**

Basisteil (Zustand vor 0.20.2) ist doppelt belegt — per offiziellem Changelog
und per eigenem Lauf gegen die lokal installierte Vor-Fix-Version v0.20.0.
Der Fix in 0.20.2 selbst ist nur changelog-behauptet; die Lokalinstallation
ist noch v0.20.0 (Stand 2026-08-11), der Fix konnte also nicht direkt im
Verhalten beobachtet werden.

## Quelle: Abschnitt und Zitat

Quelle: `sources/releases/changelog-0.20.2.md`
Abschnitt: **„Behoben" / „Profile"** (Zeilen 22–25)

Zitat (verbatim):

> **Profile:** `hermes profile install` aus einem lokalen Verzeichnis übernahm
> die `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb
> ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über
> die Beschreibung routet. Behoben.

Das Intake-Matching (`intake/releases.md`, Zeile 151–153) bildet genau diesen
Abschnitt ab; das Zitat dort stimmt wortgleich mit dem Changelog ueberein. Das
Item-Schema (`vault/profile-install-description.md`) formuliert dieselbe
Aussage in Präsens-form („uebernimmt") — das ist die nach-Fix-Zukunft, der
Changelog beschreibt den Wechsel vom Nicht-Uebernehmen zum Uebernehmen. Keine
Verstaerkung durch die Intake-Stufe.

## Was ich VERIFIZIERT habe (eigener Lauf, empirisch)

Aussage: *Vor* dem Fix uebernimmt install die description NICHT.

- Lokal installiert ist **Hermes Agent v0.20.0** (2026.8.3) — die Version vor
  dem 0.20.2-Fix.
- Ich habe eine lokale Distribution mit `distribution.yaml` gebaut:
  `name: mydist`, `description: "Test distribution desc for decomposer routing"`,
  `version`, `source`.
- `hermes profile install <dir> --name mydist -y` in isoliertem
  `HERMES_HOME=/tmp/...` (Fremdkontamination des echten Profilsystems
  ausgeschlossen).
- Ergebnis: `profile.yaml` im installierten Profil war **leer** — die
  `description` aus `distribution.yaml` wurde nicht nach `profile.yaml`
  uebernommen, obwohl sie in `distribution.yaml` vorhanden war.
- Code-Stichprobe (v0.20.0): `install_distribution()` → `_copy_dist_payload()`
  kopiert die Nutzdaten Datei-für-Datei kleiner `USER_OWNED_EXCLUDE`, ohne
  irgendwo die Manifest-`description` nach `profile.yaml` zu schreiben
  (`hermes_cli/profile_distribution.py`).

Das bestaetigt den „davor"-Teil der Aussagenklasse. Ein leerer
`profile.yaml` ohne `description` ist genau der Zustand, den der
Decomposer-Ueber-von-Beschreibung-Routing nicht auswerten kann.

## Inferenz

- Der „davor"-Zustand (Description bleibt leer) ist empirisch nachgewiesen.
- Der „nach"-Zustand (ab 0.20.2 wird sie uebernommen) ist laut offiziellem
  Changelog behoben; da die Lokalinstallation noch v0.20.0 ist, habe ich die
  Fix-Wirkung nicht selbst im Verhalten gesehen. Der Changelog ist die
  hoeherwertige Quelle (offiziell) und formuliert klipp und klar „Behoben".
- Zweite Haelfte (Decomposer routet ueber Beschreibung): wird durch den
  Changelog-Text („weil der über die Beschreibung routet") und den
  CLI-Help-Text zu `hermes profile describe` („used by the kanban
  orchestrator") gestuetzt — konsistent, kein Widerspruch gefunden.

## Was die Aussage widerlegen wuerde

- Ein Install-Lauf gegen v0.20.2+, bei dem nach Install ein nichtleerer
  `profile.yaml` ohne/abweichend von der `distribution.yaml`-`description`
  entsteht.
- Ein Doku-/Code-Beleg, dass der Decomposer nicht ueber die Beschreibung
  routet (wuerde die zweite Haelfte angreifen).

## Fazit fuer die Ingestion

Die Aussagenklasse ist als **verifiziert** einzustufen. Empfehlung an die
konflikt- und seiten-abgleich-Bahn: Textebene deckt sich mit
`wiki/pages/profile-system.md`-Themengebiet; Vorsicht bei der Formulierung —
der Changelog beschreibt einen Zustandswechsel, keine dauerhaften
Ist-Zustände. KEINE Klassifikationszeile (laut Kartenanforderung).