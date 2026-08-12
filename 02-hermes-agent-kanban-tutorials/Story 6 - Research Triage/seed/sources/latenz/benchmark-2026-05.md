# Benchmark Meridian 1 vs. 2 — Lauf Mai 2026

Aufbau: identische Hardware, identischer Datensatz (120 Mio Events),
je fuenf Durchlaeufe, Median.

| Operation | Meridian 1 | Meridian 2 | Veraenderung |
|---|---|---|---|
| Dashboard-Kaltstart | 1,9 s | 1,1 s | **-42 %** |
| Dashboard warm | 0,4 s | 0,3 s | -25 % |
| Ad-hoc-Abfrage, 7 Tage | 2,2 s | 1,4 s | -36 % |
| Ad-hoc-Abfrage, 90 Tage | 9,8 s | 4,1 s | **-58 %** |
| Backfill, 40 Mio Events | 4 h 10 min | 5 h 55 min | **+42 %** |
| Export CSV, 10 Mio Zeilen | 3 min 20 s | 8 min 05 s | **+142 %** |

Fazit des Teams: Meridian 2 ist im interaktiven Betrieb deutlich schneller und
im Massendurchsatz deutlich langsamer.
