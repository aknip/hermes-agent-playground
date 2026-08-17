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

## Betriebsbefund: der hängende Worker

Der erste Lauf der Bau-Karte blieb **16 Minuten bei 0 % CPU** stehen. `lsof`
zeigte die Ursache: die TCP-Verbindung zu OpenRouter stand auf `CLOSE_WAIT` —
die Gegenseite hatte geschlossen, der Client wartete weiter. Der Worker war
nicht langsam, sondern blockiert.

Drei Konsequenzen, die im Aufbau schon vorgesehen sind und sich hier bewährt
haben:

- **`--max-runtime` je Karte ist keine Kosmetik**, sondern der einzige
  Mechanismus, der einen so blockierten Worker beendet. Ohne ihn hängt die
  Karte unbegrenzt.
- **Der Zustand sieht von aussen aus wie Arbeit.** Das Board meldete
  `running` mit regelmässigen Heartbeats. Nur `ps` (0 % CPU) und `lsof`
  (`CLOSE_WAIT`) unterscheiden Blockade von Fortschritt — `monitor.sh` kann das
  heute nicht und meldet es folglich nicht.
- **Die Respawn-Mechanik greift**, sobald der Prozess wirklich weg ist.

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
