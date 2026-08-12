# Review-Feedback zum Passwort-Reset (offen)

Status: **OFFEN** — zwei Punkte blockieren das Merge.

1. **Passwortstärke wird nicht geprüft.**
   `POST /reset` akzeptiert jedes nicht-leere Passwort. Es fehlt eine
   Mindestprüfung (Länge, Trivialpasswörter, Ähnlichkeit zur E-Mail-Adresse).

2. **Der Reset-Link ist nicht single-use.**
   Der Token bleibt bis zum Ablauf (30 Minuten) gültig und kann innerhalb
   dieses Fensters mehrfach eingelöst werden. Er muss beim ersten
   erfolgreichen Reset invalidiert werden.

Nicht blockierend, aber erwünscht:

- Nach erfolgreichem Reset sollten alle aktiven Sessions des Nutzers
  invalidiert werden.
