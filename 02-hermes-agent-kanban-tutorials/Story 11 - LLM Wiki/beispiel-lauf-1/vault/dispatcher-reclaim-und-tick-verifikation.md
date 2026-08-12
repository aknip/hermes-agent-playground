# Verifikation: dispatcher-reclaim-und-tick

Itemschema: `vault/dispatcher-reclaim-und-tick.md` (Score 85, Status triage)
Quellen: `sources/releases/changelog-0.20.1.md`, `sources/releases/changelog-0.20.2.md`
Lane: verifikation

**Quellenranking:** beide Q (0.20.1, 0.20.2) sind offizielle Hermes-Agent-Patch-Changelogs
(GitHub Releases). Das ist die höchstwertige Quellenklasse dieser Bahn; die drei
Teilaussagen stammen direkt aus diesem Quelltyp. Keine Assertion/Ankündigung dahinter,
keine Abschwächung nötig.

**Modellalarm zur lokalen Installation:** Die lokale Hermes-Installation ist v0.20.0
(`hermes --version` → "Hermes Agent v0.20.0 (2026.8.3)"), sie predatet beide zitierten
Patches. Die geänderten Dispatcher-Verhalten aus 0.20.1/0.20.2 sind hier also NICHT
beobachtbar; lokal wurde nur geprüft, was bezüglich v0.20.0 prüfbar war (siehe
Teilaussage 3). Verdict je Teilaussage basiert auf dem Changelog-Wortlaut.

Drei Dinge werden durchgängig getrennt: was die Quelle sagt / was lokal verifiziert
wurde / was gefolgert wird.

---

## Teilaussage 1 — Claim-Reclaim ist idempotent (0.20.1), verhindert Doppel-Spawn

**Urteil: VERIFIZIERT**

**Was die Quelle sagt** (changelog-0.20.1.md, Abschnitt "## Behoben", dritter Bullet,
Zeilen 22–24):

> "- **Kanban / Dispatcher:** Ein Claim, dessen Worker ohne `kanban_heartbeat`
>   lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt
>   gespawnt. Der Reclaim ist jetzt idempotent."

Wörtlich deckt der Changelog die Teilaussage mit exakt derselben Präzision ab: (a) das
Fehlerbild ist "Worker ohne heartbeat → doppelt eingesammelt und Karte doppelt
gespawnt", (b) die Korrektur ist "Reclaim ist jetzt idempotent". Die Itemschema-Formulierung
"verhindert Doppel-Spawn bei fehlendem heartbeat" ist keine Aufschärfung des Quelltexts —
jedes Element (Fehlersymptom, Ursache "ohne heartbeat", Behebung "idempotent") steht so
im Changelog.

**Was ich verifiziert habe:** Den Wortlaut direkt aus `changelog-0.20.1.md` (Zeilen 22–24)
gelesen; keine Diskrepanz zwischen Itemschema-Behauptung und Quelltext. Lokal nicht
beobachtbar (Installation v0.20.0 predatet den Fix), daher kein lokaler Test möglich.

**Was ich folgere:** Als 0.20.1-Patchverhalten belegt. Der Begriff "idempotent" wird
dort nicht formal definiert; die Aussage "Reclaim ist jetzt idempotent" i.S.v. "derselbe
stale Claim wird nicht mehrfach (re)eingesammelt" wird durch das beschriebene Fehlerbild
getragen. Eine Verifikation gegen tatsächlich laufenden 0.20.1+-Code wäre der einzige
darüber hinausgehende Schritt, ist aber durch die Quellenklasse (offizieller Changelog)
nicht zwingend.

---

## Teilaussage 2 — Nach `hermes pause` bricht ein laufender Tick nach dem aktuellen Spawn ab (0.20.2)

**Urteil: VERIFIZIERT**

**Was die Quelle sagt** (changelog-0.20.2.md, Abschnitt "## Behoben", vierter Bullet —
"**Gateway:**", Zeilen 27–28):

> "- **Gateway:** Nach `hermes pause` beendete ein bereits laufender Tick seine
>   Spawns noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab."

