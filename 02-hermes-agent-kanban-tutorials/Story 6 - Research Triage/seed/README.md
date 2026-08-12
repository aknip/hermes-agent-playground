# Story 6 — Recherche-Triage

Die Ausgangsfrage:

> **Warum stagniert die Migration unserer Bestandskunden von Meridian 1 auf
> Meridian 2?**

`sources/` ist das Korpus. Es ist bewusst so geschnitten, dass sich vier
unabhaengige Blickwinkel darin bearbeiten lassen — und dass einer davon ins
Leere laeuft:

```
sources/
├── kosten/            Preisliste, Rechnungsvergleiche, eine Kalkulation
├── latenz/            zwei Benchmarklaeufe und ein Betriebsbericht
├── werkzeuge/         Supporttickets und ein Integrationsprotokoll
├── lizenzen/          NUR ein Sperrvermerk — hier ist absichtlich nichts
└── lizenzen-spiegel/  die Ausweichquelle, die es tatsaechlich gibt
```

Der Rechercheur fuer den Blickwinkel „Lizenzen" findet in `sources/lizenzen/`
nichts Auswertbares und blockiert seine Karte. Erst ein Kommentar von dir
zeigt ihm `sources/lizenzen-spiegel/`. Das ist der Kern der Story: ein
Mensch korrigiert mitten im Lauf, ohne dass die anderen drei Rechercheure
davon beruehrt werden.
