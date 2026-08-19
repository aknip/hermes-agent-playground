# VERIFIKATION — was an dieser ESF-Installation belegt ist

Derselbe Vertrag wie in `02-hermes-agent-kanban-tutorials/`: Jede Aussage ist
am Quellcode der installierten Version, an einem protokollierten Lauf oder an
einer der elf verifizierten Stories belegt. Was das nicht deckt, steht unten in
„Nicht verifiziert" — nicht als Tatsache im Tutorial.

**Basis:** Hermes Agent v0.20.0 (2026.8.3), macOS 25.5.0, Modell
`deepseek/deepseek-v4-flash-0731` über OpenRouter.
**Ziel-Repo:** Kaneo v2.19.1 (`04-hermes-agent-software-company-test-kaneo`).
**Lauf:** 17.08.2026, protokolliert in [`RUN-PROTOKOLL.md`](RUN-PROTOKOLL.md).

## In diesem Lauf real gemessen

| Baustein | Befund |
|----------|--------|
| **Board-Schema von `show --json`** | Liefert `{task, runs, events, comments, parents, children, latest_summary}`. Die Karte hat **kein** `metadata`-Feld; das Abschluss-`metadata` eines Workers hängt am **Lauf** (`.runs[].metadata`). Ein `.metadata`-Zugriff auf Karten-Ebene liefert immer `null` — still. |
| **Zeitstempel** | Unix-Epoch-Integer (`started_at`, `ended_at`, `completed_at`, `created_at`), **kein** ISO-8601. Ein `.updated_at` gibt es nicht. `fromdateiso8601` in jq scheitert daran. |
| **Elf Profile dispatchbar** | Nach `hermes -p <p> config set` aller vier Modell-Schlüssel meldet `kanban --board sw-company assignees` für alle elf `ON DISK = yes`. Ohne `config set` legt `profile create` keine `config.yaml` an, und Karten bleiben stumm auf `ready`. |
| **Profil-lokale Skills** | 23 Superpowers-Kopien nach `~/.hermes/profiles/<p>/skills/` verteilt; jedes Profil sieht nur seine Teilmenge. |
| **Worktree-Anlage** | `--workspace worktree:<repo> --branch feat/<slug>` legt den Worktree unter `<repo>/.worktrees/<task-id>/` an. Git ignoriert registrierte Worktrees automatisch — im Hauptbaum bleibt `git status` sauber. |
| **Eltern-Handoff** | Die Spezifikationskarte (`esf-product-manager`, 2 min 14 s) schrieb `specs/probelauf.html` formatkonform inklusive `esf-karte`, und legte Akzeptanzkriterien als `metadata.acceptance` ab. Der Vault-Linter fand 0 Befunde. |
| **Absturz und Respawn** | Ein hängender Worker (`kill`) erzeugt einen Lauf mit `outcome: "crashed"`, `error: "pid … not alive"`; der Dispatcher startet innerhalb eines Ticks Lauf 3. Die Retry-Mechanik trägt. |
| **Vault-Linter** | Auf der Fixture `seed/lint-selbsttest/` genau 9 `ERROR`, 0 `WARN`, Exit 1 — reproduzierbar, modellfrei, Teil von `setup.sh`. |
| **Merge-Riegel** | Verweigert einen nicht existierenden Branch mit Exit 1 und Begründung — Teil von `setup.sh`. |
| **Baseline des Ziel-Repos** | `pnpm typecheck` 6/6 grün, `pnpm test` 10/10 grün, Playwright 4/4 grün. `pnpm exec biome ci .` auf `e714f87` **ohne ESF-Worktrees: Exit 0** (78 Warnungen, 1 Info) — siehe die Korrektur unten. |
| **E2E-Gerüst** | Playwright 1.62.1, zwei Journeys, 4 Tests, 6,4 s. Zwei Produktfallen dokumentiert: das Passwort-Label zeigt per `for` auf den Wrapper-`div` statt aufs `input`; ein frisches Konto landet auf `/onboarding`, nicht auf `/dashboard`. |
| **Fetch und Normalisierung** | 11 Quellen, 10 erreichbar. Roh 6,4 MB, normalisiert 168 KB. `height.app` antwortete nicht und hinterliess eine `.fehler`-Datei. |
| **Gate hält den Dispatcher an** | Bei blockierter Gate-Karte meldet `dispatch --dry-run` wörtlich `Promoted: 0` / `Spawned: 0`. |
| **Die Gate-Arithmetik**, live ausgelöst | Zweite Blockade derselben Art (`needs_input`) auf derselben Karte → Ereignis `block_loop_detected`, Karte still nach `triage`. Auslöser war eine Anweisung im Kartentext, die der SOUL des Profils widersprach — der konkretere Text gewann. |
| **`triage` ist nicht das Ende der Arbeit** | Entgegen der Formulierung im Konzept holte der Dispatcher die Triage-Karte beim nächsten Tick nach `running` zurück. Zutreffend ist die schwächere Aussage: Die Karte fragt niemanden mehr, läuft aber weiter. |
| **Der Unblock-Grund steht im Kommentar** | Das `unblocked`-Ereignis hat eine **leere** Payload; `gate.sh --reason` landet als Kommentar `UNBLOCK: <verb> …`. Wer den Governance-Check auf `.payload.reason` baut, meldet jede legitime Gate-Antwort als Verstoss. |
| **Phase-0-Abschluss** | Kette Spezifikation→Bau→Review→Riegel durchgelaufen; Gate hielt; CEO-Antwort `modify` ausgeführt; Riegel bestand alle sechs Prüfungen und merged `c7eba96` nach `main`. Kein Worker rief je `kanban_unblock`. |
| **Ein Key je Profil wirkt** | Siehe den eigenen Abschnitt unten — nachgewiesen am Verbrauchszähler von OpenRouter, nicht an der eigenen Konfigurationsdatei. |

## Ein OpenRouter-Key je Profil — und warum die naheliegende Prüfung nichts wert ist

`hermes -p <profil> config set OPENROUTER_API_KEY <wert>` schreibt nach
`~/.hermes/profiles/<profil>/.env` (`hermes_cli/config.py:1153` schickt jeden
Namen auf `_API_KEY` in die `.env`, `config.py:5087` ist die Abzweigung in
`set_config_value`). Dass diese Datei die exportierte Shell-Variable schlägt,
steht in `hermes_cli/env_loader.py:496`:

```python
_load_dotenv_with_fallback(user_env, override=True)
```

Damit war belegt, was die CLI tut. Offen blieb die Frage, auf die es ankommt:
**Läuft ein Worker, den der Dispatcher startet, überhaupt mit `HERMES_HOME` auf
dem Profilverzeichnis?** Erbt er stattdessen `~/.hermes` vom Gateway-Elternteil,
wird die Profil-`.env` nie gelesen, alle elf Rollen laufen auf dem Root-Key —
und `config get` meldet trotzdem grün, weil es dieselbe Datei liest, die
`assign-keys.sh` gerade geschrieben hat. Eine Prüfung, die sich selbst bestätigt,
ist dieselbe Bauart Fehler wie ein Merge-Riegel, der prüft, ohne zu prüfen.

Der einzige Zeuge ausserhalb der eigenen Dateien ist OpenRouter:
`GET /api/v1/key` meldet den Verbrauch **des Keys, mit dem gefragt wird**.
`scripts/check-keys.sh` misst deshalb alle elf, lässt Probekarten über den
Dispatcher laufen und misst erneut.

Messung vom 17.08.2026, zweiter Durchgang (drei Keys trugen bereits Verbrauch
aus dem ersten):

| Profil | vorher | nachher | Delta |
|--------|-------:|--------:|------:|
| `esf-dev-a` | 0 | 0,004368826 | **+0,00436883** |
| `esf-reviewer` | 0 | 0,002829120 | **+0,00282912** |
| `esf-market-scout` | 0,004390536 | 0,004390536 | 0 |
| `esf-estimator` | 0,002657672 | 0,002657672 | 0 |
| `esf-controller` | 0,005610984 | 0,005610984 | 0 |
| die übrigen sechs | 0 | 0 | 0 |

Beide Hälften stimmen: Die geprüften Rollen haben ihren eigenen Key belastet,
und **keine fremde Rolle wurde mitbelastet** — auch keine der drei, die schon
vorher Verbrauch hatten. Das ist der Teil, der „jede Rolle hat einen eigenen
Key" von „irgendein Key hat gearbeitet" unterscheidet.

Zwei Nebenbefunde, beide mit Folgen:

- **Der Zähler läuft nach.** Unmittelbar nach `done` standen alle elf Keys noch
  auf 0; rund eine Minute später zeigten genau die geprüften ihren Verbrauch.
  Der erste Lauf der Prüfung meldete deshalb einen Fehlschlag, den es nicht
  gab. `check-keys.sh` wartet jetzt auf die Buchung und danach noch eine
  Kontrollrunde — sonst prüft die zweite Hälfte einen Zählerstand, der bloss
  noch nicht angekommen ist.
- **`GET /api/v1/key` authentifiziert sich mit dem Key selbst.** Für den
  Verbrauch je Rolle braucht es also **keinen** `OPENROUTER_PROVISIONING_KEY`.
  Die Annahme in `scripts/provision-keys.sh`, die Zurechnung hänge an der
  Provisioning-API, war falsch und ist dort korrigiert.

Drei Folgefehler, gefunden beim Prüfen der Prüfung:

- **Die Prüfkarten hätten das Ledger vergiftet.** `ledger-sync.sh` nimmt jede
  `done`-Karte; eine `Keyprobe`-Karte hätte je Lauf eine Zeile mit
  `reference_class: "unklassifiziert"` in `ledger/estimates.jsonl` erzeugt —
  in der Datei, aus der der `esf-estimator` schätzt und die nur angehängt, nie
  bereinigt wird. `check-keys.sh` archiviert seine Karten jetzt selbst (auch
  bei rotem Ergebnis), `ledger-sync.sh` filtert sie zusätzlich heraus.
- **Der Delta-Rundlauf war ungetestet.** Findet `ledger-sync.sh` den letzten
  Schnappschuss nicht, fällt `vorher` auf 0 zurück und jeder Tag meldet erneut
  die volle Kumulativsumme als Tagesverbrauch — ein Ledger, das Kosten still
  vervielfacht. Zweimal echt ausgeführt ohne Karten dazwischen: erster Lauf
  elf Zeilen mit `usage_delta == usage_total`, zweiter Lauf `+0.0` bei allen
  elf, Summe `0.0`. Der Rundlauf trägt.
- **`monitor.sh` beobachtete den falschen Key.** Er fragte
  `$OPENROUTER_API_KEY` ab — den Root-Key, mit dem seit der Zuordnung
  *niemand mehr arbeitet*. Er hätte auf Dauer 0 USD gemeldet, während elf
  Rollen-Keys liefen. Er summiert jetzt die elf und weist die Rollen mit
  Verbrauch einzeln aus; zum USD-Deckel schweigt er, solange `limit: null`
  ist, statt eine Überwachung vorzutäuschen.

## Eine Korrektur, gefunden von der eigenen Organisation

