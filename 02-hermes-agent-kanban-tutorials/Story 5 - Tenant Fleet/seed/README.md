# Story 5 — Mandantenflotte

`accounts/` enthaelt sechs vollstaendig getrennte Kundendatenraeume. Ein
einziges Profil (`account-manager`) bearbeitet alle sechs — pro Kunde eine
eigene Karte, ein eigener Mandant (`--tenant`) und ein eigener Workspace.

```
accounts/
├── acct-halden/       Enterprise, Health gelb   — Vertragsblocker offen
├── acct-nordwind/     Enterprise, Health gruen
├── acct-pergament/    Business,   Health rot    — hat gekuendigt
├── acct-quellwerk/    Business,   Health gruen
├── acct-steinbach/    Enterprise, Health gelb   — Auditfrist
└── acct-torfhaus/     Starter,    Health gruen  — activity.csv fehlt absichtlich
```

`acct-torfhaus` hat **keine** `activity.csv`. Das ist kein Versehen: an diesem
Kunden zeigt die Story die Fehlerisolation. Seine Karte blockiert, die anderen
fuenf laufen durch.

Eine siebte Kunde hinzuzunehmen ist ein `mkdir` — der Enumerator in
`scripts/fleet-tick.sh` zaehlt `accounts/*` ab und braucht keine Aenderung.
