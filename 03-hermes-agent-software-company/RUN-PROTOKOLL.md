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

## Phase 1 — Onboarding

Sechs Karten, zwei Fan-ins, ein Gate. Die drei Analysen liefen parallel; genau
das provozierte den Betriebsbefund oben — vier gleichzeitige Worker mit grossem
Kontext trafen die hängenden Verbindungen zuverlässig. Der Wachhund entstand
mitten in dieser Phase und fing danach jeden Hänger ab.

### Was die Organisation geliefert hat

| Karte | Profil | Zeit | Ergebnis |
|-------|--------|------|----------|
| 1/6 Codebasis | `esf-architect` | 15 min | `codebase.html`, 19 KB, **36 `datei:zeile`-Belege** |
| 2/6 Produkt | `esf-product-manager` | 12 min | `product.html`, 22 KB, 8 priorisierte Journeys mit Schrittzahlen, „Versprechen gegen Realität" |
| 3/6 Markt | `esf-market-analyst` | 18 min | `market.html`, 19 KB, **28 Korpus-Zitate über 8 Quellen**, 8 Hypothesen — exakt der `max_pro_lauf`-Deckel aus `cadence.yaml` |
| 4/6 E2E | `esf-qa-release` | 33 min | 4 neue Specs (J-02, J-03, J-04 = alle P1, dazu J-06), `journeys.html` |
| 5/6 Roadmap | `esf-chief-of-staff` | 11 min | `q1-entwurf.html`, 3 Releases, 10 Features |
| 6/6 Gate | `esf-chief-of-staff` | 14 min | Vorlage in acht Zeilen, dann Ausführung der CEO-Antwort |

Summe über alle zehn Karten des Tages: **142 Minuten Kartenzeit**.

Drei Dinge, die über blosses Abarbeiten hinausgehen:

- Der **Architekt widersprach dem Kartentext.** Der Auftrag enthielt meine
  Behauptung, `biome ci .` sei Bestandsschuld; er prüfte sie und legte mit
  Fundstellen dar, dass sie falsch ist (siehe `VERIFIKATION.md`). Das ist
  genau das Verhalten, das der Verifikationsvertrag verlangt und das man von
  einem günstigen Modell nicht erwartet.
- Die **E2E-Karte überlebte ihren eigenen Absturz.** Lauf 17 hing und wurde vom
  Wachhund beendet; Lauf 18 fand vier bereits geschriebene Specs vor,
  verifizierte deren Selektoren gegen die Anwendung, liess die volle Suite grün
  laufen und committete. Im `metadata` steht, was sie bewusst wegliess (J-05,
  J-07, J-08, J-09, jeweils mit Grund) — und der technische Befund, dass J-04
  rohe Mausereignisse statt `dragTo` braucht, weil das Board `dnd-kit` mit
  Zeiger-Sensoren benutzt.
- Der **Chief of Staff schrieb keine Zahlen hin, die er nicht hatte.** Punkt 5
  seiner Gate-Vorlage lautet sinngemäss: kein bezifferbares Intervall, das
  Ledger ist leer, jedes Feature trägt nur eine Grössenklasse mit dem Vermerk
  „ohne Historie, Konfidenz < 0.3". Das ist die unbequeme, richtige Antwort.

Unabhängig nachgemessen statt geglaubt: Suite **8/8 grün in 24,7 s**,
Arbeitsbaum sauber, Commit `58310dc` **durch den schlanken Hook** — ohne
`--no-verify`.

### Das Roadmap-Gate: `modify`

Die Roadmap war belastbar — Features auf Hypothesen mit Score und
Falsifikationsbedingung zurückgeführt, ein begründeter „Was wir NICHT
machen"-Abschnitt, eine Subtraktions-Sichtung. Empfohlen war `approve`.

Die CEO-Antwort war trotzdem `modify`: **Release 1 schrumpft von fünf auf drei
Features.** Nicht aus Zweifel am Plan, sondern wegen des leeren Ledgers. Ein
bis ans Kadenz-Limit gefülltes erstes Release liefert die ersten (Schätzung,
Ist)-Paare zu spät, und bis dahin ist auch das Budget-Gate wirkungslos — 150 %
einer P90, die es nicht gibt, löst nie aus. Drei gemessene Features schlagen
fünf blind geplante. Dazu die technische Härtung zuerst statt zuletzt, weil die
Codebasis-Analyse `apps/api/src/index.ts` als Kollisions-Hotspot benennt und
die Organisation an diesem Tag dreimal bewiesen hat, dass parallele Git-Arbeit
ihr häufigster Ausfallgrund ist. Auflage: Kalibrierung nach dem ersten fertigen
Feature. Horizont bleibt `release` — kein Quartals-Mandat für eine
Organisation, die noch kein einziges echtes Feature abgeschlossen hat.

Der Chief of Staff arbeitete das ein, verschob Import und Undo an den Anfang
von R2 (Deckel eingehalten), fror die Freigabe nach `q1-freigegeben.html` ein
und liess den Entwurf daneben stehen — „nicht überschrieben, sondern
widerlegt", das Muster aus Kapitel 7.

`check-onboarding.sh` ist danach grün: 5/5 Karten, vier Analyse-Artefakte,
Vault-Linter sauber, 6 Journey-Specs, Suite grün, Gate beantwortet und
ausgeführt, beide Roadmap-Stände im Vault.

## Was dieser Lauf gekostet hat

142 Minuten Kartenzeit über zehn Karten, verteilt auf gut zweieinhalb Stunden
Wanduhrzeit. Die Differenz sind die Hänger, die Retries und die Wartezeit am
Gate. Eine Kostenangabe in USD steht für diesen Lauf nicht hier: Er lief auf
dem einen Root-Key, und eine Aufteilung auf Rollen gäbe es nur als Erfindung.

