# Der echte Lauf vom 2026-08-11

Das ist **nicht** Teil des Setups. Es ist das Ergebnis des Durchlaufs, aus dem
die „Real gemessen"-Blöcke in [TUTORIAL.md](TUTORIAL.md) stammen — abgelegt,
damit du die Artefakte lesen kannst, ohne die Pipeline selbst laufen zu lassen.

`workspace/` wird von `reset-workspace.sh` aus `seed/` aufgebaut und ist bei
Auslieferung leer. Dieses Verzeichnis hier bleibt unangetastet.

```
intake/          die zwei Scout-Berichte
vault/items/     die zwei Items mit Score, Bahnen, Outline und Vorschlag
work/builds/     das gebaute Werkzeug (197 Zeilen) + Testbericht + Fixtures
work/videos/     Folien, Skript, Faktencheck
```

⚠ **Das ist der erste Lauf, vor zwei Nachschärfungen an den Artefakten.**
Konkret: hier liegen **zwei** Items, nicht drei. Das dritte (`commit-emoji`,
26 Punkte, archiviert), das TUTORIAL.md in Schritt 10.8 zeigt, stammt aus einem
späteren Lauf — damals filterte der Scout es noch selbst weg. Und die beiden
ungeplanten Karten in `work/videos/` stammen aus der Zeit vor dem
`idempotency_key`. Die ausgelieferten Artefakte enthalten beide Korrekturen;
dieses Verzeichnis zeigt den Stand davor.

Zwei Dinge, auf die zu schauen lohnt:

- `vault/items/*.md`, Kopf: `score` und `score_breakdown`. Das ist der Grund,
  warum die Bewertung nachprüfbar ist, obwohl sie ein Modell vergeben hat.
- `work/builds/konfigurationspfade-ambig/auftrag.md`, Abschnitt 1: der Wortlaut
  der menschlichen Entscheidung, und darunter die Notiz, dass sie die Route
  korrigiert hat. Der ursprüngliche Klassifikatorwert steht in
  `vault/items/konfigurationspfade-ambig.md` unverändert daneben.

⚠ In `work/videos/` liegen zwei Stufen, die der `folien`-Worker selbst nachgelegt
hat (`skript` doppelt, `faktencheck` zusätzlich). Das ist der Fehler, den
TUTORIAL.md unter „Was in diesem Lauf schiefgegangen ist" beschreibt — er ist
hier absichtlich nicht wegretuschiert.
