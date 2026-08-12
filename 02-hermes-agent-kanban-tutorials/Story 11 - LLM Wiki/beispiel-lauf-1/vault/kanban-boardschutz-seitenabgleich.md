# Seiten-Abgleich: kanban-boardschutz

Item: vault/kanban-boardschutz.md (triage, score 76)
Quelle: sources/releases/changelog-0.20.1.md + changelog-0.20.2.md (offizieller Changelog)
Betroffene Seite: wiki/pages/kanban-board.md
Verwandte, geprueft und nicht betroffen: wiki/pages/gateway-und-dispatcher.md

## Auftrag der Karte

Drei Guardrails pruefen: (a) relativer `workspace_path` in `kanban_create`
abgewiesen, (b) `kanban complete a b c --summary` mit Handoff-Flags abgewiesen,
(c) `kanban stats`-Alter (aelteste `ready`-Karte in Minuten).

## Was die Quellen SAGEN (woertlich)

Aus changelog-0.20.2.md:
- Z.17–20 (Guardrail a): "Ein relativer `workspace_path` wurde stillschweigend
  abgewiesen — die Karte entstand, wurde aber nie gestartet und es gab keine
  Fehlermeldung auf dem Board. Der Aufruf schlaegt jetzt mit einer Meldung
  fehl, statt eine unstartbare Karte zu hinterlassen."
- Z.32–33 (Guardrail c): "`hermes kanban stats` zeigt zusaetzlich das Alter der
  aeltesten `ready`-Karte in Minuten statt nur als Zeitstempel."

Aus changelog-0.20.1.md:
- Z.37–40 (Guardrail b): "`hermes kanban complete a b c --summary …` bleibt
  abgewiesen, wenn Handoff-Flags gesetzt sind. Das ist Absicht: Summary und
  Metadata gelten je Run, und dieselbe Zusammenfassung auf drei Karten zu
  kopieren ist fast immer falsch."

## Was ich VERIFIZIERT habe

Ich habe die Seite wiki/pages/kanban-board.md vollstaendig gelesen (72 Zeilen).
Der Abschnitt "Werkzeuge im Worker" (Z.45–54) zaehlt die Worker-Werkzeuge auf
(`kanban_show`, `kanban_list`, `kanban_complete`, `kanban_block`,
`kanban_heartbeat`, `kanban_comment`, `kanban_create`, `kanban_link`,
`kanban_unblock`, `kanban_attach`) und beschreibt `kanban_create` als
"das Werkzeug, mit dem ein Worker das Board selbst erweitert — die Grundlage
jeder Pipeline, die ihren eigenen Graphen baut."

Keiner der drei Guardrails steht dort:

| Guardrail | In der Seite? | Stelle, wo es gehoerte |
|---|---|---|
| (a) relativer workspace_path abgewiesen | NEIN | Abschnitt "Werkzeuge im Worker" |
| (b) complete a b c + Handoff-Flags abgewiesen | NEIN | Abschnitt "Werkzeuge im Worker" |
| (c) stats-Alter in Minuten | NEIN | nirgends; keine Erwaehnung von `kanban stats` |

Ich habe alle Seiten unter wiki/pages/ per Suche auf die Merkmale geprueft
(kanban_create, workspace_path, relativ, complete, stats, Alter, Minuten,
Handoff, summary, ready). Treffer gab es nur in kanban-board.md (die
Werkzeugliste selbst) und gateway-und-dispatcher.md.

gateway-und-dispatcher.md erwaehnt zwar `HERMES_KANBAN_WORKSPACE` als
"aufgeloester Workspace-Pfad" (Z.45) — das ist aber der vom Dispatcher gesetzte
Env-Pfad und sagt NICHT, dass ein relativer workspace_path in `kanban_create`
abgewiesen wird. Das ist kein Guardrail (a), nur ein Themen-Nachbar.

## Was ich SCHLIESSE

Alle drei Guardrails fehlen auf der Zielseite in gleicher Genauigkeit. Es gibt
keinen Widerspruch: keine Seite behauptet Gegenteiliges, die Seite erwaehnt die
Werkzeuge nur ohne diese Verhaltensgrenzen. Die Seite existiert und ist der
richtige Ort (Abschnitt "Werkzeuge im Worker"). Damit ist der Abgleich
**unvollstaendig** — er gaebe sich als `update` der bestehenden Seite, nicht
als neue Seite und nicht als konflikt oder shelve.

wissensstand: unvollstaendig