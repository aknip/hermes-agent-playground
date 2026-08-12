# Story 7 — Wiederkehrendes Briefing auf einem langlebigen Vault

`vault/` ist **kein** Wegwerf-Arbeitsverzeichnis. Es ist der Ordner, in dem
das Briefing ueber Wochen waechst — dieselbe Struktur, die man in einem
Obsidian- oder Notiz-Vault haette.

```
vault/
├── READER-PROFILE.md   fuer wen geschrieben wird — die Relevanzgrundlage
├── INDEX.md            Verzeichnis aller Ausgaben, wird fortgeschrieben
├── journal.jsonl       eine Zeile je Lauf — was die Pipeline schon getan hat
├── sources/<datum>/    die Rohabwuerfe eines Tages
├── shortlists/         Zwischenergebnis des Editors
└── editions/           die fertigen Ausgaben, eine Datei je Tag
```

Zwei Tagesabwuerfe liegen bei: `sources/2026-08-10/` und `sources/2026-08-11/`.
Der zweite enthaelt bewusst **zwei Meldungen, die schon am 10. drin waren**.
Daran zeigt sich, ob die Pipeline ihren eigenen Verlauf liest: der Editor soll
sie an Tag 2 nicht noch einmal durchlassen.
