# Scout-Bericht: x

Ausgewertet: 3 Dateien unter sources/x
Kandidaten: 2

## Sub-Agenten greifen ab vielen Tools im Kontext das falsche Werkzeug (oder gar keins)

- **behauptung:** Sobald viele MCP-Server bzw. Werkzeuge im Kontext liegen, greifen die Sub-Agenten das falsche Werkzeug oder gar keins — der Haupt-Agent kommt damit klar, die Sub-Agenten kippen; keine Doku nennt eine Grenze.
- **quellen:**
  - `2026-08-03-subagenten-mcp.md` — @mkirsch_dev (x), 2026-08-03 — „Drei Stunden verbrannt. Meine Sub-Agenten bekamen die Aufgabe einfach nicht hin — sie haben stumpf das falsche Werkzeug gegriffen oder gar keins."
  - `2026-08-03-subagenten-mcp.md` — @mkirsch_dev (x), 2026-08-03 — „Ab ungefaehr 60 Werkzeugen im Kontext kippt es. Der Haupt-Agent kommt damit klar, die Sub-Agenten nicht."
  - `2026-08-03-subagenten-mcp.md` — @mkirsch_dev (x), 2026-08-03 — „Niemand sagt dir das. In keiner Doku steht eine Zahl."
- **warum_relevant:** Konkreter, aktueller Schmerz mit drei verlorenen Stunden und einem kaputten Ablauf. Eine unabhaengige Stimme; Die genannte Grenze „ab ungefaehr 60 Werkzeugen" ist eine Schaetzung des Autors aus der Quelle und keine dokumentierte Spezifikation.
- **loesbar_oder_erklaerbar:** erklaeren — ein Agent kann erklaeren, warum Sub-Agenten bei vielen Tools kippen, und bauen, wenn er die Tool-Anzahl im Kontext sichtbar machen oder begrenzen kann.
- **loesungsluecke:** Es gibt keine dokumentierte Zahl/Grenze („In keiner Doku steht eine Zahl") und kein benanntes Werkzeug, das die aktuelle Tool-Anzahl im Kontext anzeigt oder Sub-Agenten davor schuetzt.
- **strategische_passung:** mittel — betrifft Nutzer mit vielen MCP-Servern wie den Autor; fuer das Publikum des Kanals naheliegend, aber nur eine Stimme als Beleg.

## Die Erweiterung liest eine andere config.toml, als die IDE-Oberflaeche schreibt — „approve required" wird ignoriert

- **behauptung:** Die IDE-Erweiterung liest eine andere config.toml als die IDE-Oberflaeche schreibt (zwei Pfade, ein Name, keine Warnung; unter WSL noch ein dritter), wodurch Einstellungen wie „approve required" nicht greifen, der Agent ohne Rueckfrage schreibt und es kein Werkzeug gibt, das zeigt, welche Datei gewinnt.
- **quellen:**
  - `2026-08-05-config-pfad.md` — @tnowak (x), 2026-08-05 — „Ich habe in der IDE-Erweiterung sauber 'approve required' gesetzt. Der Agent hat trotzdem ohne Rueckfrage geschrieben."
  - `2026-08-05-config-pfad.md` — @tnowak (x), 2026-08-05 — „Nach zwei Tagen Suche: die Erweiterung liest eine ANDERE config.toml als die IDE-Oberflaeche sie schreibt. Zwei Pfade, ein Name, keine Warnung. Unter WSL kommt noch ein dritter dazu."
  - `2026-08-05-config-pfad.md` — @tnowak (x), 2026-08-05 — „Es gibt kein Werkzeug, das dir sagt, welche Datei tatsaechlich gewinnt."
- **warum_relevant:** Konkreter Schmerz mit zwei verlorenen Tagen; zusaetzlich sicherheitsrelevant, weil die Approve-Vorgabe des Nutzers umgangen wird — der Agent fuehrt Aktionen ohne Rueckfrage aus, obwohl der Nutzer es verboten hat. Eine unabhaengige Stimme.
- **loesbar_oder_erklaerbar:** bauen — ein Agent kann ein Werkzeug bauen, das die laufenden Konfig-Pfade auflistet und anzeigt, welche Datei tatsaechlich gewinnt, oder eine Warnung bei konkurrierenden Pfaden erzeugen.
- **loesungsluecke:** Es gibt kein Werkzeug, das den effektiv geladenen Konfig-Pfad gegenueber dem von der Oberflaeche geschriebenen sichtbar macht; keine Warnung bei mehreren gleichnamigen config.toml an verschiedenen Pfaden.
- **strategische_passung:** hoch — betrifft grundlegende Konfiguration und Sicherheitsverhalten (Approve-Gate) und ist fuer viele IDE-Nutzer einschliesslich WSL-Umgebungen relevant; eine Stimme als Beleg.
