# Story 9 — Parallele Worktrees

`repo/` ist ein kleines, echtes Projekt. `reset-workspace.sh` kopiert es nach
`workspace/repo/` und macht daraus ein **Git-Repository mit einem
Ausgangscommit** — Worktrees brauchen ein Repo, an dem sie haengen koennen.

```
workspace/repo/                  main
├── .worktrees/<task-id>/        wt/s9-backend    (vom Dispatcher angelegt)
└── .worktrees/<task-id>/        wt/s9-frontend   (vom Dispatcher angelegt)
```

Backend- und Frontend-Entwickler arbeiten **gleichzeitig** in getrennten
Arbeitsbaeumen auf getrennten Branches. Sie sehen die Dateien des jeweils
anderen nicht. Der Reviewer arbeitet danach im Hauptbaum und liest beide
Branches per `git diff`.

Der Ausgangscommit enthaelt absichtlich schon einen Bericht
(`ledger/reports.py`) — daran koennen sich beide Entwickler stilistisch
orientieren, statt sich etwas auszudenken.
