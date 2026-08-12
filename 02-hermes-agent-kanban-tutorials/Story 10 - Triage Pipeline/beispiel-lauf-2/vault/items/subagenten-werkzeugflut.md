---
slug: subagenten-werkzeugflut
titel: Werkzeugflut durch zu viele MCP-Server laesst Sub-Agenten Werkzeuge falsch waehlen
status: umsetzung
score: 87
score_breakdown: {haeufigkeit: 23, schmerzintensitaet: 17, loesbar_oder_erklaerbar: 21, loesungsluecke: 12, strategische_passung: 14}
pfad: video
duplikate: [x-1-subagenten-mcp, web-2-werkzeugflut]
---

# subagenten-werkzeugflut

## Kernproblem
Ab einer gewissen Zahl geladener MCP-Werkzeuge im Kontext (~50-80, bzw. ab
~4-7 MCP-Servern) kippt die Trefferquote der Sub-/Unteragenten beim
Werkzeuggebrauch, waehrend der Haupt-Agent unbeeindruckt bleibt.

## Quellen
- `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03 — "Ab ungefaehr 60 Werkzeugen im Kontext kippt es. Der Haupt-Agent kommt damit klar, die Sub-Agenten nicht." (drei Stunden verbrannt)
- `sources/web/youtube-kommentare-agenten-werkzeuge.md` — YouTube, 2026-08-07 — @renkoe (@ilvahn: "kappt bei sieben MCP-Servern", zu viele Werkzeugbeschreibungen im Kontext)
- `sources/web/reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — u/halbmond (>4 MCP-Server), u/kd_rasmus (Messung: 40 Werkzeuge 9/10, 80 Werkzeuge 3/10), u/aniela.p (Team, seit Wochen, hielt es fuer Modellproblem)

## Bewertung
- **haeufigkeit (23/25):** mindestens sechs unabhaengige Stimmen ueber X, YouTube und Reddit bestaetigen denselben Mechanismus; ein Team haelt es seit Wochen fuer ein Modellproblem.
- **schmerzintensitaet (17/20):** akut — Stunden verbrannt, Trefferquote bricht um mehr als die Haelfte ein, wochenlange Fehldiagnose.
- **loesbar_oder_erklaerbar (21/25):** Mechanismus ist benannt und erklaerbar; eine erprobte Umgehung (pro-Sub-Agent-Allow-List) existiert.
- **loesungsluecke (12/15):** keine automatische Werkzeugbegrenzung/-erklaerung des Tools; die vorhandene Umgehung ist schlecht auffindbar und nicht dokumentiert.
- **strategische_passung (14/15):** trifft exakt das Publikum des Kanals (Nutzer von KI-Coding-Agenten mit mehreren MCP-Servern), mehrfach unabhaengig bestaetigt.

**Score: 87/100 — ueber der Schwelle (65), Status: recherche.**

## Bahn: kontext

Frage: Was ist zum Umfeld bereits bekannt — Kontextfenster-Groessen, bekannte
Limits bei Werkzeugzahlen, verwandte Diskussionen?

### Bekannte Limits bei der Werkzeugzahl (aus dem Korpus selbst)
- **Schwelle ~50-80 Werkzeuge im Kontext.** Drei unabhängige Quellen nennen
  denselben Bereich: @mkirsch_dev "ab ungefaehr 60 Werkzeugen im Kontext kippt
  es" (`sources/x/2026-08-03-subagenten-mcp.md`); u/kd_rasmus "kippt es
  zwischen 50 und 70 Werkzeugen" (`sources/web/reddit-subagenten-werkzeugflut.md`).
- **Einzige quantitative Messung im Korpus:** u/kd_rasmus — 40 Werkzeuge -> 9/10
  Laeufe gut, 80 Werkzeuge -> 3/10 (`sources/web/reddit-subagenten-werkzeugflut.md`).
  Das ist der belegbarste Datensatz: Trefferquote faellt von 90% auf 30%.
- **Schwelle in MCP-Servern gemessen:** u/halbmond "mehr als vier MCP-Server"
  (Reddit); @ilvahn "kappt bei sieben MCP-Servern"; @renkoe hat neun (YouTube).
  Also ~4-9 Server, konsistent mit ~50-80 Einzelwerkzeugen.
- **Rollen-Asymmetrie als Kernmerkmal:** alle Quellen stimmen ueberein, dass
  nur die Sub-/Unteragenten kippen, der Haupt-Agent bleibt unbeeindruckt
  (@mkirsch_dev, u/halbmond, @renkoe). Kein Gegenbeispiel im Korpus.

