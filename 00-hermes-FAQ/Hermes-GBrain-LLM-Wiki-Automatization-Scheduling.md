# GBrain-Wiki: läuft da etwas von selbst?

**Stand:** 17.09.2026 · Reine Bestandsaufnahme am laufenden System, unmittelbar
nach dem ersten Importlauf. Alle Befunde sind Ausgaben echter Kommandos, keine
Code-Lektüre.

**Ausgangsfrage:** Laufen für das GBrain-Wiki
(`~/github/hermes-llm-wiki-gbrain`, Hermes-Profil `wiki-llm`) gerade Cronjobs
oder anders getriggerte regelmäßige Programme — und sind welche geplant?

---

## Die Antwort

**Nein — es läuft nichts, und eingerichtet ist auch nichts.**

Das Wiki ist ein rein manuell gepflegter Bestand. Es ändert sich nur, wenn
`import` / `embed` / `extract` angestoßen werden oder der Agent im Chat über
`capture` / `remember` etwas hineinschreibt.

## Sieben geprüfte Stellen

| geprüft | Kommando | Befund |
|---|---|---|
| Benutzer-Crontab | `crontab -l` | `no crontab for aknipschild` |
| LaunchAgents / LaunchDaemons | `grep -rl -i gbrain ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons` | 9 Agents vorhanden (Hermes-Gateway, yabai, ownCloud, Splashtop …), **keiner** nennt gbrain |
| GBrain-Autopilot | `gbrain autopilot --status` | `Autopilot: not installed.` |
| Minion-Queue | `gbrain jobs list` | `No jobs found` — keine Worker, keine Wartenden |
| Hermes-Cron je Profil | `hermes -p <wiki-llm\|default\|developer> cron list` | überall `No scheduled jobs.` |
| Claude-Code-Cronjobs | `CronList` | `No scheduled jobs.` |
| GBrain-Hooks in Claude-Settings | `grep -c -i gbrain <settings>.json` | **0 Treffer** in allen vier vorhandenen Dateien |

Ergänzend: `ps aux | grep hermes-llm-wiki` liefert nichts, `gbrain status` meldet
`Last full cycle: never run` und `Locks: (none active)`.

## Zwei Details, die dazugehören

### Der Launcher schaltet Startup-Hooks hart ab

`~/github/hermes-llm-wiki-gbrain/bin/gbrain` setzt in Zeile 31
`GBRAIN_SKIP_STARTUP_HOOKS=1`. GBrain führt also auch beim gewöhnlichen Aufruf
nichts Angehängtes aus. Das war beim Bau der self-contained Lösung Absicht
(siehe Kapitel 3 der Installations-FAQ) und wirkt hier als zusätzlicher Riegel.

Dass in den Claude-Settings keine gbrain-Hooks stehen, hat denselben Grund:
`gbrain bootstrap` hätte sie nach `.claude/settings.local.json` verdrahtet —
dieser Schritt ist nie gelaufen.

### `self_upgrade` steht auf `notify`

`.gbrain/config.json` enthält `"self_upgrade": {"mode": "notify",
"mode_prompted": true}`. Das ist die harmlose Stufe: GBrain **meldet** eine
verfügbare neue Version, installiert sie nicht. Es ist die einzige Einstellung
im Brain, die überhaupt etwas von selbst auslösen würde.

## Was es gäbe, wenn man es wollte

Schritt 8 von `INSTALL_FOR_AGENTS.md` sieht regelmäßige Läufe vor. Keiner davon
ist eingerichtet:

- **`gbrain autopilot --install`** — Hintergrunddaemon für nächtliche
  Anreicherung, Dream-Phase, Aufräumen. Er legt einen **LaunchAgent** an, also
  etwas außerhalb des Zielpfads. Das weicht die self-contained Eigenschaft aus
  Kapitel 3 der Installations-FAQ auf — dort sind es bislang genau drei Zeiger
  nach außen, dieser wäre ein vierter.
