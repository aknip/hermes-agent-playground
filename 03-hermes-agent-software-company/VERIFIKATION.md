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
| **Baseline des Ziel-Repos** | `pnpm typecheck` 6/6 grün, `pnpm test` 10/10 grün, Playwright 4/4 grün. **`pnpm exec biome ci .` ist bereits auf dem Ausgangs-Commit rot** — Bestandsschuld von Upstream, nicht von der ESF verursacht (gemessen per `git stash` gegen den unveränderten Baum). |
| **E2E-Gerüst** | Playwright 1.62.1, zwei Journeys, 4 Tests, 6,4 s. Zwei Produktfallen dokumentiert: das Passwort-Label zeigt per `for` auf den Wrapper-`div` statt aufs `input`; ein frisches Konto landet auf `/onboarding`, nicht auf `/dashboard`. |
| **Fetch und Normalisierung** | 11 Quellen, 10 erreichbar. Roh 6,4 MB, normalisiert 168 KB. `height.app` antwortete nicht und hinterliess eine `.fehler`-Datei. |
| **Gate hält den Dispatcher an** | Bei blockierter Gate-Karte meldet `dispatch --dry-run` wörtlich `Promoted: 0` / `Spawned: 0`. |
| **Die Gate-Arithmetik**, live ausgelöst | Zweite Blockade derselben Art (`needs_input`) auf derselben Karte → Ereignis `block_loop_detected`, Karte still nach `triage`. Auslöser war eine Anweisung im Kartentext, die der SOUL des Profils widersprach — der konkretere Text gewann. |
| **`triage` ist nicht das Ende der Arbeit** | Entgegen der Formulierung im Konzept holte der Dispatcher die Triage-Karte beim nächsten Tick nach `running` zurück. Zutreffend ist die schwächere Aussage: Die Karte fragt niemanden mehr, läuft aber weiter. |
| **Der Unblock-Grund steht im Kommentar** | Das `unblocked`-Ereignis hat eine **leere** Payload; `gate.sh --reason` landet als Kommentar `UNBLOCK: <verb> …`. Wer den Governance-Check auf `.payload.reason` baut, meldet jede legitime Gate-Antwort als Verstoss. |
| **Phase-0-Abschluss** | Kette Spezifikation→Bau→Review→Riegel durchgelaufen; Gate hielt; CEO-Antwort `modify` ausgeführt; Riegel bestand alle sechs Prüfungen und merged `c7eba96` nach `main`. Kein Worker rief je `kanban_unblock`. |

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

## Nicht verifiziert

| Baustein | Status | Warum |
|----------|--------|-------|
| **OpenRouter-Key je Profil** (Provisioning-API, USD-Limit) | **Annahme** | `scripts/provision-keys.sh` ist geschrieben und an der offiziellen Doku belegt, aber nicht ausgeführt: In dieser Umgebung liegt kein `OPENROUTER_PROVISIONING_KEY` vor. Die ESF läuft mit dem Root-Key. Folge: kein harter USD-Deckel je Rolle, und `ledger-sync.sh` schreibt `cost_usd: null` statt einer Zurechnung. |
| **Kostenzurechnung je Karte** | **Annahme** | Setzt Keys je Profil voraus (siehe oben). Die Tagessumme über `/api/v1/activity` wird geholt, aber nicht auf Rollen verteilt. |
| **Cron-Auslösung zur geplanten Zeit** | **nicht geprüft** | `install-cron.sh` trägt ein und `--remove` baut zurück; dass die Einträge um 07:00/18:00/23:30 tatsächlich feuern, wurde in diesem Lauf nicht abgewartet. Die Skripte selbst sind einzeln ausgeführt. |
| **Gateway als Dauerbetrieb** | **nicht geprüft** | `hermes gateway status` meldete die Service-Definition als *stale*. Der ganze Lauf taktete deshalb über `pump.sh` von Hand. |
| **Autonomie-Horizont `quartal`** | **nicht geprüft** | Der Pfad ist in `gate.sh` und im Gate-Auftrag angelegt, aber in diesem Lauf wurde nur `release` gefahren. |
| **Sprint- und Release-Abschluss** | **nicht geprüft** | `check-sprint.sh`/`check-release.sh` gehören zu Phase 2; die Abschluss-Erkennung in `monitor.sh` ist implementiert, aber ohne echten Sprint nicht ausgelöst worden. |
| **Superpowers-Wirkung** | **Annahme** | Dass die Skills profil-lokal ankommen, ist geprüft (Dateien liegen dort). Ob ein deepseek-Worker ihnen wirklich folgt — RED-GREEN-REFACTOR statt Code-zuerst — ist nicht gemessen. |
| **Zwei Entwickler parallel** | **nicht geprüft** | `esf-dev-a` und `esf-dev-b` existieren, aber Phase 0/1 hat nie zwei Feature-Worktrees gleichzeitig laufen lassen. |
| **Modell-Tiers** | **entfällt in diesem Lauf** | Alle drei Tiers zeigen auf `deepseek/deepseek-v4-flash-0731`. Die Struktur ist da (`ESF_MODELL_HOCH` usw.), differenziert wurde sie nicht. |

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
