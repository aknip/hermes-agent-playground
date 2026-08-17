# ESF — Umsetzungsplan Phase 0 und Phase 1

Umsetzung von Kapitel 12 des Konzepts (`KONZEPT.html`) gegen das Ziel-Repo
`../04-hermes-agent-software-company-test-kaneo` (Kaneo v2.19.1).

**Modell für diesen Testlauf:** `deepseek/deepseek-v4-flash-0731` über OpenRouter
— alle drei Modell-Tiers (hoch / mittel / günstig) zeigen in diesem Lauf auf
denselben Slug. Die Tier-Struktur bleibt als Shell-Variable erhalten, damit ein
späterer Lauf sie ohne Umbau differenzieren kann.

**CEO-Rolle:** in diesem ersten Testlauf übernimmt Claude die CEO-Rolle und
beantwortet alle Gates selbst (`./gate.sh`). Jede Antwort wird in
`RUN-PROTOKOLL.md` mit Begründung protokolliert.

## Was dieses Verzeichnis liefert

Die ESF ist mit diesem Repo jederzeit neu installier- und deinstallierbar —
dieselbe Bauform wie die Stories in `02-hermes-agent-kanban-tutorials/`:

```
setup.sh              Board + 11 Profile + Skills + Vault-Arbeitskopie (idempotent)
teardown.sh           Rückbau; löscht nur .esf-markierte Profile; --keep-profiles
reset-workspace.sh    workspace/ frisch aus seed/ (Wegwerfkopie)
create-onboarding.sh  Phase-1-Analysegraph anlegen (die Startkarten)
pump.sh               manueller Dispatch-Takt (ersetzt das Gateway im Test)
gate.sh               die CEO-Hülle: validierte Verben vor genau einem unblock
install-cron.sh       die vier Betriebs-Skripte takten (--remove baut zurück)
scripts/              tick.sh · monitor.sh · report-gates.sh · ledger-sync.sh
                      merge-riegel.sh · vault-lint.py · check-*.sh
profiles/<name>/      SOUL.md + description.txt je Profil
skills/<profil>/      die profil-lokalen Superpowers-Teilmengen (vendored, MIT)
seed/company/         der Vault-Master (AGENTS.md, cadence.yaml, Struktur)
workspace/            die Wegwerfkopie — gitignored
```

## Reihenfolge (nach Risiko, nicht nach Kapitelfolge)

| # | Schritt | Token? | Nachweis |
|---|---------|--------|----------|
| 1 | `04` als eigenes Git-Repo initialisieren, Baseline committen; Playground-`.gitignore` ergänzen | nein | `git log` in `04` zeigt einen Commit; `git status` im Playground zeigt `04` nicht mehr |
| 2 | Kaneo lokal starten, **eine handgeschriebene** Playwright-Smoke-Spec grün | nein | `pnpm exec playwright test` Exit 0 |
| 3 | Deterministisches Gerüst: Vault-Seed, `cadence.yaml`, Vault-Linter, Merge-Riegel, `gate.sh`, vier Betriebs-Skripte | nein | Linter findet die eingebauten Fehler im Seed; Riegel verweigert bei rotem Test |
| 4 | `setup.sh`: Board `sw-company`, elf `esf-`-Profile, Skills profil-lokal | nein | alle elf `ON DISK = yes` |
| 5 | **Phase-0-Abschluss:** Dummy-Kette Spezifikation→Bau→Review→Riegel; Probe-Gate hält | ja | `dispatch --dry-run` meldet `Spawned: 0`, während das Gate steht |
| 6 | **Phase 1:** Analysegraph auf Kaneo → `codebase.html`, `product.html`, `market.html` | ja | `check-onboarding.sh` |
| 7 | E2E-Ausbau auf dem in Schritt 2 erprobten Gerüst → `journeys.html` | ja | Suite grün, jede Journey im Katalog |
| 8 | Roadmap mit Schätzintervallen → Roadmap-Gate-Karte blockiert | ja | Gate hält, Vorlage vollständig |
| 9 | CEO antwortet (Claude), Gate wird ausgeführt | ja | `check-onboarding.sh` grün |

Erst nach Schritt 5 wird `install-cron.sh` ausgeführt — vorher taktet `pump.sh`
von Hand. Grund: `hermes gateway status` meldet die Service-Definition als stale;
der launchd-Dispatcher ist für diesen Lauf keine verlässliche Vorbedingung.

## Bewusste Festlegungen dieses Laufs

- **Der Vault liegt in `workspace/company/`** und ist ein eigenes Git-Repo
  (aus `seed/company/` erzeugt, gitignored). Story-Invariante: `seed/` ist der
  Master, `workspace/` die Wegwerfkopie.
- **Ein OpenRouter-Key statt elf.** Die Provisioning-API (Key je Profil mit
  USD-Limit) ist im Konzept als *Annahme* markiert und braucht einen
  Provisioning-Key, der hier nicht vorliegt. `provision-keys.sh` existiert,
  meldet die fehlende Voraussetzung und bricht nicht ab; die Kostenzurechnung je
  Rolle bleibt in diesem Lauf offen und steht in `VERIFIKATION.md`.
- **Superpowers werden vendored**, nicht per Plugin installiert: die
  rollenspezifischen Teilmengen liegen unter `skills/<profil>/` und werden von
  `setup.sh` nach `~/.hermes/profiles/<p>/skills/` kopiert — der belegte Weg
  (Stories 10, 11). MIT-Lizenz und Attribution liegen bei.
- **Profil-Präfix `esf-`** plus Markerdatei `.esf` in jedem Profilverzeichnis;
  `teardown.sh` löscht ausschließlich Markiertes.

## Was hier NICHT umgesetzt wird

Phase 2 (Begleiteter Betrieb) und Phase 3 (Dauerbetrieb) aus Kapitel 12 —
sie setzen die Nachweise aus Phase 0/1 voraus.
