# ESF — Umsetzungsplan Phase 3 (Dauerbetrieb unter einem CEO-Profil)

Fortschreibung von Kapitel 12 des Konzepts (`KONZEPT.html`) nach den zwei
Sprints der Phase 2 (`RUN-PROTOKOLL.md`, `beispiel-lauf-2/`). Stand 18.08.2026:
Die ESF ist aus der Hermes-Instanz **deinstalliert**, das Ziel-Repo
`../04-hermes-agent-software-company-test-kaneo` ist auf den Ausgangszustand
zurückgesetzt. Alles Folgende ist gebaut und modellfrei selbstgetestet, aber
**nie gegen ein laufendes Board gefahren** — der Lauf ist der Nachweis, nicht
dieser Plan.

## Warum Phase 3 neu geschnitten wird

Kapitel 12 verlangte für Phase 3 „zwei Wochen ohne manuellen Eingriff außer
Gate-Antworten". Die Messung der Phase 2 (an `beispiel-lauf-2/board.json`
gezählt, nicht geschätzt) zeigt, dass dieses Kriterium den falschen Engpass
adressiert. Der Mensch in der CEO-Rolle hat dort drei verschiedene Arten von
Arbeit geleistet:

| Arbeit | Anteil (gemessen) | Wohin sie in Phase 3 gehört |
|--------|-------------------|------------------------------|
| **Entscheiden an Gates** | 2 von 9 Unblocks trugen ein Gate-Verb | → `esf-ceo`, das zwölfte Profil |
| **Betriebsrettung** (Netzausfall-Unblocks, Parkungen, `reclaim`, Worktree-Reparatur) | 7 von 9 Unblocks | → Code: `scripts/eskalation.sh` |
| **Planung/Kartentexte im Lauf** | 13 von 33 Karten ad hoc, 685 von 1131 min | → `esf-chief-of-staff` + Kartentext-Riegel (Stufe A, offen) |

Ein CEO-Agent, der die bisherige CEO-Rolle 1:1 erbt, erbt zu ~80 % Arbeit,
die kein Entscheiden ist — und für die ein Modell das falsche Werkzeug ist.
Deshalb drei Stufen mit je eigenem deterministischen Nachweis.

