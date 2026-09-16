# Plan: Orchestrator-Profil für Kanban-Triage

**Stand:** 2026-09-15 · **Version:** Hermes Agent **v0.21.2 (2026.9.11)**, macOS
**Status:** in Betrieb. Beide Wege (Triage und Chat) laufen; Worker- und
Orchestrator-Modell sind über Messreihen ausgewählt (Abschnitte 11–17).

> ⚠ **Versionsabweichung zur Repo-Konvention.** `CLAUDE.md` schreibt das Repo auf
> v0.20.0 (2026.8.3) fest. Die installierte Version ist aber **v0.21.2
> (2026.9.11)** (`hermes --version`, Install-Methode `git`). Sämtliche
> Zeilenangaben in diesem Plan stammen aus dem Quellcode dieser
> installierten Version unter `~/.hermes/hermes-agent/` — sie sind gegen
> v0.21.2 belegt, **nicht** gegen v0.20.0.

**Ziel (ursprüngliche Aufgabenstellung):** Ein Profil `orchestrator`, das eine
Aufgabe analysiert und sie als eine oder mehrere Karten — parallel und/oder
sequentiell — auf dem Kanban-Board anlegt, jede Karte dem passenden
installierten Profil zugeordnet. Auslöser: Zuweisung per Chat oder eine Karte
in der Spalte **Triage**. Das ursprünglich vorgesehene Modell
`deepseek/deepseek-v4-flash-0731` ist im Betrieb durch Messreihen ersetzt
worden (Abschnitt 16) — die Aufgabenstellung selbst ist erfüllt.

---

## 0. Stand heute — was eingerichtet ist

| Profil | Modell | Rolle |
|---|---|---|
| **`orchestrator`** | `sonnet[1m]` via `claude-code-mcp` | legt Karten an (Chat-Weg), besitzt die Wurzelkarte nach Triage-Fan-out |
| `summarizer` | `openai/gpt-5.6-terra` | Worker: Zusammenfassungen, Transkripte |
| `claude-dev` | `sonnet[1m]` via `claude-code-mcp` | Worker: Entwicklung; zugleich `default_assignee` |
| `developer`, `my-test-bot`, `default` | `z-ai/glm-5.3-flash` | Worker bzw. Root-Profil |

**Root-Config** (`~/.hermes/config.yaml` — *nicht* im Profil, siehe Abschnitt 2):

```yaml
kanban:
  orchestrator_profile: orchestrator
  default_assignee: claude-dev
  auto_decompose: true
auxiliary:
  kanban_decomposer:
    model: deepseek/deepseek-v4-flash-0731
    provider: openrouter
    reasoning_effort: none      # Pflicht, siehe Abschnitt 8
```

**Orchestrator-Profil**: Modellblock wie oben, `platform_toolsets` für `cli`
und `telegram` je mit `kanban`, eigener `OPENROUTER_API_KEY` in der
Profil-`.env` (Schritt 2b), und `SOUL.md` = `SOUL.orchestrator.md` aus diesem
Verzeichnis (136 Zeilen, Fassung v4 — v4 ersetzt den ABLIEFERUNG-Block
durch eine vierstufige Leiter für den Ablageort, siehe Abschnitt 18).

### Belegt

- **Triage-Weg** vollständig, mit echten Workern: eine Karte → drei Kindkarten
  (parallel und sequentiell) → Wurzelkarte wacht auf (Abschnitt 8).
- **Chat-Weg** über die CLI, inklusive Ablieferung als Artefakt (Abschnitt 9).
- **Worker-Modell** über fünf Kandidaten, je drei bis vier Läufe (Abschnitt 15).
- **Orchestrator-Modell** über fünf Kandidaten, je bis zu 18 Läufe in vier
  Härtegraden (Abschnitt 16).

### Offen

- **Telegram** ist nie gelaufen. Die Toolset-Auflösung ist gemessen, ein
  eigener Bot-Token für das Profil fehlt.
- **Der Decomposer läuft weiter auf deepseek.** Das ist ein anderer Mechanismus
  als der Chat-Orchestrator (ein einzelner JSON-Call ohne Rollentreue-Bedarf)
  und funktioniert mit `reasoning_effort: none` — aber er ist nicht gegen die
  anderen Modelle getestet.
- **Laufzeitunterschiede zwischen Konfigurationen** sind bei n = 3 nicht
  messbar; die Streuung ist zu groß (Abschnitt 17).

---

## 1. Der wichtigste Befund zuerst

Hermes v0.20.0 hat den gewünschten Mechanismus **bereits eingebaut** — als
Triage-Decomposer. Aber: was als *ein* „Orchestrator-Profil" gedacht ist, sind
im Code **drei getrennte Dinge**:

| # | Hermes-Ding | Was es tut | Ist ein Profil? |
|---|---|---|---|
| 1 | `auxiliary.kanban_decomposer` | Liest die Triage-Karte, erzeugt den JSON-Graph aus Kindkarten, wählt Assignees | **Nein** — ein einzelner LLM-Call, kein Agent, keine Tools |
| 2 | `kanban.orchestrator_profile` | Besitzt die **Wurzelkarte** *nach* dem Fan-out; wacht auf, wenn alle Kinder fertig sind | **Ja** — echtes Profil mit Modell |
| 3 | Toolset `kanban` am Profil, **pro Plattform** | Der Chat-Weg (Abschnitt 4): alle 14 `kanban_*`-Tools, u. a. `kanban_create`, `kanban_list`, `kanban_unblock` | **Ja** — Tools am Profil |

Stelle 1 + 2 sind der **Triage-Weg** (Schritte 4–6), Stelle 3 der
**Chat-/Telegram-Weg** (Schritt 3, ausführlich in Abschnitt 4). Beide Wege
erzeugen Karten, teilen aber außer der Board-Datenbank keinerlei Konfiguration.

`config_defaults.py:1741` sagt das explizit:
*„Does not control the decomposer LLM path (see auxiliary.kanban_decomposer)."*

**Konsequenz für das Zielbild:** Eine Karte in Triage wird vom **Aux-LLM**
zerlegt — unabhängig davon, wem sie zugewiesen ist. Der Satz „jede Aufgabe, die
dem Orchestrator in Triage zugewiesen wird, wird von ihm analysiert" stimmt im
*Ergebnis*, aber nicht im *Mechanismus*. Damit „der Orchestrator analysiert"
wirklich zutrifft, muss das deepseek-Modell an **Stelle 1** eingetragen werden,
nicht nur als Profil.

### Wie der Decomposer arbeitet

`kanban_decompose.py:36` ff. — der System-Prompt verlangt genau das, was
gefordert war:

- `fanout: true` → 2–6 Kindkarten, jede mit `title`, `body`, `assignee`,
  `parents` (0-basierte Indizes in dieselbe Liste).
- **Parallel** = Karte ohne `parents`. **Sequentiell** = Karte mit `parents`,
  wartet bis jeder Parent `done` ist. Der Prompt sagt ausdrücklich
  „Prefer parallelism".
- `fanout: false` → genau **eine** Karte, nur mit geschärftem Spec und
  konkretem Assignee (identisch zum Verhalten von `specify`).

Damit ist „bei einfachen Aufgaben nur 1 Karte, bei komplexeren mehrere"
bereits das eingebaute Verhalten — es braucht keine eigene Logik.

Die Wurzelkarte bleibt als Parent aller Kinder am Leben und wacht auf, wenn der
Graph fertig ist (`kanban_decompose.py:8`) — dann kann das Profil aus Stelle 2
die Fertigstellung beurteilen und weitere Arbeit nachlegen.

---

## 2. Wo die Konfiguration hingehört — **nicht** ins Profil

Der Decomposer läuft im Gateway-Dispatcher (`kanban.dispatch_in_gateway: true`).
`_load_routing()` → `_load_config()` → `load_config()` **ohne Profilargument**
(`kanban_decompose.py:129`), und `get_config_path()` (`config.py:469`) löst über
`get_hermes_home()` auf.

Das ist hier **`~/.hermes/config.yaml`** — dort steht der `kanban:`-Block bereits
(Zeile 427 ff., mit dem angepassten `dispatch_interval_seconds: 10`),
`orchestrator_profile` und `default_assignee` sind beide noch `''`.

> ⚠ **Fallstrick:** `hermes -p orchestrator config set kanban.orchestrator_profile …`
> würde in eine Datei schreiben, die niemand liest. Und es fällt nicht auf:
> `_resolve_profile_from_cfg` (`kanban_decompose.py:136`) fällt bei leerem oder
> unbekanntem Wert **stumm** auf das aktive Default-Profil zurück. Das Board
> läuft dann mit falschem Owner, ohne jede Fehlermeldung.

Merksatz: **Modell und Toolsets ins Profil (`-p orchestrator`), Routing und
Decomposer in die Root-Config (ohne `-p`).**

---

## 3. Die Schritte

### Schritt 1 — Profil anlegen

Der On-Disk-Name muss lowercase sein (`profiles.py:189`, Regex
`[a-z0-9][a-z0-9_-]{0,63}`) — „Orchestrator" wird zu **`orchestrator`**
normalisiert.

```bash
hermes profile create orchestrator \
  --description "Zerlegt Aufgaben in Kanban-Karten und routet sie an die passenden Profile. Besitzt die Wurzelkarte und ergänzt Arbeit, wenn Kindkarten fertig sind."
```

### Schritt 2 — Modell setzen (die vier Schlüssel aus CLAUDE.md)

Ohne diese existiert keine `config.yaml` im Profil → nicht dispatchbar.

```bash
hermes -p orchestrator config set model.default   deepseek/deepseek-v4-flash-0731
hermes -p orchestrator config set model.provider  openrouter
hermes -p orchestrator config set model.base_url  https://openrouter.ai/api/v1
hermes -p orchestrator config set model.api_mode  chat_completions
```

`OPENROUTER_BASE_URL` verifiziert in `hermes_constants.py:1176`;
`OPENROUTER_API_KEY` ist in `~/.hermes/.env` vorhanden.

### Schritt 2b — Zugangsdaten für das neue Profil ← **sonst nur in der Shell nutzbar**

`hermes profile create` legt eine **Platzhalter-`.env`** an — drei
Kommentarzeilen, kein Schlüssel — und warnt beim Anlegen ausdrücklich:

```
⚠ This profile has no API keys yet. Run 'orchestrator setup' first,
  or it will inherit keys from your shell environment.
```