- **Cron für `sync`, `dream`, `doctor`** als klassische Einträge.
- **`gbrain sync --watch`** — Live-Abgleich eines Git-Repos. Für dieses Wiki
  ohnehin nicht passend: die Importquelle
  `~/github/hermes-llm-wiki-notes-staging` ist kein Git-Repo, und die Quelle
  `default` trägt kein `local_path`. — **Der zweite Halbsatz stimmt nicht
  mehr**, siehe Befund 2 im Nachtrag: `sources list` zeigt heute ein
  `local_path` auf `memory/`.

### Eine Einschätzung zum Zeitpunkt

Eine nächtliche Automatik auf einem Brain, dessen **Linkgraph noch leer ist**
(0 Links aus 2951 Kandidaten, siehe Abschnitt 7 der Installations-FAQ), bringt
wenig: Dream und Anreicherung arbeiten über Kanten, die es nicht gibt. Sinnvoll
wird der Autopilot erst, wenn die Frage der Linksyntax entschieden ist.

> **Korrektur vom 17.09.2026.** Hier stand ursprünglich, eine solche Automatik
> „würde vor allem Modellkosten erzeugen". Der erste echte Lauf widerlegt das
> (siehe Nachtrag unten): Die teuren Phasen laufen mangels Konfiguration gar
> nicht erst an. Das Urteil „verfrüht" bleibt, die Begründung war falsch — es
> ist nicht Verschwendung, sondern Leerlauf.

## Nachtrag 17.09.2026: der erste Dream-Lauf

Real gemessen, bei geschlossener Hermes-Session — der PGLite-Lock muss frei
sein, denn `dream` delegiert **nicht** an einen laufenden `serve` (anders als
`sync` und `sweep`):

```bash
gbrain dream --dir ~/github/hermes-llm-wiki-gbrain --phase lint --phase backlinks --json
```

| Kennzahl | Wert |
|---|---|
| Laufzeit | `duration_ms: 6328`, Wanduhr 7,5 s |
| Modellkosten | **keine** — beide Phasen sind deterministisch |
| `brain_dir` | `/Users/aknipschild/github/hermes-llm-wiki-gbrain` — vom `--dir` erzwungen, **nicht** der Wert, den GBrain selbst gewählt hätte (Befund 2) |
| `lint` | `warn` — 690 Seiten gescannt, 1692 Issues, **3 gefixt**, 1689 offen |
| `backlinks` | `ok` — 0 Gaps, `mode: audit-only` |

### Vier Befunde

**1. Ein nackter `dream` läuft heute weitgehend leer — und kostet nichts.**

Der Grund ist nicht der leere Linkgraph, sondern fehlende Konfiguration. Die
synthesize-Phase, das eigentliche Herz des Zyklus, endet ohne
`dream.synthesize.session_corpus_dir` mit `skipped('not_configured')`
(`src/core/cycle/synthesize.ts:423-425`); `enabled` ist genau dann `true`, wenn
dieser Pfad gesetzt ist (`:1502-1507`). Es existiert bislang auch kein
Transkript-Korpus: `transcript-discovery.ts` erwartet `.txt`-Dateien ab 2000
Zeichen mit `YYYY-MM-DD`-Dateinamen.

Was dagegen **schon passt**: `agent.use_gateway_loop` ist gesetzt. Ohne das
würden die Synthese-Subagenten bei nicht-anthropischem Chat-Modell und
fehlendem `ANTHROPIC_API_KEY` bereits bei der Job-Abgabe scheitern
(`src/core/minions/handlers/subagent.ts:444-457`).

**2. `--dir` auf das Repo-Root ist zu grob — und war überflüssig.**

Ohne `--dir` löst `dream` den Pfad selbst auf, und zwar besser. `sources list`
zeigt, dass die Quelle `default` sehr wohl ein `local_path` trägt:

```
default   federated   1550 pages   never synced
          /Users/aknipschild/github/hermes-llm-wiki-gbrain/memory
```

