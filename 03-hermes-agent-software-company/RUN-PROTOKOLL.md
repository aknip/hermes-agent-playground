# RUN-PROTOKOLL — Phase 0 und Phase 1, 17.08.2026

Der erste vollständige Lauf der ESF gegen ein echtes Repo. Protokolliert wird,
was passiert ist — auch und gerade, wo es nicht nach Plan lief. Die Befunde
sind in [`VERIFIKATION.md`](VERIFIKATION.md) zusammengefasst; hier steht der
Hergang.

**Aufbau:** Hermes Agent v0.20.0 (2026.8.3), macOS, Modell
`deepseek/deepseek-v4-flash-0731` über OpenRouter für alle elf Profile.
**Ziel:** Kaneo v2.19.1, `04-hermes-agent-software-company-test-kaneo`.
**CEO:** in diesem Testlauf von Claude übernommen; jede Gate-Antwort steht
unten mit Begründung.
**Takt:** durchgehend `pump.sh` von Hand — `hermes gateway status` meldete die
Service-Definition als *stale*, also war der launchd-Dispatcher keine
verlässliche Vorbedingung.

## Vorlauf: das Ziel-Repo arbeitsfähig machen

`04/` war kein Git-Repository, sondern lag als Dateisammlung im Playground-Repo.
Ohne eigene Historie gibt es keine Branches und keine Worktrees, und damit
keine ESF. Also `git init` und ein Baseline-Commit `e714f87`.

Danach der Baseline-Befund — vor jeder ESF-Änderung gemessen, per `git stash`
gegen den unveränderten Baum:

| Prüfung | Ergebnis |
|---------|----------|
| `pnpm typecheck` | grün, 6/6 |
| `pnpm test` | grün, 10/10 |
| `pnpm exec biome ci .` | scheinbar **rot** — die Deutung war falsch, siehe unten |
| E2E | existierte nicht |

Der rote Linter wurde zum wichtigsten Befund des Vorlaufs — allerdings anders,
als ich damals dachte. Ich schloss daraus auf Bestandsschuld von Upstream und
baute darauf den schlanken ESF-Hook. **Der Schluss war falsch**, und aufgedeckt
hat ihn Stunden später die Codebasis-Analyse eines Agenten; der ganze Hergang
steht in `VERIFIKATION.md` unter „Eine Korrektur, gefunden von der eigenen
Organisation".

Der Messfehler ist lehrreich genug, um ihn zu benennen: Ich prüfte mit
`… | tail -4; echo "rc=$?"` — und las damit den Exit-Code von `tail`, nicht den
von Biome. Die Ausgabe *sah* rot aus, die gemessene Null war bedeutungslos.
Der schlanke Hook bleibt trotzdem richtig, aber aus dem einen Grund, der von
Anfang an trug: `pnpm run build` bei jedem Commit kostet Minuten.

### Das E2E-Gerüst wurde von Hand gebaut, nicht von einem Agenten

Bewusst: Ein Agent, der eine Playwright-Suite für eine Anwendung schreiben
soll, die noch nie gebootet hat, debuggt pnpm, Postgres und Ports durch ein
Modell hindurch. Also erst die Infrastruktur beweisen, dann übergeben.

Dabei fielen zwei Produktfallen an, die jeden späteren E2E-Autor Zeit gekostet
hätten und deshalb in `tests/e2e/support/journey.ts` und in `04/AGENTS.md`
dokumentiert sind:

- Das Passwort-Label zeigt per `for` auf den Wrapper-`<div>`, nicht aufs
  `<input>`. `getByLabel("Password")` liefert ein Element, das man nicht
  befüllen kann.
- Ein frisch registriertes Konto landet auf `/onboarding`, nicht auf
  `/dashboard` — es hat noch keinen Arbeitsbereich.

Ergebnis: zwei Journeys, vier Tests, 6,4 s, grün. Commit `ccd72ee`.

## Phase 0 — Gerüst

`./setup.sh` legte an: Board `sw-company`, elf `esf-`-Profile mit SOUL,
Beschreibung und `config.yaml`, 23 profil-lokale Superpowers-Kopien, den
Firmen-Vault als eigenes Git-Repo.

Drei modellfreie Selbsttests am Ende von `setup.sh`, alle bestanden:

