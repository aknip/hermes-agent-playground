# Ingest-Vorschlag: Neue Seite — <titel>

**Slug:** `<slug>` · **Route:** `neue_seite` · **Punkte:** <score>/100
**Branch (geplant):** `kb/ingest-<slug>`

## 1. Warum es diese Seite noch nicht gibt

<Ein Satz: was in der Wissensbasis geprüft wurde und was dort fehlt. „Nicht
gefunden" genügt nicht — nenne die Seiten, die geprüft wurden.>

## 2. Geplante Seite

**Dateiname:** `pages/<neuer-slug>.md`

```yaml
title: <titel>
slug: <neuer-slug>
updated: <YYYY-MM-DD>
tags: [<tag>, …]
sources: [<datei>, …]
version: <version>
```

**Gliederung nach AGENTS.md 2.2:**

- `## Kurzfassung` — <ein Satz, was dort stehen wird>
- `## Details` — <die geplanten ###-Unterabschnitte, als Liste>
- `## Quellen` — <welche>
- `## Siehe auch` — <welche Wikilinks>

**Geschätzte Länge:** <n> Zeilen (Grenze 120)

## 3. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `<datei>` | <zeitmarke> | „<zitat>" |

**Verifikations-Bahn sagt:** <bestätigt | teilweise bestätigt | nicht belegbar>
— <ein Satz>

## 4. Folgen für den Rest der Wissensbasis

**Index:** `[[<neuer-slug>]]` wird ergänzt — Pflicht nach AGENTS.md 4.
**Eingehende Links:** <welche bestehenden Seiten sollen auf die neue verlinken>
**Heilt einen Linter-Befund:** <ja, welchen | nein>
**Prune-Kandidaten:** <keine | Liste>

## 5. Was NICHT aufgenommen wird

<Pflicht. Der Unterschied zwischen Ingest und Kopie.>

## 6. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | <n>/25 | <ein Satz> |
| quellenvertrauen | <n>/20 | <ein Satz> |
| themenbezug | <n>/25 | <ein Satz> |
| versionsrelevanz | <n>/15 | <ein Satz> |
| klarheitsgewinn | <n>/15 | <ein Satz> |
| **Summe** | **<score>/100** | Schwelle 65 |
