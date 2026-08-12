# minibuch

Ein winziges Buchhaltungsmodul. Kein Framework, keine Abhaengigkeiten ausser
der Standardbibliothek.

```
ledger/model.py     Datensatz und Speicher
ledger/reports.py   vorhandener Bericht (Monatssummen)
web/index.html      minimale Oberflaeche
web/app.js          holt Berichte und stellt sie dar
tests/              Tests zur Standardbibliothek
```

Starten:

```bash
python3 -m tests.test_reports
python3 -m http.server -d web 8099
```