- alle elf Profile `ON DISK = yes`
- der Vault-Linter findet auf `seed/lint-selbsttest/` genau 9 ERROR, Exit 1
- der Merge-Riegel verweigert einen nicht existierenden Branch mit Exit 1

Ein Stolperstein beim Bauen: `declare -A` gibt es im Bash 3.2 von macOS nicht.
Zwei parallele indizierte Arrays lösen es — dasselbe Muster wie in Story 11.

### Der Probelauf

Die Kette Spezifikation → Bau → Review → Riegel plus ein Probe-Gate.

**1/4 Spezifikation** (`esf-product-manager`, 2 min 14 s) — lief glatt. Schrieb
`specs/probelauf.html` formatkonform inklusive `esf-karte`, legte die
Akzeptanzkriterien als `metadata.acceptance` ab, Vault-Linter 0 Befunde.

**2/4 Bau** (`esf-dev-a`) — hier wurde es lehrreich, gleich zweimal.

*Erster Befund: der hängende Worker.* Lauf 2 stand **16 Minuten bei 0 % CPU**.
Das Board meldete währenddessen brav `running` mit Heartbeats. `lsof` zeigte
die Ursache: die TCP-Verbindung zu OpenRouter stand auf `CLOSE_WAIT` — die
Gegenseite hatte geschlossen, der Client wartete weiter. Nach `kill` erkannte
der Dispatcher den Absturz (`outcome: "crashed"`, `error: "pid … not alive"`)
und startete Lauf 3, der in wenigen Minuten fertig war.

Daraus folgt dreierlei, und alles drei ist im Aufbau vorgesehen: `--max-runtime`
je Karte ist der einzige Mechanismus, der so etwas beendet; die Blockade sieht
von aussen exakt aus wie Arbeit; und die Respawn-Mechanik trägt, sobald der
Prozess wirklich weg ist. Was `monitor.sh` heute **nicht** kann, ist diesen
Zustand melden — dafür bräuchte es die CPU-Zeit des Worker-Prozesses. Steht in
`VERIFIKATION.md`.