Die Teilaussage deckt den Changelog exakt ab: Vorher "beendete/erledigte der Tick seine
Spawns noch", jetzt "bricht er nach dem aktuellen Spawn ab". Itemschema: "bricht ein
bereits laufender Tick nach dem aktuellen Spawn ab" — identische Präzision, keine
Aufschärfung.

**Was ich verifiziert habe:** Wortlaut aus `changelog-0.20.2.md` (Zeilen 27–28) gelesen.
Lokal nicht beobachtbar (Installation v0.20.0 predatet 0.20.2).

**Was ich folgere:** Belegt als 0.20.2-Gateway-Verhalten. Hingewiesen sei auf die
Zuschreibung: Die Bahn-Karte schreibt das Thema "gateway-und-dispatcher" zu; der
Changelog führt diese Änderung unter "**Gateway:**", nicht unter Kanban. Das ist eine
Beobachtung zur Zuordnung, kein Widerspruch zur inhaltlichen Aussage — der Tick ist der
Dispatcher-Tick im Gateway, und die heartbeat/reclaim-Zwillinge im Systemtext beschreiben
denselben Mechanismus.

---

## Teilaussage 3 — `kanban.dispatch_stale_timeout_seconds` Default bleibt 14400, ist aber pro Profil überschreibbar (0.20.2)

**Urteil: VERIFIZIERT**

**Was die Quelle sagt** (changelog-0.20.2.md, Abschnitt "## Geändert", zweiter Bullet,
Zeilen 34–35):

> "- Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400,
>   ist aber jetzt pro Profil überschreibbar."

Beide Hälften — "Default bleibt 14400" und "jetzt pro Profil überschreibbar" — stehen
wörtlich im Quelltext mit exakt der Präzision der Itemschema-Formulierung.

**Was ich verifiziert habe (lokal, an v0.20.0):**
- Default 14400 bestätigt: `hermes_cli/config_defaults.py` Zeile 2398 liefert
  `"dispatch_stale_timeout_seconds": 14400`; zusätzlich steht in `~/.hermes/config.yaml`
  (Zeile 437) und in `~/.hermes/profiles/developer/config.yaml` (Zeile 437) jeweils
  `dispatch_stale_timeout_seconds: 14400`.
- Das greift lokal auch: `hermes config get kanban` zeigt `dispatch_stale_timeout_seconds: 14400`.
- Lesepfad in v0.20.0: `gateway/kanban_watchers.py` Zeile 1019→1023 lädt `cfg` global
  (`_load_config()`) und liest `kanban_cfg.get("dispatch_stale_timeout_seconds", 0)`
  (Zeile 1120). In der installierten 0.20.0 ist damit KEIN pro-Profil-Override sichtbar;
  der "pro Profil überschreibbar"-Teil ist eine 0.20.2-Neuerung und lokal nicht
  beobachtbar.

**Was ich folgere:** Die "Default bleibt 14400"-Hälfte ist lokal (v0.20.0) verifiziert.
Die "pro Profil überschreibbar"-Hälfte ist durch den offiziellen 0.20.2-Changelog
belegt, aber als Verhalten nicht direkt beobachtbar, da die Installation den Patch
nicht enthält. Kein Widerspruch zwischen lokalem Zustand und Changelog — lokale 0.20.0
darf den 0.20.2-Override schlicht noch nicht haben.

---

## Zusammenfassung

| # | Teilaussage | Urteil |
|---|-------------|--------|
| 1 | Reclaim idempotent, verhindert Doppel-Spawn (0.20.1) | verifiziert |
| 2 | Tick bricht nach `hermes pause` nach aktuellem Spawn ab (0.20.2) | verifiziert |
| 3 | `dispatch_stale_timeout_seconds` Default 14400 bleibt, pro Profil überschreibbar (0.20.2) | verifiziert (Default-Hälfte lokal; Override-Hälfte per Changelog) |

Alle drei Teilaussagen stammen aus dem offiziellen Changelog (höchste Quellenklasse),
und die Itemschema-Formulierungen schärfen keinen der Quelltexte auf. Die einzige
Wiederbetätigungsschwäche: Diese Installation (v0.20.0) predatet beide Patches — kein
Verhalten konnte am laufenden System beobachtet werden. Wer die Aussagen am Code
abklopfen will, braucht eine Hermes-Installation ≥ 0.20.2.