`resolveBrainDir` (`src/commands/dream.ts:332-372`) sucht in der Reihenfolge
`--dir` → `local_path` der Quelle → `sync.repo_path` → `null`. Stufe zwei
greift also, und `--dir` auf das Repo-Root **überschreibt** sie. Gegenprobe
ohne das Flag:

```
brain_dir: /Users/aknipschild/github/hermes-llm-wiki-gbrain/memory
lint:      ok — 3 Seiten, 0 Issues (228 ms)
```

690 gescannte Seiten statt drei waren eine Folge des Flags, nicht des Systems:
`collectPages` (`src/commands/lint.ts:444-462`) läuft alles unterhalb des
Zielpfads ab und schließt nur `node_modules` aus:

| Verzeichnis | `.md`-Dateien | was das ist |
|---|---:|---|
| `runtime/` | 628 | der GBrain-Checkout (gitignored, fremder Code) |
| `skills/` | 82 | scaffoldete Skill-Bundles |
| `memory/` | **3** | der Wiki-Inhalt auf Platte — nur 3 von 1550 Seiten, siehe Befund 4 |

Die 1689 verbleibenden Issues liegen damit **vollständig außerhalb** des
Wikis — Lint-Beschwerden über fremde Doku, kein Befund. Die drei Wiki-Dateien
auf Platte sind sauber.

**3. `lint` schreibt im Zyklus — es ist kein Audit.**

`runPhaseLint` ruft `runLintCore({ target: brainDir, fix: true, ... })`
(`src/core/cycle.ts:1056`), ohne `exclude`. Der Zyklus kann den Pfad also
nicht einschränken, und `--phase lint` ist nicht read-only. Die drei Fixes
trafen exakt die drei Dateien in `memory/` (mtime `20:59:23` = der Lauf).