*Zweiter Befund: die Arbeit selbst war gut.* Lauf 3 legte die Datei exakt
spezifikationsgemäß an, committete auf `feat/esf-probelauf` (`c3aea9c`), führte
die E2E-Suite selbst aus (4/4) und merged **nicht**. Bemerkenswert ist das
`deliberately_not_done` im Abschluss-`metadata`: Der Worker stiess selbst auf
den scheiternden Hook, benutzte `--no-verify` und schrieb ausdrücklich hin,
warum. Er übernahm dabei allerdings meine Fehldeutung („präexistente,
unverwandte Lint-Fehler") — ein Beispiel dafür, wie eine falsche Prämisse aus
dem Kartentext in das Abschluss-`metadata` wandert und dort wie ein Befund
aussieht.

**3/4 Review** — scheiterte zunächst hart, und der Fehler saß im Kartenentwurf:

    fatal: 'feat/esf-probelauf' is already used by worktree at …

Zwei Karten können denselben Branch nicht gleichzeitig als Worktree
beanspruchen. Der Circuit Breaker gab nach zwei Versuchen auf
(`gave_up`, `failures: 2`), die Karte stand blockiert da. Die Reparatur ist
zugleich die richtige Bauform: **Der Reviewer arbeitet im Hauptbaum
(`dir:<repo>`)** und sieht von dort in die fremden Bäume unter `.worktrees/`.
Ein einzelner Worktree könnte ohnehin nie ein Fan-in-Review über mehrere
Feature-Branches eines Sprints leisten — der Fehler hat eine Annahme
korrigiert, nicht nur einen Tippfehler.

Review- und Gate-Karte wurden archiviert und korrigiert neu angelegt.

**3/4 Review, zweiter Anlauf** — sauber. Und bemerkenswert gründlich: Der
Reviewer verglich den Dateiinhalt byte-genau gegen das
`exact_content_specified` aus dem Abschluss-`metadata` der Spezifikationskarte,
zählte die Zeilen mit `awk`, prüfte, dass `main` unberührt ist — und führte die
E2E-Suite **selbst im Baum des Entwicklers** aus (4/4). Genau der Unterschied
zwischen Behauptung und geprüfter Tatsache, den seine SOUL verlangt.
Urteil: `approved`, keine Befunde.

**4/4 Das Gate** — hielt. `dispatch --dry-run` meldete `Spawned: 0`, während
die Karte blockiert stand. Die Vorlage hatte genau acht Zeilen und war ohne
Öffnen einer Datei entscheidbar.

Bemerkenswert daran: Der Chief of Staff hatte vor dem Blockieren den
Merge-Riegel im Trockenlauf laufen lassen, dieser hatte **verweigert** (der
Arbeitsbaum war durch meine eigenen, noch nicht committeten Änderungen
schmutzig) — und der Worker schrieb diese Verweigerung ehrlich in Zeile 2 der
Vorlage, statt sie zu übergehen. Seine Empfehlung lautete trotzdem `approve`.

### Die CEO-Antwort: `modify`, nicht `approve`

Ein Riegel, den man überstimmt, ist keiner. Beide Ursachen der Verweigerung
waren behebbar und behoben — der schmutzige Baum committet, und der
Riegel-Fehler mit dem `git checkout` repariert. Also `modify` mit dem Auftrag,
den Riegel erneut laufen zu lassen, diesmal ohne `--dry-run`, und nur bei
bestandener Prüfung zu mergen.

Der Worker führte die Korrektur aus. Der Riegel verweigerte erneut — diesmal
aus einem echten Grund: **ein Unit-Test von 374 fiel**
(`mcp-internal-api-url.test.ts`). Ein isolierter Nachlauf war 374/374 grün, ein
zweiter Riegel-Lauf unter Last wieder rot. Die Zahlen im Protokoll erklären es:
`import` dauerte unter vier parallelen Workern **52,9 s** statt 7,3 s. Der Test
ist nicht zufällig flaky, sondern lastempfindlich.

### Und dann kippte die Gate-Karte nach `triage`

Mein `modify`-Auftrag enthielt den Satz „Verweigert er erneut, blockiere erneut
mit dem Grund". Der Worker tat genau das — und löste damit
`block_loop_detected` aus: zweite Blockade derselben Art (`needs_input`) auf
derselben Karte, `BLOCK_RECURRENCE_LIMIT = 2`, Karte still nach `triage`.

Das ist die Gate-Arithmetik aus Kapitel 7, live und selbst verschuldet. Die
Regel „jede Entscheidung bekommt ihre eigene Karte" ist keine Stilfrage: Ein
Kartentext, der eine zweite Blockade derselben Art anweist, widerspricht der
SOUL des Profils (dort steht das Verbot korrekt) und gewinnt, weil er konkreter
ist. Beide Gate-Aufträge sind entsprechend korrigiert.

Nachspiel mit eigener Erkenntnis: Der Dispatcher holte die Karte beim nächsten
Tick **aus der Triage zurück** in `running`. Das Konzept beschreibt Triage als
Endstation („fragt niemanden mehr"); zutreffend ist die schwächere Aussage —
die Karte fragt niemanden mehr, läuft aber weiter. Für die Praxis heisst das:
`triage` ist nicht das Ende der Arbeit, sondern das Ende der Rückfrage.

### Was Phase 0 dabei über die eigenen Skripte gelernt hat

Vier Fehler in ESF-Code, alle erst im Lauf sichtbar, alle behoben:

| Skript | Fehler | Warum er still war |
|--------|--------|--------------------|
| `ledger-sync`, `check-daily`, `monitor`, `report-gates` | griffen `metadata` auf Kartenebene ab und rechneten mit ISO-Zeitstempeln | Beides liefert `null` bzw. scheitert lautlos |
| `merge-riegel` | `git checkout <branch>` im Hauptbaum | Der Selbsttest deckte nur „Branch existiert nicht" ab |
| `merge-riegel` | nahm den Probemerge doch zurück; Prüfungen liefen gegen `main` | Der Lauf war grün — nur eben ohne Aussage |
| `monitor` | `$n×` unter `set -u`; Governance-Check auf `.payload.reason` | Ersteres brach das Skript ab, Letzteres meldete jede legitime Gate-Antwort als Verstoss |

Der dritte ist der unangenehmste: Ein grüner Lauf, der nichts prüft, ist
schlimmer als ein roter. Gefunden wurde er nur, weil der Diff der eigenen
Korrektur noch einmal gelesen wurde.