## Das Zielbild: drei Autoritätsebenen

    Supervisor (Mensch)   Quartals-/Roadmap-Gate · Einspruch bei Irreversibel · Notfall
            │  (gate.sh, wie bisher — Roadmap ist nicht delegierbar)
    esf-ceo (Profil #12)  Release-Gate · Budget-Gate · Irreversibel-Gate
            │  (Entscheidungsdokument → ceo-tick.sh validiert → gate.sh führt aus)
    Code                  Riegel · Checks · Betriebsrettung · Eskalationsleiter

- **Supervisor**: sieht die Organisation planmäßig am Roadmap-Gate (das bleibt
  wörtlich „nicht delegierbar") und sonst nur, wenn die Eskalationsleiter ihn
  ruft. Sein Werkzeug bleibt `gate.sh`.
- **`esf-ceo`**: entscheidet die inhaltsgetriebenen Gates. Höchstes
  Modell-Tier (`ESF_MODELL_CEO`, Default = hoch) und ein eigener
  OpenRouter-Key — damit sitzt der teuerste Kopf erstmals **innerhalb** der
  Kostenrechnung. Die Messung der Phase 2 („9,35 USD") war ohne die
  Führungsarbeit; ab jetzt wird sie mitgezählt.
- **Code**: alles Deterministische — unverändert der Riegel und die Checks,
  neu die Betriebsrettung und die Notfall-Definition.

## Die Mechanik — und warum die Governance-Invariante überlebt

„**Kein Agent ruft je `kanban_unblock`**" war die zentrale Invariante der
Phasen 0–2, und der Lauf hat zweimal belegt, dass ein konkreter Kartentext
eine SOUL schlägt. Ein CEO-Profil, das Gates direkt öffnet, wäre über den
Text der Gate-Vorlage manipulierbar (die Vorlage schreibt ein Worker).
Der Weg, der die Invariante wörtlich intakt lässt:

1. **Die Gate-Karte blockiert sich selbst** — unverändert; das ist der einzige
   Mechanismus in v0.20.0, der den Dispatcher nachweislich anhält.
2. **`scripts/ceo-tick.sh`** (Cron, stündlich) findet blockierte Gate-Karten
   und legt je Gate **eine eigene Entscheidungskarte** für `esf-ceo` an
   (Idempotenzschlüssel `ceo-entscheid-<gate-id>`). „Jede Entscheidung
   bekommt ihre eigene Karte" gilt weiter — `BLOCK_RECURRENCE_LIMIT = 2`
   erzwingt es. Die Entscheidungskarte ist **kein Kind** der Gate-Karte: ein
   Kind einer blockierten Karte startet nie.
3. **`esf-ceo` schreibt ein Entscheidungsdokument** in den Vault:
   `reports/ceo-entscheid-<gate-id>.html` mit den Metas `esf-gate` und
   `esf-verb` und vier Pflichtabschnitten (`#vorlage`, `#messung`,
   `#begruendung`, `#antwort`). Pflicht im `#messung`-Abschnitt: die
   **selbst ausgeführten** deterministischen Checks (`check-release.sh` usw.)
   mit Befehl und Ausgabe in einem `<pre>`-Block. Der wertvollste Teil der
   bisherigen CEO-Arbeit war das unabhängige Nachmessen — hier wird es
   Formpflicht. Gate-Vorlagen sind Worker-Text und gelten als Behauptung,
   nicht als Beleg.
4. **`scripts/ceo-lint.py` validiert deterministisch** (Metas, Verb passt zur
   Gate-Art, Pflichtabschnitte, Messbeleg, Begründung bei modify/shelve/cut/
   stop/escalate) — dieselbe Bauart wie `vault-lint.py`, mit Fixture-Selbsttest
   in `seed/ceo-selbsttest/`.
5. **Code öffnet das Gate**: `ceo-tick.sh` ruft `gate.sh <verb> <id> "…" --von
   esf-ceo`. Der Unblock-Kommentar trägt `[von:esf-ceo]` plus den Verweis auf
   das Dokument. `monitor.sh` prüft weiter jedes `unblocked`-Ereignis auf das
   Verb-Muster; die neue Invariante lautet: *kein Agent ruft `kanban_unblock` —
   der CEO entscheidet, Code validiert und führt aus.*

### Das neue Verb: `escalate`

`esf-ceo` darf nicht raten. Reicht die Beleglage nicht oder liegt die
Entscheidung außerhalb des Mandats, trägt das Dokument `esf-verb: escalate` —
dann öffnet **niemand** das Gate; `ceo-tick.sh` journaliert die Eskalation und
der Supervisor antwortet über `gate.sh` wie bisher. `escalate` ist bewusst
kein `gate.sh`-Verb: Es öffnet nichts.

### Einspruchsfrist für Irreversibel-Gates

Bei `GATE Irreversibel` führt der Executor eine **gültig validierte**
CEO-Entscheidung erst nach `irreversibel_einspruch_stunden` (cadence.yaml,
Default 24) aus. Der Dispatcher steht in dieser Zeit ohnehin — die Frist
kostet in einer Cron-Organisation fast nichts. Antwortet der Supervisor
innerhalb der Frist selbst über `gate.sh`, ist das Gate nicht mehr blockiert
und die CEO-Entscheidung wird als `ueberholt` journaliert. Das erste
Irreversibel-Gate der Phase 2 war eine Datenmigration mit Betriebsausfall als
Schlimmstfall — das ist der Preis, den die Frist wert ist.

### Die Notfall-Leiter (deterministisch, `scripts/eskalation.sh`)

„Nur im absoluten Notfall" trägt nur, wenn **Code** entscheidet, was ein
Notfall ist — sonst entscheidet das Modell über seine eigene Entmündigung.

| Stufe | Auslöser (am Board erkennbar) | Reaktion |
|-------|-------------------------------|----------|
| Code repariert | blockierte Nicht-Gate-Karte, Blockgrund passt auf ein bekanntes Betriebsmuster (`pid … not alive`, `APIConnectionError`, `Iteration budget`, `worktree add failed`, Netzausfall) — **erstes Mal** auf dieser Karte | `unblock --reason "manuell: betriebsrettung …"` + Journalzeile. Nur bei `betriebsrettung: auto`; Default ist `melden` |
| CEO entscheidet | Gate-Karte blockiert (Release/Irreversibel/Budget) | Entscheidungskarte, siehe oben |
| CEO eskaliert selbst | `esf-verb: escalate` im Dokument | Journal + Notfall-Meldung |
| Code eskaliert am CEO vorbei | zweite Betriebsrettung derselben Karte · Karte in `triage` · `respawn_guarded` · Gate älter als `gate_unbeantwortet_stunden` ohne gültiges Dokument · Dokument fällt **zweimal** durch `ceo-lint` · blockierte Nicht-Gate-Karte ohne bekanntes Muster | Notfall an den Supervisor: Journalzeile `ledger/eskalationen.jsonl`, Exit ≠ 0, Report |

Wichtig aus Phase 0: `triage` ist **nicht** das Ende der Arbeit (der
Dispatcher holt Karten zurück) — ein Notfall verlässt sich deshalb nie auf
`triage`, sondern wird aktiv gemeldet.

## Wer bewacht den CEO

1. **Entscheidungsjournal** `ledger/ceo-entscheidungen.jsonl` (nur angehängt,
   Schema in `AGENTS.md 6.1`): jede Validierung, Ausführung, Eskalation,
   Überholung — plus das Dokument selbst im Vault. Der Supervisor liest es am
   Roadmap-Gate; die Quartalsabnahme ist zugleich die Revision der
   Entscheidungen.
2. **Einspruchsfrist** (oben) für alles Irreversible.
3. **Entscheidungsgüte als Messgröße**: Im Schattenbetrieb (Stufe B) schreibt
   `ceo-tick.sh` je Gate einen Vergleich CEO-Verb gegen Supervisor-Verb ins
   Journal (`schatten-vergleich`, `uebereinstimmung: true|false`).
   `check-phase3.sh --stufe b` zählt sie. Autonomie wird erhöht, wenn die
   Quote es trägt — nicht, weil der Kalender es sagt.
4. **Deckel gegen Durchwinken**: `ceo_fragen_pro_tag` (Default 6) begrenzt die
   je Lauf neu angelegten Entscheidungskarten. Ein Modell mit zwölf wartenden
   Gates winkt genauso durch wie ein Mensch.

## Die drei Stufen und ihre Nachweise

| Stufe | Inhalt | Abschluss-Nachweis (deterministisch) |
|-------|--------|--------------------------------------|
| **3A — Selbstplanung & Betriebsrettung** | Sprint-Graphen legt der `esf-chief-of-staff` an (Vorlagen + Kartentext-Riegel statt 1368 Zeilen Bash je Sprint); Review→Nacharbeit als Karte vom Board statt von Hand; `eskalation.sh` auf `auto` | Ein Sprint, in dem **kein Kartentext von Hand** entsteht und **jedes `unblock` ein Verb trägt** — am Board zählbar |
| **3B — Schattenbetrieb** | `ceo_modus: schatten`: `esf-ceo` beantwortet jedes Gate in ein Dokument, der Executor führt **nicht** aus, der Supervisor antwortet wie bisher | `check-phase3.sh --stufe b`: ≥ 3 Gates mit gültigem Dokument **und** Supervisor-Antwort; Übereinstimmungsquote ausgewiesen |
| **3C — CEO live** | `ceo_modus: live` (stellt der Supervisor am Roadmap-Gate um): Executor führt aus, Supervisor nur Roadmap + Notfall | `check-phase3.sh --stufe c`: ein volles Release, in dem jedes CEO-Gate `[von:esf-ceo]` trägt, kein Roadmap-Gate von `esf-ceo` beantwortet wurde, keine Eskalation offen blieb und das Irreversibel-Journal die Frist belegt |

Stufe B und C sind vollständig gebaut (dieses Verzeichnis, siehe unten).
Von Stufe A ist die **Betriebsrettung** gebaut (`eskalation.sh`); die
Graph-Generierung durch den Chief of Staff mit Kartentext-Riegel ist
**bewusst offen** — sie ist ein eigenes Arbeitspaket derselben Größenordnung
wie die Führungsebene und wird erst gebaut, wenn Stufe B am laufenden Board
gemessen hat, ob ein `deepseek`-CEO die Urteilsarbeit überhaupt trägt.

## Was gebaut wurde (18.08.2026)

| Baustein | Datei | Selbsttest |
|----------|-------|-----------|
| Zwölftes Profil | `profiles/esf-ceo/` (SOUL + description) | `setup.sh` prüft `ON DISK = yes` für 12 |
| Führungs-Kadenz | `seed/company/cadence.yaml` Abschnitt `fuehrung:` | — |
| Vertrag | `seed/company/AGENTS.md` §7 neu (drei Ebenen), §6.1 (zwei neue Journale) | Vault-Linter |
| Dokument-Riegel | `scripts/ceo-lint.py` + `seed/ceo-selbsttest/` (4 Fixtures) | genau 5 ERROR auf den Negativ-Fixtures, 0 auf der positiven — Teil von `setup.sh` |
| Executor & Entscheidungskarten | `scripts/ceo-tick.sh` (`--schatten` aus `cadence.yaml`, `--dry-run`, `--selbsttest`) | `--selbsttest` läuft hermes-frei |
| Notfall-Leiter | `scripts/eskalation.sh` (`melden`/`auto` aus `cadence.yaml`) | `bash -n` + Muster-Selbsttest |
| Nachweis-Check | `scripts/check-phase3.sh --stufe a|b|c` | `bash -n` |
| Supervisor-Hülle | `gate.sh`: `--von`, Roadmap-Riegel (verweigert `--von esf-ceo` am Roadmap-Gate) | Verb-Validierung unverändert |
| Verdrahtung | `setup.sh` (12 Profile, `ESF_MODELL_CEO`, ceo-lint-Selbsttest), `scripts/assign-keys.sh` (11 **oder** 12 Keys; bei 11 läuft `esf-ceo` gelb markiert auf dem Root-Key), `teardown.sh`, `install-cron.sh` (2 neue Takte) | Skript-Selbsttests |

## Reihenfolge der Arbeit

| # | Schritt | Token? | Nachweis |
|---|---------|--------|----------|
| 1 | `./setup.sh` — 12 Profile, ceo-lint-Selbsttest | nein | 12× `ON DISK = yes` |
| 2 | Phase 0–2 wiederherstellen oder neu fahren (`restore-phase1.sh --ledger` bzw. die Phase-2-Kette) | teils | `check-phase2.sh` grün |
| 3 | Stufe B: `ceo_modus: schatten`, `install-cron.sh`, Gates doppelt beantworten lassen | **ja** | `check-phase3.sh --stufe b` |
| 4 | Supervisor-Entscheid am Roadmap-Gate: `ceo_modus: live` | nein | Vault-Commit |
| 5 | Stufe C: ein Release ohne Supervisor außer Roadmap + Notfall | **ja** | `check-phase3.sh --stufe c` |

## Was hier NICHT umgesetzt wird

- **Die Selbstplanung (Stufe A, Graph-Generierung)** — siehe oben; erst nach
  der Schatten-Messung.
- **Push-Benachrichtigung des Supervisors** — die Notfall-Leiter journaliert
  und macht den Cron-Log laut (Exit ≠ 0); ein echter Push-Kanal (Mail,
  Messenger) bleibt Betriebsfrage und Annahme.
- **Der USD-Deckel** — die zwölf Keys haben weiterhin `limit: null`; das
  Budget-Gate bleibt so informativ wie in Phase 2. Ohne Provisioning-Key oder
  Ledger-Deckel ändert der CEO daran nichts.

## Risiken, ausgesprochen

- **Selbstbestätigung**: CEO und Worker aus derselben Modellfamilie. `ceo-lint`
  prüft Form und Anwesenheit von Messbelegen, nicht deren Wahrheit; der echte
  Schutz bleibt, dass die Checks selbst Code sind — und die Schatten-Quote.
- **Prompt-Injection über Gate-Vorlagen** ist der neue Hauptangriff auf die
  Governance. Die Executor-Schicht entschärft die *Ausführung* (Verb muss zur
  Gate-Art passen, Roadmap ist gesperrt), nicht das *Urteil*.
- **Ob ein günstiges Modell die Urteilsarbeit trägt**, ist offen — die drei
  CEO-Korrekturen der Phase 2 (Kaltstart-Diagnose, AK8-Metrik,
  Roadmap-Prämisse) waren Urteil, nicht Fleiß. Genau dafür existiert Stufe B.
- **Latenz**: Gates warten im Cron-Betrieb bis zum nächsten `ceo-tick` (bis zu
  einer Stunde) plus ggf. Einspruchsfrist. Gewollt — Bedenkzeit ist billig —
  aber in der Sprint-Kadenz einzupreisen.
