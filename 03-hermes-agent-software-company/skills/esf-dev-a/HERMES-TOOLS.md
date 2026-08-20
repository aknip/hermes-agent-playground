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
| `find /`, `find ~`, „search the filesystem" | **nie.** Dein Suchraum ist das Produkt-Repo und der Vault — nichts darüber. `git -C <repo> ls-files`, `grep -rn … <repo>`, `glob` im Workspace |
| „create a PR" | Branch committen und fertigmelden. Merge macht `scripts/merge-riegel.sh`, nicht du |

## Eine Suche über das Dateisystem ist ein Hänger, keine Suche

Am 20.08.2026 gemessen, im Probelauf der ESF gegen sich selbst: Zwei von vier
Karten verbrachten **83 von 146 Minuten Kartenzeit** in dateisystemweiten
Suchen. Die Bau-Karte suchte zweimal mit `find $HOME` nach einem pnpm-Store
(~12 min). Die Gate-Karte startete `find / -name tastatur-command-palette.spec.ts`
und stand damit **71 Minuten bei 0 % CPU** auf einem hängenden Netzlaufwerk —
ohne einen Eingriff von Hand wäre sie in ihren 90-Minuten-Deckel gelaufen:
voller Preis, kein Ergebnis, vollständige Wiederholung.

Dein Suchraum ist das Produkt-Repo und der Vault. In dieser Reihenfolge:

    git -C <repo> ls-files | grep <muster>     kennt nur versionierte Dateien — meist genau richtig
    grep -rn <muster> <repo>/<unterordner>     wenn du den Inhalt suchst
    glob im Workspace                          für den Vault

Findest du etwas dort nicht, dann **existiert es für deine Karte nicht.**
Schreib das hin — ein „nicht gefunden, gesucht in X und Y" ist ein Ergebnis.
Das Dateisystem abzugrasen ist keines: Du weißt vorher nicht, wie lange es
dauert, und dein Deckel läuft mit.

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
