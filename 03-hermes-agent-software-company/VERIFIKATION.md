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
