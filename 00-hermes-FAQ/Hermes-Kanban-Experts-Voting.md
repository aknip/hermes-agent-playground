# Experten-Voting per Kanban: eine Beurteilung von mehreren Bots einholen

**Stand:** 14.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11,
upstream `b6b53c69`)** in `~/.hermes/hermes-agent/` — nicht an der im Repo
festgeschriebenen v0.20.0. Reine Code-Analyse, **kein protokollierter Lauf**.
Hintergrund: [Hermes-Kanban-vs-Bot-Collaboration.md](Hermes-Kanban-vs-Bot-Collaboration.md).

**Ausgangsfrage:** Ich möchte aus einem Kanban-Lauf heraus eine Sache von einer
Gruppe spezialisierter Bots beurteilen lassen (Gutachten, Abstimmung, Review aus
mehreren Blickwinkeln). Bot-Gruppen-Chats sind dafür nicht erreichbar — was ist
der kanban-native Weg?

---

## Kurzantwort

**Fan-out auf Experten-Karten, Fan-in in eine Synthese-Karte.** Ein Worker legt
per `kanban_create` je eine Karte pro Experten-Profil an und eine Synthese-Karte
mit allen Experten-Karten als `parents`. Die Synthese-Karte wartet in `todo`,
bis alle Eltern `done` sind, wird dann automatisch `ready`, und ihr Worker
findet die Gutachten fertig aufbereitet unter **„## Parent task results"** in
seinem Kontext. Kein Chat, kein RPC, kein Desktop — nur Karten.

Genau dieses Muster fährt Story 6 (`planner` → vier `researcher` → `analyst`)
bereits über die CLI; hier geht es um die Variante, die ein **Worker selbst**
aus einem Lauf heraus startet.

## Die drei Bausteine im Code

| Baustein | Was er tut | Quelle |
|---|---|---|
| `kanban_create` mit `assignee` + `parents` | Kind-Karte anlegen; „stays in 'todo' until every parent reaches 'done'; then it auto-promotes to 'ready'" | `tools/kanban_tools_schemas.py:352-420` |
| Re-Gate `todo`/`ready` | `ready` genau dann, wenn jeder Parent terminal ist | `hermes_cli/kanban_db.py:3259-3262` |
| `## Parent task results` im Worker-Kontext | Für jeden `done`-Parent: `summary` + `metadata` des jüngsten `completed`-Runs, mit relativem Alter | `hermes_cli/kanban_db.py:3731-3770` |

Die Übergabe läuft über `kanban_complete` (`kanban_tools_schemas.py:89-130`):
`summary` ist der menschenlesbare Ein- bis Dreizeiler, `metadata` ein freies
Dict für „machine-readable facts … Surfaced to downstream workers alongside
summary". **Das Votum gehört in `metadata`**, nicht in einen langen Kommentar:
Der Kontext kappt lange Texte (`_ctx_cap`), Kommentare erscheinen nur über
`kanban_show`, aber die Parent-Handoffs kommen automatisch.

## Rezept

### 1. Experten-Profile anlegen

Ein Profil pro Blickwinkel, z. B. `expert-security`, `expert-cost`,
`expert-ux`, plus `synthesizer`. Jedes Profil braucht — wie in allen Stories —
eine `~/.hermes/profiles/<name>/config.yaml` mit den vier Modell-Schlüsseln,
sonst ist es nicht dispatchbar (siehe `CLAUDE.md`, Story-Invarianten).

Die Rolle steht in `SOUL.md` bzw. der Profil-Beschreibung. Wichtig ist der
**Antwortvertrag**, den jeder Experte in `kanban_complete` einhalten soll:

```
summary:  1–3 Sätze Begründung
metadata: {"vote": "approve" | "reject" | "abstain",
           "confidence": 0.0–1.0,
           "risks": ["…"], "conditions": ["…"]}
```

### 2. Der Aufrufer fächert auf

Der Worker, der die Beurteilung braucht (oder der Mensch per CLI), legt die
Karten an. Als Tool-Aufrufe aus einem Worker heraus:

```
kanban_create(title="Gutachten Security: <Sache>", assignee="expert-security",
              body="<Sache, Kontext, Bewertungsfrage, Antwortvertrag>",
              idempotency_key="vote-<sache>-security")
kanban_create(title="Gutachten Kosten: <Sache>",   assignee="expert-cost", …)
kanban_create(title="Gutachten UX: <Sache>",       assignee="expert-ux", …)

kanban_create(title="Synthese: <Sache>", assignee="synthesizer",
              parents=[<id-security>, <id-cost>, <id-ux>],
              body="Fasse die Gutachten unter '## Parent task results' zu
                    einem Gesamturteil zusammen: Mehrheit, Konfidenz,
                    offene Risiken. Bei Uneinigkeit: kanban_block.")
```

Anschließend schließt der Aufrufer seine eigene Karte mit
`kanban_complete(created_cards=[…])` — der Kernel prüft die IDs
(`kanban_tools_schemas.py:126-135`).