Der wichtigste Einzelbefund dieses Laufs widerlegt eine Behauptung, die ich
selbst aufgestellt und an fünf Stellen dokumentiert hatte.

**Behauptet war:** `pnpm exec biome ci .` sei im Ziel-Repo schon auf dem
Ausgangs-Commit rot; das sei Bestandsschuld von Upstream und der Grund für
den schlanken ESF-Hook.

**Die Codebasis-Analyse von `esf-architect` widersprach** — mit Fundstellen:
`biome.json:4-6` setze `vcs.enabled: false`, Biome ignoriere damit die
`.gitignore`, laufe in das von der ESF angelegte `.worktrees/` und breche dort
an dessen `biome.json` ab.

**Nachgemessen, und der Analyst hatte recht:**

| Zustand | `biome ci .` |
|---------|--------------|
| `e714f87` als sauberes Archiv, ohne Worktrees | **Exit 0** — 78 Warnungen, 1 Info, 0 Fehler |
| derselbe Baum mit einem ESF-Worktree | **Exit 1** — „nested root configuration" |

Der Linter des Produkt-Repos war also grün. **Die ESF hat ihn kaputtgemacht.**
Behoben durch `!**/.worktrees` und `!**/.esf-hooks` in `biome.json`.

Und noch ein Stück weiter: Der danach verbliebene Fehler stammte ebenfalls
nicht von Upstream, sondern aus dem handgeschriebenen E2E-Gerüst — ein
Formatierungsfehler in `playwright.config.ts` und zwei nicht in `turbo.json`
deklarierte Umgebungsvariablen. Genau das, was der schlanke ESF-Hook gefangen
hätte, wäre der Commit nicht mit `--no-verify` an ihm vorbeigegangen. Behoben
in `c9e0343`; die vier E2E-Dateien enden jetzt mit Exit 0.

Was `biome ci .` über das ganze Repo weiterhin rot macht, sind zwei Befunde
ohne Regelbezug — alle 78 Lint-Treffer sind Warnungen; einer der beiden ist
die Schema-Abweichung in `biome.json` (deklariert 2.5.4, CLI 2.5.7). Das ist
Konfigurations-Drift des Repos, an der keine Feature-Karte etwas ändert, und
genau deshalb misst der Riegel die Regression statt des Absolutstands.