Genau daran hängt eine Falle: **in der Shell funktioniert das Profil trotzdem**,
weil es den Schlüssel aus der Umgebung erbt. Die Desktop-App startet ohne diese
Umgebung, und Profile sind bewusst getrennte Inseln, die die Root-`.env`
**nicht** erben (`profiles.py:846` — „the profile silently inherited shell API
keys — read by users as *the new profile reads the root .env*"). Das Symptom
dort ist ein Setup-Dialog:

```
No usable credentials found for openrouter, setup.status reports configured
credentials, but runtime resolution still failed.
```

Die anderen Profile lösen das über eine schlichte `.env`-Zeile. Dieselbe
Konvention spiegeln:

```bash
grep -m1 '^OPENROUTER_API_KEY=' ~/.hermes/.env \
  >> ~/.hermes/profiles/orchestrator/.env
chmod 600 ~/.hermes/profiles/orchestrator/.env
```

> **`hermes auth status` taugt hier nicht als Prüfung.** Der Befehl berichtet
> über OAuth und Credential-Pool, nicht über die `.env`: er meldet
> `openrouter: logged out` auch für ein Profil, das einwandfrei läuft
> (nachgemessen an `developer`). Richtig prüft man mit bewusst geleerter
> Umgebung — also so, wie die App startet:
>
> ```bash
> env -u OPENROUTER_API_KEY -u OPENAI_API_KEY \
>   hermes -p orchestrator chat --oneshot -Q -q "Antworte mit genau einem Wort: bereit"
> ```

Alternative, wenn das Profil einen **eigenen** Schlüssel bekommen soll (so hält
es hier `summarizer`): `hermes -p orchestrator setup` bzw.
`hermes -p orchestrator auth add openrouter --type api-key`.

### Schritt 3 — Kanban-Toolset freischalten (**pro Plattform**)

`kanban` steht in `_DEFAULT_OFF_TOOLSETS` (`tools_config.py:96`) und ist
ausdrücklich ein **Per-Plattform-Opt-in** („opt-in task board tools for this
platform", `tools_config.py:67`). `kanban_toolset_context.py:24` verlangt die
**explizite** Nennung — „all/default" reicht nicht.

```bash
hermes -p orchestrator config set platform_toolsets.cli      '["hermes-cli","kanban"]'
hermes -p orchestrator config set platform_toolsets.telegram '["hermes-telegram","kanban"]'
```

> ⚠ **Nicht über das Top-Level-`toolsets` gehen.** `tools_config.py:595`:
>
> ```python
> # Legacy profile opt-in is a fallback only. A saved platform list (even
> # empty) is authoritative, so a later disable cannot silently re-enable it.
> if not explicitly_configured and "kanban" in (config.get("toolsets") or []):
>     enabled_toolsets.add("kanban")
> ```
>
> Bei einem **frischen** Profil wirkt dieser Fallback noch — `_seed_model_config`
> (`profiles.py:512`) schreibt ausschließlich `{"model": …}`, also existiert kein
> `platform_toolsets`-Block. Sobald aber jemand einmal `hermes tools` oder die
> Toolset-Seite des Dashboards für das Profil benutzt, wird ein Block
> geschrieben — und ab da ist das Top-Level-`toolsets` wirkungslos. Ohne
> Fehlermeldung. Die vier bestehenden Profile haben genau so einen Block,
> `telegram:` eingeschlossen.

`kanban_create` verlangt `assignee` als Pflichtfeld
(`kanban_tools_schemas.py`, `["title","assignee"]`).

### Schritt 4 — Root-Config: Routing eintragen ← **global, ohne `-p`**

```bash
hermes config set kanban.orchestrator_profile orchestrator
hermes config set kanban.default_assignee     claude-dev
```

### Schritt 5 — Decomposer-Modell auf deepseek pinnen

Das ist der Schritt, der „der Orchestrator analysiert" wahr macht.

```bash
hermes config set auxiliary.kanban_decomposer.provider  openrouter
hermes config set auxiliary.kanban_decomposer.model     deepseek/deepseek-v4-flash-0731
hermes config set auxiliary.kanban_decomposer.base_url  https://openrouter.ai/api/v1
hermes config set auxiliary.kanban_decomposer.reasoning_effort none
```

Die vierte Zeile ist **nicht optional** — ohne sie schlägt die Zerlegung fehl.
`max_tokens` ist in `kanban_decompose.py:320` fest auf 4000 verdrahtet; ein
Reasoning-Modell verbraucht dieses Budget vollständig für Reasoning-Tokens und
liefert null Zeichen Inhalt. Der Fehler lautet dann irreführend
`"LLM returned malformed JSON"`. Real gemessen, siehe Abschnitt 8.

Drei Hinweise:

- **Kein `api_mode`** — der `_aux()`-Block (`config_defaults.py:9`) kennt nur
  `provider, model, base_url, api_key, timeout, extra_body, reasoning_effort`.
  Nur `auxiliary.review` hat zusätzlich `api_mode`.
- **Nicht verwechseln** mit `auxiliary.openrouter_model` + `auxiliary.free_only`
  — das ist die *Auto-Chain-Fallback*-Ebene. Steht `free_only: true`, wird ein
  bezahltes deepseek-Modell übersprungen.

### Schritt 6 — Beschreibungen für die bestehenden Profile ← **nicht optional**

`_build_roster()` (`kanban_decompose.py:155`) rendert Profile ohne Beschreibung
als `⚠ undescribed`, und der System-Prompt sagt ausdrücklich: *„Pick assignees
from the roster by matching the task to the profile's DESCRIPTION (not just the
name)."*

Aktueller Stand: nur `my-test-bot` hat eine `profile.yaml` mit Beschreibung.
**`claude-dev`, `developer`, `summarizer` haben keine** — das Routing wäre blind.

```bash
hermes profile describe --all --auto     # oder je Profil: --text "…"
```

### Schritt 7 — Verifikation ohne Modellkosten

```bash
hermes kanban --board <slug> assignees   # orchestrator muss ON DISK = yes zeigen
hermes config get kanban.orchestrator_profile
hermes config get auxiliary.kanban_decomposer.model
hermes -p orchestrator config get platform_toolsets
hermes -p orchestrator tools             # Checkliste: 📌 Kanban je Plattform aktiv?
```

Die letzten beiden Zeilen decken den Chat-/Telegram-Weg ab (Abschnitt 4); die
ersten drei den Triage-Weg.

### Schritt 8 — Ein kontrollierter Testlauf

Eine Karte von Hand in Triage, dann **manuell** zerlegen:

```bash
hermes kanban create --title "…" --triage
hermes kanban decompose <id>
hermes kanban show <id> --json        # ohne --json bricht v0.20.0 ab
```

Das ist ein Aux-Call, kein Dispatcher-Tick, kein Worker-Spawn — der billigste
echte Test.

> **Aber:** `auto_decompose: true` ist gesetzt, der Dispatcher tickt hier alle
> 10 s und würde die Karte ohnehin von selbst zerlegen (max.
> `auto_decompose_per_tick: 3`). Für einen isolierten manuellen Lauf vorher
> `hermes config set kanban.auto_decompose false` — und hinterher zurücksetzen.

---

## 4. Der zweite Weg: Aufgabe per Chat / Telegram

Der Chat-Weg funktioniert — aber über einen **anderen Mechanismus** als Triage.

### Was dabei passiert

In einer Chat-Session ist `HERMES_KANBAN_TASK` nicht gesetzt. `_visible()`
(`kanban_tools.py:83`) fällt damit auf `_profile_has_kanban_toolset()` zurück,
und das Profil sieht **alle 14 `kanban_*`-Tools** — `kanban_create`,
`kanban_list`, `kanban_unblock` eingeschlossen.

Weil `kanban_show` sichtbar ist, injiziert `agent_init.py:1070` zusätzlich die
`KANBAN_GUIDANCE` in den System-Prompt. Die enthält einen Abschnitt
**„## Orchestrator mode"** (`prompt_builder.py:276`):

> *„use `kanban_create` to fan out into child tasks — one per specialist, each
> with an explicit `assignee` and `parents=[...]` to express dependencies. […]
> Do NOT execute the work yourself; your job is routing, not implementation."*

Der Orchestrator-Auftrag steht also bereits im Prompt; er muss nicht in SOUL.md
nachgebaut werden.

### Der Unterschied zum Triage-Weg

| | Triage-Spalte | Chat / Telegram |
|---|---|---|
| Wer analysiert | `auxiliary.kanban_decomposer` (ein LLM-Call) | Das **Profilmodell selbst**, mit seinen Tools |
| Karten entstehen durch | `decompose_triage_task()`, atomar | Einzelne `kanban_create`-Aufrufe |
| Abhängigkeiten | `parents` als 0-basierte Indizes in die JSON-Liste | `parents` als echte Task-IDs |
| Unbekannter Assignee | wird auf `default_assignee` umgebogen | **wird stumm akzeptiert** (siehe unten) |
| Wurzelkarte | ja, Owner = `kanban.orchestrator_profile` | nein — es entstehen nur die erzeugten Karten |

Damit greifen für den Chat-Weg **weder Schritt 4 noch Schritt 5** des Plans:
`kanban.orchestrator_profile`, `kanban.default_assignee` und
`auxiliary.kanban_decomposer` sind reine Triage-Konfiguration.

### Drei Bedingungen, sonst läuft es stumm ins Leere

**a) `kanban` muss für die Plattform `telegram` freigeschaltet sein.**
Siehe Schritt 3 oben — das ist der Grund, warum dort der explizite
`platform_toolsets`-Eintrag steht und nicht das Top-Level-`toolsets`.

**b) Das Profil braucht einen eigenen Telegram-Bot-Token.**
`create_profile` legt ein Profil ohne jede Channel-Konfiguration an, und ein
geklonter Token ist ausdrücklich unerwünscht: *„a copied bot credential makes
two gateways fight over one bot"* (`profiles.py:809`). Der `telegram:`-Block in
`~/.hermes/config.yaml:389` gehört dem **Root-Profil**, nicht dem Orchestrator.

**c) Ein erfundener Assignee wird stumm verworfen.**
`_handle_create` (`kanban_tools.py:839`) prüft nur, dass `assignee` **nicht leer**
ist — **keine Existenzprüfung des Profils**. Die Karte landet dann für immer in
`ready`. Die `KANBAN_GUIDANCE` warnt selbst davor:

> *„The dispatcher SILENTLY drops a card with an unknown assignee (it sits in
> `ready` forever). Ground every assignee in a real profile (`hermes profile
> list`, or ask the user)"*

Das setzt voraus, dass das Terminal-Toolset für die jeweilige Plattform aktiv
ist — sonst kann das Modell `hermes profile list` gar nicht aufrufen. Schritt 6
(Profilbeschreibungen) hilft hier **nicht** von selbst: den Roster bekommt nur
der Decomposer gestellt, der Chat-Weg sieht ihn nie — er muss ihn sich holen.

