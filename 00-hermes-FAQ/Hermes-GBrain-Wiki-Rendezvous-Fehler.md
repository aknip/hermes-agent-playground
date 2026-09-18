# „Provider error — Die Werkzeugaufrufe der CLI sind nicht am Rendezvous angekommen"

**Stand:** 17.09.2026 · **Analysiert, reproduziert und behoben.** Der Fix liegt in
`04-hermes-claude-code-provider/plugin/client.py` und ist in alle Homes ausgerollt.

Belegt an den Logs des Profils `wiki-llm`, an der gespeicherten Sitzung in dessen
`state.db`, an vier eigenen Läufen gegen die echte Claude-Code-CLI **2.1.274** und an
einer Regressionsprobe ohne Modell. Rohdaten und Messwerte im
[Run-Protokoll, Lauf 14](../04-hermes-claude-code-provider/RUN-PROTOKOLL.md#lauf-14--der-fehler-aus-dem-wiki-profil-ein-tool_use-der-nie-ankommt).

**Ausgangsfrage:** Im Wiki-Profil `wiki-llm` sollte per Chat ein neuer Eintrag ins
GBrain-Wiki aufgenommen werden. Statt dessen kam „Provider error — Die Werkzeugaufrufe
der CLI sind nicht am Rendezvous angekommen". Woran liegt das, und wie geht es weg?

---

## Die Kurzfassung

Der Fehler kommt **nicht** von GBrain, nicht vom Wiki und nicht von Hermes, sondern vom
selbstgebauten Provider-Plugin `claude-code-mcp` — dem Stück, das Claude Code als Modell
hinter dem Profil fährt. Es hielt eine Annahme für selbstverständlich, die nicht stimmt:
dass jeder Werkzeugaufruf, den das Modell ausspielt, auch bei Hermes ankommt.

Was wirklich passiert ist, in vier Schritten:

1. Das Profil `wiki-llm` hat den MCP-Server `gbrain` mit **137 Werkzeugen**. Zusammen mit
   Hermes' eigenen sind das rund 175 — genug, dass Hermes' `tool_search` greift und
   **153 davon zurückstellt**: die CLI bekommt nur 22–25 Werkzeuge zu sehen, der Rest
   soll über die Hülle `tool_call` gerufen werden.
2. Das Modell liest im Ergebnis von `tool_search` einen zurückgestellten Namen — hier
   `mcp__gbrain__takes_search` — und ruft ihn **direkt** auf, statt ihn durch `tool_call`
   zu schicken.
3. Die CLI kennt diesen Namen nicht. Sie beantwortet den Aufruf **selbst**
   (`<tool_use_error>Error: No such tool available: …</tool_use_error>`) und lässt das
   Modell im selben Prozess nachbessern — es ruft dann ein richtiges Werkzeug. Das
   funktioniert; die CLI hat sich selbst erholt.
4. Das Plugin wartete derweil auf die Kennung des **abgewiesenen** Aufrufs, lief nach
   60 s in seine Frist, warf den brauchbaren Aufruf samt Sitzung weg und meldete den
   Fehler. Hermes wiederholte dreimal, jedes Mal dasselbe — dann war der Zug tot.

Aus der Chat-Sicht sah das aus wie „das Wiki ist kaputt". Tatsächlich war es eine zu
starke Annahme im Zwischenstück: **ausgespielt heißt nicht zugestellt.**

## Was behoben wurde

Die Leseschleife des Clients hält nicht mehr beim `tool_use`-Block des Modells an,
sondern bei der **Ankunft am Rendezvous**. Offene Blöcke werden gesammelt; was die CLI
selbst beantwortet hat, fällt still heraus, und das Gespräch läuft weiter. Eine
Abweisung kostet jetzt eine Runde statt des Gesprächs.

Dieselbe abgebrochene Sitzung, mit `--resume` fortgesetzt: vorher 3 von 3 Versuchen tot,
nachher zehn Werkzeugrunden am Stück auf einer residenten Sitzung, saubere Schlussantwort.

Nebenbei ist dabei zweierlei erstmals gemessen worden, was im Provider-Ordner als
ungeprüft stand: die CLI schickt **je Inhaltsblock ein eigenes `assistant`-Ereignis**,
und mehrere Werkzeugaufrufe einer Antwort stellt sie **nacheinander** zu — der nächste
erst, wenn das Ergebnis des vorigen da ist.

## Was jetzt zu tun ist

1. **Hermes neu starten** (Desktop-App bzw. Gateway). Python lädt ein Provider-Plugin
   einmal je Prozess; der laufende Prozess hält sonst weiter die alte Kopie.
2. Danach den Wiki-Eintrag erneut im Chat anstoßen — der abgebrochene Zug ist nicht
   wiederherstellbar, die Nachricht muss noch einmal gestellt werden.

Der Rollout selbst ist erledigt: Root-Home und die Profile `claude-dev`, `developer`,
`orchestrator`, `summarizer`, `wiki-llm` tragen den neuen Stand
(`./install.sh --no-model-picker …`, keine `config.yaml` angefasst).

## Optional: die Fehlgriffe ganz vermeiden

Der Fix macht die Abweisung harmlos, aber sie passiert weiter — jedes Mal eine
verschenkte Runde. Wer sie loswerden will, schaltet die Zurückstellung ab:

```bash
hermes -p wiki-llm config set tools.tool_search.enabled false
```

Dann stehen **alle** Werkzeuge im Satz der CLI, `mcp__gbrain__*` eingeschlossen, und das
Modell kann sie direkt rufen — was es ohnehin versucht. Der Preis sind rund 35.000 Token
Werkzeugschemata in jedem CLI-Prozess (weitgehend Cache-Treffer, aber nicht umsonst).
**Nicht gemessen** — weder die Kosten noch, ob damit wirklich alle Fehlgriffe
verschwinden; deshalb hier als Vorschlag, nicht als Empfehlung.

## Was davon unabhängig ist

Die **PGLite-Sperre** (`database already open through gbrain serve`) ist ein anderer
Befund und bleibt bestehen: siehe
[`Hermes-GBrain-PGLite-Lock.md`](Hermes-GBrain-PGLite-Lock.md). Sie ist in einem der
Prüfläufe aufgetreten — ein zweiter Hermes-Prozess auf demselben Profil bekommt den
`gbrain`-Server nicht angeschlossen, weil die Desktop-App die Datenbank hält. Der
Rendezvous-Fehler trat dabei trotzdem auf und ließ sich prüfen; die beiden haben
nichts miteinander zu tun.
