# Bahn SEITEN-ABGLEICH — Item skills-system

Route-Klassifikation fuer das Item `skills-system` (score 88, status recherche).
Frage dieser Bahn: Welche Seiten sind betroffen, und wo steht was bereits in
welcher Genauigkeit?

## Ausgangslage

- Die Seite `wiki/pages/skills-system.md` existiert **nicht**.
- `wiki/index.md` (Zeile 21, Abschnitt `## Automatisierung`) verlinkt bereits
  `[[skills-system]] — Skills, Aufloesung, profil-lokale Skills`. Das ist ein
  **Stub-Link**: ein `[[slug]]` ohne existierende Zielseite. Der AGENTS.md-Vertrag
  (Abschnitt 3) stuft einen solchen Link als Linter-Fehler ein. Kein anderes
  `[[skills-system]]` existiert im Index oder in den Seiten.

## Betroffene / betroeffene Seiten

| Seite | Quelle-Zeile | Was dort steht | Genauigkeit |
|---|---|---|---|
| `wiki/pages/skills-system.md` | — | existiert nicht | **fehlt** |
| `wiki/index.md` | Zeile 21 | `[[skills-system]] — Skills, Aufloesung, profil-lokale Skills` | Stub-Link, keine Inhaltsaussage |
| `wiki/pages/profile-system.md` | Zeile 29 (`skills/<name>/SKILL.md`), Zeilen 13–17 (Kurzfassung: „eigene Skills") | erwaehnt, dass Profile eigene Skills haben und dass `skills/<name>/SKILL.md` eine Profildatei ist | **unvollstaendig** (Topic-Mention, keine der sechs Mechanik-Aussagen) |
| `wiki/pages/kanban-board.md` | Zeile 59–60 | „…mit der Skill `sdlc-review`…" | Topic-Mention (Skill-Name), keine Mechanik |
| `wiki/pages/release-historie.md` | — | keine Skillinhalte | nicht betroffen |
| `wiki/pages/memory-system.md` | — | keine Skillinhalte | nicht betroffen |
| `wiki/pages/cron-und-zeitplan.md` | — | keine Skillinhalte | nicht betroffen |
| `wiki/pages/kanban-block-semantik.md` | — | keine Skillinhalte | nicht betroffen |
| `wiki/pages/gateway-und-dispatcher.md` | — | keine Skillinhalte | nicht betroffen |

## Die sechs Skill-Aussagen vs. Wissensbasis

Geprueft gegen die Quelle `sources/transcripts/2026-08-07-skills-system.md`
(Tonbi's AI Garage, 2026-08-07, Bezug Hermes Agent 0.20.0). Die sechs Aussagen
(gesammelt in `vault/skills-system.md`, Frontmatter `gebuendelt_aus`):

1. **Struktur einer Skill** — „Eine Skill ist ein Verzeichnis mit einer
   `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`,
   darunter Markdown." (Z. 15–18). Keine Registrierung/Installation; das
   Verzeichnis wird gefunden. → nirgends in gleicher Genauigkeit.
2. **Drei Ablageorte** — global `~/.hermes/skills/`; profil-lokal
   `~/.hermes/profiles/<name>/skills/` (in `skills list` als `local`); eingebaut.
   (Z. 20–24). → `profile-system.md` Z. 29 nennt nur den profil-lokalen Pfad,
   nicht die Reihenfolge/global/eingebaut. Ablageorte also **nicht** abgedeckt.
3. **Lade-Mechanik** — „nur die `description` landet ungefragt im Kontext. Der
   Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die
   Skill relevant ist." (Z. 26–30). → nirgends.
4. **`hermes kanban create … --skill <name>`** erzwingt eine Skill im
   Worker-Kontext. (Z. 32–36). → nirgends; `kanban-board.md` nennt SkILLs/
   Kanban-Werkzeuge, aber nicht `--skill` bei `kanban create`.
5. **`hermes -p <profil> skills list`** zeigt Aufloesung mit Herkunft
   (`hub-installed`, `builtin`, `local`) und `enabled`/`disabled`. (Z. 38–41).
   → nirgends.
6. **Skill vs. MCP** — Skill ist Text (kostet Kontext); MCP-Server ist Werkzeug
   (kostet Kontext **und** Werkzeug-Slots). (Z. 43–47). → nirgends.

Die einzige Stelle, die das Themengebiet „Skills" ueberhaupt beruehrt, ist
`profile-system.md` (Z. 13–17 und Z. 29). Sie stellt fest, dass Profile eigene
Skills haben und `skills/<name>/SKILL.md` eine Profildatei ist — das ist eine
Topic-Mention, **keine** Abdeckung der sechs Mechanik-Aussagen in gleicher
Genauigkeit. Nach AGENTS.md-Vertrag (Abschnitt 7 / ingest.yaml Z. 102–106) ist
„das Thema kommt vor" keine Abdeckung.

## Urteil je Aussage

| Aussage | Stand in der Wissensbasis | Klassifikation |
|---|---|---|
| 1 Struktur `SKILL.md` | fehlt | fehlt |
| 2 drei Ablageorte | `profile-system.md` nennt nur profil-lokal | unvollstaendig (nur profillokal; global/eingebaut fehlen) |
| 3 Lade-Mechanik (description im Kontext) | fehlt | fehlt |
| 4 `kanban create --skill` | fehlt | fehlt |
| 5 `skills list` Herkunft/enabled | fehlt | fehlt |
| 6 Skill vs. MCP-Kosten | fehlt | fehlt |

Eine ganze, bereits verlinkte Seite fehlt; die sechs Mechanik-Aussagen stehen in
keiner der sieben vorhandenen Seiten in gleicher Genauigkeit. Es gibt keinen
Widerspruch und keine verstaerkte Aussage.

## Was die Klassifikation entscheidet

`fehlt` → Route `neue_seite` (ingest.yaml Z. 171). Passend: die Zielseite
existiert nicht, nur ein Index-Stub, und alle sechs Aussagen brauchen einen
Platz. Keine bestehende Seite muesste korrigiert oder ergaenzt werden, damit die
Aussagen einen korrekten Ort haben — eine neue `skills-system.md` ist der
richtige Ort.

wissensstand: fehlt
