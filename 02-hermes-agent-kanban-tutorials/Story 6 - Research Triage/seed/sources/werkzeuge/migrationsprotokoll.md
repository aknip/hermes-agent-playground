# Protokoll der Migrationsbegleitung — 9 Kunden, Q2 2026

| Kunde | Ergebnis | Abbruchpunkt |
|---|---|---|
| Nordwind Energie | migriert | — |
| Steinbach Kliniken | migriert | — |
| Birkenhof Media | migriert | — |
| Quellwerk GmbH | abgebrochen | Webhook-Signaturwechsel nicht angekuendigt |
| Halden Logistics | abgebrochen | Backfill-Dauer |
| Alpsteg Handel | abgebrochen | Migrationsskript ohne Trockenlauf, kein Rollback |
| Pergament Verlag | abgebrochen | Teilmigration nicht rueckabwickelbar |
| Torfhaus Reisen | verschoben | wartet auf Festpreis |
| Weiher & Co | verschoben | keine Kapazitaet |

Drei von vier Abbruechen hatten dieselbe Wurzel: **das Migrationswerkzeug
kennt keinen Trockenlauf und keinen Rueckweg.** Wer einmal angefangen hat,
kommt nicht zurueck, ohne ein Backup einzuspielen. Kunden mit
Produktionsbetrieb gehen dieses Risiko nicht ein.

Nordwind, Steinbach und Birkenhof sind genau die drei Kunden, die ein
Testsystem betreiben. Das ist kein Zufall.
