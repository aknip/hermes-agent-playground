# Story 8 — Eine dauerhafte Identitaet

`mailops/` ist der Arbeitsraum eines **benannten Assistenten**, nicht eines
Wegwerf-Workers. Dasselbe Profil (`inbox-triage`) laeuft jeden Zyklus auf
demselben Postfach fuer denselben Menschen.

```
mailops/
├── PROFILE.md            wer der Eigentuemer ist, wie er schreibt, wer zaehlt
├── MEMORY-NOTES.md       was der Assistent gelernt hat — zu Beginn fast leer
├── ESKALATIONSREGELN.md  was er NICHT entscheiden darf
├── inbox/zyklus-1/       fuenf Nachrichten
├── inbox/zyklus-2/       fuenf Nachrichten, teils dieselben Absender
├── drafts/               Ziel: Antwortentwuerfe (nie versendet)
├── legal/                Ziel: die Einschaetzung des @legal-Profils
└── logs/journal.jsonl    Ziel: eine Zeile je Entscheidung
```

`MEMORY-NOTES.md` ist der Unterschied zu einem Cronjob. Nach Zyklus 1 steht
darin, was der Assistent ueber die Absender gelernt hat; in Zyklus 2 liest er
es wieder ein. Vergleiche die Datei vor und nach dem ersten Lauf — das ist der
ganze Punkt dieser Story.

In `inbox/zyklus-1/` liegt eine Nachricht mit einer Vertragsklausel. Die darf
der Assistent laut `ESKALATIONSREGELN.md` nicht selbst beantworten: er legt
dafuer eine Karte fuer das Profil `legal` an — mitten im Lauf, ohne
anzuhalten.