## Nachtrag: elf Keys, elf Rollen

Nach dem Lauf kamen elf OpenRouter-Keys dazu. `scripts/assign-keys.sh` ordnet
sie den elf Profilen zu — nach Reihenfolge, festgehalten in
`key-zuordnung.txt` mit Fingerabdruck statt Geheimnis.

Interessant ist nicht die Zuordnung, sondern was sie zu beweisen zwang. Dass
`hermes -p <profil> config set` in die Profil-`.env` schreibt und die
Shell-Variable schlägt, steht im Quelltext (`env_loader.py:496`, `override=True`).
Offen war, ob ein vom **Dispatcher** gestarteter Worker überhaupt mit
`HERMES_HOME` auf dem Profilverzeichnis läuft. Wäre es anders, liefen alle elf
Rollen still auf dem Root-Key — und `config get` meldete trotzdem grün, weil es
dieselbe Datei liest, die eben geschrieben wurde.

`scripts/check-keys.sh` fragt deshalb OpenRouter statt sich selbst. Zwei
Probekarten, vorher und nachher gemessen: `esf-dev-a` +0,00436883 USD,
`esf-reviewer` +0,00282912 USD, die anderen neun exakt unverändert — drei davon
mit Vorbelastung aus dem ersten Durchgang, die sich nicht bewegte.

Der erste Lauf dieser Prüfung meldete einen Fehlschlag, den es nicht gab: Der
Zähler bei OpenRouter läuft dem Lauf gut eine Minute nach, und direkt nach
`done` stand alles auf null. Die Prüfung wartet jetzt auf die Buchung und
danach noch eine Kontrollrunde.

Nebenbei fiel eine falsche Annahme aus meinen eigenen Unterlagen: `GET
/api/v1/key` authentifiziert sich mit dem abgefragten Key selbst. Die
Kostenzurechnung je Rolle braucht also **keinen** Provisioning-Key —
`provision-keys.sh` behauptete das Gegenteil. `ledger-sync.sh` schreibt seither
echte Zahlen nach `ledger/kosten-je-rolle.jsonl`; die fünf Probekarten kosteten
zusammen 0,0199 USD. Je **Karte** bleibt `cost_usd` trotzdem `null`: Der Zähler
ist kumulativ je Key, also je Rolle, und alles Feinere wäre eine Division mit
dem Anschein einer Messung.

## Bilanz

Was an diesem Lauf trägt, ist nicht die Menge der Artefakte, sondern die Liste
der Fehler, die er sichtbar gemacht hat: sechs in ESF-Code, drei im Rückbau,
zwei im Betrieb, einer in meiner eigenen Beweisführung. Alle stehen in
`VERIFIKATION.md`, alle sind behoben, und keiner davon wäre ohne einen echten
Lauf gegen ein echtes Repo aufgefallen.

Der unangenehmste ist der eigene: Eine bequeme Erklärung wurde fünfmal
weitergeschrieben, ohne dass jemand den Exit-Code isoliert gemessen hätte.
Der erste, der nachsah, war ein Agent.

---

# Phase 2 — Begleiteter Betrieb, 17.08.2026

Derselbe Aufbau, dasselbe Modell (`deepseek/deepseek-v4-flash-0731`), dieselbe
CEO-Rolle. Der Plan steht in [`PHASE-2-PLAN.md`](PHASE-2-PLAN.md); hier steht
wieder der Hergang, und wieder ist die Fehlerliste der wertvollere Teil.

**Kapitel 12 verlangt drei Nachweise:** zwei Sprint-Reports mit
(Schätzung, Ist)-**Paaren**, das erste Release durch das Release-Gate, und eine
Schätzgüte-Baseline im Controller-Report. `scripts/check-phase2.sh` prüft genau
diese drei.

## Vorlauf: zwei Entscheidungen, die vor dem ersten Kartenzug fielen