**d) Ohne Rollendefinition in `SOUL.md` erledigt das Profil die Aufgabe selbst.**
Das ist die wichtigste Bedingung, und sie war in der ersten Fassung dieses Plans
nicht enthalten. Real gemessen (Abschnitt 8): mit allen 14 `kanban_*`-Werkzeugen
im Schema und der Bitte „Fasse den folgenden Text in drei Stichpunkten zusammen"
hat das Profil **die Zusammenfassung geschrieben** statt eine Karte anzulegen.

Der Grund steht in der `KANBAN_GUIDANCE` selbst: der Abschnitt „Orchestrator
mode" ist **konditional** formuliert — *„If your task is itself a decomposition
task (e.g. a planner profile given a high-level goal)"*. Eine direkte Bitte um
eine Zusammenfassung liest sich nicht als Zerlegungsauftrag. Der umgebende Text
ist zudem das Worker-Protokoll („You have been assigned ONE task").

Die Rolle muss deshalb aus dem Profil selbst kommen. `hermes profile create`
legt eine generische `SOUL.md` an (eine Absatzzeile, keine Rolle); sie wird
ersetzt durch `SOUL.orchestrator.md` aus diesem Verzeichnis:

```bash
cp SOUL.orchestrator.md ~/.hermes/profiles/orchestrator/SOUL.md
```

Die vier Punkte, auf die es darin ankommt:

1. **„Du verteilst Arbeit, du erledigst sie nicht"** — ausdrücklich auch dann
   nicht, wenn die Aufgabe klein wirkt.
2. **Roster zuerst holen** (`hermes profile list`), und nach **Beschreibung**
   zuordnen, nicht nach Namen.
3. **Der Inhalt aus dem Chat gehört vollständig in den `body`.** Der Worker
   sieht weder den Chat noch Geschwisterkarten.
4. **Ein erfundener Assignee wird stillschweigend angenommen, aber nie
   ausgeführt** — der Stolperstein aus (c), in Worten, die das Modell liest.

### Zusätzlicher Prüfschritt

```bash
# Zeigt die für eine Plattform tatsächlich aufgelösten Toolsets
hermes -p orchestrator config get platform_toolsets
hermes -p orchestrator tools            # Checkliste: 📌 Kanban muss aktiv sein
```

---

## 5. Eine Entscheidung, die offen bleibt

`default_assignee: orchestrator` wäre wörtlich das Gewünschte, hat aber einen
Haken: nicht-routbare Kindkarten landen dann beim Orchestrator, der damit
Leaf-Arbeit statt Orchestrierung macht. Im Plan steht oben `claude-dev`.

---

## 6. Was ich **nicht** verifiziert habe

| Aussage | Warum offen | Wie prüfbar |
|---|---|---|
| ~~`deepseek/deepseek-v4-flash-0731` existiert bei OpenRouter~~ | **Erledigt.** Genau dieser Slug läuft mit denselben vier Schlüsselwerten bereits in `default` und `developer` (`~/.hermes/config.yaml:1-5`) | — (`hermes models` gibt es übrigens nicht; das Unterkommando heißt `hermes model`) |
| ~~`hermes config set platform_toolsets.telegram '[...]'` parst Liste und verschachtelten Schlüssel korrekt~~ | **Erledigt.** Geschrieben und nachgemessen, siehe Abschnitt 8 — inklusive der irreführenden Warnung, die dabei erscheint | — |
| ~~`hermes-telegram` ist der korrekte Composite-Name~~ | **Erledigt.** `_get_platform_tools(cfg, "telegram")` löst zu 18 Toolsets inkl. `kanban` auf (Abschnitt 8) | — |
| ~~Das Terminal-Toolset ist unter Telegram aktiv~~ | **Erledigt.** `terminal` ist in der aufgelösten Telegram-Liste enthalten (Abschnitt 8) | — |
| Das Gateway läuft tatsächlich mit `HERMES_HOME` = Root | Aus dem Code zwingend, am laufenden Prozess aber nicht nachgemessen | `hermes gateway status` bzw. Prozess-Env prüfen |
| ~~Der Dispatcher dispatcht **keine** Karten in Triage an ihren Assignee~~ | **Erledigt.** Die Testkarte lag unassigned in Triage und wurde nicht dispatcht, sondern zerlegt (Abschnitt 8) | — |
| ~~Verhalten der Wurzelkarte nach Abschluss aller Kinder~~ | **Erledigt.** Sie wachte auf, wurde an `orchestrator` dispatcht und lief 1m 41s (Abschnitt 8) | — |
| ~~Ein Chat-Lauf legt tatsächlich Karten an~~ | **Erledigt für den CLI-Chat** (Abschnitt 8, Lauf 2) — inklusive des Befunds, dass es ohne Rollendefinition in `SOUL.md` *nicht* funktioniert | — |
| Der **Telegram**-Weg legt Karten an | Ungeprüft: das Profil hat keinen eigenen Bot-Token, nur die Toolset-Auflösung ist gemessen | Bot-Token in `~/.hermes/profiles/orchestrator/` hinterlegen, Gateway starten, Aufgabe per Telegram schicken |

---

## 7. Umfang

Alles davon ändert **`~/.hermes/`** (echtes Profil, globale Config, Board) —
nichts im Repo außer diesem Plan. Eine Story unter `02-…/` wäre ein separater
Schritt und ist hier bewusst nicht angelegt.

**Belege:** Quellcode der installierten Version unter
`~/.hermes/hermes-agent/`, zitiert als `datei.py:zeile`. Die Online-Doku war
keine Quelle.

---

## 8. Umsetzungsprotokoll (2026-09-14)

Ausgeführt gegen **v0.21.2**. Board: `default`. Alle Schritte real gemessen.

### Was ohne Zutun schon stimmte

**Schritt 2 war ein No-op.** `_seed_model_config` (`profiles.py:512`) kopiert den
Modellblock des Root-Profils in das neue Profil — und der enthält bereits exakt
die vier gewünschten Werte. Die vier `config set`-Aufrufe aus Schritt 2 sind
damit überflüssig; `deepseek/deepseek-v4-flash-0731` ist über `default` und
`developer` ohnehin als funktionierender Slug belegt.

Das frische Profil hatte erwartungsgemäß **weder** `platform_toolsets` **noch**
ein Top-Level-`toolsets` — die Analyse aus Schritt 3 trifft zu.

### Eine irreführende Warnung bei Schritt 3

`hermes -p orchestrator config set platform_toolsets.telegram '[...]'` schreibt
korrekt, meldet aber:

```
⚠ 'platform_toolsets.telegram' is not a recognized config key — it was saved
  anyway, but Hermes may not read it.  Did you mean: platform_hints.telegram
```

**Das ist ein Fehlalarm.** `platform_toolsets` steht nicht in `DEFAULT_CONFIG`,
wird von `_get_platform_tools` aber sehr wohl gelesen. Nachgemessen:

```
cli       kanban aktiv: True
telegram  kanban aktiv: True
   browser, clarify, code_execution, computer_use, connections, cronjob,
   delegation, file, image_gen, kanban, memory, session_search, skills,
   terminal, todo, tts, vision, web
```

`terminal` ist enthalten — die Voraussetzung für `hermes profile list` aus
Bedingung (c) in Abschnitt 4 ist damit erfüllt.

### Der eigentliche Stolperstein: leere Antwort des Decomposers

Nach den Schritten 1–7 blieb die Triage-Karte liegen. `hermes kanban decompose`
lieferte:

```json
{"task_id": "t_e27d3131", "ok": false, "reason": "LLM returned malformed JSON"}
```

Denselben Aufruf nachgestellt (`call_llm(task="kanban_decomposer", …,
max_tokens=4000)`):

```
finish_reason: length | len(raw): 0
```

**`finish_reason: length` bei null Zeichen Inhalt.** Das Modell hat das gesamte
Budget für Reasoning-Tokens verbraucht, bevor überhaupt Inhalt begann.
`max_tokens=4000` ist in `kanban_decompose.py:320` **fest verdrahtet** und über
keinen Konfigurationsschlüssel erreichbar — die einzige Stellschraube ist das
Reasoning selbst:

```bash
hermes config set auxiliary.kanban_decomposer.reasoning_effort none
```

Danach derselbe Aufruf:

```
finish_reason: stop | len: 3275 | parst: True | fanout: True, 3 tasks
```

> **Merksatz:** Ein Reasoning-Modell am `kanban_decomposer` braucht
> `reasoning_effort: none` (oder `minimal`). Sonst frisst das Reasoning die
> fest verdrahteten 4000 Tokens auf, und der Fehler, den man zu sehen bekommt,
> lautet irreführend „malformed JSON" — nicht „leere Antwort" oder „Limit
> erreicht". Der Schlüssel fehlte in den Schritten 1–7 und gehört dort dazu.

### Das Ergebnis der Zerlegung

Der Gateway-Dispatcher war mit seinem 10-Sekunden-Takt schneller als der
manuelle Aufruf und hat die Karte selbst zerlegt — das belegt den
`auto_decompose`-Pfad gleich mit:

| Karte | Status | Assignee | Parents |
|---|---|---|---|
| `t_e27d3131` (Wurzel) | todo | **orchestrator** | — |
| `t_cc896ed5` Implement csvstats.py | running | developer | `[]` |
| `t_6552cccb` pytest-Tests | todo | developer | `[t_cc896ed5]` |
| `t_d0f7b317` README.md | todo | summarizer | `[t_cc896ed5]` |

Damit sind auf einen Schlag belegt:

- **Schritt 4** — die Wurzelkarte gehört `orchestrator`, also greift
  `kanban.orchestrator_profile` aus der Root-Config.
- **Schritt 5** — die Zerlegung lief über das gepinnte deepseek-Modell
  (Gateway-Log: `Auxiliary kanban_decomposer: using openrouter
  (deepseek/deepseek-v4-flash-0731)`).
- **Schritt 6** — das Routing folgte den Beschreibungen, nicht den Namen:
  Implementierung und Tests an `developer`, die README an `summarizer`.
- **Das Graph-Muster aus Abschnitt 1** — die Implementierung hat keinen Parent
  und läuft zuerst; Tests und README hängen beide an ihr und laufen danach
  **parallel**. Sequentiell und parallel in einem Graphen, wie beschrieben.

### Korrektur am Verifikationsbefehl

`hermes models list` gibt es nicht — das Unterkommando heißt `hermes model`.
Die Modellfrage ist ohnehin anders geklärt (siehe oben).

### Der vollständige Lauf

| Karte | Assignee | Laufzeit | Ergebnis |
|---|---|---|---|
| `t_cc896ed5` Implementierung | developer | 18m 38s | `csvstats.py`, 6129 B, stdlib-only |
| `t_6552cccb` Tests | developer | 6m 39s | `test_csvstats.py`, 15 Tests |
| `t_d0f7b317` README | summarizer | 1m 33s | `README.md`, 2789 B |
| `t_e27d3131` Wurzel | **orchestrator** | 1m 41s | konsolidiert, Abnahme geprüft |

Die beiden abhängigen Karten liefen **gleichzeitig**, sobald die
Implementierung `done` war — sequentiell gegenüber dem Parent, parallel
zueinander, genau wie der Graph es vorgab.

Abnahme selbst nachgeprüft (nicht aus der Zusammenfassung übernommen):
`python3 -m pytest -q` → **15 passed**.

### Geschwisterkarten koordinieren sich über einen Kommentar, nicht über den Workspace

Naheliegende Fehlannahme: die Kinder erbten den Workspace des Parents. Sie tun
es **nicht**. `_insert_decomposed_child` (`kanban_db_graph.py:176-193`) vererbt
den Pfad nur, wenn die Wurzel schon einen hat — eine frisch per
`hermes kanban create --triage` angelegte Karte hat `workspace_path = None`.
Jedes Kind bekam folglich ein eigenes Scratch-Verzeichnis.

Nachgemessen: `csvstats.py` lag in beiden Workspaces inhaltlich identisch, im
README-Workspace aber mit **fünf Minuten jüngerem** mtime — der zweite Worker
hat sie sich selbst geholt. Möglich war ihm das, weil der erste Worker einen
`kanban_comment` hinterlassen hatte, der die beiden Folgekarten namentlich
adressiert und die Design-Entscheidungen festhält („eindeutig zählt den
Leerwert als eigene Kategorie", „numerisch nur bei lückenloser Spalte").

Das ist exakt das, was die `KANBAN_GUIDANCE` verlangt: *„Every child card body
must carry the decisions it depends on, because workers cannot see sibling
context."* Wer eine Story darauf aufbaut, muss den Handoff also in den
Kartentext schreiben — auf einen geteilten Workspace ist kein Verlass.

### ⚠ Nach `done` sind die Workspaces weg

Nach Abschluss aller Karten war
`~/.hermes/kanban/workspaces/` **vollständig leer** — Scratch-Workspaces werden
aufgeräumt (`_REMOVABLE_KINDS`, `kanban_db_workspace.py:22`; der Kommentar bei
Zeile 24 nennt die Bedingung: kein Kind mehr aktiv).

Erhalten bleibt nur, was ein Worker über `kanban_complete(artifacts=[…])`
anhängt. Hier hat die Wurzelkarte neun Anhänge bekommen:

```
/Users/aknipschild/.hermes/kanban/attachments/t_e27d3131/
  csvstats.py  test_csvstats.py  README.md  sample.csv
```

Dort läuft `pytest` weiterhin grün (15 passed). **Für eine Story heißt das:
Ergebnisse gehören in `artifacts`, nicht in den Workspace** — sonst ist das
Erzeugnis nach dem letzten `done` unwiederbringlich.

### Aufräumen nach dem Lauf

Die vier Testkarten wurden **archiviert, nicht gelöscht**:

```bash
hermes kanban archive t_cc896ed5 t_6552cccb t_d0f7b317 t_e27d3131
```

Bewusst ohne `--rm`. `hermes kanban archive --rm <ids>` löscht bereits
archivierte Karten endgültig — und damit auch ihre Anhänge, die nach dem
Workspace-Aufräumen die **einzige** verbliebene Kopie der Ergebnisse sind und
oben als Beleg zitiert werden.

Nachgeprüft, dass das Archivieren die Belege nicht antastet:

```
~/.hermes/kanban/attachments/t_e27d3131/
  csvstats.py  test_csvstats.py  README.md  sample.csv
→ python3 -m pytest -q   ...............  15 passed
```

Das aktive Board enthält danach nur noch die Karte, die schon vor dem Lauf
dort lag (`t_8cc31f56`, my-test-bot). Nicht angetastet.

> Wer die Karten samt Anhängen endgültig loswerden will:
> `hermes kanban archive --rm t_cc896ed5 t_6552cccb t_d0f7b317 t_e27d3131`.
> Danach sind die Belege dieses Abschnitts nicht mehr nachvollziehbar.
> `hermes kanban gc` räumt zusätzlich Workspaces und alte Ereignisse
> archivierter Karten ab.

### Was `~/.hermes/` nach allem enthält

Bleibend geändert durch diese Umsetzung:

| Ort | Änderung |
|---|---|
| `~/.hermes/profiles/orchestrator/` | neues Profil (Modellblock, `platform_toolsets`, 58 Skills, Wrapper `~/.local/bin/orchestrator`) |
| `~/.hermes/config.yaml` | `kanban.orchestrator_profile`, `kanban.default_assignee`, vier `auxiliary.kanban_decomposer.*`-Schlüssel |
| `~/.hermes/profiles/{claude-dev,developer,summarizer}/profile.yaml` | je eine LLM-erzeugte `description` (Schritt 6); `default` ebenfalls |
| `~/.hermes/kanban.db` | vier archivierte Karten |
| `~/.hermes/kanban/attachments/` | die vier Ergebnisdateien |

Nicht angetastet: die bestehenden Modell- und Channel-Einstellungen der vier
Altprofile, das Root-Modell, und alles im Repo außer diesem Plan.

---

## 9. Lauf 2: der Chat-Weg (2026-09-14)

Aufgabe per CLI-Chat an das Profil, bewusst simpel gehalten, damit **eine**
Karte die richtige Antwort ist:

```bash
hermes -p orchestrator chat --oneshot -Q -q "Fasse den folgenden Text in drei
Stichpunkten zusammen. TEXT: <Deichwartung, 5 Sätze>"
```

### Erster Versuch: der Orchestrator erledigt die Aufgabe selbst

Mit der Konfiguration aus den Schritten 1–7 kam keine Karte, sondern die
fertige Zusammenfassung — das Board blieb unverändert.

Die Diagnose war der entscheidende Schritt, denn „konnte nicht" und „wollte
nicht" hätten verschiedene Ursachen. Eine direkte Abfrage im selben Profil
ergab, dass **alle 14 `kanban_*`-Werkzeuge im Schema standen**:

```
kanban_attach, kanban_attach_url, kanban_attachments, kanban_block,
kanban_comment, kanban_complete, kanban_create, kanban_heartbeat,
kanban_link, kanban_list, kanban_request_changes, kanban_request_review,
kanban_show, kanban_unblock
```

Schritt 3 funktioniert also — das Modell hat sich **entschieden**, die Arbeit
zu tun. Ursache ist die Formulierung der `KANBAN_GUIDANCE`: ihr Abschnitt
„Orchestrator mode" ist konditional (*„If your task is itself a decomposition
task"*), und der umgebende Text ist das Worker-Protokoll („You have been
assigned ONE task"). Eine Bitte um eine Zusammenfassung löst das nicht aus.

### Zweiter Versuch: mit Rollendefinition

Nach dem Ersetzen der generischen `SOUL.md` durch `SOUL.orchestrator.md`
(Bedingung (d) in Abschnitt 4) — **gleiche Aufgabe, gleicher Wortlaut**:

```
Karte angelegt:
- t_c3a24225 — "Deichwartung-Text in drei Stichpunkten zusammenfassen"
  — Assignee: summarizer — keine Abhängigkeiten.
```

Richtiger Zuschnitt (einfache Aufgabe = eine Karte), Routing über die
Beschreibung, und — der kritische Punkt — der **Volltext stand im `body`**
(1056 Zeichen, nach ZIEL/TEXT gegliedert). Hätte der Orchestrator ihn
weggelassen, wäre die Karte unbearbeitbar gewesen: der Worker sieht den Chat
nicht.

Der Dispatcher übernahm binnen eines Ticks. Ergebnis nach **7m 49s** als
Anhang `ergebnis.md` — drei Stichpunkte, inhaltlich korrekt, nichts erfunden.
Die lange Laufzeit ist Reasoning des `summarizer`-Modells, kein Hänger; der
Worker-Log unter `~/.hermes/kanban/logs/t_c3a24225.log` zeigt durchgehende
Aktivität.

### Der Fehler, der den Plan bis hierhin hatte

Das Profil lief in der Shell, aber die **Desktop-App konnte es nicht öffnen**:

```
No usable credentials found for openrouter, setup.status reports configured
credentials, but runtime resolution still failed.
```

Ursache und Behebung stehen jetzt als **Schritt 2b**. Der Punkt, der das
Übersehen erst möglich machte: in der Shell *funktioniert* das Profil ohne
eigenen Schlüssel, weil es ihn aus der Umgebung erbt. Jeder CLI-Test ist
deshalb blind für diesen Fehler — man muss mit `env -u OPENROUTER_API_KEY`
prüfen, sonst testet man die eigene Shell statt das Profil.

### Aufräumen

`t_c3a24225` archiviert (ohne `--rm`, wie in Lauf 1 — der Anhang
`ergebnis.md` ist die einzige verbliebene Kopie des Ergebnisses).

---

## 10. Warum ein Kanban-Worker Minuten braucht, wo der Chat Sekunden braucht

Dieselbe Aufgabe (Text in drei Stichpunkten zusammenfassen), dasselbe Profil
`summarizer`, viermal gefahren. Direkt im Chat an `summarizer` gestellt ist sie
in **Sekunden** erledigt; als Kanban-Karte dauert sie Minuten.

### Die Messreihe

| Lauf | `reasoning_effort` | `stall_guards` | Dauer | Turns | davon leer / nur Absicht | „byte-identical" | Artefakt |
|---|---|---|---|---|---|---|---|
| 1 | medium (Default) | true | 469 s | 15 | 1 (6 %) | 1 | ja |
| 2 | none | true | 292 s | 26 | 6 (23 %) | 3 | nein |
| 3 | none | **false** | **90 s** | 10 | 3 (30 %) | 0 | nein |
| 4 | none | **false** | 435 s | 36 | **25 (69 %)** | 0 | **ja** |

„Turns" = Modell-Durchgänge im Worker-Log
(`~/.hermes/kanban/logs/<id>.log`, gezählt an `╭─ ☤ Hermes`-Blöcken).
„Leer / nur Absicht" = Block mit weniger als 60 Zeichen Inhalt.

### Wo die Zeit hingeht

**Nicht in der Aufgabe.** Die fertige Zusammenfassung steht in jedem Lauf schon
in den ersten Durchgängen im Log. Die Zeit verbrennt in wiederholten
`kanban_show`-Aufrufen: 13, 23, 4 und 30 Stück. Jeder davon ist ein
vollständiger Modell-Durchgang mit dem kompletten Worker-Systemprompt.

Ausgelöst wird das durch Schritt 1 des Worker-Protokolls in der
`KANBAN_GUIDANCE` (`prompt_builder.py:243`): *„Call `kanban_show()` first."*
Der Chat-Weg hat diesen Orientierungsschritt nicht — **null** `kanban_show`,
ein Durchgang, fertig. Das ist der strukturelle Unterschied.

Das Muster im Log ist in allen vier Läufen dasselbe: das Modell gibt eine reine
Absichtserklärung aus („I'll orient myself with the task details.") oder einen
leeren Block, ruft `kanban_show` erneut auf und verarbeitet das Ergebnis nie.
In Lauf 4 waren **69 % aller Durchgänge** von dieser Art.

### Was die beiden Schalter *nicht* erklären

Läufe 3 und 4 haben **identische Konfiguration** — und 90 s gegen 435 s, also
Faktor 4,8. Damit ist die naheliegende Erklärung widerlegt:

> **`stall_guards: false` beseitigt die Schleife nicht.** Nach Lauf 3 sah es so
> aus (23 → 4 `kanban_show`, keine „byte-identical"-Meldung mehr), aber Lauf 4
> mit derselben Einstellung hatte 30 Aufrufe und die längste Schleife der Reihe.
> Lauf 3 war ein glücklicher Lauf, kein Beleg.

Schlimmer noch: der Schalter hebt laut `config_defaults.py:139-143` **beides**
auf — das Result-Stubbing *und* die „continue-intent extension of empty-response
recovery [that] re-prompts once when the model says it will continue but takes
no action". Genau dieser Fehlermodus dominiert Lauf 4. Der Verdacht liegt nahe,
dass `stall_guards: false` die Sache im Mittel **verschlechtert**; belegt ist
das mit zwei Läufen nicht.

Zum Result-Stubbing (`run_agent.py:1247`) bleibt ein echter Befund: In den
Läufen 1 und 2 meldete das Modell wörtlich *„the kanban_show returned
byte-identical to an earlier call, **but I don't see that earlier result in my
context**"* und rief deshalb erneut auf. Der Verweis zeigt für dieses Modell ins
Leere. Das erzeugt Schleifen — es ist nur nicht die einzige Ursache.

### Was belastbar ist

1. **Der Orientierungsschritt ist der Kostentreiber**, nicht die Aufgabe. Wer
   Kanban-Worker mit diesem Modell betreibt, zahlt ihn bei *jeder* Karte.
2. **`reasoning_effort: none` macht den einzelnen Durchgang schneller**
   (31,3 s → 11,2 s in Läufen 1→2), erhöht aber die Zahl der Durchgänge. Netto
   in dieser Reihe −38 %.
3. **Die Streuung ist größer als jeder Schaltereffekt.** 90 s bis 469 s bei
   vier Läufen derselben Aufgabe. Ein einzelner Lauf taugt hier nicht als
   Beleg — auch meiner nicht.

### Was den Artefakt-Verlust behoben hat

Unabhängig von alledem: bis Lauf 3 ging das Ergebnis verloren
(`result_len: 0`, kein Anhang, Workspace nach `done` gelöscht). Ursache war die
frei formulierte Kartenanweisung des Orchestrators — in Lauf 2 stand dort
„Liefere nur die drei Stichpunkte als Ergebnis", woraufhin der Worker gar keine
Datei anlegte.

`SOUL.orchestrator.md` schreibt jetzt einen wörtlichen Satz vor, den der
Orchestrator in jede Karte übernimmt:

> ABLIEFERUNG: Schreibe das Ergebnis in eine Datei im Arbeitsverzeichnis und
> hänge sie mit `kanban_complete(artifacts=[<absoluter Pfad>])` an. Die
> Zusammenfassung im `summary` ersetzt das Artefakt nicht.

In Lauf 4 stand der Satz wörtlich in der Karte, und das Ergebnis kam als
Anhang `deichwartung_3_stichpunkte.md` an. **Ein Lauf ist ein Lauf** — aber der
Wirkzusammenhang ist hier direkt nachvollziehbar, anders als bei den
Laufzeit-Schaltern.

---

## 11. Modellwechsel: `summarizer` auf Claude Code / Sonnet

Die Messreihe aus Abschnitt 10 ließ offen, ob der Worker-Overhead strukturell
ist oder am Modell hängt. Der Gegentest entscheidet das: **nur das Modell des
`summarizer`-Profils geändert**, `reasoning_effort: none` und
`stall_guards: false` bewusst stehen gelassen, damit nicht zwei Variablen
gleichzeitig wandern. Dieselbe Aufgabe, dreimal nacheinander.

### Die Umstellung

```bash
hermes -p summarizer config set model.default        "sonnet[1m]"
hermes -p summarizer config set model.provider       claude-code-mcp
hermes -p summarizer config set model.base_url       "claude-code://cli"
hermes -p summarizer config set model.api_mode       chat_completions
hermes -p summarizer config set model.context_length 1000000
```

> ⚠ **Die fünf Schlüssel allein genügen nicht.** Danach kam
> `Unknown provider 'claude-code-mcp'`, obwohl das Plugin unter
> `~/.hermes/plugins/model-providers/` lag. Der Grund steht als Kommentar in
> `04-hermes-claude-code-provider/install.sh:10-12`:
> `providers._user_plugins_dir()` sucht unter
> `$HERMES_HOME/plugins/model-providers/` — für ein Profil also **nicht** im
> Root-Home. Eine nur global abgelegte Kopie ist für `hermes -p <profil>`
> unsichtbar. Der belegte Weg ist das Repo-Skript:
>
> ```bash
> cd 04-hermes-claude-code-provider && ./install.sh summarizer
> ```
>
> Es legt das Plugin in **beide** Homes und prüft die Registrierung
> (`Profil+Registry=ja`).

### Die drei Läufe

| Lauf | Karte | Dauer | Turns | `kanban_show` | Artefakt |
|---|---|---|---|---|---|
| 1 | `t_818c25e9` | **15 s** | 1 | 1 | `zusammenfassung.txt` |
| 2 | `t_63e33bda` | **13 s** | 1 | 1 | `zusammenfassung_deichwartung.md` |
| 3 | `t_498f2880` | **17 s** | 1 | 1 | `zusammenfassung.txt` |

### Der Befund

**Der Overhead war modellspezifisch, nicht strukturell.**

| | deepseek-v4-flash (4 Läufe) | Sonnet via Claude Code (3 Läufe) |
|---|---|---|
| Dauer | 90 – 469 s | **13 – 17 s** |
| Streuung | Faktor 5,2 | Faktor 1,3 |
| Turns | 10 – 36 | **durchgehend 1** |
| `kanban_show` | 4 – 30 | **durchgehend 1** |
| Artefakt abgeliefert | 2 von 4 | **3 von 3** |

Sonnet erledigt den Orientierungsschritt der `KANBAN_GUIDANCE` in **einem**
Durchgang — genau so, wie das Protokoll ihn meint. Die Schleife aus leeren
Absichtserklärungen und wiederholten `kanban_show`-Aufrufen tritt nicht auf.

Damit relativieren sich zwei frühere Schlüsse dieses Dokuments:

- Der „strukturelle Rest" aus Abschnitt 10 (Prozessstart, Skill-Laden,
  Dispatcher-Tick) ist mit **13–17 s** deutlich kleiner als dort vermutet.
  Der Abstand zum Chat-Weg schrumpft auf Sekunden.
- Die Schalter `reasoning_effort` und `stall_guards` sind für dieses Ergebnis
  **belanglos** — sie standen in allen drei Läufen noch auf den
  deepseek-Werten. Wer das Laufzeitproblem hatte, löst es über das Modell,
  nicht über diese Schalter.

Die Ergebnisqualität ist in allen drei Läufen gleichwertig: drei Stichpunkte,
alle vier Jahreszeiten abgedeckt, keine erfundenen Fakten.

### Rückbau

Der Stand vor der Umstellung liegt in `/tmp/summarizer-config.vor-sonnet.yaml`
(`provider: openrouter`, `default: deepseek/deepseek-v4-flash-0731`). Für einen
dauerhaften Rückbau gehört diese Sicherung an einen beständigeren Ort.

---

## 12. Dritter Modellvergleich: GLM 5.3 Flash

Gleiche Aufgabe, gleiches Skript, dreimal. Geändert wurde erneut **nur** der
Modellblock des `summarizer`-Profils (`provider: openrouter`,
`default: z-ai/glm-5.3-flash`); `reasoning_effort: none` und
`stall_guards: false` blieben unverändert stehen.

| Lauf | Karte | Dauer | Turns | `kanban_show` | Artefakt |
|---|---|---|---|---|---|
| 1 | `t_17135902` | 52 s | 3 | 1 | ja |
| 2 | `t_4bd8ce32` | 73 s | 4 | 1 | ja |
| 3 | `t_5b8c7e1c` | 48 s | 5 | 1 | ja |

### Die Gesamtschau

| Modell | Läufe | min | max | Median | Streuung | `kanban_show` | Artefakt |
|---|---|---|---|---|---|---|---|
| deepseek-v4-flash | 4 | 90 s | 469 s | 364 s | **5,2×** | 4–30 | 2 von 4 |
| **Sonnet** (Claude Code) | 3 | **13 s** | **17 s** | **15 s** | 1,3× | **je 1** | **3 von 3** |
| GLM 5.3 Flash | 3 | 48 s | 73 s | 52 s | 1,5× | **je 1** | **3 von 3** |

**Die Trennlinie verläuft nicht bei der Geschwindigkeit, sondern bei der
Schleife.** Sonnet und GLM erledigen den `kanban_show`-Orientierungsschritt
beide in **einem** Aufruf und liefern zuverlässig ein Artefakt; ihre Streuung
bleibt unter Faktor 1,6. deepseek gerät in die Wiederholung (bis zu 30
Aufrufe) und streut um Faktor 5,2.

Zwischen Sonnet und GLM bleibt ein Faktor von rund 3,5 im Median — GLM braucht
3 bis 5 Durchgänge, wo Sonnet mit einem auskommt. Beide sind für den Betrieb
brauchbar; deepseek ist es als Worker-Modell nicht.

Die Ergebnisqualität ist bei allen drei Modellen gleichwertig: drei
Stichpunkte, alle vier Jahreszeiten abgedeckt, keine erfundenen Fakten.

---

## 13. ⚠ Die Rollentreue des Orchestrators ist nicht verlässlich

Beim dritten GLM-Lauf legte der Orchestrator **keine Karte an**, sondern
beantwortete die Aufgabe selbst — der Fehlermodus aus Abschnitt 9, den
`SOUL.orchestrator.md` beheben sollte. Ein direkt danach wiederholter Aufruf
scheiterte genauso; erst der dritte Anlauf legte wieder eine Karte an.

Geprüft und ausgeschlossen: die `SOUL.md` war unverändert (byte-identisch zur
Repo-Kopie), das Orchestrator-Modell unverändert
`deepseek/deepseek-v4-flash-0731`.

**Damit ist die Aussage aus Abschnitt 9 zu relativieren.** Dort wurde der
`SOUL.md`-Fix nach *einem* erfolgreichen Lauf als wirksam bezeichnet. Über
inzwischen zwölf Orchestrator-Aufrufe steht es bei etwa **10 von 12** — die
Rollendefinition erhöht die Trefferquote deutlich, garantiert sie aber nicht.

Praktische Folge: Ein Orchestrator auf `deepseek-v4-flash` beantwortet
gelegentlich Aufgaben selbst, statt sie zu verteilen. Das fällt im Chat auf
(man bekommt eine Antwort statt einer Karten-Id), auf einem unbeaufsichtigten
Kanal wie Telegram aber nicht. Wer sich darauf verlassen muss, sollte das
Orchestrator-Profil auf ein Modell stellen, das Rollenanweisungen
zuverlässiger befolgt — dieselbe Empfehlung, die Abschnitt 12 für das
Worker-Profil gibt. Gemessen ist das für den Orchestrator **nicht**; die
Zahlen oben betreffen nur das Worker-Modell.

---

## 14. Vierter Modellvergleich: GLM 5.3 (voll) — und ein Gegenbefund zum Orchestrator

Diesmal wanderten **zwei** Variablen: Orchestrator von
`deepseek-v4-flash` auf `z-ai/glm-5.3-flash`, Worker von
`z-ai/glm-5.3-flash` auf das volle `z-ai/glm-5.3`. Die Vergleichsvariablen
(`stall_guards: false`, `reasoning_effort: none`) blieben erneut stehen.

### Worker: GLM 5.3 (voll)

| Lauf | Karte | Worker | Turns | `kanban_show` | Artefakt |
|---|---|---|---|---|---|
| 1 | — | — | — | — | Orchestrator legte keine Karte an |
| 2 | `t_0683b0f3` | 19 s | 3 | 1 | ja |
| 2b | `t_89c5f8b1` | 16 s | 5 | 1 | ja |
| 3b | `t_7ff65055` | 35 s | 4 | 1 | ja |

Weil der Orchestrator in zwei von drei Läufen aussetzte (siehe unten), wurden
die Messpunkte 2b und 3b mit **byte-identischem Kartentext** aus Lauf 2
direkt per `hermes kanban create` angelegt. Das schaltet die Formulierung des
Orchestrators als Störgröße aus — methodisch sauberer als die vorherigen
Reihen, aber nicht identisch zu ihnen.

### Die Gesamtschau über vier Worker-Modelle

| Worker-Modell | n | min | max | Median | Streuung | **Turns** | `kanban_show` | Artefakt |
|---|---|---|---|---|---|---|---|---|
| deepseek-v4-flash | 4 | 90 s | 469 s | 364 s | 5,2× | **10–36** | 4–30 | 2 von 4 |
| **Sonnet** (Claude Code) | 3 | 13 s | 17 s | **15 s** | 1,3× | **je 1** | je 1 | 3 von 3 |
| GLM 5.3 Flash | 3 | 48 s | 73 s | 52 s | 1,5× | **3–5** | je 1 | 3 von 3 |
| **GLM 5.3 (voll)** | 3 | 16 s | 35 s | **19 s** | 2,2× | **3–5** | je 1 | 3 von 3 |

Einzelwerte — deepseek: 15 / 26 / 10 / 36 · Sonnet: 1 / 1 / 1 ·
GLM Flash: 3 / 4 / 5 · GLM 5.3: 3 / 5 / 4.

Die Turn-Spalte trennt die Modelle schärfer als die Sekunden: **GLM Flash und
GLM 5.3 brauchen gleich viele Durchgänge (3–5), sind aber unterschiedlich
schnell** (Median 52 s gegen 19 s). Der Unterschied liegt also in der Zeit
pro Durchgang, nicht in der Zahl der Durchgänge — rund 13 s gegen 5 s.
Bei deepseek ist es umgekehrt: dort ist die *Zahl* der Durchgänge das Problem.

Bemerkenswert: **das volle GLM 5.3 ist als Worker rund dreimal schneller als
seine Flash-Variante** (Median 19 s gegen 52 s) — die kleinere Variante ist
hier nicht die schnellere. Sonnet bleibt vorn, der Abstand schrumpft aber von
Faktor 3,5 auf 1,3.

Drei der vier Modelle erledigen den Orientierungsschritt in **einem**
`kanban_show`-Aufruf. Allein deepseek-v4-flash gerät in die Schleife. Das
bleibt die Trennlinie.

### ⚠ Gegenbefund: GLM Flash ist als Orchestrator **schlechter** als deepseek

| Orchestrator-Modell | Karte angelegt |
|---|---|
| `deepseek-v4-flash` | ~10 von 12 |
| `z-ai/glm-5.3-flash` | **1 von 3** |

In beiden Aussetzern schrieb GLM Flash die Zusammenfassung sauber selbst —
nach 15 bzw. 10 Sekunden, also ohne je ein Werkzeug anzufassen.

**Damit ist die Empfehlung aus Abschnitt 13 widerlegt.** Dort stand, man solle
den Orchestrator „auf ein Modell stellen, das Rollenanweisungen zuverlässiger
befolgt". Der erste Gegentest zeigt das Gegenteil: das neue Modell ist
schlechter. Der Fehlermodus tritt bei **zwei verschiedenen Modellen** auf und
ist damit keine Modelleigenschaft, sondern strukturell — eine Rollenanweisung
in `SOUL.md` tritt gegen eine konkret formulierte Nutzeraufgabe an, und je
kleiner und eindeutiger die Aufgabe, desto häufiger gewinnt die Aufgabe.

Wer Verlässlichkeit braucht, löst das vermutlich nicht über die Modellwahl,
sondern über einen Weg, der gar keine Rollentreue voraussetzt — die
**Triage-Spalte** (Abschnitt 1–3): dort zerlegt der Decomposer jede Karte
zwangsläufig, ohne dass ein Modell sich für oder gegen das Orchestrieren
entscheiden könnte. Gemessen ist dieser Vergleich nicht.

---

## 15. Fünfter Modellvergleich: GPT 5.6 Terra

Nur der Worker geändert (`openai/gpt-5.6-terra` über OpenRouter);
`stall_guards: false` und `reasoning_effort: none` unverändert.

**Methode:** Der Orchestrator stand noch auf GLM 5.3 Flash, das zuletzt nur in
1 von 3 Läufen eine Karte anlegte (Abschnitt 14). Die drei Karten wurden
deshalb direkt per `hermes kanban create` mit dem **byte-identischen
Kartentext** aus Lauf 2 des vorigen Abschnitts angelegt. Diese Reihe ist damit
exakt mit den Nachmessungen 2b/3b vergleichbar und näherungsweise mit den
früheren Reihen, in denen der Orchestrator den Text jeweils neu formulierte.

| Lauf | Karte | Worker | Turns | `kanban_show` | `skill_view` | Artefakt |
|---|---|---|---|---|---|---|
| 1 | `t_74e10502` | 17 s | 1 | 1 | 1 | ja |
| 2 | `t_f19b08d3` | 20 s | 1 | 1 | 1 | ja |
| 3 | `t_a3c31b19` | 24 s | 1 | 1 | 1 | ja |

### Die Gesamtschau über fünf Worker-Modelle

| Worker-Modell | n | min | max | Median | Streuung | Turns | `kanban_show` | Artefakt |
|---|---|---|---|---|---|---|---|---|
| deepseek-v4-flash | 4 | 90 s | 469 s | 364 s | 5,2× | 10–36 | 4–30 | 2 von 4 |
| **Sonnet** (Claude Code) | 3 | 13 s | 17 s | **15 s** | 1,3× | **je 1** | je 1 | 3 von 3 |
| GLM 5.3 Flash | 3 | 48 s | 73 s | 52 s | 1,5× | 3–5 | je 1 | 3 von 3 |
| GLM 5.3 (voll) | 3 | 16 s | 35 s | 19 s | 2,2× | 3–5 | je 1 | 3 von 3 |
| **GPT 5.6 Terra** | 3 | 17 s | 24 s | **20 s** | 1,4× | **je 1** | je 1 | 3 von 3 |

Einzelwerte — deepseek: 15 / 26 / 10 / 36 · Sonnet: 1 / 1 / 1 ·
GLM Flash: 3 / 4 / 5 · GLM 5.3: 3 / 5 / 4 · GPT: 1 / 1 / 1.

### Wie GPT die eine Runde nutzt

Das Log zeigt einen einzigen Durchgang, in dem **alle vier Werkzeuge gebündelt**
laufen, bevor überhaupt Text entsteht:

```
kanban_show → skill_view (summarizer-Skill) → write_file → kanban_complete
```

GPT ist damit das **einzige Modell der Reihe, das den im Profil hinterlegten
`summarizer`-Skill überhaupt zieht** — in allen drei Läufen. Sonnet kommt auch
mit einem Turn aus, aber ohne diesen Schritt.

Damit erreichen zwei Modelle das Optimum von einem Durchgang, auf
unterschiedlichem Weg: Sonnet über kürzere Einzelschritte (Median 15 s), GPT
über einen breiteren Werkzeug-Batch inklusive Skill (20 s). Der Unterschied
zwischen beiden ist kleiner als die Streuung innerhalb der deepseek-Reihe.

### Ein Messfehler, der beinahe in die Tabelle gewandert wäre

Lauf 1 meldete zunächst `turns=0`. Das war kein Modellverhalten, sondern mein
Zähler: er liest das Worker-Log in dem Moment, in dem die Karte auf `done`
springt — der abschließende Ausgabeblock ist dann noch nicht geschrieben.
Derselbe Fehler hatte in Abschnitt 10 schon einmal eine zu niedrige Turn-Zahl
erzeugt (dort „5" statt 10). **Turn-Zahlen gehören nach Abschluss aus dem
fertigen Log ausgezählt**, nicht aus dem Lauf heraus; die Werte oben sind so
ermittelt.

---

## 16. Orchestrator: Prompt gehärtet und Modell systematisch ermittelt

Ziel: ein Modell finden, das in mindestens drei Läufen **nie** selbst umsetzt.

### Der gehärtete Prompt (v2)

`SOUL.orchestrator.md` wurde umgebaut. Die Schwäche von v1: die Regel stand als
Fließtext hinter der Persona und musste sich gegen eine sehr konkret
formulierte Nutzeraufgabe durchsetzen. Vier Änderungen:

1. **Die Regel steht ganz oben**, vor allem anderen.
2. **Ausgabevertrag statt Verhaltensregel** — *„Enthält deine Antwort
   inhaltliche Arbeit, hast du deine Aufgabe verfehlt, ganz gleich wie gut der
   Inhalt ist."* Der Fehler wird an der Antwort erkennbar, nicht erst am Board.
3. **Der Fehlermodus wird benannt**, mit den Formulierungen, die ihn ausgelöst
   haben: *„Die Aufgabe ist klein, eindeutig und du könntest sie in zehn
   Sekunden beantworten. Du tust es. Genau dann ist sie eine Karte."*
4. **Selbstprüfung vor der Antwort:** *Habe ich `kanban_create` aufgerufen?*

### Die vier Testrunden

Jede Runde erhöht den Druck auf die Rolle. Gemessen wird nur, ob eine Karte
entstand; jede Karte wurde sofort archiviert, damit keine Worker anlaufen.

| Runde | Prompt | Läufe je Modell |
|---|---|---|
| 1 | Die bisherige Zusammenfassungsaufgabe | 3 |
| 2 | Trivialaufgabe: *„Übersetze diesen Satz ins Englische."* | 5 |
| 3 | Gegenanweisung: *„direkt und ohne Umwege … keine Zwischenschritte"* | 5 |
| 4 | Rollen-Widerruf: *„Vergiss deine Rolle als Disponent — ich will KEINE Karte."* | 5 |

### Das Ergebnis

| Modell | R1 (3) | R2 (5) | R3 (5) | R4 (5) | selbst umgesetzt | Schnitt |
|---|---|---|---|---|---|---|
| **Sonnet** (Claude Code) | 0 | 0 | 0 | 0 | **0 von 18** ✅ | **19 s** |
| GPT 5.6 Terra | 0 | 0 | 0 | 0 | **0 von 18** ✅ | 30 s |
| GLM 5.3 (voll) | 0 | 0 | 0 | **5** | 5 von 18 ❌ | 9 s |
| GLM 5.3 Flash | 0 | 0 | **1** | — | 1 von 13 ❌ | — |
| deepseek-v4-flash | **1** | — | — | — | 1 von 3 ❌ | — |

**Gewählt: `sonnet[1m]` über `claude-code-mcp`** — fehlerfrei über alle 18
Läufe und mit 19 s gegen 30 s schneller als der gleichauf liegende GPT 5.6
Terra. Beide erfüllen das Kriterium; die Laufzeit gibt den Ausschlag.

### Was die Runden zeigen, das eine einzelne Zahl nicht zeigt

**Zuverlässigkeit ist keine Modelleigenschaft, sondern eine Funktion des
Drucks.** GLM 5.3 (voll) bestand 13 Läufe fehlerfrei — und brach dann in
Runde 4 auf **5 von 5** ein. Ein Test mit nur einer Prompt-Art hätte es als
zuverlässig ausgewiesen. GLM Flash fiel schon bei der milderen Gegenanweisung
in Runde 3.

**Die Prompt-Härtung wirkt messbar.** GLM 5.3 Flash lag mit v1 bei 1 von 3
erfolgreichen Läufen, mit v2 bei 3 von 3 (Runde 1) und 5 von 5 (Runde 2).
Behoben ist der Fehlermodus damit nicht — verschoben schon.

**Drei Läufe sind ein dünner Beleg.** Ein Modell mit 83 % Trefferquote
(deepseeks Quote unter v1) besteht eine 3er-Serie mit rund 58 %
Wahrscheinlichkeit. Das hier gesetzte Kriterium „nie bei mindestens drei
Läufen" ist erfüllbar, ohne verlässlich zu sein — deshalb die 18 Läufe.

> **Einordnung, die zur Fairness gehört:** Runde 4 ist ein Grenzfall. Ein
> Nutzer, der ausdrücklich schreibt „ich will KEINE Karte", äußert einen
> legitimen Wunsch; ihm nachzugeben ist nicht zwingend falsch. Für das hier
> gesetzte Kriterium zählt allein die Rollentreue, und danach ist GLM 5.3
> ausgeschieden. Wer den Orchestrator eher als kooperativen Assistenten
> möchte, liest dieselbe Zeile als Vorteil.

### Nebenbefund: `hermes profile list` zeigt keine Beschreibungen

Die Funktionsprobe des neuen Orchestrators meldete „Keine Beschreibungen
hinterlegt" — obwohl Schritt 6 sie erzeugt hat. `hermes profile list` hat
**keine Optionen** und gibt nur Name, Modell, Gateway, Alias aus. Abrufbar
sind die Beschreibungen einzeln über `hermes profile describe <name>`.

Die `SOUL.md` wies bis dahin auf `hermes profile list` — also auf einen
Befehl, der die Information gar nicht liefert; das Routing im Chat-Weg lief
damit faktisch über Namen statt Beschreibungen. Korrigiert: v2 enthält jetzt
eine Terminal-Zeile, die beides zusammenführt, und die Anweisung, bei
fehlenden Beschreibungen die dünne Grundlage in der Antwort zu benennen.
Nachgemessen — der Orchestrator gibt die Zuständigkeiten seither korrekt aus.

---

## 17. Aufräumen der deepseek-Tunings — und was dabei auffiel

`agent.stall_guards: false` und `agent.reasoning_effort: none` waren
Anpassungen für deepseek als Worker (Abschnitt 10). Seit `summarizer` auf
GPT 5.6 Terra läuft, haben sie dort keinen Zweck mehr. Beide Schlüssel wurden
per `config unset` **entfernt** — nicht auf Default-Werte gesetzt —, sodass
wieder die Vorgaben aus `config_defaults.py` greifen
(`stall_guards: True`, `reasoning_effort` ungesetzt). Der `agent:`-Block
ist damit ganz aus der Profil-Config verschwunden.

### ⚠ `hermes config set agent.reasoning_effort none` bewirkt das Gegenteil

Beim Nachmessen schrieb der Befehl **`null`** in die Datei, nicht die
Zeichenkette `none`. Das ist nicht dasselbe:

| Wert in der Datei | `parse_reasoning_effort` | Wirkung |
|---|---|---|
| `null` | `None` | Provider-Default — Reasoning **AN** |
| `none` (Zeichenkette) | `{'enabled': False}` | Reasoning **AUS** |

Ursache: `agent.reasoning_effort` steht **nicht** in `DEFAULT_CONFIG` (geprüft).
Der Setter meldet es als „nicht erkannten Schlüssel" und schiebt den Wert durch
eine generische Umwandlung, die `none` zu YAML-`null` macht. Bei
`auxiliary.*.reasoning_effort` passiert das nicht — dieser Schlüssel ist
bekannt und behält seinen Typ.

> **Die Warnung ist hier also echt.** Bei `platform_toolsets` (Abschnitt 8) war
> dieselbe Meldung ein Fehlalarm — dort wird der Schlüssel trotzdem gelesen.
> Bei `agent.reasoning_effort` zeigt sie ein reales Problem an. Die Meldung
> allein sagt nicht, welcher Fall vorliegt; das muss man nachmessen.

Sofort geprüft: der Decomposer-Fix aus Abschnitt 8
(`auxiliary.kanban_decomposer.reasoning_effort`) ist **intakt** — dort steht
die Zeichenkette `none` und löst zu `{'enabled': False}` auf.

Wer `agent.reasoning_effort` wirklich setzen will, schreibt den Wert direkt in
die `config.yaml` und prüft mit:

```python
resolve_reasoning_config(load_config())   # muss {'enabled': False} liefern
```

### Die Laufzeit-Frage ließ sich nicht beantworten

Nach dem Zurücksetzen lief die erste Kontrollreihe langsamer, und ich hatte
bereits „der Aufräumschritt kostet rund 45 % Laufzeit" notiert. Die
Isolationsreihe widerlegt das:

| Konfiguration | Läufe | Median | Spanne |
|---|---|---|---|
| A — `stall=false`, `reasoning=none` | 17 / 20 / 24 s | 20 s | 17–24 s |
| B — beide auf Default | 27 / 29 / 36 s | 29 s | 27–36 s |
| C — nur `reasoning=none` | 38 / 24 / 17 s | 24 s | **17–38 s** |

Reihe C überlappt **beide** anderen vollständig. Die Streuung innerhalb einer
Konfiguration ist damit so groß wie der vermeintliche Unterschied zwischen
Konfigurationen — bei n = 3 ist keine der drei voneinander zu trennen.

**Damit ist die 45-Prozent-Aussage zurückgenommen.** Sie beruhte auf zwei
nicht überlappenden 3er-Reihen, und genau dieser Trugschluss ist in diesem
Dokument schon zweimal vorgekommen (Abschnitt 10: `stall_guards` als
vermeintliche Ursache; Abschnitt 14: eine Empfehlung aus einem einzelnen
Lauf). Alle neun Läufe zusammen liegen zwischen 17 s und 38 s, ohne erkennbare
Gruppierung nach Konfiguration.

**Endzustand:** beide Schlüssel entfernt. Es gibt keinen gemessenen Grund,
sie zu behalten — aber auch keinen belegten Nachteil dadurch, sie entfernt zu
haben.

---

## 18. Ablageort der Ergebnisse: `workspace_kind=dir` statt „Arbeitsverzeichnis"

**Stand:** 15.09.2026 · Quellcode der installierten **v0.21.2**, Lauf real gemessen.

### Der Befund

Karte `t_075937a7` („Zusammenfassung DeepSeek-V4.1-Flash", Assignee `summarizer`)
lief sauber durch, aber die Ergebnisdatei lag **nicht** in
`~/hermes-working/summarizer`, sondern in
`~/.hermes/kanban/attachments/t_075937a7/`. Systemweite Suche: genau eine Kopie.

Ursache ist kein Fehler, sondern Absicht an zwei Stellen:

1. Der Worker läuft im **Workspace der Karte**, nicht im `terminal.cwd` des
   Profils. Der Dispatcher überschreibt `TERMINAL_CWD` explizit mit dem
   Workspace (`hermes_cli/kanban_db_dispatch.py:2239-2240`, Kommentar: *„the
   workspace is where the task's work actually happens"*). Das konfigurierte
   `terminal.cwd: ./hermes-working/summarizer` ist für Karten damit wirkungslos.
2. `workspace_kind` ist ohne Angabe `scratch` (`kanban_db.py:1271-1272`). Das
   Verzeichnis wird nach `done` gelöscht; `kanban_complete(artifacts=[…])`
   rettet die Dateien vorher in den Attachment-Store
   (`kanban_db.py:2745`, `kanban_db_workspace.py:113-118`).

Ein Profil hat für Karten also **kein** Arbeitsverzeichnis. Der bisherige
ABLIEFERUNG-Satz der `SOUL` („in eine Datei im Arbeitsverzeichnis") wurde vom
Modell trotzdem so gelesen — er ist wörtlich in den `body` von `t_075937a7`
gewandert.

### Die Änderung (SOUL v3)

Der ABLIEFERUNG-Block ist durch eine **Zwei-Zweig-Regel** ersetzt:

- **(a) Anfrage nennt einen Ablageort** → Orchestrator ermittelt den absoluten
  Pfad (`hermes -p <assignee> config get terminal.cwd`, relativ gegen `$HOME`)
  und legt die Karte mit `workspace_kind="dir"` + `workspace_path=<absolut>` an.
  Der `body` nennt den Pfad wörtlich.
- **(b) kein Ablageort genannt** → `scratch` wie bisher.

Zwang zum kollisionsfreien Dateinamen, weil `dir` laut Schema ein *„shared
directory"* ist: mehrere Karten auf dasselbe Verzeichnis teilen sich das cwd.

### Belegt (Lauf `t_582dbca2`, 15.09.2026)

Aufgabe per Chat („… => speichere im Arbeitsverzeichnis des ausgewählten
Profils"). Der Orchestrator legte an:

```
workspace_kind = dir
workspace_path = /Users/aknipschild/hermes-working/summarizer
```

Die Ergebnisdatei `zusammenfassung_ios-macos27-updates_2026-09-15.md` (3197 B)
lag nach ~60 s im Zielverzeichnis. Die Karte erreichte nach **278 s** den Status
`done` (`outcome = completed`, kein Fehler). **Damit ist der Kernpunkt belegt.**

### ⚠ Fehler in SOUL v3, korrigiert in v3.1

v3 wies den Worker an, zusätzlich `kanban_attach(path=<absoluter Pfad>)`
aufzurufen. **Das Werkzeug hat keinen `path`-Parameter** — es verlangt
`filename` + `content_base64` (`tools/kanban_tools_schemas.py:291-314`). Der
Worker von `t_582dbca2` lief in die Fehlermeldung
`content_base64 is not valid base64`, versuchte dann von Hand zu kodieren
(`base64 -i … | tr -d '\n'` → exit 126, danach `execute_code`) und hing dort
über zwei Minuten fest.

Der Worker hat sich am Ende selbst befreit — aber teuer: Von 278 s Gesamtlaufzeit
entfielen gut 200 s auf diesen Umweg (die Vergleichskarte `t_075937a7` mit
`scratch` brauchte 133 s). Und er hängte die Datei **zweimal** an:

| Anhang | Größe | Inhalt |
|---|---|---|
| `…2026-09-15.md` | 3215 B | ältere Fassung mit Dopplung („zustimmen müssen zustimmen müssen") |
| `…2026-09-15 (1).md` | 3197 B | byte-identisch mit der Datei im Zielverzeichnis |

Die erste, fehlerhafte Fassung bleibt dauerhaft an der Karte hängen. Der
Base64-Umweg kostet also nicht nur Zeit, er produziert auch falsche Artefakte.

v3.1 streicht den `kanban_attach`-Aufruf aus dem `dir`-Zweig: die Datei liegt
dort ohnehin dauerhaft, und `kanban_complete(artifacts=[…])` trägt den
absoluten Pfad in die `completed`-Ereignisnutzlast. Wer den Anhang zusätzlich
will, nimmt im Terminal `hermes kanban attach $HERMES_KANBAN_TASK <Pfad>`.

### Gegenprobe mit v3.1 (`t_41dc0447`, 15.09.2026)

Identischer Auftrag, identischer Wortlaut, identischer Artikel — geändert war
allein die `SOUL`-Fassung:

| | Lauf 1 · v3 (`t_582dbca2`) | Lauf 2 · v3.1 (`t_41dc0447`) |
|---|---|---|
| Laufzeit | 278 s | **100 s** |
| `kanban_attach`-Zeilen im Log | 8 | **0** |
| Base64-Zeilen im Log | 7 | **0** |
| Anhänge an der Karte | 2 (einer inhaltlich falsch) | 0 |
| Ergebnisdatei im Zielverzeichnis | ja (3197 B) | ja (2402 B) |
| Ausgang | `done` / `completed` | `done` / `completed` |

Der Base64-Umweg war damit tatsächlich die Ursache der Mehrlaufzeit: ohne ihn
liegt der Lauf bei 100 s und damit sogar unter der `scratch`-Vergleichskarte
`t_075937a7` (133 s). Die Karte wählte von sich aus einen anderen Dateinamen
(`zusammenfassung-ios-macos27-2026-09-15.md`), sodass die Datei aus Lauf 1
nicht überschrieben wurde — die Regel zum kollisionsfreien Namen greift.
`kanban_complete` trug den absoluten Pfad wie vorgesehen in
`metadata["artifacts"]` ein.

### v4: jede Karte bekommt einen Ablageort (15.09.2026)

v3.1 ließ Karten **ohne** genannten Zielpfad weiter auf `scratch` laufen. Karte
`t_6ff096d1` (Kommentar-Artikel, Text direkt im Chat) landete deshalb wieder im
Attachment-Store statt im Arbeitsverzeichnis. Gewünscht ist: **immer** ein
echtes Verzeichnis. v4 ersetzt die Zwei-Zweig-Regel durch eine Leiter, erste
zutreffende Stufe gewinnt:

| Stufe | Bedingung | `workspace_path` |
|---|---|---|
| 1 | Anfrage nennt einen Zielpfad | dieser Pfad (schlägt auch Stufe 2) |
| 2 | Anfrage übergibt eine Eingabedatei **mit Pfad** | Verzeichnis dieser Datei |
| 3 | sonst | `terminal.cwd` des **Assignees**, zu `$HOME/<Rest>` expandiert |
| 4 | Stufe 3 nicht auflösbar | `scratch` wie bisher |

Stufe 1 bis 3 setzen `workspace_kind="dir"`. Abgrenzung zu Stufe 2: ein im Chat
**eingefügter** Text ohne Pfad ist Stufe 3, nicht Stufe 2 — das war der Fall
`t_6ff096d1`.

### Belegt (drei Karten, 15.09.2026)

Geprüft wurde die Feldsetzung des Orchestrators, nicht erneut das Schreiben
durch den Worker — das ist über `t_582dbca2`/`t_41dc0447` bereits belegt.

| Karte | Auslöser | `workspace_kind` / `workspace_path` |
|---|---|---|
| `t_a43527d0` | Text im Chat, kein Pfad | `dir` / `~/hermes-working/summarizer` ✓ Stufe 3 |
| `t_8fac3da3` | Eingabedatei `…/eingabe-test/deichwartung.txt` | `dir` / `…/eingabe-test` ✓ Stufe 2 |
| `t_5c8c8940` | dieselbe Datei **plus** `=> speichere in …/orchestrator` | `dir` / `~/hermes-working/orchestrator` ✓ Stufe 1 schlägt Stufe 2 |

Alle drei liefen zusätzlich vollständig durch, jede legte ihre Datei im
erwarteten Verzeichnis ab:

| Karte | Datei |
|---|---|
| `t_a43527d0` | `~/hermes-working/summarizer/zusammenfassung-deichwartung-2026-09-15.md` (374 B) |
| `t_8fac3da3` | `…/eingabe-test/deichwartung-zusammenfassung-2026-09-15.txt` (347 B) — neben der Eingabedatei |
| `t_5c8c8940` | `~/hermes-working/orchestrator/deichwartung-zusammenfassung-2026-09-15.txt` (387 B) — **nicht** neben der Eingabedatei |

Damit ist auch die Vorrangregel praktisch belegt und nicht nur an der
Feldsetzung: dieselbe Eingabedatei, einmal mit und einmal ohne expliziten
Zielpfad, führt zu zwei verschiedenen Ablageorten. Alle drei endeten mit
`outcome = completed`, ohne Fehler.

Die Laufzeiten streuen dabei stark (`t_5c8c8940` 58 s gegen `t_8fac3da3` 235 s
bei identischer Eingabedatei und identischer Aufgabe). Bei n = 1 je Stufe ist
das **keine** belastbare Aussage über die Stufen — es ist vor allem eine
Erinnerung daran, dass die Laufzeitstreuung des Modells groß genug ist, um
Einzelvergleiche wertlos zu machen (vgl. Abschnitt 17).

### Preis der Umstellung

Da jetzt **jede** Karte `dir` ist, entsteht **kein `task_attachments`-Eintrag**
mehr (`_scratch_workspace()` liefert für `dir` `None`, siehe oben). Das Board
verliert damit die herunterladbaren Artefakte; die Provenienz bleibt über
`metadata["artifacts"]` und die `completed`-Ereignisnutzlast erhalten. Wer den
Anhang will, nimmt `hermes kanban attach $HERMES_KANBAN_TASK <Pfad>`.

Zweiter Nebeneffekt bei Stufe 2: `TERMINAL_CWD` zeigt auf das Verzeichnis der
Eingabedatei, und über `build_context_files_prompt` lädt der Worker eine dort
liegende `AGENTS.md` als Kontext mit.

### Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Ob der Zeitunterschied 278 s → 100 s allein am Base64-Umweg liegt | je ein Lauf pro Fassung; Modell-Laufzeitstreuung nicht ausgemittelt (vgl. Abschnitt 17 zum n = 3-Trugschluss) |
| `hermes kanban attach $HERMES_KANBAN_TASK <Pfad>` im Worker | CLI-Signatur gelesen (`kanban_parser.py:270-276`), nicht ausgeführt |
| Verhalten bei zwei gleichzeitigen `dir`-Karten auf dasselbe Verzeichnis | nicht provoziert; Kollisionsrisiko nur aus dem Schema abgeleitet |
| Stufe 4 der v4-Leiter (`scratch`-Fallback) | **nicht testbar in dieser Installation** — alle vier Profile haben ein explizites `terminal.cwd`, die Stufe wird nie erreicht |
| Ob Stufe 2 die `AGENTS.md` neben der Eingabedatei wirklich lädt | aus `kanban_db_dispatch.py:2233-2240` abgeleitet, nicht provoziert |
| Ob `terminal.cwd` auf anderen Wegen (Cron, Gateway) doch greift | nur der Dispatcher-Pfad gelesen |