Dieselbe Struktur per CLI (`hermes_cli/kanban_parser.py:150-152`, `--parent`
ist wiederholbar):

```bash
S=$(hermes kanban --board <slug> create "Gutachten Security: …" --assignee expert-security --body "…")
C=$(hermes kanban --board <slug> create "Gutachten Kosten: …"   --assignee expert-cost     --body "…")
U=$(hermes kanban --board <slug> create "Gutachten UX: …"       --assignee expert-ux       --body "…")
hermes kanban --board <slug> create "Synthese: …" --assignee synthesizer \
    --parent "$S" --parent "$C" --parent "$U" --body "…"
```

(Story 6, `create-tasks.sh:28-31` und `:92-93`, zeigt den Wrapper dafür.)

### 3. Die Experten arbeiten parallel

Der Dispatcher startet alle drei Karten beim nächsten Tick, jede in ihrem
Profil, unabhängig voneinander. Die Experten sehen nur ihre Karte — kein
Gruppen-Chat, keine gegenseitige Beeinflussung. Das ist für ein Voting eher ein
Vorteil (unabhängige Stimmen) als ein Nachteil.

### 4. Die Synthese liest die Stimmen

Sobald alle drei `done` sind, wird die Synthese-Karte `ready`. Ihr Worker
bekommt im Kontext:

```
## Parent task results
### <id-security> (completed 4m ago)
<summary des Experten>
metadata: vote=reject confidence=0.7 risks=[…]
### <id-cost> …
```

Er zählt aus, gewichtet nach `confidence`, schreibt das Gesamturteil per
`kanban_complete(summary=…, metadata={"verdict": …, "votes": {…}})`.

### 5. Optional: menschliches Tor bei Uneinigkeit

Soll ein Mensch bei Patt oder niedriger Konfidenz entscheiden, blockiert der
Synthesizer: `kanban_block(reason="2:1 bei Konfidenz < 0.5 — bitte
entscheiden", kind="vote-tie")`. Der Grund ist bei `block` positional,
`--reason` gibt es nur bei `unblock`; `BLOCK_RECURRENCE_LIMIT = 2` gilt pro
`kind` (siehe `CLAUDE.md`, v0.20.0-Eigenheiten). Story 10 zeigt so ein Tor im
Betrieb.

## Varianten

- **Zweite Runde („Experten reagieren aufeinander")**: Der Synthesizer legt
  pro Experte eine Folgekarte an, deren `body` die anderen Gutachten enthält,
  plus eine zweite Synthese-Karte mit diesen als `parents`. Das ist ein
  serieller Durchgang wie im Gruppen-Chat — aber explizit, nachvollziehbar und
  ohne Rundenlimit.
- **Gleiches Profil, verschiedene Modelle**: `kanban_create(model=…, provider=…)`
  pinnt den Worker auf ein anderes Modell (`kanban_tools_schemas.py:471-485`).
  So stimmt ein Profil-Prompt mit drei Modellen ab — nützlich für
  Modell-Ensembles statt Rollen-Ensembles.
- **Blindes Voting**: Kein Experte sieht die anderen Karten, solange er sie
  nicht per `kanban_list` sucht. Wer das ausschließen will, nennt die anderen
  Karten im `body` nicht und vergibt neutrale Titel.
- **Laufzeitgrenze**: `max_runtime_seconds` pro Experten-Karte, damit ein
  hängender Gutachter die Synthese nicht ewig blockiert
  (`kanban_tools_schemas.py:422-426`).

## Grenzen

- Die Handoffs sind **Momentaufnahmen** beim Abschluss des Parents — der
  Kontext sagt das dem Synthesizer selbst („point-in-time snapshots, not live
  state", `kanban_db.py:3749-3755`).
- Nur der **jüngste `completed`-Run** eines Parents zählt. Wer eine Karte
  wiederholt, überschreibt damit die Stimme.
- `metadata` wird in eine Zeile gerendert (`_ctx_metadata_line`); tiefe
  Strukturen sind dort schlecht lesbar. Flach halten.
- Kein Tempo-Vorteil gegenüber dem Gruppen-Chat bei nur einem Experten — das
  Muster lohnt sich ab zwei unabhängigen Stimmen.

## Was ich **nicht** verifiziert habe

| Aussage | Status |
|---|---|
| Das Rezept läuft mit drei Experten-Profilen durch | nicht gelaufen; Story 6 belegt das Fan-in-Muster, nicht den Antwortvertrag |
| Wie `_ctx_metadata_line` verschachtelte `metadata` genau darstellt | Funktion gesehen, Ausgabe nicht angeschaut |
| `model`/`provider`-Pin in `kanban_create` auf v0.20.0 | nur v0.21.2-Schema gelesen |

## Quellen

- Lokaler Quelltext: `tools/kanban_tools_schemas.py`, `hermes_cli/kanban_db.py`,
  `hermes_cli/kanban_parser.py`
- `02-hermes-agent-kanban-tutorials/Story 6 - Research Triage/create-tasks.sh`
- [Kanban – Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)
