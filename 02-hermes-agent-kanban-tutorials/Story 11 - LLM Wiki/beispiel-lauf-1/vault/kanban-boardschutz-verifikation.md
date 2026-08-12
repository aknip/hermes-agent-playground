# Verifikation: kanban-boardschutz

Item: `vault/kanban-boardschutz.md` (Score 76, Status triage)
Quellen: `sources/releases/changelog-0.20.1.md`, `sources/releases/changelog-0.20.2.md`
Lane: **verifikation** — geprüft: stimmt die Aussagenklasse, taugt die Quelle?
Datum: 2026-08-11

## Quellenrang

Beide Quellen sind die offiziellen GitHub-Changelogs für Hermes Agent
0.20.1 (2026-08-06) und 0.20.2 (2026-08-09). Rang: offizieller Changelog —
höchste Stufe der Quellenhierarchie (offizieller Changelog > gemessene Demo >
Behauptung > Ankündigung).

Hinweis zur lokalen Prüfbarkeit: Die lokale Hermes-Installation ist v0.20.0
(`hermes --version`). Sie ist älter als beide Changelogs, sodass die drei
behaviors hier weder reproduziert noch direkt widerlegt werden können. Das
Fehlen der Features in 0.20.0 ist mit den Angaben der Changelogs konsistent
und kein Widerspruch. Gemessen wurde lokal nur als Baseline, dass `hermes
kanban stats` (0.20.0) noch kein Alters-/Minutenfeld der ältesten `ready`-Karte
ausweist.

---

## Teilaussage 1 — kanban_create weist relativen workspace_path jetzt mit Meldung ab

**Verdikt: verifiziert** (gegen Quelltext, offizieller Changelog 0.20.2)

### Was die Quelle sagt
Quelle: `sources/releases/changelog-0.20.2.md`, Abschnitt **„Behoben"** →
**„Kanban / `kanban_create` im Worker"**, Zeilen 17–20:

> „Ein relativer `workspace_path` wurde stillschweigend abgewiesen — die Karte
> entstand, wurde aber nie gestartet und es gab keine Fehlermeldung auf dem
> Board. Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare
> Karte zu hinterlassen."

### Abgleich mit dem Item
Item-Formulierung: „kanban_create im Worker weist relativen workspace_path jetzt
mit einer Meldung ab; vorher entstand eine Karte, die nie startete."
- „vorher entstand eine Karte, die nie startete" ← Quelltext: „die Karte
  entstand, wurde aber nie gestartet" — deckungsgleich.
- „jett mit einer Meldung ab" ← Quelltext: „Der Aufruf schlägt jetzt mit einer
  Meldung fehl" — deckungsgleich.
- Die Changelog-Angabe „stillschweigend abgewiesen" beschreibt das ALTE
  Verhalten als „Karte wird nicht gestartet, keine Fehlermeldung"; das
  Intake-Item nennt nur die beiden Teilbeobachtungen (Karte entsteht / startet
  nie), ohne den Widerspruch „erstellt, aber abgewiesen" zu erläutern. Die
  Kernaussage ist unverändert getreu.

### Was ich verifiziert habe
Ich habe die Aussage verbatim gegen den Changelog-Text abgeglichen; sie ist dort
exakt belegt. **Nicht** reproduzierbar auf der lokalen Installation (v0.20.0,
älter als das Release) — die Verifikation stützt sich daher auf die
Changelog-Aussage selbst.

