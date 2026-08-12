---
lane: seiten-abgleich
item: profile-install-description
slug: profile-system
datum: 2026-08-11
quelle: sources/releases/changelog-0.20.2.md
---

# Seiten-Abgleich: profile-install-description

## Claim (Item) — was die Quelle SAAGT

Quelle `changelog-0.20.2.md` (Zeile 22–25), offizieller Changelog, Version
0.20.2, veroeffentlicht 2026-08-09:

> `hermes profile install` aus einem lokalen Verzeichnis uebernahm die
> `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb
> ein installiertes Profil fuer den Kanban-Decomposer unsichtbar, weil der ueber
> die Beschreibung routet. Behoben.

Zwei pragbare Teilaussagen:
1. Der Kanban-Decomposer routet ueber die **Profilbeschreibung**.
2. `profile install` muss die `description` aus `distribution.yaml` in
   `profile.yaml` **uebernehmen**; fehlt das, ist das installierte Profil fuer
   den Decomposer unsichtbar (Routing-Wirkung). Bug in 0.20.2 behoben.

## Betroffene Seite: wiki/pages/profile-system.md

Frontmatter: updated 2026-01-20, version 0.17.0.

### Abschnitt "### Die Beschreibung ist funktional" (Zeile 40–44)

> Der Kanban-Decomposer routet Triage-Karten ueber die **Profilbeschreibung**,
> nicht ueber den Profilnamen. Eine leere Beschreibung heisst: dieses Profil
> bekommt nie eine zerlegte Karte.

**Deckt Teilaussage 1 ab, in gleicher Genauigkeit.** Das Routing-Prinzip ist
deckungsgleich mit der Changelog-Begruendung ("weil der ueber die Beschreibung
routet").

### Abschnitt "### Verteilen" (Zeile 46–50)

> Profile lassen sich exportieren, importieren und als Distribution mit einer
> `distribution.yaml` installieren. Weil eine Distribution eine `config.yaml`
> mitbringt, ist ein so installiertes Profil sofort dispatchbar.

**Deckt Teilaussage 2 NICHT ab.** Die Stelle erwaehnt Install via
`distribution.yaml`, spricht aber nur das Mitbringen der `config.yaml` an
(Dispatchbarkeit). Die `description`-Uebernahme aus `distribution.yaml` in
`profile.yaml` beim Install wird **nicht** erwahnt — weder der Mechanismus noch
der behobene Bug in 0.20.2 noch die Folgewirkung auf die Decomposer-Sichtbarkeit.

## Verifikation / Gesamtbeurteilung des Wissensstands

- Teil 1 (Decomposer routet ueber Beschreibung): auf der Seite vorhanden,
  gleiche Genauigkeit → abgedeckt.
- Teil 2 (description-Uebernahme beim `profile install`, behobener Bug): auf der
  Seite **fehlend**.
- Kein Widerspruch: Die Seite sagt an keiner Stelle das Gegenteil. Die Aussage
  "sofort dispatchbar" bezieht sich auf die config.yaml-basierte Dispatchbarkeit
  (Abschnitt "Die config.yaml entscheidet ueber Dispatchbarkeit"), nicht auf die
  Decomposer-Sichtbarkeit — also nicht widerspruechlich zur Bugbeschreibung,
  sondern daneben (anderer Mechanismus).
- Die Seite hat den thematischen Platz ("Verteilen" / "Die Beschreibung ist
  funktional") bereits — die fehlende Install-Uebernahme ist eine Luecke in
  einer bestehenden Seite, keine Seiten-neu. Daher `unvollstaendig` (Route
  `update`), nicht `fehlt`.

## Widerspruchs-Check (Ablenkpfad)

Ein Leser der "Verteilen"-Zeile koennte meinen, ein per `distribution.yaml`
installiertes Profil sei automatisch decompose-sichtbar ("sofort dispatchbar").
Nach der Changelog-Aussage haengt die Decomposer-Sichtbarkeit aber zusaetzlich
von der `description`-Uebernahme in `profile.yaml` ab. Das ist eine pragbare
Ungenauigkeit im Wording ("dispatchbar" hoert nach einem was-auch-immer gleich)
und stuetzt die Einstufung `unvollstaendig` weiter.

## Ergebnis

wissensstand: unvollstaendig