**R1 läuft in zwei Sprints statt vier.** `cadence.yaml` nennt vier als
Obergrenze („max. 4 Sprints je Release", Kapitel 5), nicht als Soll. R1 trägt
nach der CEO-Änderung vom Vortag drei Features, und die beiden Phase-2-Nachweise
gehen nur zusammen auf, wenn das Release wirklich landet. S1 = R1-F5 (Härtung),
S2 = R1-F1 ∥ R1-F2, dann Release-Abschluss und Gate.

**Phase 2 startet auf einem wiederhergestellten Phase-1-Stand.** Dazwischen lag
ein Rückbau: leeres Board, `workspace/company/` frisch aus `seed/`.
`restore-phase1.sh` spielt die Artefakte aus `beispiel-lauf-1/` zurück. Was
**nicht** zurückkommt, ist die Karten-Historie — die `esf-karte`-Metas der
Dokumente nennen IDs, die es auf dem Board nicht mehr gibt. Nachschlagen geht
nur in `beispiel-lauf-1/board.json`. Der Weg vom Dokument zur Entscheidung führt
also über die Akte statt über das Board; das ist eine echte Lücke und steht als
`reports/herkunft-phase1.txt` im Vault.

## Der Ledger-Backfill: warum die erste Schätzung überhaupt möglich war

Der Knackpunkt der ganzen Phase. `ledger/estimates.jsonl` war **leer** —
`ledger-sync.sh` war über die Phase-1-Karten nie gelaufen, nachgeprüft an der
Akte (0 Zeilen). Ein `esf-estimator` ohne Ledger darf nach `AGENTS.md 6` keine
Zahl schreiben; ohne Zahl gibt es kein Paar; ohne Paar fällt Nachweis 1 aus.

Der Ausweg war keine Erfindung, sondern eine Nachbuchung: Die Wanduhrzeiten der
zehn Phase-0/1-Karten **sind gemessen** und liegen in `board.json` als
Board-Zeitstempel — die Quelle, die Kapitel 8 als die verlässliche benennt.
`restore-phase1.sh --ledger` bucht sie nach, mit drei Regeln: `estimate` bleibt
`null`, die Referenzklasse wird über eine sichtbare Tabelle im Skript
**zugeordnet** statt geraten, und jede Zeile trägt `backfill: true`.

Ergebnis: sieben Referenzklassen, darunter `impl-worktree-S` (21 min),
`review-repo-S` (2 min), `spec-vault-S` (2 min), `gate-vault-S` (11/14 min).
Wenig, aber gemessen.

## Der eigene Vertrag hält — auch gegen mich

Mein Herkunftsvermerk lag zuerst als `analysis/HERKUNFT.txt` und wurde vom
eigenen Vault-Linter mit zwei ERROR abgewiesen: `AGENTS.md 2.1` nimmt
Maschinenprotokolle nur unter `reports/` von der HTML-Pflicht aus, `2.3`
verlangt kleine Dateinamen. Zu Recht. Ein Skript der Organisation, das sich vom
Vertrag der Organisation ausnimmt, wäre der Anfang vom Ende des Vertrags.

Zweiter eigener Fehler, teurer: `create-sprint.sh` las `cadence.yaml` ohne den
Zeilenkommentar abzuschneiden. `karten_pro_feature: 8   # Deckel für den
Planungsgraphen je Feature` landete als ganzer Kommentar mitten im Kartentext
eines Workers. Der S1-Graph wurde deshalb archiviert und neu angelegt — kostenlos,
weil noch nichts gelaufen war.

## S1 — R1-F5, die technische Härtung

| Karte | Profil | Zeit | Ergebnis |
|-------|--------|------|----------|
| 1/5 Konzept & ADR | `esf-architect` | 30 min | ADR-001 mit drei Optionen inkl. Nullvariante, `specs/r1-f5-haertung.html`, 10 abhakbare Kriterien |
| 2/5 Schätzung | `esf-estimator` | 4 min | drei Intervalle mit genannten Ledger-Zeilen und offengelegtem Multiplikator |
| 3/5 Umsetzung | `esf-dev-a` | 113 min über **5 Läufe** | `index.ts` 968 → 20 Z., Commit `89b9462` |
| 4/5 Review | `esf-reviewer` | 25 min | `changes_requested`, zwei Verstöße, ein Governance-Verdacht |

### Was der Architekt geliefert hat

Drei Dinge über das Abarbeiten hinaus: die **Nullvariante** („Datei so lassen")
als ernsthaft abgewogene und begründet verworfene Option; die
**verhaltenswirksame Registrierungsreihenfolge** um die `api.use('*')`-Middleware
als festgeschriebene Invariante — der Punkt, an dem eine Umstrukturierung ohne
Verhaltensänderung normalerweise kippt; und als Prüfung der Routen-Parität einen
**Diff des OpenAPI-Exports vor/nach**, also eine Messung statt einer Behauptung.

Seine Fundstellen wurden gegen das echte Repo nachgeprüft statt geglaubt:
`tests/api-integration/` existiert, `apps/api/scripts/export-openapi.ts`
existiert, `index.ts` hat tatsächlich 968 Zeilen.

### Was der Estimator geliefert hat

Er nennt seine Grundlage per `task_id` statt „aus der Historie", zeigt den
Multiplikator (3,3× von S nach M) offen, und gibt `merge-repo-S` die
**niedrigste** Konfidenz (0.20), obwohl es die kleinste Karte ist — weil dort
kein Nachbar existiert. Das ist die richtige Rangfolge, nicht die bequeme.

Nebenbei das erste eigene Paar: Er schätzte seine **eigene** Karte auf p50 = 20
und brauchte 4 Minuten. Faktor 0,2 — die Rolle, die vor optimistischer
Selbsteinschätzung schützen soll, hat sich um das Fünffache überschätzt.

## Fünf Betriebsbefunde, alle neu gegenüber Phase 1

### 1. `agent.max_turns` — der Deckel, den das Konzept nicht kennt

Lauf 5 der Umsetzungs-Karte endete `gave_up` mit
`Iteration budget exhausted (500/500)` — nach 9 Minuten Wanduhr, bei **genau
zwei** verbleibenden `TS6133`-Fehlern. Der Umbau war vollständig; das Budget war
weg.

Das ist der teuerste denkbare Ausgang: voller Preis, kein Ergebnis. Und der
Deckel, der ihn hätte begrenzen sollen, war nicht der, der zuschlug —
`KONZEPT.html` nennt als harte Deckel je Karte nur `--max-runtime` und
`--max-retries`. `agent.max_turns` (Default 500, per Profil setzbar) fehlt dort.

Behoben: 1200 für die vier werkzeugintensiven Rollen (`dev-a`, `dev-b`,
`reviewer`, `qa-release`), dauerhaft in `setup.sh`. Die urteilenden Rollen
bleiben bei 500 — ihre Arbeit ist Denken, nicht Schleifen.

### 2. Der Wachhund war die Ursache, nicht die Rettung

`watchdog.sh` beendete Lauf 6 (51 min) und Lauf 7 (30 min) — beide
**produktiv**. Das `agent.log` von Lauf 7 zeigt 55 normale API-Aufrufe mit
5–24 s Latenz und endet mit `Turn ended: reason=interrupted_by_user`. Das war
mein Kill.

Der Mechanismus, präzise: Ein Worker, der ein langes lokales Kommando fährt
(`pnpm test` gemessen 41 s, ein Playwright-Lauf, im Log ein Kommando mit 194 s),
hält **keine** `ESTABLISHED`-Verbindung — die letzte HTTP-Antwort ist
abgeschlossen —, alte Pool-Sockets liegen auf `CLOSE_WAIT`, und der
Python-Prozess rechnet nicht, weil sein **Kind** rechnet. Zeichen für Zeichen die
Signatur, auf die das Skript tötete.

Damit ist die Phase-1-Diagnose zu verallgemeinern **und** zu korrigieren:
`0 % CPU + toter Socket` ist kein verlässlicher Hänger-Nachweis. Der Wachhund
hat jetzt drei Kriterien — CPU über den ganzen **Prozessbaum** (`pnpm → node →
vitest`, die CPU sitzt unten), **kein Kindprozess**, und erst dann `CLOSE_WAIT`
ohne lebende Verbindung.

Bemerkenswert: Auf derselben Karte hatte er zuvor bei 7 Minuten und 0 % CPU
korrekt **abgelehnt** („solange eine Verbindung steht, ist eine lange
Modellantwort die wahrscheinlichere Erklärung"). Die Unterscheidung war halb
richtig — sie kannte Verbindungen, aber keine Kinder.

### 3. Ein Worker hat aus dem Worktree in den Hauptbaum geschrieben

Er suchte die `.env`. Die ist gitignored, ein frischer Worktree hat keine, und
ohne sie startet die Anwendung nicht. Also schrieb er die `.env` des
**Hauptbaums** neu (Zeitstempel 19:58) und steckte rund 80 Minuten in
Umgebungs-Archäologie — `AUTH_SECRET`, `DATABASE_URL`, ein Stash namens
`j03-baseline-test`, zwei von der Hardline-Sperre abgewiesene Kommandos.

Das hebt die Isolation auf, auf der die ganze parallele Arbeit beruht.
`create-sprint.sh` gibt allen drei Bau-Karten jetzt einen `env_hinweis`-Absatz:
die eine Zeile zum Verlinken, das Verbot, in den Hauptbaum zu schreiben, und das
Verbot, Geheimnisse neu zu erzeugen.

### 4. Der Pre-Commit-Hook hat in **keinem** Worktree existiert

Der schwerste Befund, und gefunden hat ihn wieder die eigene Organisation: Der
Reviewer fand 11 biome-Fehler in einem Commit, den der Hook hätte blockieren
müssen, und nannte zwei mögliche Ursachen — `--no-verify` oder defekte
Hook-Mechanik.

Es war die zweite. `core.hooksPath` stand **relativ** auf `.esf-hooks`; Git löst
das gegen die Wurzel des jeweiligen Arbeitsbaums auf, und `.esf-hooks/` liegt
nur im Hauptbaum und nicht im Git. Im Worktree zeigte der Pfad ins Leere, und
Git committete ohne jede Prüfung — lautlos, ohne Warnung. Der Entwickler hatte
nichts umgangen; es gab nichts zu umgehen.

Das ist die unangenehme Sorte Lücke: In Phase 1 wurde der Hook im **Hauptbaum**
nachgewiesen („Commit `58310dc` durch den schlanken Hook — ohne `--no-verify`")
und galt seither als belegt. Genau dort, wo die Feature-Arbeit stattfindet, war
er nie da. **Jede Bau-Karte der ESF hat bis hierhin ungelintet committet.**

Behoben mit einem absoluten Pfad — `core.hooksPath` steht in der gemeinsamen
`.git/config`, ein absoluter Pfad wirkt daher in allen Worktrees zugleich, auch
in den erst später angelegten. Nachgewiesen mit einem absichtlich fehlerhaften
Probe-Commit im Worktree: abgewiesen, HEAD blieb stehen.

### 5. „Suite 8/8 grün" ist kalt nicht reproduzierbar

J-03 (`aufgabe-erfassen-und-zuweisen.spec.ts`) scheiterte im Suitenlauf
reproduzierbar an `expect(page).not.toHaveURL(/\/onboarding/, { timeout: 30_000 })`
in `tests/e2e/support/journey.ts:58`. Die Messung, die die Ursache festlegt:

    pnpm exec playwright test …/aufgabe-erfassen-und-zuweisen.spec.ts --repeat-each=3
    Lauf 1  ROT    34,3 s      (der 30-s-Deckel reisst)
    Lauf 2  grün    7,5 s
    Lauf 3  grün    4,9 s

Die **erste** Arbeitsbereich-Anlage nach einem kalten API-Start braucht länger
als 30 s, jede weitere unter 8 s. J-03 ist im Suitenlauf der erste Test, der
einen Arbeitsbereich anlegt — deshalb trifft es immer ihn und nie J-01, obwohl
J-01 denselben Helfer benutzt.

Ausgeschlossen, jeweils gemessen: nicht der R1-F5-Umbau (der Hauptbaum steht
unverändert auf `58310dc` und zeigt dasselbe Bild); **nicht** der
Datenbank-Zustand — ich habe die Testdatenbank komplett neu aufgesetzt
(`down -v`, `up`, `db:migrate`) und es blieb rot, womit meine eigene Hypothese
„angesammelter Zustand" (vorher 72 Workspace-, 81 User-, 69 `trial_grant`-Zeilen)
**widerlegt** war; und nicht Zufall, dreimal deterministisch reproduziert.

Damit ist der Phase-1-Eintrag „Suite 8/8 grün in 24,7 s" zu korrigieren: Damals
lief die Suite hinter einem Worker, der die Anwendung schon warmgelaufen hatte.
Ein Regressionsnetz, dessen Ergebnis davon abhängt, was vorher lief, ist kein
Netz. Kapitel 6 sagt „Flakiness wird behandelt wie ein Bug" — also eine Karte
für `esf-qa-release`, verdrahtet als Elternteil der Merge-Karte, damit der
Riegel erst auf einer geheilten Suite läuft.

## Das Review, und wie der CEO darauf entschied

25 Minuten, und die stärkste Karte des Sprints. Routen-Parität **136/136
byte-identisch, selbst gemessen**; Unit 374/374 und Integration 181/181 selbst
gefahren; der J-03-Kaltstart unabhängig als vorbestehend erkannt; und der
Entwickler bei einer Falschbehauptung erwischt (sein `metadata` behauptete,
`app.ts` mit 565 Zeilen entspräche der Spezifikation, die `< 450` fordert).

**AK7 (biome, 11 Fehler) → Nacharbeit.** Keine Diskussion; und jetzt greift der
Hook wirklich.

**AK8 (`app.ts` 565 > 450) → CEO-Entscheid: Limit aufgehoben.** Der Reviewer
hatte den Verstoß gemeldet **und** dazugesagt, dass die Spezifikation intern
gespannt ist: Sie weist `app.ts` inhaltlich alle Inline-Routen, den
Auth-Middleware-Block, die 27-gliedrige Montageliste, Typen, Error-Handler und
CORS zu — mit Herkunftszeilen, die zusammen weit über 450 liegen — und fordert
danach `< 450`. Nachgeprüft: stimmt. Beides ist nicht erfüllbar.

Begründung des Entscheids: Zweck von R1-F5 ist, die **Kollisionsfläche** zu
senken, bevor F1 und F2 parallel laufen — nicht, eine Zeilenzahl zu erreichen.
Das ist erreicht: `index.ts` 968 → 20, Auth-Routen in `routes/auth.ts`; beide
Features berühren `app.ts` künftig mit je einer Registrierungszeile statt in
vielen Regionen einer 968-Zeilen-Datei. Was zusätzlich auszulagern wäre, um unter
450 zu kommen — WS, `/openapi`, MCP —, berührt F1 und F2 **nicht**; der Ausbau
senkt das Kollisionsrisiko um null und erhöht das Umbaurisiko. Eine Hilfsgröße
gegen ihren eigenen Zweck durchzusetzen ist Buchstabentreue, nicht Sorgfalt.

Der Entscheid wird nicht still hingenommen — der Reviewer hatte genau das
verlangt: Eine Karte für den `esf-architect` trägt den Nachtrag in die
Spezifikation ein, lässt das ursprüngliche AK8 wörtlich daneben stehen
(`AGENTS.md 3.3`) und ersetzt es durch ein Kriterium, das den **Zweck** misst
statt eine Zahl zu setzen.

## Kosten je Rolle — erstmals über einen ganzen Sprint gemessen

Stand nach S1 bis zur Merge-Karte, `scripts/assign-keys.sh --verbrauch`:

| Rolle | USD |
|-------|-----|
| `esf-dev-a` | 0,5666 |
| `esf-architect` | 0,0972 |
| `esf-estimator` | 0,0290 |
| `esf-controller` | 0,0056 |
| `esf-market-scout` | 0,0044 |
| `esf-qa-release` | 0,0029 |
| `esf-reviewer` | 0,0028 |
| **Summe** | **0,7085** |

Die Verteilung ist die eigentliche Aussage: **80 % liegen auf einer Rolle**, und
davon ist der grösste Teil in vier abgebrochenen Läufen verbrannt. Nicht das
Modell war teuer, sondern die Werkzeug-Fehlkonfiguration — der Iterations-Deckel
und mein eigener Wachhund.

### Der erste Merge-Versuch: der Riegel schlug sich selbst

Der Riegel verweigerte — und zwar richtig. Bemerkenswert war das *Wie*: Er lief,
verweigerte, lief **einmal** sauber nach (wie sein Kartentext vorschreibt),
verweigerte erneut, maß den Test isoliert mit 3/3 in 752 ms, entlastete den
Branch mit einem Argument (`git diff --name-only` zeigt sechs Dateien, keine
davon in `apps/api/src/mcp`) — und mergte **trotzdem nicht**, weil seine eigene
Regel sagt: zweite Verweigerung = Sachgrund. Statt zu überstimmen legte er eine
Nacharbeitskarte an.

Dahinter steckte ein struktureller Befund über den Riegel selbst:

| Lauf | Ergebnis | `import` |
|------|----------|----------|
| Branch allein, volle Unit-Suite | 374/374 grün | **6,81 s** |
| main allein | 374/374 grün | — |
| Riegel-Lauf | 2 rot | **107,74 s** |

Faktor 16. `pnpm test` ist `turbo test`, und turbo fährt die Paket-Tasks
parallel. **Der Riegel erzeugte die Last, an der er scheiterte** — und sein
Urteil hing davon ab, wie viele andere Karten gerade liefen. „Code entscheidet,
kein Modell" trägt nur, wenn der Code deterministisch ist; ein Riegel, dessen
Ergebnis vom Betriebszustand abhängt, ist ein Würfel mit Protokoll. Er
serialisiert seither (`--concurrency=1`) und entschied danach dreimal in Folge in
vier Minuten.

Die Nacharbeit fand die Ursache genauer als das Wort „lastempfindlich": Das
5000-ms-Default-Timeout killte Test 1 **mitten im Request**, und sein noch
laufender Modul- und Fetch-Zustand leckte in den frischen `fetch`-Stub des
nächsten Tests — daher `toHaveBeenCalledOnce` mit 2. Behoben mit Warmlauf in
`beforeAll`, 60-s-Budget je Test und Modul-Isolation; verifiziert mit 3 normalen,
4 Last- und 4 Turbo-Riegel-Läufen.

## S2 — R1-F1 und R1-F2 parallel

Die Auflage der Roadmap hat gegriffen: `create-sprint.sh 2` prüfte selbst, dass
`Kalibrierung S1` fertig war, bevor es Karten anlegte. Die Reihenfolge war
Riegel, nicht Absicht.

### R1-F1: die Karte, die glatt durchlief

34 Minuten, ein Lauf, Schätzung p50 = 35 → **Ist/Schätzung 0,97**. Damit hatte
sich die Kalibrierungsschleife geschlossen: S1 schätzte 70 und maß 114 roh; S2
schätzte 35 und traf.

Zwei Dinge darüber hinaus. Der Product Manager **widerlegte eine Prämisse der
eigenen Roadmap** und ließ beide Aussagen nach `AGENTS.md 3.3` nebeneinander
stehen: Die Baseline hatte bereits einen sichtbaren Sidebar-Suchbutton
(`app-sidebar.tsx:42`), was `analysis/product.html` K9 widerspricht — und die
Roadmap hatte F1 mit Score 22,5 als „größten Bruch mit dem Markenversprechen"
begründet. Er verkleinerte das Feature ehrlich auf den Header-Griff, rein
Frontend. Und `git diff main...feat/esf-r1-f1-globale-suche -- apps/api/src/app.ts`
blieb **leer**: Das neue AK8 des Architekten wirkte als Bauanleitung, nicht als
Prüfung. Die Kollision, die in S1 dreimal zuschlug, kam gar nicht erst zustande.

### R1-F2: vier Prüfzyklen, zwei echte Befunde

**Zyklus 1 — Review `rejected`, Sicherheitsbefund.** Der 2FA-Hook feuerte nur auf
den Passwort-Anmeldewegen (`plugins/two-factor/index.mjs:222`); Magic-Link,
E-Mail-OTP und Social/OAuth bauten Sessions ohne zweiten Faktor
(`auth.ts:252-306`), und `twoFactorEnabled` wurde außerhalb des Plugins nirgends
konsultiert — belegt mit einem grep über den gesamten Dist. Drei Umgehungspfade.
Ein zweiter Faktor mit Hintertür ist keiner.

**Zyklus 2 — geschlossen.** Ein `databaseHooks.session.create.before`-Hook
verwirft die Session-Erzeugung bei `user.twoFactorEnabled`. Gewählt wurde
*ablehnen* statt *herausfordern*, weil Letzteres den Plugin-Matcher forken **und**
die Web-Client-Anmeldebehandlung umbauen müsste. Bewiesen mit Gegenprobe: Konto
ohne 2FA meldet sich unverändert an.

**Zyklus 3 — Nachprüfung `rejected`, Frage 4.** Die drei Wege waren empirisch
geschlossen, kein vierter Weg, Gegenprobe echt — aber die Abweisung erreichte den
Nutzer nicht: Magic-Link zeigte rohes 401-JSON, E-Mail-OTP hing **endlos** auf
„Verifying…". Und der Nebenbefund war der lehrreichere: `J-08b umgeht den
Web-Client absichtlich und prüft nur den Server-Vertrag` — deshalb war die Lücke
grün getestet. Ein Test, der den Weg des Nutzers auslässt, färbt genau die Stelle
grün, an der es weh tut.

**Zyklus 4 — behoben, und ein belegtes Nein.** `authClient.signIn.emailOtp` hängt
bei einer 401, weil sein Promise nie auflöst; der Endpunkt wird jetzt per `fetch`
gerufen, die Abweisung erkannt und als Meldung mit Passwort-Link angezeigt (i18n
en-US und de-DE), J-08b prüft den Browser-Weg. Für den Magic-Link lieferte der
Entwickler eine **Absage mit Fundstellen**: `/api/auth/magic-link/verify` gibt
auch mit `errorCallbackURL` eine rohe 401 zurück, weil das Plugin den `APIError`
nicht in einen `redirectWithError` übersetzt, und der Browser navigiert direkt zur
API-Origin und umgeht die SPA. Dazu der entscheidende Produktbefund: **Die
Anwendung versendet selbst keine Magic-Links.**

**CEO-Entscheid (a):** descopen. Kein nutzersichtbarer Pfad, sicherheitlich
geschlossen, die 401 ist hässlich statt durchlässig. Als bekannte Einschränkung
in `apps/api/src/auth.ts:660` dokumentiert — nicht in einem Kartenkommentar, der
in einem Monat verloren wäre.

Meine Grenze war vorher ausgesprochen: **ein Versuch, dann wandert 2FA nach R2** —
und ausdrücklich als Zusage formuliert, nicht als Drohung: „Ein ehrliches Nein
kostet mich zwanzig Minuten, ein optimistisches Ja kostet zwei Stunden." Genau
das kam zurück.

### Das Irreversibel-Gate: `modify` mit zwei Auflagen

Die 2FA-Spezifikation enthielt eine irreversible Datenmigration (`two_factor`,
`user.two_factor_enabled`). Kapitel 7 macht das **immer** gate-pflichtig, also
legte ich die Gate-Karte an, **während ihr Elternteil noch offen war** — sonst
startet der Dispatcher sie zwischen `create` und `block`. Sie hing nicht daran,
ob der Reviewer die Migration bemerkt: Eine Pflicht aus Kapitel 7 ist keine
Beobachtung.

Die Vorlage war vorbildlich und ehrlich beim Schlimmstfall (Punkt 4: Boot-Migrate
scheitert → API startet nicht, Betriebsausfall ohne Datenverlust). Die Antwort
war trotzdem `modify`:

- **Auflage 1:** Die Migration geht nicht vor dem geschlossenen zweiten Faktor
  nach main. Ein irreversibles Schema für ein Feature freizugeben, das falsche
  Sicherheit verkauft, wäre die Reihenfolge genau falschherum.
- **Auflage 2:** Der Backup-Hinweis wird **geschrieben**, nicht empfohlen. Punkte
  5 und 7 nannten ihn als einzigen Rückweg und zugleich als einzige Auflage — er
  stand aber nirgends. Eine Auflage, die im selben Dokument schon erfüllt klingt,
  ist keine.

Kein `shelve`, und der Grund gehört dazu: Die Migration ist additiv, auf einer
echten Bestands-DB mit **79 Nutzern** verifiziert, und der Aussperr-Pfad steht mit
echten Spaltennamen im Repo. Der Blocker lag in der Anmeldung, nicht in der
Datenhaltung; ein `shelve` hätte gute Arbeit für einen fremden Fehler bestraft.

Das Gate legte für Auflage 2 eine **eigene Karte** an statt sie selbst
auszuführen — eine Entscheidung, eine Karte. `ADR-002` hält den Beschluss fest,
inklusive der verworfenen Option A („Migration ohne Kopplung freigeben") mit ihrer
Begründung.

## Vier weitere v0.20.0-Eigenheiten

Sie stehen mit ihren Konsequenzen in `PHASE-2-PLAN.md`; hier die Kurzfassung.

**Eine Karte im Status `review` kann sich selbst nicht abschließen.**
`kanban_complete` antwortet `could not complete <id> (unknown id or already
terminal)`. Ein Worker drehte **vier Läufe** in dieser Schleife, je 0 Minuten,
während seine Arbeit längst committet war. Ausweg ist
`hermes kanban complete <id> --metadata '<json>'` von außen — `complete` nimmt
`--metadata`, die Fremdschließung ist also vorgesehen. Die Kartentexte verbieten
`request_review` seither.

**Der Dispatcher gibt einen Branch an den Worktree der neuen Karte und detacht
den alten.** Ich habe deshalb einen fertigen Fix fälschlich für fehlend erklärt —
im detachten Baum nachgesehen. Verlässlich ist `git branch -v`.

**`link` hält keine Karte zurück, die schon `ready` ist.** Beim Archivieren einer
laufenden Karte wurde ihr Kind elternlos und startete auf einem leeren Branch.
Der Weg ist `reclaim` plus `schedule` — nicht `block`, denn die Karte wartet auf
Arbeit, nicht auf einen Menschen.

**Worker verlassen die vorgesehene Arbeitsfläche.** Zwei Git-Worktrees in
`/private/tmp/`, ein Verzeichnis mit verstümmeltem Pfad im Elternverzeichnis des
Repos (`03-hermes-agent-softire-company/…/revironments/it's.`, 0 Byte, ein falsch
gequotetes `mkdir -p`), und eine neu geschriebene `.env` im Hauptbaum.
`monitor.sh` meldet seither Worktrees außerhalb von `.worktrees/`.

## Der schwerste Messbefund: wessen Anwendung testen wir eigentlich?

Er kam als **Nebenbemerkung** einer QA-Karte:

> Die E2E-Baseline lag einem stalen Dev-Server aus dem R1-F2-Worktree zugrunde —
> deshalb fiel auch J-07 rot.

`playwright.config.ts` hat `reuseExistingServer: !process.env.CI`. Die Suite
benutzt also, **was auf dem Port lauscht** — auch einen Server aus einem fremden
Worktree, der anderen Code ausliefert. Und weil jede Feature-Karte ihren eigenen
Stack in ihrem eigenen Worktree startet (gemessen: zwei zusätzliche
Postgres-Container neben dem des Hauptbaums), ist das der **Normalfall**.

Ein grüner oder roter Lauf sagt dann nichts über den Branch, den der Riegel
prüft. Dieselbe Fehlerklasse wie der „grüne Lauf, der nichts prüft" aus Phase 1 —
nur schwerer zu sehen, weil das Ergebnis plausibel aussieht. Der Riegel ordnet
jetzt vor dem E2E-Schritt die lauschenden Prozesse ihrem Arbeitsverzeichnis zu
und verweigert bei fremder Herkunft, mit dem `kill`-Befehl im Protokoll.
Nachgewiesen mit einem Worktree-Lauscher auf einem Testport.

Dieselbe QA-Karte behob auch die zweite Flakiness und maß deren Ursache statt sie
zu raten: `fill()` wird vom React-kontrollierten RHF-Feld über Base-UI
`FieldControl` unter Last **still verworfen**, das Feld bleibt dauerhaft leer.
Behoben im Helfer (nachführen bis der kontrollierte Wert hält), **kein
`--retries`**, 5 von 5 vollen Läufen grün.

## Die Kalibrierung: was zwei Sprints ergeben haben

`check-sprint.sh S2` ist grün — **7 vollständige Paare, keins zerrissen**. In S1
riss eines, weil der Estimator nur Elternteil der ersten Folgekarte war; seither
ist er direkter Elternteil jeder Karte, die er schätzt.

| Klasse | n | Ist/Schätzung |
|--------|---|---------------|
| `impl-worktree-M` | 3 | **1,04** |
| `merge-repo-S` | 4 | 0,50 |
| `review-repo-M` | 3 | 0,68 |
| `estimate-vault-S` | 3 | 0,28 |

Die Bau-Schätzungen treffen; Merge und Review werden systematisch überschätzt.
Das ist jetzt eine messbare Aussage statt eines Gefühls — und der Gate-Report
leitet daraus einen Korrekturfaktor von etwa 0,6 auf p50 ab.

Der unbequemste Befund der Kalibrierung ist ein **Prozess**-Befund: Derselbe
Estimator behandelte dieselbe Klasse zweimal verschieden — bei R1-F1 mit der
bereinigten Basis (traf 0,97), bei R1-F2 mit der rohen (überschätzte um Faktor
2). Die Arithmetik war beide Male richtig; es fehlte die Disziplin, die
Entscheidung des Controllers anzuwenden. Eine Kalibrierungsschleife schließt sich
nur, wenn die nächste Rolle das Urteil der vorigen achtet. Das steht seit heute
in der SOUL des `esf-estimator` — eine Auflage bindet R2, eine SOUL bindet die
Rolle.

Und die Zahl, die betriebswirtschaftlich am schwersten wiegt: **ungeplante Arbeit
555 Minuten = 73 % der Sprint-Wanduhr**, gegen 203 geplante. Keine Ausfälle,
sondern Review-Befunde, Betriebsdefekte und CEO-Auflagen — also genau das, was
diese Organisation gut macht. Wer R2 mit fünf Features zum Nominalaufwand plant,
plant an drei Vierteln der Wirklichkeit vorbei.

## Das Release-Gate: `approve` mit zwei Auflagen

Vor der Antwort habe ich jede Zahl der Vorlage selbst nachgemessen, mit einem
eigenen **kalten** E2E-Lauf und vorher keinen laufenden Servern:

| Behauptung der Karte | selbst gemessen |
|----------------------|-----------------|
| E2E 11/11 ohne `--retries` | 11 passed, kalt, 2,7 min |
| Unit 613 passed | 613 passed über 7 Pakete |
| Typecheck 6/6 | grün |
| main sauber auf `56e0b8f` | 0 offene Änderungen |
| alle drei Features drin | alle drei `in main` |

Meine erste Unit-Zahl (726) war ein eigener Zählfehler — Testdateien
mitaddiert. Die Karte hatte recht.

Die Antwort war `approve`, mit zwei Auflagen für den Roadmap-Fortschritt: der
gemessene Klassenfaktor wird **angewendet und mit seinem n genannt** (bei n < 5
bleibt die Konfidenz unter 0,4), und R2 wird gegen die **gemessene** Kapazität
geplant statt gegen die nominelle. Dazu drei Punkte, die nicht verlorengehen
dürfen: die Magic-Link-Einschränkung als benannter R2-Backlog-Posten, die Pflicht
jeder R2-Spezifikation, ihre Roadmap-Begründung zuerst am Code zu prüfen (die
Lehre aus R1-F1), und der Autonomie-Horizont bleibt `release` — kein
Quartals-Mandat für eine Organisation, die für ihr erstes Release vier
Prüfzyklen, drei Zeitüberschreitungen und sieben ungeplante Karten gebraucht hat.

Das Gate legte die Kapazitätsfrage dem Roadmap-Gate **vor** statt sie zu
entscheiden (Empfehlung: R2 von fünf auf drei Features plus Ungeplant-Puffer
≈3×) — genau die Rollentrennung, die verlangt war.

## Was Phase 2 gekostet hat

| Rolle | USD | |
|-------|-----|-|
| `esf-dev-b` | 5,8477 | 63 % |
| `esf-dev-a` | 1,1944 | 13 % |
| `esf-qa-release` | 0,8969 | 10 % |
| `esf-reviewer` | 0,7518 | 8 % |
| die übrigen sieben | 0,6598 | 7 % |
| **Summe** | **9,3506** | |

1131 Minuten Kartenzeit über 33 Karten. Das Konzept schätzt „~20–60 USD je
Sprint"; zwei Sprints kosteten **9,35 USD** — deutlich darunter. Aber **ein
Feature verbrauchte 63 %**: 2FA, mit vier Prüfzyklen, drei Zeitüberschreitungen
und mehreren Netzausfällen. Teuer wurde die bauende Rolle nicht durch das Modell,
sondern durch die Zahl der Anläufe.

## Bilanz von Phase 2

Alle drei Nachweise aus Kapitel 12 sind grün, deterministisch geprüft:
15 echte (Schätzung, Ist)-Paare in zwei Sprint-Reports, das erste Release durch
das Release-Gate, und eine Schätzgüte-Baseline, die eine **Reihe** ist und kein
Einzelwert.

Was an diesem Lauf trägt, ist wieder nicht die Menge der Artefakte, sondern die
Verteilung der Fehler. Von den vierzehn Befunden lagen **neun in meinem eigenen
Werkzeug**: der unbekannte Iterations-Deckel, der prozessbaum-blinde Wachhund,
die fehlende `.env` im Worktree, der Hook, der in keinem Worktree existierte, der
selbst-blockierende Riegel, der übergriffige Vault-Linter, der Estimator ohne
Eltern-Beziehung, der stale Dev-Server — und viermal dieselbe Fehlerklasse: ein
Leser, der eine Datenform annahm und nie gegen echte Daten gelaufen war
(`metadata` auf Karten- statt Laufebene, flache gegen verschachtelte Schätzung,
Gate-Antwort in der Payload statt im Kommentar, `tail -1` statt Summe über sieben
Pakete). Der letzte davon stand im grünen Phase-2-Nachweis selbst und meldete
111 statt 613.

Zwei Befunde betrafen die Arbeit der Modelle, und beide fand der Reviewer: die
biome-Verstöße und eine Falschbehauptung im `metadata`. Drei Befunde waren
Bibliotheks- oder Testmängel im Produkt, alle drei von der Organisation selbst
gefunden und behoben.

Und dreimal hat die Organisation **den CEO korrigiert** — beim Kaltstart (meine
Diagnose „API" gegen die gemessene „Client-Vite"), bei der AK8-Metrik (mein
Zahlen-Vorschlag gegen ein Kriterium, das die überschriebene Fläche misst) und
bei einer Roadmap-Prämisse (Score 22,5 für einen Bruch, den die Codebasis
teilweise widerlegte). Jedes Mal mit Messung oder Argument, nie mit Meinung. Das
ist der Teil, der sich nicht aus einem Kartentext ergibt.

Ein Punkt bleibt offen und rot, bewusst: `check-sprint.sh S1` meldet weiterhin
ein zerrissenes Paar auf `t_4f601104`, der ersten, verweigerten Merge-Karte. Sie
hat ihre Schätzung wirklich nicht mitgenommen. Die Ursache ist bekannt und
strukturell behoben — aber dem Prüfer das Verzeihen zu lehren wäre der teuerste
Fehler, den man an einem Riegel machen kann.
