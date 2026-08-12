---
quelle: web
url: https://reddit.example/r/aiagents/comments/1f2k9x
plattform: Reddit — r/aiagents
datum: 2026-08-04
stimmen: 4
---

# "Sub-Agenten ignorieren Werkzeuge, sobald zu viele MCP-Server laufen"

**OP (u/halbmond):** Sobald ich mehr als vier MCP-Server aktiv habe, faellt die
Trefferquote meiner Sub-Agenten ins Bodenlose. Der Haupt-Agent merkt nichts.

**u/kd_rasmus:** Genau das. Bei mir kippt es zwischen 50 und 70 Werkzeugen.
Ich habe es nachgemessen: 40 Werkzeuge -> 9 von 10 Laeufe gut, 80 Werkzeuge ->
3 von 10.

**u/aniela.p:** Bei uns im Team dasselbe, seit Wochen. Wir dachten erst, es
liegt am Modell.

**u/halbmond:** Loesung gefunden: pro Sub-Agent eine Allow-List setzen, dann
sieht er nur seine sechs Werkzeuge. Geht seit einer Weile, steht aber nirgends
in der Doku — ich habe es aus einem Changelog-Eintrag von vor vier Monaten.

**u/kd_rasmus:** Kann ich bestaetigen. Der Konfigurationsschluessel heisst
nicht so, wie man ihn suchen wuerde.
