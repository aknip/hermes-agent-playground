# ⚠ Ingest-Vorschlag: KONFLIKT — <titel>

**Slug:** `<slug>` · **Route:** `konflikt` · **Punkte:** <score>/100
**Branch (geplant):** `kb/ingest-<slug>`

> Dieser Vorschlag ist **kein** Update. Die neue Information **widerspricht**
> einer bestehenden Seite. Eine der beiden Aussagen ist falsch, und welche das
> ist, entscheidet ein Mensch.

## 1. Die beiden Aussagen, direkt gegenübergestellt

| | Was die Wissensbasis sagt | Was die Quelle sagt |
|---|---|---|
| **Aussage** | <wörtlich, aus der Seite> | <wörtlich, aus der Quelle> |
| **Fundstelle** | `pages/<slug>.md:<zeile>` | `<datei>` <zeitmarke> |
| **Datiert auf** | `updated: <datum>` | <datum> |
| **Bezieht sich auf Version** | <version> | <version> |
| **Quellenart** | <offizielle Doku / Demo / Behauptung> | <dito> |

## 2. Warum sich das nicht auflösen lässt, ohne zu entscheiden

<Zwei bis vier Sätze. Wenn eine Seite einfach älter ist und die neue Quelle
offiziell, sage das — dann ist die Entscheidung leicht, aber sie bleibt eine
Entscheidung. Wenn beide Quellen plausibel sind, sage auch das.>

**Konflikt-Dossier:** `vault/<slug>-konflikt.md`

## 3. Wie sich der Konflikt prüfen lässt

<Der wertvollste Abschnitt. Gibt es einen Befehl, ein Experiment, eine Stelle im
Quellcode, mit der man die Frage in einer Minute selbst entscheiden kann? Dann
hierhin — wörtlich, kopierbar.>

```bash
<befehl>
```

**Erwartet, wenn die Quelle recht hat:** <…>
**Erwartet, wenn die Wissensbasis recht hat:** <…>

## 4. Was der Ingest tun würde, wenn du zustimmst

| Seite | Änderung |
|---|---|
| `pages/<slug>.md` | <die falsche Aussage wird **ersetzt**, nicht ergänzt> |
| `pages/<slug>.md` | `updated` und `version` werden nachgezogen |

**Prune:** <Der widerlegte Absatz wird entfernt. Das ist ein Prune und
entscheidet ausschließlich Tor 2 — siehe AGENTS.md 6.>
**Alternative bei `modify`:** `status: strittig` setzen und beide Aussagen mit
Datum stehen lassen.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | <n>/25 | <ein Satz> |
| quellenvertrauen | <n>/20 | <ein Satz> |
| themenbezug | <n>/25 | <ein Satz> |
| versionsrelevanz | <n>/15 | <ein Satz> |
| klarheitsgewinn | <n>/15 | <ein Satz> |
| **Summe** | **<score>/100** | Schwelle 65 |
