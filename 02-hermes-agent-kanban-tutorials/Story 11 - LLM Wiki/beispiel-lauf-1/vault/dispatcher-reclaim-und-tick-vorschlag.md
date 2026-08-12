# Ingest-Vorschlag: Update — Dispatcher: Reclaim idempotent, Tick bricht nach pause ab

**Slug:** `dispatcher-reclaim-und-tick` · **Route:** `update` · **Punkte:** 85/100
**Branch (geplant):** `kb/ingest-dispatcher-reclaim-und-tick`

## 1. Was aufgenommen werden soll

Zwei Patch-Releases (0.20.1, 0.20.2) ändern zwei Verhalten des Dispatchers bzw.
Gateway, die auf der bestehenden Seite fehlen. (1) Seit 0.20.1 ist der
Claim-Reclaim idempotent: ein Claim, dessen Worker ohne `kanban_heartbeat`
lief, wurde in seltenen Fällen doppelt eingesammelt und die Karte doppelt
gespawnt; genau das ist jetzt unterbunden. (2) Seit 0.20.2 bricht ein bereits
laufender Tick nach einem `hermes pause` nach dem aktuellen Spawn ab statt
seine restlichen Spawns noch zu beenden – laufende Arbeit stirbt dabei nicht,
es kommen nur keine neuen Spawns mehr dazu.

## 2. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `changelog-0.20.1.md` | „## Behoben", Kanban/Dispatcher, Z. 22–24 | „Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt gespawnt. Der Reclaim ist jetzt idempotent." |
| `changelog-0.20.2.md` | „## Behoben", Gateway, Z. 27–28 | „Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab." |

**Verifikations-Bahn sagt:** beide Teilaussagen decken den offiziellen Changelog
exakt ab (höchste Quellenklasse). Die Konfigurationsaussage über
`kanban.dispatch_stale_timeout_seconds` (pro Profil überschreibbar) wird
**bewusst nicht** aufgenommen: sie steht nur im Changelog, nicht an der
Installation verifiziert.

## 3. Betroffene Seiten

| Seite | Änderung | Warum |
|---|---|---|
| `pages/gateway-und-dispatcher.md` | Abschnitt `## Details`/`### Heartbeats` ergänzen; Betrieb-Tabelle (`hermes pause`) präzisieren | Seite nennt bereits Reclaim-Mechanismus + Default 14400 und listet `hermes pause`; die beiden neuen Präzisierungen fehlen dort in gleicher Genauigkeit |

**Index:** unverändert (`gateway-und-dispatcher` ist bereits im Index)
**Neue Seiten:** keine
**Prune-Kandidaten:** keine

## 4. Was NICHT aufgenommen wird

Es wird nur die Präzisierung der bestehenden gateway-und-dispatcher-Seite
übernommen, kein Changelog-Absatz abgeschrieben. Die Seite `cron-und-zeitplan.md`
(Pause aus Cron-Perspektive) wird bewusst nicht angefasst: deren Aussage
„laufende Arbeit wird dabei nicht getötet" bleibt korrekt und konsistent mit #2
– der Tick stapelt nur keine neuen Spawns mehr. Die Versionsangabe
`version: 0.20.0` wird auf die aktuelle Patch-Ebene gehoben, ohne eigene Seite
je Patch. Die Changelog-Aussage zur pro-Profile-Überschreibbarkeit von
`dispatch_stale_timeout_seconds` wird nicht übernommen (nur im Changelog, nicht
verifiziert).

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 18/25 | Zwei Dispatcher-Verhaltensänderungen, keine steht so auf der Seite. |
| quellenvertrauen | 20/20 | Offizieller Changelog 0.20.1/0.20.2, höchste Quellenklasse. |
| themenbezug | 22/25 | Direkt Gateway/Dispatcher; weniger Kern als Block-Semantik. |
| versionsrelevanz | 15/15 | Betrifft die aktuellen Patch-Versionen. |
| klarheitsgewinn | 10/15 | Präzisiert Heartbeat/Reclaim und Pause-Verhalten; kein neues Thema. |
| **Summe** | **85/100** | Schwelle 65 |