### Was ich inferiere
Ich inferiere daraus nur die Intentionalität des Fixes („statt eine unstartbare
Karte zu hinterlassen" = gewollter Guardrail), nicht mehr. Ein Verhaltenstest auf
der echten 0.20.2-Installation wäre der einzig stärkere Beleg; ein solcher Test
fehlt hier.

### Was würde widerlegen
Ein `kanban_create`-Aufruf mit relativem `workspace_path` auf einer echten
0.20.2-Installation, der (a) ohne Fehlermeldung durchläuft und (b) eine Karte
erzeugt, die anschließend startet — beides zusammen säße dem Changelog.
Letzteres allein („Karte startet nicht") ist gerade der dokumentierte Altzustand
und widerlegt nicht.

---

## Teilaussage 2 — complete a b c --summary … wird bei Handoff-Flags abgewiesen (Absicht)

**Verdikt: verifiziert** (gegen Quelltext, offizieller Changelog 0.20.1)

### Was die Quelle sagt
Quelle: `sources/releases/changelog-0.20.1.md`, Abschnitt **„Bekannte
Einschränkung"**, Zeilen 36–40:

> „`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn
> Handoff-Flags gesetzt sind. Das ist Absicht: Summary und Metadata gelten je
> Run, und dieselbe Zusammenfassung auf drei Karten zu kopieren ist fast immer
> falsch."

### Abgleich mit dem Item
Item-Formulierung: „hermes kanban complete a b c --summary … wird abgewiesen,
sobald Handoff-Flags gesetzt sind — Absicht (Summary/Metadata je Run)."
- „wird abgewiesen, sobald Handoff-Flags gesetzt sind" ← Quelltext: „bleibt
  abgewiesen, wenn Handoff-Flags gesetzt sind" — deckungsgleich (Item „sobald"
  ↔ Quelle „wenn"; die Quelle nennt keinen Schwellenwert, nur das Setzen der
  Flags — „sobald" ist eine akzeptable Paraphrase, nicht eine Verschärfung).
- „— Absicht (Summary/Metadata je Run)" ← Quelltext: „Das ist Absicht: Summary
  und Metadata gelten je Run …" — deckungsgleich.
- Das Item hat weder verschärft noch abgeschwächt. Getreu.

### Was ich verifiziert habe
Verbatim-Abgleich gegen den Changelog-Text; die Aussage ist dort wörtlich
belegt. Lokal nicht reproduzierbar (Installation 0.20.0 < 0.20.1).

### Was ich inferiere
Nichts über das „warum" hinaus, das die Quelle bereits selbst nennt. Insbesondere
keine Aussage darüber, ob das Abweisen eine Fehlermeldung erzeugt oder ob es
einen Workaround (z. B. pro Karte einzeln mit `--summary`) gibt — beides steht
nicht im Changelog und wurde nicht geprüft.

### Was würde widerlegen
Ein `hermes kanban complete a b c --summary …` (mehrere Karten + Handoff-Flags)
auf einer echten 0.20.1+ Installation, der in einem Erfolg auf mehreren Karten
mündet. Weil die Quelle selbst von „bleibt abgewiesen … Absicht" spricht, gilt
ein Durchlaufen ohne Fehler als Beleg gegen die Behauptung; das ist die
entsprechende Prüfbedingung für einen Human- oder Agententest.

---

## Teilaussage 3 — stats zeigt Alter der ältesten ready-Karte in Minuten

**Verdikt: verifiziert** (mit einer feinen Nuance im Maß, offizieller Changelog 0.20.2)

### Was die Quelle sagt
Quelle: `sources/releases/changelog-0.20.2.md`, Abschnitt **„Geändert"**,
Zeilen 32–33:

> „`hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte
> in Minuten statt nur als Zeitstempel."

### Abgleich mit dem Item
Item-Formulierung: „hermes kanban stats zeigt das Alter der ältesten
ready-Karte in Minuten."
- „zeigt das Alter der ältesten ready-Karte in Minuten" ← Quelltext: „zeigt
  zusätzlich das Alter der ältesten `ready`-Karte in Minuten" — deckungsgleich.
- Eine Nuance: Die Quelle sagt „zusätzlich" und „statt nur als Zeitstempel" —
  d. h. es wird nicht nur Minuten angezeigt, sondern das Minutenfeld ergänzt
  den Zeitstempel (bzw. ersetzt dessen alleinige Anzeige). Das Item lässt die
  Existenz des Zeitstempels unerwähnt, behauptet aber nichts Gegenteiliges —
  es unterschlägt den Zusatz, verschärft nicht. Kein Widerspruch.

### Was ich verifiziert habe
Verbatim-Abgleich gegen den Changelog-Text; Kernaussage wörtlich belegt.
Zusätzlich lokal gemessen auf der vorhandenen 0.20.0-Installation: `hermes
kanban stats` zeigt dort **nur** „By status" / „By assignee" und kein
Alters-/Minutenfeld der `ready`-Karte. Das ist konsistent damit, dass dieses
Feld erst in 0.20.2 (Version > 0.20.0) ergänzt wurde — bestätigt also die
Versionszuordnung als „neu ab 0.20.2", widerlegt nichts. Ein echter endpoint-
Test auf 0.20.2 (eine `ready`-Karte mit bekannten Alter vorhanden, stats zeigt
Minuten) wäre stärker, ist hier nicht möglich.

### Was ich inferiere
Dass das Minutenfeld beim Anzeigen nur erscheint, wenn es mindestens eine
`ready`-Karte gibt („Alter der ältesten ready-Karte") — bei `ready`-Bestand 0,
wie lokal messbar, wäre nichts anzuzeigen. Das ist eine Schlussfolgerung über
das Format bei leerem Bestand; sie ist plausibel, aber im Changelog nicht
explizit.

### Was würde widerlegen
Ein `hermes kanban stats` auf einer echten 0.20.2-Installation mit mindestens
einer `ready`-Karte, das KEINE Altersangabe in Minuten ausweist (weder als
Zusatzspalte noch als Ergänzung zum Zeitstempel).

---

## Zusammenfassung

| # | Teilaussage | Verdikt | Quelle |
|---|-------------|---------|--------|
| 1 | kanban_create lehnt relativen workspace_path jetzt mit Meldung ab (vorher unstartbare Karte) | verifiziert | Changelog 0.20.2 |
| 2 | complete a b c --summary … bei Handoff-Flags abgewiesen — Absicht (Summary/Metadata je Run) | verifiziert | Changelog 0.20.1 |
| 3 | stats zeigt Alter der ältesten ready-Karte in Minuten | verifiziert (Nuance: als Zusatz zum Zeitstempel) | Changelog 0.20.2 |

Alle drei Teilaussagen sind in den offiziellen Changelogs wörtlich oder
quasi-wörtlich belegt; keine wurde verschärft oder verfälscht wiedergegeben.
Lokale Prüfung war nur für die Baseline (0.20.0, Absenz des stats-Feldes)
möglich; die eigentlichen Behaviors entziehen sich der lokalen Reproduktion, da
die installierte Version 0.20.0 beiden Release-Patches vorausgeht.