Was geändert wurde, per Vergleich gegen den älteren DB-Stand
(`gbrain get 09-software/tokscale`): ein zusätzliches `created:` im
Frontmatter, zeichengleich mit dem schon vorhandenen `ingested_at`. Das ist
`promoteCreatedFromCapture` (`src/commands/lint.ts:346-349`, Issue #3958) —
fehlendes `created` wird aus einem vorhandenen Capture-Zeitstempel befördert.
Additiv und verlustfrei; ein Fix pro Datei bei drei Dateien.

**4. Der wichtigste Nebenbefund: `memory/` ist derzeit nicht der Master.**

Die Quelle meldet **1550 Seiten**, im aufgelösten Verzeichnis liegen **3
Dateien**:

```
gbrain list --limit 5000 | wc -l          → 1550
find .../memory -name '*.md' | wc -l      →    3
```

Der Importlauf kam aus `~/github/hermes-llm-wiki-notes-staging`; die Seiten
landeten in der Datenbank, nicht unter `local_path` — daher auch das `never
synced` in `sources list`. 1547 Seiten existieren damit **ausschließlich** in
`.gbrain/brain.pglite`, und dieses Verzeichnis ist per `.gitignore` von der
Versionierung ausgenommen.

Das widerspricht dem README des Brain-Repos, das `memory/` als Master führt.
Für den *Aufbau* stimmt das weiter; für den *heutigen Zustand* nicht. Zwei
Folgen:

- Die Dateisystem-Phasen des Zyklus (`lint`, `backlinks`, `sync`, `extract`)
  sehen 3 von 1550 Seiten. Das ist der eigentliche Grund, warum der Lauf oben
  so wenig zu tun hatte — nicht der leere Linkgraph.
- `.gbrain/backup-status.json` meldet zwar `"pages_at_risk": 0`, trägt aber
  `"checked_at": "2026-09-16T19:23"` — **vor** dem Import vom 17.09. Die Null
  bezieht sich auf einen leeren Brain und sagt über den heutigen Stand nichts.

Der Weg zurück in den Dateibestand wäre `gbrain export --dir`. Er ist nicht
gelaufen; ob er den `memory/`-Baum so erzeugt, wie das README ihn meint, ist
ungeprüft.

### Folge für die Konfiguration

`sync.repo_path` wurde anschließend auf das Repo-Root gesetzt:

```bash
gbrain config set sync.repo_path ~/github/hermes-llm-wiki-gbrain
```

Wirkung auf `dream`: **keine.** Der Schlüssel ist Stufe drei der Auflösung, und
Stufe zwei — das `local_path` der Quelle `default` — greift vorher. Ein nackter
`dream` zeigt weiterhin auf `memory/`, nachgemessen oben. Der Schlüssel bleibt
als Rückfallebene liegen, falls die Quelle ihr `local_path` je verliert; für
`sync` ist das Repo-Root der richtige Wert, weil nur dort ein Git-Repo liegt.

**Die praktische Regel ist damit umgekehrt zur ursprünglichen Empfehlung:**
`--dir` weglassen. Das Flag überschreibt die korrekte Auflösung und lenkt
`lint --fix` auf den gitignored `runtime/`-Checkout.

```bash
gbrain dream --phase lint --phase backlinks --json
```

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Ob einer der neun vorhandenen LaunchAgents indirekt GBrain anfasst | geprüft wurde auf den Namen `gbrain` in den Plist-Dateien; was die referenzierten Programme intern tun, ist ungelesen — bei `ai.hermes.gateway*.plist` naheliegend zu prüfen, falls es je Auffälligkeiten gibt |
| Ob `hermes cron list` wirklich alle Auslöser eines Profils zeigt | nur die Kommandoausgabe, keine Code-Lektüre |
| Ob die Hermes-Desktop-App eigene Zeitpläne außerhalb der Profile führt | die App lief während der Prüfung nicht |
| Was `gbrain autopilot --install` konkret in den LaunchAgent schreibt | nie ausgeführt |
| Ob `self_upgrade: notify` beim Start tatsächlich nach außen telefoniert | plausibel, aber nicht beobachtet — der Launcher setzt `GBRAIN_SKIP_STARTUP_HOOKS=1`, was es vermutlich unterbindet |
| Ob der aufgelöste Pfad `memory/` auch für `sync`, `extract` und `synthesize` trägt | verifiziert ist er nur für `lint` und `backlinks`; `resolveBrainDir` liefert **einen** Pfad für alle Dateisystem-Phasen, und ein reines Inhaltsverzeichnis ist kein Git-Repo — `sync` meldet für die Quelle bis heute `never synced` |
| Seit wann die Quelle `default` ihr `local_path` trägt | die frühere Bestandsaufnahme oben notiert das Gegenteil („die Quelle `default` trägt kein `local_path`"). Ob das damals falsch beobachtet wurde oder der Wert zwischenzeitlich gesetzt wurde, ist nicht rekonstruiert — `sources list` zeigt ihn heute |
| Ob außer `created:` noch etwas an den drei `memory/`-Dateien geändert wurde | `memory/` ist untracked, ein Vorher-Stand existiert nicht im Git; verglichen wurde gegen den älteren DB-Stand, und `gbrain get` rendert die Provenienzfelder nicht mit. `fixed: 3` bei drei Dateien spricht für genau einen Fix je Datei |
| Ob `gbrain export --dir` die 1550 DB-Seiten als `memory/`-Baum herstellt | nie ausgeführt; belegt ist nur die Diskrepanz 1550 ↔ 3, nicht der Weg zurück |
| Ob die 1689 verbleibenden lint-Issues wirklich alle harmlos sind | nur aggregiert gezählt, nicht einzeln gelesen — belegt ist allein, dass keines davon in `memory/` liegt |

---

**Verwandt:** [Hermes-GBrain-LLM-Wiki-Installation.md](Hermes-GBrain-LLM-Wiki-Installation.md)
— Installation, Self-Containment, Importlauf und Linkgraph-Befund.
