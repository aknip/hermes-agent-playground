# miniauth — Übungsprojekt für Story 3: Passwort-Reset

Drei Rollen arbeiten hintereinander am selben Feature:

    Spec: password reset flow  →  Implement password reset flow  →  Review password reset PR
              pm                          backend-dev                      reviewer

```
workspace/
├── README.md            ← diese Datei
├── REVIEW-FEEDBACK.md   ← offene Review-Punkte (Auslöser für den Block im 1. Versuch)
├── spec/                ← hier landet die Spezifikation des PM-Workers
└── auth/
    └── reset.py         ← hier landet die Implementierung des Engineer-Workers
```

## Warum REVIEW-FEEDBACK.md existiert

Story 3 soll zeigen, wie ein Task **blockiert** und danach in einem **zweiten Run**
erfolgreich abgeschlossen wird. Damit das reproduzierbar ist und nicht von der
Tageslaune des Modells abhängt, steht im Task-Body eine harte Regel:

- **Erster Versuch** (kein früherer Run im `worker_context`):
  Der Worker liest `REVIEW-FEEDBACK.md` und ruft `kanban_block()` mit diesen
  Punkten als Begründung auf. Der Run schließt mit Outcome `blocked`.
- **Zweiter Versuch** (nach `hermes kanban unblock`, mit dem Block-Grund im
  `worker_context`): Der Worker arbeitet genau diese Punkte ab und schließt
  mit `kanban_complete()` ab.

Das ist gleichzeitig die Demonstration der Kernaussage von Story 3: der
Worker im zweiten Versuch **sieht**, warum der erste Versuch scheiterte, und
fängt nicht von vorne an.