### Kontextfenster-Groessen
- **Keine absoluten Token-/Kontextfenster-Zahlen im Korpus.** Keine Quelle
  nennt eine Context-Window-Groesse (z.B. 8k/32k/128k/200k Token) oder den
  Platzbedarf einzelner Werkzeugbeschreibungen in Tokens. Der Mechanismus ist
  nur qualitativ benannt: @ilvahn "zu viele Werkzeugbeschreibungen im Kontext",
  u/kd_rasmus "Werkzeuge im Kontext". -> Luecke: eine absolute Zahl, die das
  Phaenomen an ein reales Modellfenster bindet, fehlt im gesamten Korpus.

### Verwandte Diskussionen im Vault
- **`vault/items/subagenten-allow-list-unbekannt.md` (archiviert, Score 63):**
  dieselbe Ursache, anderer Winkel — die erprobte Umgehung (pro Sub-Agent eine
  Werkzeug-Allow-List) existiert, ist aber nirgends dokumentiert und der
  Konfigurationsschluessel heisst anders als erwartet (u/halbmond: "steht aber
  nirgends in der Doku — ich habe es aus einem Changelog-Eintrag von vor vier
  Monaten"; u/kd_rasmus: "Der Konfigurationsschluessel heisst nicht so, wie man
  ihn suchen wuerde"). Direkte thematische Nachbarin; als eigenstaendiges Thema
  zu duenn belegt, fuer die Werkzeugflut aber die existierende Loesungsbasis.
- **`vault/items/config-pfade-mehrdeutig.md` (recherche, Score 81):** anderes
  Thema (welche config.toml wirkt), aber gemeinsamer Unterbau mit demselben
  Publikum und derselben Luecken-Struktur — Funktion existiert, wird aber
  umgangen, weil die wirksame Konfiguration/der Mechanismus unklar ist.
  Nebenbefund fuer andere Bahnen: beide Items teilen das Muster "existierende
  Funktion, schlecht bis gar nicht auffindbar".

### Fazit fuer die Bahn
- Der Tool-Count-Limit (~50-80 Werkzeuge, ~4-9 MCP-Server) ist im Korpus
  mehrfach unabhaengig belegt und quantitativ einmal gemessen (90% -> 30%).
- Absolute Kontextfenster-Groessen sind NICHT belegt (Luecke): das Phaenomen
  ist nur an die relative Werkzeugzahl, nicht an ein Token-Budget gebunden.
- Die existierende Umgehung (Allow-List) ist bekannt und belegt, aber
  undokumentiert — Anknuepfungspunkt fuer die Loesungs-Bahn.

## Bahn: loesungs-audit

Frage: Was loest das heute schon?

Befund: Es GIBT bereits eine funktionierende Loesung — die pro-Sub-Agent
Allow-List (Werkzeugbegrenzung je Unteragent), durch die ein Sub-Agent nur
noch seine wenigen benoetigten Werkzeuge sieht.

Belege:
- Reddit r/aiagents 2026-08-04, u/halbmond: "Loesung gefunden: pro Sub-Agent
  eine Allow-List setzen, dann sieht er nur seine sechs Werkzeuge. Geht seit
  einer Weile" — bestaetigt durch u/kd_rasmus: "Kann ich bestaetigen."
- YouTube 2026-08-07, @ilvahn: "Gib jedem Unteragenten nur die Werkzeuge, die
  er braucht. Dann laeuft es wieder." (sources/web/youtube-kommentare-agenten-werkzeuge.md, Zeilen 20-22)

Die Loesung funktioniert also (Quelle belegt Funktion, nicht nur Existenz).
Der zentrale Mangel ist NICHT Funktion, sondern Auffindbarkeit/Dokumentation:
- Reddit u/halbmond: "steht aber nirgends in der Doku — ich habe es aus einem
  Changelog-Eintrag von vor vier Monaten" (Z. 22-23)
- Reddit u/kd_rasmus: "Der Konfigurationsschluessel heisst nicht so, wie man
  ihn suchen wuerde" (Z. 25-26)
- Item-Bewertung selbst (loesungsluecke, 12/15): "keine automatische
  Werkzeugbegrenzung/-erklaerung des Tools; die vorhandene Umgehung ist
  schlecht auffindbar und nicht dokumentiert."

Einordnung gegen route.tabelle:
- fehlt? nein — Allow-List existiert und wird in zwei unabhaengigen Quellen als funktionierend belegt.
- kaputt? nein — Quellen bestaetigen, dass sie laeuft ("geht seit einer Weile").
- gut? nein — sie ist nicht leicht zu finden, Mehrheit findet sie gar nicht, es gibt keine automatische Begrenzung.
- verwirrend / schlecht_erklaert: die Loesung ist da und funktioniert, aber
  mies dokumentiert und der Schluesselname ist nicht suchbar → **schlecht_erklaert**.

Nebenbefund (nicht meine Bahn): Item haelt es fuer ein Modellproblem (u/aniela.p,
Seite 3, Z. 18-20) — eigentlich ein Kontext-/Konfigurationsproblem. Betrifft
eher Bahn "quellen-pruefen"/"kontext".

loesungsqualitaet: schlecht_erklaert

## Bahn: quellen-pruefen

**Frage:** Ist der Schmerz echt, belegbar und nicht ein Einzelfrust?

**Urteil: JA — echt, mehrfach unabhaengig belegt, kein Einzelfrust.**

### Unabhaengige Stimmen (6, ueber 3 Plattformen)
1. `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X): ~60 Werkzeuge im Kontext kippt es; Haupt-Agent ok, Sub-Agenten nicht; 3 Stunden verbrannt; "in keiner Doku steht eine Zahl".
2. `sources/web/youtube-kommentare-agenten-werkzeuge.md` — @renkoe: Unteragenten benutzen Werkzeuge nicht, Haupt-Agent problemlos; 9 MCP-Server.
3. ebd. — @ilvahn: kappte bei 7 MCP-Servern, "zu viele Werkzeugbeschreibungen im Kontext"; bestaetigt Umgehung (pro Unteragent nur noetige Werkzeuge).
4. `sources/web/reddit-subagenten-werkzeugflut.md` — OP u/halbmond: ab >4 MCP-Servern faellt Trefferquote der Sub-Agenten, Haupt-Agent merkt nichts.
5. ebd. — u/kd_rasmus: **quantitative Messung** 40 Werkzeuge -> 9/10, 80 Werkzeuge -> 3/10 (Einbruch > Haelfte).
6. ebd. — u/aniela.p: Team, seit Wochen, haelt es fälschlich fuer Modellproblem.

### Beleglage
- **Mechanismus konsistent** quer durch alle Stimmen: Schwelle ~50-80 Werkzeuge / ~4-7 MCP-Server; Symptom ist spezifisch fuer Sub-/Unteragenten, Haupt-Agent bleibt unbeeindruckt; Ursache = zu viele Werkzeugbeschreibungen im Kontext.
- **Unabhaengigkeit hoch:** 6 verschiedene Nutzerkennungen, 3 getrennte Plattformen, separate Threads; keine Anzeichen von Abkuenftigkeit (kein Textueberlapp zwischen Quellen).
- **Quantitativ untermauert** (u/kd_rasmus: 40->9/10, 80->3/10) — nicht nur anekdotisch.
- **Auswirkung real:** verbrannte Stunden (mkirsch), wochenlange Fehldiagnose (aniela.p), alltaeglicher Block fuer Konfigurationen mit mehreren MCP-Servern.

### Gap / Einschraenkung
- **Verlinkung nicht live verifizierbar:** alle URLs sind Platzhalter-Domains (`x.example` / `youtube.example` / `reddit.example`). Die Inhalte sind redigierte Quellenauszuege, keine pruefbaren Originalseiten; externe Nachpruefung der Threads ist ohne echte URLs nicht moeglich.
- Messung (u/kd_rasmus) ist eine einmalige informelle Messung, kein kontrollierter Labortest; keine unabhängige Zweitmessung in derselben Grosse.
- **Kein Gegenbefund erhoben** (niemand berichtet das Gegenteil); das schwaerzt die Beleglage nicht, ist aber eine fehlende Gegenprobe.

### Nebenbefund (andere Bahnen)
- Reddit u/halbmond + u/kd_rasmus nennen eine **pro-Sub-Agent-Allow-List** als Umgehung, die "nirgends in der Doku steht" bzw. deren Konfigurationsschluessel "nicht so heisst, wie man ihn suchen wuerde" — relevant fuer die Bahn loesungsluecke/doku. In `sources/web/reddit-subagenten-werkzeugflut.md`, Zeile 21-26.