Die Lehre ist unangenehm und gehört hierher: Eine bequeme Erklärung
(„Bestandsschuld") wurde fünfmal weitergeschrieben, ohne dass jemand den
Exit-Code isoliert gemessen hätte. Der erste, der nachsah, war ein Agent.

## Drei Befunde zur Git-Exklusivität — derselbe Satz, dreimal

Git lässt einen Branch in **genau einem** Worktree auschecken. Das ist banal
und stand trotzdem an drei Stellen im Weg, weil jede für sich plausibel aussah:

1. **Die Reviewer-Karte** bekam `worktree:<repo> --branch feat/…` — denselben
   Branch, den die Bau-Karte schon hielt. `git worktree add` verweigerte, der
   Circuit Breaker gab nach zwei Versuchen auf (`gave_up`, `failures: 2`), die
   Karte stand blockiert. Reparatur: `dir:<repo>`, der Hauptbaum.
2. **Der Merge-Riegel** machte in den Schritten 3–6 `git checkout <branch>` im
   Hauptbaum — derselbe Konflikt. Ein perfekt mergebarer Branch wurde deshalb
   verweigert. Reparatur: Der Probemerge aus Schritt 2 bleibt stehen; geprüft
   wird der **gemergte Baum**. Das ist ohnehin die richtige Frage: nicht „ist
   der Branch grün", sondern „ist grün, was auf `main` landet".
3. **Warum es der Selbsttest nicht fing:** `setup.sh` prüfte am Riegel nur den
   Pfad *Branch existiert nicht*. Ein Verweigerungsfall als einziger Test
   beweist, dass das Skript Nein sagen kann — nicht, dass es Ja sagen kann.

## Betriebsbefund: ein flaky Unit-Test

Im Riegel-Lauf um 15:37:50 fiel genau ein Test von 374:
`tests/api/mcp-internal-api-url.test.ts` („advertises the public URL while
fetching tools through the internal…"). Der Riegel verweigerte korrekt. Ein
direkter Nachlauf desselben Befehls war **374/374 grün**.

Der Test ist also flaky, vermutlich unter Last. Für die ESF ist das kein
Ärgernis, sondern der vorgesehene Ablauf: Der Riegel hält, und Flakiness
bekommt eine Karte für `esf-qa-release` — behandelt wie ein Bug, nicht wie
Wetter. Was der Vorfall zusätzlich zeigt: Ein Riegel, der die volle Suite
fährt, erbt deren Flakiness. Ohne die Regel „Flake = Bug + Karte" wird genau
das der Grund, aus dem später jemand den Riegel abschaltet.

## Betriebsbefund: der hängende Worker

Der erste Lauf der Bau-Karte blieb **16 Minuten bei 0 % CPU** stehen. `lsof`
zeigte die Ursache: die TCP-Verbindung zu OpenRouter stand auf `CLOSE_WAIT` —
die Gegenseite hatte geschlossen, der Client wartete weiter. Der Worker war
nicht langsam, sondern blockiert.

Das war **kein Einzelfall**. Im weiteren Lauf traf es alle drei
Analyse-Worker der Phase 1 gleichzeitig; über den ganzen Nachmittag waren es
mindestens sechs Vorfälle. Auffällig ist die Korrelation mit Parallelität:
Vier gleichzeitige Worker mit grossem Kontext trafen es zuverlässig. Ob die
Ursache beim Provider, beim Netz (die Firmen-npm-Registry war ebenfalls nicht
auflösbar) oder in Hermes' HTTP-Schicht liegt, ist von hier aus nicht
entscheidbar — die Wirkung ist es.

Vier Konsequenzen:

- **`--max-runtime` je Karte ist keine Kosmetik**, sondern der einzige
  eingebaute Mechanismus, der einen so blockierten Worker beendet.
- **Der Zustand sieht von aussen aus wie Arbeit.** Das Board meldete `running`
  mit regelmässigen Heartbeats. Nur `ps` (0 % CPU) und `lsof` (`CLOSE_WAIT`)
  unterscheiden Blockade von Fortschritt — beides liegt ausserhalb von Hermes.
- **Die Respawn-Mechanik greift**, sobald der Prozess wirklich weg ist:
  `outcome: "crashed"`, dann ein neuer Lauf im Rahmen von `--max-retries`.
- **Deshalb gibt es `scripts/watchdog.sh`.** Er prüft beide Merkmale zusammen
  und beendet nur, was ein `CLOSE_WAIT`-Socket bei ~0 % CPU hält. Beim ersten
  Lauf fand er sofort zwei Hänger, die eine manuelle Sichtung übersehen hatte —
  ein Worker kann mehrere Sockets halten, und der Blick auf das zuletzt
  gelistete genügt nicht. Ein bloss langsamer Worker (0 % CPU, aber alle
  Sockets `ESTABLISHED`) wird ausdrücklich **nicht** beendet; dort ist eine
  lange Modellantwort die wahrscheinlichere Erklärung, und dafür ist
  `--max-runtime` zuständig.

## Der Rundlauf: Teardown und Neuinstallation

Die Zusage „jederzeit neu installierbar und deinstallierbar" ist durchgespielt —
und hat drei Befunde geliefert, alle drei behoben.

| Befund | Was schiefging | Behebung |
|--------|----------------|----------|
| **Falsche Flags, still** | `hermes profile delete --force` gibt es nicht; das Kommando fragt trotzdem interaktiv nach dem Profilnamen, bekommt eine leere Antwort und meldet `Cancelled.` Das nachfolgende `rm -rf` räumte das Verzeichnis zwar weg, aber die Löschung lief nie durch Hermes. Richtig ist `-y`. | `teardown.sh` |
| **`boards rm` archiviert nur** | Ohne `--delete` wandert das Board nach `boards/_archived/` statt zu verschwinden. Ein archiviertes Board taucht beim nächsten `setup.sh` als „existiert bereits" wieder auf — mit den Karten des letzten Laufs. Ein `--force` gibt es nicht. | `teardown.sh` |
| **Der Gateway-Daemon legt das Board wieder an** | Läuft irgendein `hermes … gateway run` (hier zwei, für fremde Profile), erscheint das Board-Verzeichnis binnen Sekunden erneut — als **leere Hülle** mit aus dem Slug abgeleitetem Namen `Sw Company`. Karten und Historie sind wirklich weg; was bleibt, ist ein namenloses Gerippe. | `teardown.sh` meldet es samt Ursache statt Erfolg zu behaupten; `setup.sh` zieht den Anzeigenamen per `boards rename` nach, sonst verliert die ESF ihn bei jedem Rundlauf |

**Ergebnis nach vollständigem `./teardown.sh --yes` und erneutem `./setup.sh`:**
elf Profile wieder `ON DISK = yes`, Vault frisch aus `seed/`, beide modellfreien
Selbsttests bestanden, `core.hooksPath` sauber zurückgesetzt und wieder gesetzt,
Board mit korrektem Namen. Das Produkt-Repo blieb unangetastet — `58310dc`,
Arbeitsbaum sauber, `feat/esf-probelauf` und sein Worktree stehen weiterhin.
Das ist Absicht: Der Rückbau entfernt die Organisation, nicht ihr Ergebnis.

**Zweiter Rundlauf, nach der Key-Zuordnung.** Er prüft einen Pfad, den der
erste nicht hatte: `hermes profile create` auf einem **frischen**
Profilverzeichnis, gefolgt von `config set OPENROUTER_API_KEY`. Die
`.env`-Dateien der früheren Läufe existierten bereits samt Kopfzeilen-Vorlage;
schriebe Hermes die Zeile auf einem neuen Profil anders — in Anführungszeichen
etwa —, liefe die Prüfung in `assign-keys.sh` ins Leere und ein korrekter
Aufbau meldete rot. Gemessen: `./teardown.sh --yes` (elf Profile weg, kein
`esf-` mehr unter `~/.hermes/profiles/`), dann `./setup.sh` → Exit 0, elf Keys
zugeordnet, elf verschiedene Fingerabdrücke, und `assign-keys.sh --pruefen`
unabhängig danach ebenfalls Exit 0.

## Nicht verifiziert

| Baustein | Status | Warum |
|----------|--------|-------|
| **USD-Deckel je Rolle** | **entfällt mit diesen Keys** | Die elf zugeordneten Keys melden `limit: null` — sie haben keinen Deckel. Ein Key je Rolle bringt hier die Zurechnung, nicht die Bremse. Ein Limit setzt man bei OpenRouter je Key; über die API geht das nur mit `OPENROUTER_PROVISIONING_KEY` (`scripts/provision-keys.sh --limit`), der weiterhin nicht vorliegt. |
| **Kostenzurechnung je Karte** | **geht nicht, und zwar grundsätzlich** | `GET /api/v1/key` meldet den **kumulativen** Verbrauch eines Keys, also je Rolle. Eine Rolle mit fünf Karten am Tag liesse sich nur durch Division aufteilen — genau die erfundene Zahl, die das Ledger nicht enthalten soll. `cost_usd` bleibt je Karte `null`; die Rollensummen stehen in `ledger/kosten-je-rolle.jsonl`. |
| **Cron-Auslösung zur geplanten Zeit** | **nicht geprüft** | `install-cron.sh` trägt ein und `--remove` baut zurück; dass die Einträge um 07:00/18:00/23:30 tatsächlich feuern, wurde in diesem Lauf nicht abgewartet. Die Skripte selbst sind einzeln ausgeführt. |
| **Gateway als Dauerbetrieb** | **nicht geprüft** | `hermes gateway status` meldete die Service-Definition als *stale*. Der ganze Lauf taktete deshalb über `pump.sh` von Hand. |
| **Autonomie-Horizont `quartal`** | **nicht geprüft** | Der Pfad ist in `gate.sh` und im Gate-Auftrag angelegt, aber in diesem Lauf wurde nur `release` gefahren. |
| ~~**Sprint- und Release-Abschluss**~~ | **überholt am 18.08.2026 (Phase 2)** | Beide Checks sind gegen echte Sprints gelaufen: `check-sprint.sh S2` grün mit 7 Paaren, `check-release.sh R1` grün inklusive eigener Messung von main. `check-sprint.sh S1` bleibt **rot** — ein zerrissenes Paar auf `t_4f601104`, siehe unten. |
| **Superpowers-Wirkung** | **Annahme** | Dass die Skills profil-lokal ankommen, ist geprüft (Dateien liegen dort). Ob ein deepseek-Worker ihnen wirklich folgt — RED-GREEN-REFACTOR statt Code-zuerst — ist nicht gemessen. |
| ~~**Zwei Entwickler parallel**~~ | **überholt am 18.08.2026 (Phase 2)** | S2 hat R1-F1 (`esf-dev-a`) und R1-F2 (`esf-dev-b`) gleichzeitig in eigenen Worktrees gebaut. Keine Kollision — und nicht durch Glück: Das neue AK8 (rein additiver Diff auf `app.ts`) wirkte als Bauanleitung, beide Diffs auf `app.ts` blieben **leer**. |
| **Modell-Tiers** | **entfällt in diesem Lauf** | Alle drei Tiers zeigen auf `deepseek/deepseek-v4-flash-0731`. Die Struktur ist da (`ESF_MODELL_HOCH` usw.), differenziert wurde sie nicht. |

### Neu aus Phase 2 (18.08.2026)

| Baustein | Status | Warum |
|----------|--------|-------|
| **5 von 5 Suitenläufen grün ohne `--retries`** | **fremdgemessen, nicht nachgeprüft** | Die Zahl stammt aus dem `metadata` der QA-Karte `t_288738fa`. Ich habe **zwei** eigene kalte Volldurchgänge gefahren (11/11), nicht fünf. Bei einem Defekt, der je Lauf einen **zufälligen** Journey traf, sind zwei grüne Läufe ein schwacher, kein wertloser Beleg: Die Wahrscheinlichkeit, ihn zweimal zufällig zu verpassen, ist nicht klein. Der Ursachenbefund (`fill()` wird vom kontrollierten RHF-Feld still verworfen) ist im Code nachvollziehbar, aber ich habe ihn nicht selbst reproduziert. |
| **`merge-repo-S` n=4 mischt zwei Arten von Arbeit** | **Messfehler, benannt statt korrigiert** | Von den vier Paaren dieser Klasse stammt eines von `t_4f601104` — einer Merge-Karte, die **verweigert** hat (6 min) und nie gemerged. Der Mittelwert 0,50 vermischt also *Riegel gelaufen und gemerged* mit *Riegel gelaufen und abgebrochen*. Bei vier Punkten ist das relevant. Bereinigt bleiben drei Paare (4, 5, 5 min gegen p50 8 bzw. 15) — der Faktor bliebe unter 1, die Aussage *Merge wird überschätzt* trägt also. Korrigiert wird das Ledger **nicht**: Es wird nur angehängt, nie umgeschrieben (`AGENTS.md 6`). Der `esf-estimator` muss die Zeile an ihrem `riegel_ergebnis` erkennen. |
| **Magic-Link ist sicherheitlich zu** | **fremdbelegt, nicht selbst geprobt** | Beruht auf dem grep des Reviewers über den gesamten `better-auth`-Dist und auf dem `curl`- und Browser-Beleg des Entwicklers. Ich habe die Anmeldung über einen Magic-Link für ein 2FA-Konto **nicht selbst versucht**. Der Hook sitzt an `session.create.before`, also am gemeinsamen Engpass — strukturell plausibel und durch die Integrationstests der drei Wege gestützt, aber die Probe am laufenden System fehlt. |
| **`check-sprint.sh S1` bleibt rot** | **echter, offener Befund** | Ein zerrissenes (Schätzung, Ist)-Paar auf `t_4f601104`: Die Karte hat ihre Schätzung wirklich nicht ins Abschluss-`metadata` kopiert. Ursache bekannt — der Estimator war damals nicht ihr direkter Elternteil — und strukturell behoben, historisch aber nicht heilbar, weil das Ledger nicht umgeschrieben wird. Dem Prüfer hier das Verzeihen zu lehren wäre der teuerste Fehler, den man an einem Riegel machen kann; der Sprint-Report von S1 trägt den Punkt. |
| **Netzausfälle als Kontamination** | **benannt, nicht quantifiziert** | Mehrere Läufe endeten `pid not alive` mit `APIConnectionError` (belegt im Worker-Log). Diese Wanduhrzeit steckt in den Ledger-Zeilen der betroffenen Karten. Der Controller-Report benennt sie; ich habe **nicht** ausgerechnet, wieviele Minuten insgesamt darauf entfallen. |
| **Kaltstart-Fix gegen einen echten Rechner-Kaltstart** | **nicht geprüft** | Geprüft ist der Kaltstart von API und Vite bei gelöschtem DB-Volume. Nicht geprüft ist der Fall nach einem Neustart des Rechners oder nach Standby — genau die Lage, die Kapitel 8 als Kontamination der Wanduhrmessung nennt. |
| **Der Riegel-Wächter gegen fremde Dev-Server** | **synthetisch geprüft** | Nachgewiesen mit einem `python -m http.server` aus `.worktrees/t_6c366810` auf einem Testport: korrekt als WORKTREE erkannt, die echten Server des Hauptbaums als in Ordnung. **Nicht** erlebt hat der Wächter den Ernstfall — einen echten stalen Vite-Server aus einem Feature-Worktree während eines Riegel-Laufs. Der Befund, der ihn auslöste, wurde von einem Worker gemeldet, nicht von ihm gefangen. |

### Neu aus dem zweiten Rundlauf (18.08.2026, Phasen 0 und 1)

Ein zweiter Durchlauf von `setup.sh` und `create-onboarding.sh` auf einer frisch
zurückgebauten Hermes-Instanz, gegen dasselbe Ziel-Repo. Protokoll in
`RUN-PROTOKOLL.md`, Akte in `beispiel-lauf-3/`.

| Baustein | Status | Warum |
|----------|--------|-------|
| **`agent.max_turns` je Profil** | **real gemessen — Annahme war falsch** | `setup.sh` hob den Wert für vier Rollen auf 1200 und liess die acht anderen „bei 500", dem Hermes-Default. Diese Maschine hatte `agent.max_turns: 90` in `~/.hermes/config.yaml` — die urteilenden Rollen wären mit 90 Zügen gelaufen. Behoben: beide Werte werden explizit gesetzt (`ce01cfe`), nachgemessen mit `hermes -p <profil> config get`. Ein geerbter Deckel ist kein Deckel, sondern ein Zufall. |
| **Journey→Spec-Zuordnung in `check-onboarding.sh`** | **war falsch, jetzt belegt** | Der Prüfer meldete grün „9 von 9 Kern-Journeys haben eine existierende Spec-Datei"; es waren fünf, und **keine** der neun Zuordnungen stimmte — ein `grep -B4 -A8` traf in einer Tabelle die Spec der Nachbarzeile. Jetzt wird die Tabellenzeile gelesen und die Zuordnung Journey für Journey ausgegeben (`608cc8f`). Der Wert 5 von 9 ist gegen `ls tests/e2e/journeys/` und den Katalogtext von Hand gegengelesen. |
| **P1-Abdeckung** | **war falsch, jetzt belegt** | „5 von 6" bei fünf P1-Journeys: Die letzte `<tr>` lief bis zum Dateiende weiter, J-08 (P2) erbte ein „P1" aus dem Fliesstext hinter der Tabelle. Zeilen werden jetzt am `</tr>` abgeschnitten. Der Fehler steckte in der **Korrektur** des vorigen Punktes und fiel nur auf, weil diese die Zahl nachrechenbar machte. |
| **Gate-Antwort im Phase-1-Nachweis** | **war unlesbar, jetzt im Klartext** | Der Prüfer las `.payload.reason` des `unblocked`-Ereignisses — die Payload ist leer, der Grund steht im Kommentar. Er bestand grün mit `beantwortet und ausgeführt: "?"`, also ohne sagen zu können, **was** entschieden wurde. `monitor.sh`, `check-phase3.sh` und `check-release.sh` kannten die Eigenheit längst; dieser war der letzte Nachzügler. Zusätzlich sind jetzt „kein `unblocked`-Ereignis" und „Unblock ohne gültiges Verb" harte Fehler. |
| **Roter Pfad des neuen Verb-Riegels** | **erst falsch, jetzt beide Zweige belegt** | Der Zweig „Unblock ohne gültiges Verb" hätte nie ausgelöst: `"" \| split("\n")[0]` ergibt in jq `null`, mit `jq -r` den String `null` — nicht leer, also grün mit der Antwort „null". `check-release.sh`, von dem die jq-Kette stammt, hat kein `split`; es war mein Zusatz. Behoben mit `// ""`. Belegt sind jetzt beide Richtungen: leere Eingabe bleibt leer, die echte Gate-Antwort bleibt vollständig, und der rote Zweig wurde an einer Karte ohne Gate-Antwort tatsächlich ausgelöst. |
| **Journey→Spec-Fix gegen fremde Daten** | **real gemessen** | Derselbe Fix gegen `beispiel-lauf-1/vault/analysis/` — anderes Modell, andere Tabelle, zehn Journeys — liefert 6 von 6 und trifft genau die Specs, die das Protokoll vom 17.08. nennt (J-00/J-01 bestehend, J-02/J-03/J-04/J-06 neu). Ein Prüfer, der nur gegen die Daten geprüft wurde, für die er geschrieben ist, ist nicht geprüft. |
| **`--max-runtime` als teurer Deckel** | **real gemessen** | Die E2E-Karte lief `timed_out` bei **5406 s** gegen `limit_seconds: 5400` — sechs Sekunden über dem Limit, bei echtem Fortschritt. Der zweite Lauf erbte die Vorarbeit und schloss ab; von den 103 Minuten Kartenzeit ist gut die Hälfte Wiederholung. Anders als `max_turns` in Phase 2 ging hier nichts verloren, weil die Karte ihren eigenen Absturz überlebt. |
| **Vault-Commit-Disziplin der Analyse-Rollen** | **beobachtet, nicht geregelt** | `esf-architect` und `esf-qa-release` committeten ihre Artefakte selbst, `esf-market-analyst` und `esf-product-manager` nicht — der Kartentext verlangt es bei keiner der drei Analysekarten. Aufgeräumt hat es der Gate-Commit des Chief of Staff (`8e33331`). Die Asymmetrie ist Modellverhalten, kein Regelverstoss, und bleibt unkorrigiert stehen. |
| **Wiederholschleife im E2E-Helfer** | **eingebaut vom Agenten, nicht angefordert** | `arbeitsbereichAnlegen` versucht den Submit jetzt bis zu fünfmal, begründet mit einem Rennen gegen React Hook Form. Das Argument trägt (eine clientseitig abgewiesene Eingabe legt nichts an), aber es ist Toleranz gegen Flakiness, die eine echte Regression im Onboarding-Formular verdecken kann. Nicht zurückgebaut, hier benannt. |
| **Rollenbezeichnung im Freigabe-Dokument** | **falsch, bewusst nicht nachgebessert** | `q1-freigegeben.html` nennt die Supervisor-Antwort durchgehend „CEO-Entscheidung"; seit Phase 3 ist der Mensch Supervisor und `esf-ceo` ein Profil. Eine Korrektur hätte einen zweiten Block auf derselben `kind` gekostet — `BLOCK_RECURRENCE_LIMIT = 2`, danach Triage. Der Preis wäre höher gewesen als der Fehler. |

### Neu aus Phase 2 des zweiten Rundlaufs (18./19.08.2026)

Zwei Sprints, 22 Karten, 558 Minuten Kartenzeit, Release R1 durch das Gate.
`check-phase2.sh` grün. Protokoll in `RUN-PROTOKOLL.md`, Akte in
`beispiel-lauf-3/`.

| Baustein | Status | Warum |
|----------|--------|-------|
| **Turbo-Cache im Merge-Riegel** | **real gemessen — der Riegel war zwei von sechs Prüfungen blind** | `merge-riegel.sh` fuhr `turbo typecheck` und `turbo test` ohne `--force`. Gemessen im Worktree der F-R1-2-Umsetzung, direkt nach dem Lauf des Entwicklers: `Cached: 6 cached, 6 total — 170ms >>> FULL TURBO`. turbo spielt bei gleichem Eingabe-Hash das alte Ergebnis ab. Ein Cache-Treffer ist kein Urteil — und der Riegel ist die Stelle, an der „Code entscheidet, kein Modell" hängt. Behoben mit `--force`; das Riegel-Protokoll des nächsten Merges belegt den Fix in seiner ersten Zeile. **`playwright test` war nie betroffen** (läuft nicht über turbo) — genau deshalb fiel es seit dem ersten Lauf nicht auf. |
| **„Führe die Tests SELBST aus" im Review** | **war wirkungslos, jetzt belegt** | Derselbe Mechanismus: Der Reviewer führte den Befehl aus, turbo antwortete mit dem Protokoll des Entwicklers, und er meldete es als eigene Messung („Selbst ausgeführt: pnpm typecheck → 6 successful", „374 Tests bestanden"). Aufgefallen an der Laufzeit — 3,6 Minuten für Typecheck, 374 Unit-Tests und die volle E2E-Suite. Sein E2E-Lauf war echt und ist unabhängig belegt (`results.json`: 39230,7 ms, 7 expected, 0 unexpected, im Laufzeitfenster). |
| **Kalibrierung über zwei Sprints** | **real gemessen** | S1 (Anker: Dummy-Probelauf) `impl 0,21` / `review 0,09`; S2 (Anker: echte Paare) `impl 1,38` / `review 0,88` / `e2e 0,63`. Der S2-Estimator hat den Faktor nicht blind übernommen, sondern den S→M-Umfangssprung beziffert und die Merge-Klasse unverändert gelassen, weil sie als einzige traf. Der F-R1-4-Estimator hat die verzerrte `e2e-repo-L`-Zeile erkannt und bereinigt („103 min runs:2 bereinigt auf ~50"). |
| **Zwei parallele Worktrees ohne Kollision** | **real gemessen** | F-R1-3 und F-R1-4 gleichzeitig, beide unter `tests/`. Schnittmenge der berührten Dateien leer, von mir selbst nachgerechnet. Beide Entwickler legten ihren Helfer in eine eigene Datei (`support/tastatur.ts`, `support/einladung.ts`) statt `journey.ts` zu erweitern — die Regel stand in beiden Kartentexten, beide Reviewer wiesen ihre Einhaltung einzeln nach. |
| **`--max-runtime` für dieses Modell** | **real gemessen** | Zwei Karten rissen ihre Grenze um Sekunden (5406/5400, 1516/1500) und verloren dadurch ihren ganzen Lauf. Die betroffene Probelauf-Karte schreibt eine dreizeilige Markdown-Datei; ihr erfolgreicher Lauf brauchte 11 Minuten. Die verlorene Zeit landet als Wanduhr im Ledger — `impl-worktree-S` steht dort mit 36 Minuten für 11 Minuten Arbeit. Karten mit voller Suite jetzt auf 90 statt 60 Minuten. |
| **Der dritte Elternteil verdrängt die Schätzung** | **real gemessen, an zwei Karten derselben Art** | Merge F3 (2 Eltern: Review + Schätzung) kopierte sein `estimate`; Merge F4 (3 Eltern: Review + Merge F3 + Schätzung) ließ es ganz weg. Der dritte Elternteil diente nur der Serialisierung der Riegel-Läufe und trägt keine Zahl. Der Handoff-Kontext ist ein begrenzter Kanal. Nicht durch Entfernen behoben — die Serialisierung ist nötig —, sondern indem beide Kartentexte sagen, welcher Elternteil die Zahl trägt. |
| **`check-sprint.sh` bleibt in beiden Sprints rot** | **echte, offene Befunde** | S1: `t_e70f40ff` ohne Referenzklasse (Ursache: `metadata_pflicht` sprach fast nur vom Kopieren eines Intervalls, das die erste Karte einer Kette nie hat). S2: `t_c35344ff` ohne Schätzung (Ursache oben). Beide Ursachen behoben, beide Befunde historisch nicht heilbar — das Ledger wird nur angehängt. `check-phase2.sh` zählt deshalb die Paare im Ledger, nicht den Exit-Code von `check-sprint.sh`. |
| **Katalog-Widerspruch J-03** | **offen, mit Auflage** | `analysis/journeys.html` führt J-03 mit 6 Schritten, die Spec im Code sagt 5 — die Subtraktion aus F-R1-2 wurde im Katalog nicht nachgezogen. Von der Gate-Vorlage selbst gemeldet, von mir nachgemessen. Auflage a) des Release-Gates: strukturell beheben, nicht nur die Zahl. |
| **Ein Skript im laufenden Betrieb bearbeitet** | **eigener Betriebsfehler** | Ich habe `merge-riegel.sh` geändert, während die Merge-Karte lief. Bash liest Skripte häppchenweise nach; der Lauf ging verloren. Der Worker ordnete es korrekt als Betriebsgrund ein und setzte neu an. Keine Regel dagegen im Repo — die Lehre steht hier. |

### Phase 3, erste Messungen am laufenden Board (19.08.2026)

| Baustein | Status | Warum |
|----------|--------|-------|
| **`company/AGENTS.md` ist für einen dispatchten Worker nicht schreibbar** | **real gemessen — Blocker für Stufe C** | Die Karte `t_28c5032d` (Auflage a) des R1-Gates) sollte eine Regel in `company/AGENTS.md` verankern. Der Worker erledigte Teil 1, blockierte für Teil 2 und schrieb den Grund hin: `AGENTS.md` gilt als geschützte Agent-Instruktionsdatei, deren Schreiben eine **interaktive Freigabe** verlangt; im Dispatch-Lauf gibt es niemanden, der sie erteilt, und der Prompt lief in den Timeout. Bemerkenswert: Er hat die Sperre **nicht** über `terminal`/`execute_code` umgangen, sondern den fertigen Einfügetext hinterlegt. Das ist das gewünschte Verhalten — die Lücke ist der Betrieb, nicht der Agent. **Konsequenz für `ceo_modus: live`:** Jede CEO-Entscheidung, deren Ausführung `AGENTS.md` berührt, blockiert dort dauerhaft, ohne dass ein Mensch in der Schleife wäre, der entblocken könnte. Der Supervisor hat den Text am 19.08.2026 selbst eingetragen (Vault-Commit `c61ddc5`) und mit `manuell:`-Verb entblockt. |
| **Die Schatten-Reihenfolge ist zwingend und leicht zu verderben** | **am Code belegt (`ceo-tick.sh:290–366`), noch nicht gefahren** | `schatten-validiert` wird nur journaliert, solange das Gate **noch blockiert** ist; `schatten-vergleich` entsteht erst in der Nachlese, die über `schatten-validiert`-Einträge iteriert, deren Gate inzwischen beantwortet wurde. Antwortet der Supervisor, **bevor** ein gültiges Dokument validiert wurde, gibt es für dieses Gate nie einen Vergleich — das Gate ist für den Stufe-B-Nachweis verloren. Zwingende Folge: Gate blockiert → `ceo-tick` (Karte) → Pumpe (Dokument) → `ceo-tick` (validiert) → **erst dann** `gate.sh` → `ceo-tick` (Vergleich). |
| **Stufe A** | **grün am laufenden Board** | `check-phase3.sh --stufe a`: zwölf Profile `ON DISK = yes`, alle drei Unblock-Ereignisse tragen ein Verb (inkl. des `manuell:`-Unblocks des Supervisors), Eskalations-Journal leer, `triage` leer. Der Teil-Nachweis „kein Kartentext von Hand" bleibt offen, weil die Graph-Generierung bewusst nicht gebaut ist. |
| **`ceo-tick.sh` überspringt Roadmap-Gates** | **am Code belegt** | `art_von` → `roadmap` führt zu `continue` mit Warnung. Die drei Schatten-Vergleiche der Stufe B können also **nur** aus Release-, Irreversibel- und Budget-Gates stammen. Ein Budget-Gate feuert bei 1,5× P90; nach der S2-Kalibrierung (0,63–1,38) ist damit nicht zu rechnen, und eine Karte zu bauen, die es auslöst, wäre hergestellte Evidenz. Drei Vergleiche brauchen daher realistisch **zwei Release-Zyklen** — ein Befund über die Schwelle, kein Fehlschlag. |
| **Der Messbeleg des CEO ist erreichbar** | **am Kartentext belegt** | Die Entscheidungskarte nennt absolute Pfade nach `scripts/`; `esf-ceo` arbeitet zwar in `dir:VAULT`, kann `check-release.sh` von dort aber ausführen. `ceo-lint.py` verlangt einen `<pre>`-Block im Abschnitt `messung` — die Vorbedingung dafür ist gegeben. Selbsttest `ceo-tick.sh --selbsttest` grün (seit dem 19.08.2026 5/5, hermes-frei). |

| **Ein CEO-`escalate` erzeugte im Schattenbetrieb nie einen Vergleich** | **gefunden vor dem ersten Lauf, behoben und gegengemessen** | Der `escalate`-Zweig steht **oberhalb** des `if [ "$MODUS" = "schatten" ]`-Blocks und endet auf `continue`. Ein gültiges Dokument mit `VERB=escalate` wird also als `eskaliert` journaliert und erreicht `schatten-validiert` nie — folglich findet die Nachlese es nicht, und es entsteht kein `schatten-vergleich`. Dabei ist genau dieser Fall der aussagekräftigste, den der Schattenbetrieb messen kann: „der CEO traut sich nicht, der Supervisor hat entschieden". Zweite Folge: `notfall=$((notfall + 1))` und damit `exit 1` gelten auch im Schatten, wo nichts ausgeführt wurde und nichts gefährdet war — unter `install-cron.sh` schlägt der Tick dann fehl. **Behoben am 19.08.2026:** Der Schatten-Block steht jetzt **vor** dem `escalate`-Zweig; im Schatten wird ein `escalate` als ganz normales Urteil nach `schatten-validiert` journaliert und landet in der Nachlese als Vergleich (`esf-ceo=escalate` gegen das Supervisor-Verb, `uebereinstimmung:false`) — ohne `notfall`, ohne `exit 1`. **Gegengemessen:** `--selbsttest` trägt eine fünfte, hermes-freie Reihenfolge-Wache, die die eigene Datei liest; sie ist auf der reparierten Fassung grün (Zeile 315 vor 329) und auf einer Kopie mit der alten Reihenfolge rot (Zeile 315 vor 323, Exit 1). Ein reiner Code-Review hätte das nicht gefangen — der Schaden zeigt sich erst am laufenden Board, und dann ist das Gate schon verbraucht. |
| **Vermutung, die sich am Code NICHT bestätigt hat: `manuell` fehle in der Nachlese-Regex** | **geprüft und verworfen** | Die Nachlese liest `capture("^UNBLOCK: *(?<v>approve\|modify\|shelve\|continue\|cut\|stop)")` — sechs Verben, während im Repo achtmal von Verben die Rede ist. Der Verdacht auf zwei fehlende (`manuell`, `escalate`) ist nur zur Hälfte richtig. `gate.sh` kennt ausschließlich diese sechs (`VERBEN_ENTSCHEIDUNG="approve modify shelve"`, `VERBEN_BUDGET="continue cut stop"`); `manuell:` ist **kein Gate-Verb**, sondern der rohe `hermes kanban unblock --reason`-Weg für eine **echte Blockade** (`gate.sh:156,204`) — und echte Blockaden fallen in `ceo-tick.sh` unter `art=keins` und werden vor jeder Schatten-Logik übersprungen. Die Regex ist an dieser Stelle also korrekt. Festgehalten, weil die Vermutung plausibel war und der Gegenbeleg sonst verlorenginge. |
| **„Den Worktree nicht aufraeumen, er ist Beleg" — eine eigene Anweisung, die sich als falsch erwiesen hat** | **real gemessen (19.08.2026, Karte `t_0b6f6f2b`)** | Die Wartungskarte von S3 konnte auf `main` nicht committen: `biome ci .` im Pre-Commit-Hook fand in den drei liegengebliebenen R1-Worktrees je eine **verschachtelte `biome.json`** und brach ab. Der Worker entfernte die drei Verzeichnisse (alle drei Branches waren `--merged main`), dokumentierte es unter `umgebung` und arbeitete weiter — und tat damit genau das, was der Merge-Kartentext ihm auf einer **anderen** Karte verboten hatte. Nachgeprüft: alle drei Branches existieren unverändert (`5677e0f`, `3e61f8e`, `e480390`), also ist **kein Beleg verlorengegangen** — der Beleg war nie das Verzeichnis, sondern die Branch-Referenz. Die Anweisung steht seitdem umgekehrt in `create-sprint.sh` (drei Stellen), und die bereits angelegte S3-Merge-Karte hat die Korrektur als Kommentar bekommen, weil `hermes kanban` den Text einer offenen Karte nicht ändern kann (`edit` greift nur auf abgeschlossene Karten). |
| **`turbo typecheck test --force` ist praeexistent flaky, wenn beide Tasks parallel laufen** | **vom Worker gemessen und auf sauberem Baum gegengeprüft** | `tests/api/mcp-internal-api-url.test.ts` fällt in `@kaneo/api` mit 5-s-Timeout und „vi.fn() called once but got 2 times" — **nur** im kombinierten Parallellauf. Einzeln grün: `turbo test --force` 10/10, `turbo typecheck --force` 6/6, Playwright 14/14. Der Worker hat den Befund auf dem sauberen Baum (Änderungen gestasht) identisch reproduziert und ihn deshalb als `gefunden_nicht_gemacht` geführt statt ihn zu beheben. Das ist relevant für die Review- und Merge-Karten von S3, die genau diesen kombinierten Befehl vorschreiben — ihr Absatz „bekannter Störfaktor: `mcp-internal-api-url.test.ts` ist lastempfindlich" deckt den Fall bereits ab, und dass er hier zum zweiten Mal unabhängig auftaucht, bestätigt die Einstufung als Betriebsbefund. |
### Sprint S3 — der erste Sprint von R2 (19.08.2026)

| Baustein | Status | Warum |
|----------|--------|-------|
| **F-R1-1 Import ist gebaut und auf `main`** | **real gemessen** | Merge-Commit `c11647e`, Branch `feat/esf-r2-f1-import-csv-wekan` (`1de4756`), Riegel bestanden nach einem Betriebs-Rerun. Der Architekt hat den Schnitt selbst gewählt und ihn begründet: `KaneoClient` aus `packages/planka-import` in ein geteiltes `packages/kaneo-client` extrahiert, darauf `packages/csv-import` als zweites CLI-Paket — WeKan blieb als benanntes Folgestück liegen, genau wie der Kartentext es verlangt („ein erster Schnitt, der trägt, statt zweier halber"). Der Entwickler hat elf Akzeptanzkriterien belegt, darunter einen **echten Importlauf gegen eine laufende Instanz** (4 Zeilen → 4 Tasks, 3 Labels, 2 Kommentare, 0 Zeilenfehler) und die Idempotenz (zweiter Lauf legt `CPI-2` an, `CPI` bleibt unangetastet, per API nachgeprüft). Selbst gemessen vom Reviewer: typecheck 7/7 ohne Cache, 609 Unit-Tests über fünf Pakete, Playwright 14/14. |
| **Kein Irreversibel-Gate — und das ist ein Befund, kein Fehlen** | **real gemessen** | Der Reviewer hat die Migrationsfrage mit vier Belegen verneint: `git diff main…branch -- apps/api packages/libs` leer, keine Drizzle-Migration, `app.ts` unberührt, und `migrate.ts` schreibt **ausschließlich über die öffentliche API** (`KaneoClient`). Damit erzeugt der Import — das Feature, von dem am ehesten ein Irreversibel-Gate zu erwarten gewesen wäre — **keines**. Für Phase 3 Stufe B heißt das: nach S3 stehen weiterhin **null** Schatten-Vergleiche im Journal. Das bestätigt die Rechnung vom 19.08.2026: Irreversibel-Gates sind emergent und nicht planbar, und das Release-Gate von R2 ist der erste realistische Kandidat. |
| **Auflage b) des Release-Gates R1 ist NICHT erfüllt** | **real gemessen, nicht heilbar** | Die Auflage verlangte: „`check-sprint.sh` muss im nächsten Sprint auf Prüfung 3 grün sein." Sie ist rot. `t_de53e678` (Umsetzung F-R1-1) hat ein Abschluss-`metadata` mit genau **zwei** Schlüsseln geschrieben — `acceptance` (elf belegte Kriterien) und `worker_session_id` — und dabei das `estimate`-Objekt weggelassen, obwohl der `esf-estimator` es vollständig geliefert hatte (`impl-worktree-M`, p50 65 / p90 130, Konfidenz 0,2, mit hergeleitetem S→M-Faktor). Das Ledger wird nur angehängt; die Zeile steht als `unklassifiziert` und wird nicht nachträglich beschrieben — dieselbe Regel, die ich am R1-Gate für die S2-Lücke aufgestellt habe, gilt auch, wenn sie mich selbst trifft. **Der `esf-controller` hat den Befund selbst gefunden und an die erste Stelle seines Reports gesetzt** — die Prüfkette der Organisation hat funktioniert; die Auflage ist trotzdem gerissen. |
| **Der Schätz-Handoff reißt etwa einmal pro Sprint, unabhängig vom Wortlaut** | **drei Messpunkte** | S1: `t_e70f40ff` (Spezifikationskarte, Fall „läuft vor dem Estimator"). S2: `t_c35344ff` (Merge-Karte, Fall „dritter Elternteil verdrängt den, der die Zahl trägt"). S3: `t_de53e678` (Umsetzungskarte, Fall „metadata auf das inhaltlich reichste Feld zusammengefaltet"). Nach S1 und nach S2 wurde der Kartentext gezielt für die jeweils vorige Variante nachgeschärft; **die Rate hat sich nicht bewegt.** Eine naheliegende Erklärung — die Karte fordere dieselbe Information zweimal (als `acceptance`-Häkchen und als eigene Schlüssel) und das Modell dedupliziere — **hält der Messung nicht stand**: Die Review-Karte desselben Sprints (`t_4ebb816f`) schrieb aus derselben Kartentext-Form **18** Schlüssel, `acceptance` **und** `estimate` darunter. Der Befund ist damit nicht „schlechter Kartentext", sondern: *Das (Schätzung, Ist)-Paar hängt daran, dass ein Modell am Ende eines langen Laufs ein Buchhaltungs-JSON korrekt abschreibt, und dieser Schritt ist je Karte ungefähr, aber nicht sicher zuverlässig.* Das ist eine Aussage über Kapitel 12: Der Phase-2-Nachweis, so wie er spezifiziert ist, ruht auf einer Modell-Kopie je Karte, und deren gemessene Zuverlässigkeit trägt keine harte Gate-Auflage. `ledger-sync.sh` liest die Schätzung ausschließlich aus dem `metadata` der abschließenden Karte selbst (Zeile 133–150, beide Formen — verschachtelt und flach); einen Weg über die Estimator-Karte gibt es nicht. Ihn einzubauen wäre naheliegend und ist bewusst **nicht** getan worden: Er würde die Fehlerklasse und ihren Detektor in derselben Bewegung entfernen, unmittelbar nachdem der Detektor zum dritten Mal korrekt angeschlagen hat. Die Entscheidung gehört ans nächste Roadmap-Gate, mit den drei Messpunkten in der Hand. |
| **Prüfung 5 von `check-sprint.sh` war eine falsche Grüne** | **gefunden und behoben (`78efa34`)** | Sie suchte hart nach `^feat/esf-r1-`. Beim Check von S3 (Branch `feat/esf-r2-f1-…`) prüfte die Schleife deshalb drei **R1**-Branches, meldete sie als in `main` enthalten und gab grün — die einzige Frage, für die die Prüfung existiert, wurde nie gestellt. Genau die Scheinvollständigkeit, gegen die dieser Prüfer gebaut ist, eine Ebene höher. Sie liest die Branch-Namen jetzt aus den **Merge-Karten desselben Sprints**. Gegengemessen: S3 → genau sein eigener Branch, S2 → genau seine zwei. **Folge für den Rückblick:** Die grünen Prüfung-5-Ergebnisse von S1 und S2 sind unter dem kaputten Muster entstanden und waren nie echt — dass ihre Branches trotzdem in `main` liegen, ist unabhängig davon nachgewiesen (Merge-Commits `5677e0f`, `3e61f8e`, `e480390`). |
| **Kosten von S3** | **real gemessen (OpenRouter)** | ≈ 2,75 USD über alle Rollen, davon ≈ 2,45 USD auf die fünf Rollen, die S3-Karten ausgeführt haben. Kartenzeit: Wartung 29 min, Spezifikation 21 min, Schätzung wenige Minuten, Umsetzung 49 min, Review 17 min, Merge 9 min. |

### Die E2E-Videos: .mp4 und nachvollziehbar langsam (19.08.2026)

| Baustein | Status | Warum |
|----------|--------|-------|
| **`.webm` → `.mp4`, Bestand und Neubau** | **real gemessen** | Playwright zeichnet ausschließlich VP8/`.webm` auf, und das spielt außerhalb eines Browsers oft gar nicht. Jedes Einzelvideo wird nach dem Einsammeln nach H.264/`.mp4` umgesetzt; ohne `ffmpeg` bleibt das `.webm` liegen und der Index verlinkt es **sichtbar als Ausnahme** statt still zu fehlen. Bestand nachgezogen: **123 `.webm` → 0**, 136 `.mp4` in 16 Akten, Stichprobe h264/1280×720. |
| **`launchOptions.slowMo` — die ehrliche Verlangsamung** | **drei Läufe derselben Suite gemessen** | Die Suite lief in Maschinen-Geschwindigkeit: 14 Journeys in 1,3 min, einzelne Journeys unter 2 s. Gemessen wurde nicht geraten: **0 ms → 350 ms → 900 ms** ergab bei J-03 5,3 → 8,4 → 15,9 s, bei J-06 6,6 → 12,3 → 24,2 s, Gesamtvideo 68 → 112 → 204 s, Suitenlaufzeit 1,3 → 1,9 → 3,3 min. 350 ms brachte nur ~1,5× — zu wenig. **900 ms** bringt 2,5–3,5× auf den bedienungsintensiven Journeys und ist jetzt die Vorgabe. Reine Navigations-Journeys bleiben kurz (2,9 s), weil `slowMo` nur **Aktionen** verzögert und keine Ladezeiten; dort gibt es auch nichts nachzuvollziehen. Mitgemessen: das Test-Zeitlimit muss mitwachsen (die abgeleitete Config setzt 300 s), sonst liefert ein Test, der in sein Limit läuft, ein **abgeschnittenes statt eines langsamen** Videos. Beides wirkt nur auf den Aufzeichnungslauf — der Lauf, der über den Merge entscheidet, ist ein anderer. |
| **Gedehnt ist nicht langsam aufgenommen** | **als Unterschied gebaut, nicht verwischt** | Bestehende Akten lassen sich nicht nachträglich langsamer *aufnehmen*, nur langsamer *abspielen* (`ffmpeg setpts`, Faktor 2,5). Eine gedehnte Aufnahme zeigt nicht mehr die Zeit, die der Lauf gebraucht hat. `--nachziehen` schreibt deshalb in **jede** nachgezogene Akte einen `DEHNUNG.txt` als Rohbeleg und einen gelb hinterlegten Hinweis in den Index, der auf `lauf.txt` für echte Zeiten verweist. Neue Akten tragen den Hinweis nicht — sie brauchen ihn nicht. |
| **`ffmpeg` ohne `-nostdin` frisst die Schleife** | **gefunden, weil das Ergebnis nicht zur Meldung passte** | Der erste `--nachziehen`-Lauf meldete „✓ 8 Akte(n)" und **Exit 0** — und ließ 73 `.webm` liegen. `ffmpeg` liest ohne `-nostdin` von stdin und verschlang die Ausgabe von `find`, aus der die `while read`-Schleife ihre Verzeichnisse las; sie brach nach dem ersten Durchlauf still ab. Nichts war rot, es fehlte nur die Hälfte — dieselbe Fehlerklasse wie die falsche Grüne in Prüfung 5, nur in einem anderen Werkzeug. Aufgefallen ist es am **Zählen**, nicht an einer Meldung. Flag an allen fünf Aufrufstellen; der Selbsttest trägt jetzt eine **Schleifen-Wache** (drei von `ffmpeg` selbst erzeugte Quellen durch dieselbe Konstruktion — ohne das Flag überlebt genau eine). Selbsttest 9/9, offline, ohne Repo und ohne Playwright. |

### Das Roadmap-Gate R2 — das erste, an dem die Organisation den Supervisor umgestimmt hat (19.08.2026)

| Baustein | Status | Warum |
|----------|--------|-------|
| **Der Chief of Staff hat den Einwand des Supervisors vorweggenommen — und ihn entkräftet** | **real gemessen** | Der Supervisor hatte Option b (die Schätzung technisch über die Estimator-Karte auflösen) am 19.08. schriftlich **verworfen**, mit der Begründung: „er würde die Fehlerklasse und ihren Detektor in derselben Bewegung entfernen, unmittelbar nachdem der Detektor zum dritten Mal korrekt angeschlagen hat." Der Chief of Staff hat genau diesen Satz als **Preis** seiner eigenen Empfehlung ins Dokument geschrieben, bevor er sie aussprach — und dagegengehalten: „Damit bleibt ein Detektor — er wandert nur von der Karte zum Schätzer." Er legte zusätzlich unaufgefordert eine vierte Option (d) vor, ausdrücklich gerahmt als „eine Entscheidung über ein Prinzip, nicht über Kosten". Der Supervisor hat seine Position darauf **geändert**. Das ist der erste Fall in diesem Lauf, in dem eine Rolle den Menschen mit einem Argument umgestimmt hat statt umgekehrt. |
| **Eine Falle, die Option b still hätte scheitern lassen** | **am Board gemessen, vor der Umsetzung** | Der Schätzer schlüsselt sein `estimates`-Objekt nach **Kartentiteln**, und die stimmen nicht mit den Karten überein: Schlüssel `"S3 F1 3/5 Umsetzung"` gegen Titel `"S3 F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan"`. Ein Nachschlagen über den Titel fände **nichts** und schriebe still `estimate: null` — dieselbe Lücke wie heute, nur unsichtbar, weil der kartenseitige Detektor dann abgeschaltet wäre. Ursache ist wieder ein Kartentext des Supervisors: Die Estimator-Karte gibt eine Tabelle mit verkürzten Titeln vor und schreibt dazu „mit genau den Kartentiteln oben als Schlüssel" — der Schätzer hat die Tabelle befolgt. Der Befund ist als **Bedingung 2a** (Auflösung über die Karten-ID) in die Freigabe eingegangen, zusammen mit **2b** (die Auflösung scheitert laut, nie still — S1 hatte den Estimator-Elternteil noch gar nicht) und **2c** (der Detektor wird ersetzt, nicht gestrichen: `check-sprint.sh` bekommt eine metadata-Vollständigkeitsquote je Sprint als Zahl, weil `t_de53e678` auch `changed_files`, `tests` und `commit` verloren hat und Prüfung 3 das unbeabsichtigt mitgemessen hatte). |
| **Die Auflagen stehen im Vault, nicht nur im Gate-Kommentar** | **nachgeprüft** | `roadmap/r2-freigegeben.html` (Commit `601e05e`) trägt die Antwort im Wortlaut **und** einen eigenen Abschnitt 5 „Verbindliche Auflagen und Bedingungen aus der Entscheidung" mit 2a, 2b, 2c benannt. Das war eine ausdrückliche Vorgabe im Kartentext des Gates — begründet mit dem Fehler, den der Supervisor am R1-Gate selbst gemacht hatte: Bedingungen, die nur in einem Kommentar stehen, sind in zwei Wochen vergessen. |
| **Die Zahlen des Neuschnitts, gegengerechnet** | **real gemessen** | 12 vollständige (Schätzung, Ist)-Paare in 7 Klassen — vom Supervisor Karte für Karte gegen `ledger/estimates.jsonl` gehalten, stimmt. Die Zerreißquote 2/12 = 17 % stimmt ebenfalls, samt der korrekten Herausnahme der S1-Spezifikationskarte aus der Grundgesamtheit (Prüfung 3 prüft Umsetzung, Review, Merge — keine Spezifikationen). Die „genau 8 Karten" bei F-R2-2 und F-R2-3 sind Arithmetik, kein Zurechtbiegen: 8 = 4 Bau-Karten plus fester Überbau, die Auflage lässt n ≤ 4 zu, und beide Zerlegungen nennen vier inhaltlich verschiedene Bau-Karten samt der Zusage, im Zweifel zu **teilen statt zu quetschen**. |
| **F-R1-1b: angenommen, aber kein Präzedenzfall** | **entschieden, mit Grund** | WeKan als „F-R1-1b" zu führen hält R2 bei fünf Features — der Chief of Staff hat diesen Zusammenhang selbst offengelegt („R2 hätte sonst sechs Features und bräche `features_pro_release: 5`"). Angenommen, weil die **freigegebene Roadmap F-R1-1 wörtlich als „Import: CSV + WeKan"** führt: WeKan war nie ein zweites Feature, sondern die zweite Hälfte des ersten, vom Architekten bewusst als Folgestück geschnitten. Ausdrücklich mit Auflage 1a versehen: Ein Feature in „a" und „b" zu teilen, um unter dem Limit zu bleiben, höhlt genau das Limit aus, das den Release klein halten soll — künftige „b"-Varianten werden als eigener Feature-Slot vorgelegt. |

## Phase 3 — gebaut am 18.08.2026, nicht gelaufen

Nach Phase 2 wurde die ESF aus der Hermes-Instanz deinstalliert und das
Ziel-Repo auf den Ausgangszustand zurückgesetzt. Die Phase-3-Bausteine
(CEO-Profil, Executor, Notfall-Leiter — `PHASE-3-PLAN.md`) sind deshalb
**gebaut und modellfrei selbstgetestet, aber nie gegen ein laufendes Board
gefahren**. Sie stehen hier und nicht unter „Real gemessen", bis Stufe 3B den
ersten Lauf liefert.

| Baustein | Status | Warum |
|----------|--------|-------|
| **`ceo-lint.py`, der Dokument-Riegel** | **modellfrei selbstgetestet** | Vier Fixtures in `seed/ceo-selbsttest/`: die gültige passiert (Verb parsebar), die drei defekten liefern zusammen genau 5 ERROR, die Roadmap-Sperre und das Budget-Vokabular greifen. Teil von `setup.sh` und `ceo-tick.sh --selbsttest`. |
| **`ceo-tick.sh`, der Executor** | **nur Syntax und Selbsttest** | Die board-seitigen Pfade (Entscheidungskarte anlegen, Journal, Schatten-Vergleich, Einspruchsfrist, `gate.sh --von`) haben nie gegen ein echtes Board gearbeitet. Die Karten-Anlage folgt den in Phase 0–2 verifizierten Mustern (`--idempotency-key`, absolute Pfade, kein Kind einer blockierten Karte), aber Muster sind kein Lauf. |
| **`eskalation.sh`, die Notfall-Leiter** | **Muster-Erkennung selbstgetestet, Rettung nie ausgeführt** | Die Betriebsmuster stammen wörtlich aus den 7 manuellen Rettungs-Unblocks der Phase 2 (`beispiel-lauf-2/board.json`) und werden gegen genau diese Texte positiv, gegen drei Sachgründe negativ getestet. Der automatische Unblock (`betriebsrettung: auto`) ist nie gelaufen; Default ist `melden`. |
| **`gate.sh --von` und der Roadmap-Riegel** | **nur Syntax** | Der Verweigerungspfad (Roadmap-Gate mit `--von esf-ceo`) ist nicht am Board ausgelöst worden. |
| **Ob ein günstiges Modell die CEO-Urteilsarbeit trägt** | **offen, per Bauart** | Die drei CEO-Korrekturen der Phase 2 waren Urteil, nicht Fleiß. Der Schattenbetrieb (Stufe 3B) mit Übereinstimmungsquote im Journal ist genau die Messung dieser Frage — vor ihr gibt es keinen Live-Modus. |
| **Einspruchsfrist am Irreversibel-Gate** | **nicht geprüft** | Frist-Arithmetik über `validiert`-Journalzeilen; nie mit echten Zeitstempeln durchlaufen. |
| **Zwölfter Key für `esf-ceo`** | **Datei geprüft, Zuordnung nicht gelaufen** | `openrouter-keys.txt` trägt seit dem 18.08.2026 zwölf Paare (`esf-hermes-agent-12` als letztes). Mit der Einlese-Logik von `assign-keys.sh` nachgemessen: 12 Keys, 12 verschiedene, und die elf Fingerabdrücke der Phase-2-Zuordnung sind unverändert — der neue Key verschiebt keine Rolle. Die Zuordnung selbst (`config set` auf ein existierendes Profil) und der Verbrauchsnachweis stehen aus, bis die ESF wieder installiert ist; `config get` bewiese auch dann nichts. |

## Der Video-Kanal (18.08.2026) — was gemessen ist und was nicht

Gebaut nach `AGENTS.md 8`: Video-Zusammenfassungen aller CEO-/Supervisor-
Dokumente, vertonte Gate-Vorlagen, Playwright-Videoaufzeichnung nach jedem
grünen E2E-Lauf (seit 18.08.2026 nicht mehr an den Merge gebunden),
Headless-Pflicht. Die Messlage, sauber getrennt:

| Baustein | Status | Warum |
|----------|--------|-------|
| **Der Rückfall-Renderer (`say` → ffmpeg)** | **gemessen am 18.08.2026, seither nicht mehr im Weg** | Damals rendert `--selbsttest` eine echte 17-Sekunden-Titelkarte per ffmpeg: Extraktion (5 Sätze), `.vtt` aus gemessener Audiodauer (Cues enden exakt bei der Solldauer). Werkzeuge auf dieser Maschine: ffmpeg 7.1.1, ffprobe, `say` mit Stimme „Anna" (de_DE). **Achtung bei der Auslegung:** seit Hyperframes trägt, nimmt der Selbsttest auf DIESER Maschine den Primärpfad — er rendert 1920×1080 und weist das auch aus. Der Rückfall ist damit nicht mehr laufend gegengeprüft; er greift nur, wenn der Hyperframes-Aufruf scheitert (kein Netz, kein Chrome). Wer ihn messen will, muss ihn erzwingen. |
| **Die Linter-Regeln zu `AGENTS.md 8`** | **modellfrei gemessen** | Meta-ohne-Skript → ERROR, falscher Videoname → ERROR, fehlende Zusammenfassung im Geltungsbereich → WARN (Übergang: die Phase-0–2-Dokumente tragen noch keine Skripte, `restore-phase1.sh` spielt sie unverändert zurück). Die Fixture-Invariante des Vault-Linters (genau 9 ERROR) blieb dabei unverändert — nachgemessen mit echtem Exit-Code, nicht mit `… \| tail; echo $?`. |
| **Der Headless-Wächter** | **modellfrei gemessen** | Vier Fälle im Selbsttest von `e2e-video.sh`: saubere Config passiert, `headless: false` gefangen, `--headed` gefangen, die eigene abgeleitete Config wird nicht als Verstoß gelesen. Riegel (verweigert), Tick (überspringt + Karte) und Aufzeichnung führen DENSELBEN Wächter aus. |
| **Hyperframes als primärer Renderer** | **real gemessen (18.08.2026)** | Installiert über die ÖFFENTLICHE Registry (`--registry https://registry.npmjs.org` am Aufruf, globale `~/.npmrc` unangetastet): Hyperframes **0.8.3**. `doctor` grün bei Node v22.23.1, ffmpeg/ffprobe 7.1.1, Chrome (headless-shell) und Docker; die roten Posten `whisper-cpp`, Kokoro-TTS und MusicGen sind optional und für diesen Kanal irrelevant (Stimme = macOS `say`, keine Musik). **Fünf** Dokumente sind echt gerendert, je 1920×1080, 30 fps, AAC-Ton: `product.mp4` (65 s), `codebase.mp4` (80 s), `q1-freigegeben.mp4` (78 s), `market.mp4` (81 s), `q1-entwurf.mp4` (73 s). Der market-Render brauchte 28,7 s für 2442 Frames. Gegenprobe auf den Renderer nicht über das Protokoll, sondern über die Datei: der ffmpeg-Rückfall liefert 1280×720, alle fünf sind 1920×1080. `rendere_job` nennt in der Ausgabe den Renderer je Datei, deshalb ist belegt, dass es Hyperframes war und nicht der ffmpeg-Rückfall. |
| **Die frühere CLI-Konvention war FALSCH** | **widerlegt** | Das Skript rief `hyperframes render index.html`. Das Positional von `render` ist aber ein **Projektverzeichnis**, keine Datei (eine Datei bräuchte `-c/--composition`) — der Aufruf hätte nie funktioniert und wäre stumm in den Rückfall gelaufen. Jetzt `render .` aus dem Job-Verzeichnis. Das ist der Grund, warum eine Annahme so lange als Annahme markiert bleiben muss, bis sie ausgeführt ist. |
| **Die Vorlage war ungültig** | **korrigiert, mit `lint` belegt** | `hyperframes lint` wies die von Hand geratene Komposition mit **6 Fehlern** ab: fehlende `data-composition-id`, fehlende `data-width`/`data-height`, keine Registrierung an `window.__timelines`, `performance.now()` und `requestAnimationFrame` (beide laufen auf Wanduhr statt Timeline) und ein `<audio>` ohne `src`. Nach dem Umbau gegen das Gerüst von `hyperframes init --example blank`: **0 Fehler**, eine kosmetische Warnung (Track-Dichte). Zwei Folgefehler kamen erst dabei heraus — Opacity-Tweens auf Clips (`gsap_exit_missing_hard_kill`: Hyperframes verwaltet Clip-Sichtbarkeit selbst) und ein Millisekunden-Überlapp benachbarter Clips aus unabhängig gerundeten Start- und Dauerwerten. |
| **`ffmpeg` frisst die Job-Schleife** | **real gemessen, behoben** | Im ersten Lauf scheiterte **jede zweite** Datei an einem Pfad ohne führenden Schrägstrich (`Users/…` statt `/Users/…`). Ursache: Die Job-Schleife liest ihre Zeilen von stdin, und `ffmpeg` liest stdin ebenfalls — es verschluckt je Aufruf ein Byte der nächsten Jobzeile. Behoben mit `ffmpeg -nostdin` (beide Aufrufe) und `</dev/null` am Hyperframes-Aufruf. Ein Fehler, den nur ein Lauf über **mehrere** Dokumente zeigt: bei einem einzigen Job gibt es keine nächste Zeile, die verstümmelt werden könnte. |
| **Die zwei Tore der individuellen Komposition** | **modellfrei gemessen** | `video-werkzeug.py pruefe` wies **sieben** verfälschte Kompositionen ab und liess die gültige passieren: manipulierte Dauer (81,38 → 60), entfernte Timeline-Registrierung, `src` per JavaScript statt Attribut, `requestAnimationFrame` im Code, eingebautes Fremd-CDN-Bild, fehlendes `data-width`, offener Platzhalter. `hyperframes lint` auf derselben Komposition: 0 Fehler, 1 kosmetische Warnung (Track-Dichte). |
| **Die dreistufige Render-Leiter** | **real durchgefahren** | Mit tragfähiger Komposition rendert Stufe 1 (`komposition(esf-video-designer)`, 1920×1080, 81 s). Mit auf 55 s verfälschter Dauer fällt sie **laut** auf `vorlage(generisch)` — der Befund steht in der Ausgabe, nicht nur im Log. Der Selbsttest trägt seither beide Fälle. |
| **Der Vault-Linter und das neue Verzeichnis** | **gemessen, Fehler gefunden und behoben** | `*.komposition/index.html` ist eine Hyperframes-Szene, kein Vault-Dokument — der Linter forderte zunächst die drei Pflicht-Metas und meldete **3 ERROR**, was den Vault blockiert hätte. Ausnahme eingebaut; die Fixture-Invariante von genau **9 ERROR** in `seed/lint-selbsttest` blieb dabei unverändert. |
| **Der Master der Vault-`.gitignore`** | **Invarianten-Bruch gefunden** | Die `*.mp4`-Regeln existierten **nur im Live-Vault**, nicht im Master — der Master ist die Heredoc in `reset-workspace.sh:51`, nicht `seed/company/.gitignore` (die Datei gab es nie). Ein Muster **mit** Schrägstrich ist zudem an die Wurzel gebunden: `*.komposition/lint.log` erfasste `analysis/…` nicht, erst `**/*.komposition/lint.log` tut es. Beides gemessen mit `git check-ignore`. |
| **Der erste echte Designer-Lauf** | **real gemessen (18.08.2026)** | Karte `t_84b70d60`, `esf-video-designer` auf `deepseek/deepseek-v4-flash-0731` über Key 13, **11,5 Minuten**. Beide Tore grün **beim ersten Versuch**: `pruefe` ok, `hyperframes lint` 0 Fehler (1 kosmetische Warnung). Gerendert hat Stufe 1 — `komposition(esf-video-designer)`, 1920×1080, 30 fps, 2442 Frames, 5,92 MB (die generische Fassung desselben Dokuments: 3,15 MB). Damit ist belegt, dass ein günstiges Modell den Framework-Vertrag einhalten kann; **eine** Messung ist keine Quote. |
| **Individualität: gestaltet er anders als die Vorlage?** | **ja, gemessen an der Datei** | Nicht Text auf Karten, sondern die **sieben Feature-Hypothesen als Ranking-Balken** (`brow`/`blab`/`bscore`/`bfill`), dazu Knoten-und-Kanten-Elemente und Feature-Karten; acht Clips, einer je Erzähl-Cue. 23,5 KB gegen 6,4 KB der generischen Instanz. Ob es *schöner* ist, ist Geschmack und steht hier nicht. |
| **Zahlentreue in diesem Lauf** | **geprüft, hält — aber weiter kein Tor** | Alle sieben Label-Score-Paare gegen das Dokument gegengelesen: 20 / 19 / 18,5 / 18,5 / 18,5 / 15,5 / 14,5, jeder Wert im Umfeld seiner Hypothese belegt, Sortierung absteigend bei erhaltenen Hypothesen-IDs (H2 vor H1, weil 20 > 18,5). **Das war eine Handprüfung von mir, kein Riegel.** Die Struktur-Tore können Zahlentreue nicht prüfen; bei jedem weiteren Lauf haftet allein die Rolle. |
| **Ein Fehler in MEINER Auftragsvorbereitung, vom Modell gefunden** | **gegengemessen und behoben** | `--auftraege` kopierte die generische Vorlage als `referenz-generisch.html` **ins** Projektverzeichnis. Zwei Root-HTML mit `data-composition-id` sind ein lint-Fehler (`multiple_root_compositions`: „The runtime may discover both as entry points, causing duplicate audio playback") — nachgemessen: **1 error**. Der Designer entfernte die Datei selbst und begründete es; wäre sie liegen geblieben, wäre Tor 2 rot gewesen und das Video **still auf Stufe 2** gefallen. Behoben: die Referenz wird nur noch genannt, und `pruefe` prüft jetzt selbst auf genau eine Root-Komposition (ohne zweite Wurzel ok, mit zweiter abgewiesen). |
| **Ob der Designer VERLÄSSLICH trägt** | **sechs Läufe, alle grün** | Sechs Karten, fünf Dokumente, zwei Typen (`analyse`, `roadmap`) — jede Komposition passierte beide Tore, keine fiel auf Stufe 2. Weiter ungemessen: die Typen `report` und `gate`, ein Dokument ohne Zahlen, und der Rückfall auf Stufe 2 ist konstruiert und gegengemessen, aber **noch nie von einem echten Modellfehler ausgelöst** worden. Zahlentreue prüft weiterhin kein Tor. |
| **Die Sprecherstimme (18.08.2026)** | **real gemessen** | Der lokale Weg wurde zuerst geprüft und **fällt aus**: `hyperframes tts` bringt Kokoro-82M offline mit, kennt aber kein Deutsch (Sprachliste 0.8.3: en-us, en-gb, es, fr-fr, hi, it, pt-br, ja, zh); macOS hat für `de_DE` nur die Kompaktstimme „Anna“ plus Spaßstimmen, Premium braucht einen GUI-Download. Gewählt: `openai/gpt-audio`, Stimme `alloy` — **kein neuer Cloud-Service**, sondern derselbe OpenRouter-Provider, abgerechnet über Key 13. Zwei Eigenheiten gemessen: Audio-Ausgabe verlangt `stream: true` (sonst HTTP 400), und die Chunks liegen base64 in `delta.audio.data`. Kosten ~$0,11 je 80-s-Video. |
| **Der Wörtlichkeits-Riegel** | **modellfrei gemessen** | Ein Sprachmodell ist kein TTS-Gerät: es kann umformulieren, und die `.vtt`-Cues entstehen aus den **Sätzen des Dokuments** — Abweichung heißt Drift. `tts-openrouter.py` vergleicht sein Transkript mit dem Sprechertext und verweigert die Datei unter 0,92 Wortähnlichkeit. Gegengemessen: wörtliche Texte 0,958–1,000; ein Text, der zum Umformulieren verleitet, 0,107 → abgewiesen, Rückfall auf `say`. Ziffern und Zahlwörter fliegen vor dem Vergleich raus, weil das Transkript „19“ schreibt, wo der Text „neunzehn“ sagt. |
| **Fünf individuelle Videos mit der neuen Stimme** | **real gemessen** | Alle fünf Dokumente neu gestaltet und gerendert, **alle fünf auf Stufe 1** (`komposition(esf-video-designer)`), je 1920×1080 mit AAC-Ton; Untertitel enden exakt auf der gemessenen Dauer (65,00 / 79,35 / 79,90 / 84,05 / 85,30 s). Herkunft des Tons belegt über die Abtastrate: **24000 Hz** = OpenRouter, `say` liefert 22050 Hz. Formvokabular je Dokument verschieden — `codebase` Monospace-Modulkarte, `q1-entwurf` Feature-Karten mit IDs, `market` Rangbalken, `product` Panels, `q1-freigegeben` Zonen. Damit ist auch der zweite Dokumenttyp (`roadmap`) gemessen. |
| **Idempotency-Key der Designer-Karte** | **Fehler gefunden und behoben** | Der Key bestand nur aus dem Dokumentpfad. Nach dem Stimmwechsel gab Hermes die **abgeschlossene** Karte von `market` zurück statt eine neue anzulegen — `market` wäre nie neu gestaltet worden und **still auf die generische Vorlage** gefallen. Gefunden beim Nachzählen der Karten, **nicht von einem Riegel**. Der Key trägt jetzt die gemessene Dauer. |
| **Playwright-Videoaufzeichnung** | **real gemessen (18.08.2026, 20:59)** | Erster echter Lauf gegen 04 auf `4430537`: `e2e-video.sh --alle --anlass bestandsaufnahme`, **7 passed (38,1 s)**, sieben `.webm` eingesammelt (21 K–317 K, 1–7 s), Gesamtvideo `alle-journeys.mp4` (31 s, 415 K), `index.html` mit sieben `<video>`-Elementen, `lauf.txt` mit dem vollen Protokoll. Damit sind drei bis dahin ungeprüfte Annahmen belegt: die **Vererbung** über den Default-Export von `playwright.config.ts` trägt (die Suite lief mit der abgeleiteten Config grün, obwohl die Repo-Config `video: "off"` setzt), das **Einsammeln je Test** funktioniert (sieben Tests → sieben Dateien, benannt nach dem Testverzeichnis), und das **Aufräumen** greift (`.esf-video.playwright.config.ts` und `.esf-video-results/` sind weg, `git status` in 04 leer). Der Vault-`.gitignore` deckt die Akte, an den echten Pfaden mit `git check-ignore` nachgewiesen. **Ein Befund, gefunden und behoben:** Playwright zeichnete in seiner Vorgabegröße **800×450** auf und rechnete den 1280×720-Viewport von Desktop Chrome herunter. Die abgeleitete Config pinnt die Größe jetzt (`video: { mode: "on", size: { width: 1280, height: 720 } }`), und der **zweite echte Lauf** hat es gegengemessen: 22:07, wieder **7 passed (39,8 s)**, alle acht Dateien 1280×720 (`ffprobe` je Datei), Gesamtvideo 831 K statt 415 K, ein Frame aus J-02 von Hand angesehen — Text lesbar statt weich. Die 800×450-Akte desselben Commits wurde danach verworfen; sie war ein reproduzierbares Duplikat in schlechterer Auflösung. |
| **Der neue Auslöser: nach jedem grünen Lauf statt nach dem Merge** | **teils gemessen, teils Annahme** | **Gemessen (offline):** Der Selbsttest von `e2e-video.sh` trägt jetzt sechs Fälle — dazu `--anlass` (aus `riegel-feat/…` wird `riegel-feat-…`, der Leerfall fällt auf `lauf`) und die Eindeutigkeit (zwei Läufe gleichen Anlasses ergeben `tick-2`, `tick-3`, keine Überschreibung). `--dry-run` nennt für alle drei Aufrufformen den erwarteten Pfad. Und die **Nicht-Blockierung ist als Konstrukt gemessen**, nicht behauptet: mit einem Stub, der sofort `exit 1` liefert, laufen alle drei Aufrufformen (Tick unter `set -euo pipefail`, Riegel und Nachweise unter `set -uo pipefail`) in ihren Betriebsbefund und danach weiter — Exit 0. **Real gemessen (18.08.2026):** der Aufruf-Weg selbst — ein von Hand gestarteter Lauf (`--anlass bestandsaufnahme`) erzeugt die Akte vollständig (Zeile darüber). **Annahme geblieben:** dass die **vier automatischen Aufrufstellen** dabei auch wirklich feuern — keine von ihnen ist seit der Umstellung gelaufen (der Riegel braucht einen Feature-Branch, der Tick einen Cron-Lauf, die Nachweise einen Phasen-Abschluss). Ebenso ungemessen: dass der Riegel im `--dry-run` wirklich nichts schreibt (Guard gesetzt, nie gefahren), und dass `git diff --cached` die Specs des Branches findet — das ersetzt das frühere `HEAD~1 HEAD`, das an der neuen Stelle (vor dem Merge-Commit) leer wäre. |
| **Warum keine Aufzeichnung aus dem Worktree** | **aus einer echten Messung abgeleitet** | Die Aufzeichnung läuft bewusst nur gegen den Hauptbaum. Grund ist der Befund vom 18.08.2026 (Karte `t_288738fa`): `reuseExistingServer` in `playwright.config.ts` ließ die Suite gegen einen stalen Dev-Server aus dem R1-F2-Worktree laufen, J-07 fiel rot, obwohl der Code in Ordnung war. Eine Aufzeichnung aus einem Feature-Worktree hätte dieselbe Falle — und zeigte fremden Code unter dem Namen des eigenen Features. Deshalb tragen `esf-dev-a/b` und `esf-reviewer` die Pflicht NICHT; sie steht nur in `esf-qa-release`, die auf `main` misst. |
| **`.vtt`-Cue-Genauigkeit** | **Näherung, benannt** | Die Cue-Zeiten verteilen die GEMESSENE Gesamtdauer proportional zur Wortzahl je Satz. Das ist deterministisch und passt in der 17-s-Probe; wortgenaue Zeitmarken lieferte erst eine TTS mit Timing-Ausgabe. Die Näherung steht in `AGENTS.md 8` als solche. |
| **Sprechertext-Pflicht der Rollen** | **ungeprüft, per Bauart** | Ob ein deepseek-Worker den Skill `esf-video-zusammenfassung` befolgt und brauchbare 120–220 Wörter liefert, ist nicht gemessen — dieselbe offene Frage wie bei den Superpowers-Skills. Der Linter fängt das Fehlen (WARN) und die Formfehler (ERROR); die Qualität fängt er nicht. |

## Bewusst nicht benutzt

Übernommen aus Kapitel 13 des Konzepts — für jedes gibt es einen verifizierten
Ersatzweg:

`hermes kanban create --goal` (nur Hilfetext; stattdessen deterministische
Endzustands-Checks) · `--model` je Karte (stattdessen Modellwahl über die
Profil-Konfiguration) · `--project` als Gruppierung (stattdessen Eltern-Ketten
und Titel-Präfixe) · Auto-Decompose (stattdessen zerlegt der Chief of Staff
explizit) · `--initial-status blocked` als Gate (**kein** menschliches Tor:
erzeugt kein `blocked`-Ereignis und wird mitbefördert — Gates blockieren sich
selbst per `kanban_block`).
