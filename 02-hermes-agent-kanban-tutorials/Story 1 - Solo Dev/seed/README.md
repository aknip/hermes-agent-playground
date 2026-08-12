# miniauth — Übungsprojekt für Story 1

Ein absichtlich leeres Mini-Projekt. Die Kanban-Worker füllen es.

```
workspace/
├── README.md          ← diese Datei (Startdatei, wird nie überschrieben)
├── auth/
│   └── __init__.py    ← Startdatei, hier landet die API-Implementierung
├── migrations/        ← hier landen die SQL-Migrationen des Schema-Workers
└── tests/             ← hier landen die Integrationstests des QA-Workers
```

Aufgabe des Projekts: ein minimaler Authentifizierungs-Baustein mit
Registrierung, Login, Token-Refresh und Logout. Bewusst ohne Framework —
es geht um die Kanban-Mechanik, nicht um Web-Frameworks.

Die drei Kanban-Tasks der Story hängen voneinander ab:

    Design auth schema  →  Implement auth API endpoints  →  Write auth integration tests
         backend-dev              backend-dev                        qa-dev
