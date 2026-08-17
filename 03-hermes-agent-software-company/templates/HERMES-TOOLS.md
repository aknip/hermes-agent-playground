# Superpowers auf Hermes — das Werkzeug-Mapping

Die Skills in diesem Ordner stammen aus [obra/superpowers](https://github.com/obra/superpowers)
und sind für Claude Code geschrieben. Du bist ein Hermes-Worker. Wo ein Skill
ein Werkzeug nennt, das du nicht hast, gilt diese Übersetzung.

**Lies das hier, bevor du einem Skill folgst.**

## Werkzeuge

| Superpowers sagt | Du benutzt |
|------------------|------------|
| `Read`, `Write`, `Edit`, `Glob`, `Grep` | dieselben Dateiwerkzeuge — unverändert |
| `Bash` | `terminal` |
| `Skill`, „invoke the skill" | `skill_view` — der Skill wird gelesen, nicht ausgeführt |
| `Task` / Subagent starten | `delegate_task`, oder eine Karte per `kanban_create` |
| `TodoWrite` | keine Entsprechung. Der Plan gehört in eine Datei im Workspace, der Fortschritt in dein Abschluss-`metadata` |
| `AskUserQuestion`, „ask the user" | `kanban_block(kind="needs_input", reason=…)`. Du hast keinen Chat: Blockieren **ist** die Frage. Die Antwort steht bei deinem nächsten Lauf im Kommentar-Thread |
| `ExitPlanMode`, Plan-Modus | gibt es nicht. Du planst, schreibst den Plan in eine Datei und arbeitest weiter |
| `WebFetch`, `WebSearch` | **nicht verfügbar.** Alles Externe liegt als Datei im Workspace (`company/sources/<datum>/`). Kein Netz heißt: was nicht im Korpus steht, ist nicht belegt |
| „create a PR" | Branch committen und fertigmelden. Merge macht `scripts/merge-riegel.sh`, nicht du |

## Vier Stellen, an denen Hermes anders ist als der Skill annimmt

**1. Du kannst nicht zurückfragen und weiterarbeiten.** In Claude Code stellt
ein Skill eine Frage und bekommt im selben Zug eine Antwort. Hier endet dein
Lauf mit dem Block. Formuliere die Frage deshalb so, dass sie ohne Nachhaken
beantwortbar ist — und nur die Fragen, die du wirklich brauchst.

**2. Denselben `kind` nie zweimal auf derselben Karte.** Hermes zählt das als
Schleife und schiebt die Karte still nach `triage`, wo niemand hinsieht.
Nutzbar sind `needs_input` und `capability` — also höchstens zwei Fragen je
Karte, je einmal.

**3. Der Arbeitsbereich ist gesetzt, nicht gewählt.** `using-git-worktrees` will
einen Worktree anlegen; deiner existiert bereits — die Karte wurde mit
`--workspace worktree:<repo> --branch <name>` gestartet. Du arbeitest darin und
legst keinen zweiten an.

**4. Fertig heißt `kanban_complete`.** Kein Skill-Ende, keine Zusammenfassung im
Chat. Was nicht in `summary` und `metadata` steht, ist nicht passiert — das
`metadata` ist der Audit-Kanal der ganzen Organisation.

## Was trotzdem unverändert gilt

Der Kern der Skills überträgt sich eins zu eins, und er ist der Grund, warum sie
hier liegen:

- **RED-GREEN-REFACTOR.** Erst der fehlschlagende Test, dann der Code. Einen
  Test, den du nicht hast scheitern sehen, hast du nicht geprüft.
- **Erst die Ursache, dann der Fix.** `systematic-debugging` verbietet das
  Herumprobieren, und das Verbot gilt hier genauso.
- **Belege vor Behauptungen.** `verification-before-completion` ist die
  Skill-Fassung des Verifikationsvertrags dieser Organisation: Befehl
  ausgeführt, Ausgabe gesehen, dann erst „fertig" sagen.
