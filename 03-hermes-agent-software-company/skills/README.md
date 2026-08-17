# Profil-lokale Skills der ESF

Die Unterverzeichnisse sind **Profilnamen**, nicht Skillnamen:
`skills/<profil>/<skill>/SKILL.md`. `setup.sh` kopiert jedes davon nach
`~/.hermes/profiles/<profil>/skills/`. Ein Profil sieht nur, was seine Rolle
braucht — das ist der Flotten-Hebel aus Kapitel 4 des Konzepts.

## Herkunft

Die Skills stammen aus [obra/superpowers](https://github.com/obra/superpowers)
(MIT, Copyright (c) 2025 Jesse Vincent), Version **6.3.0**, eingesammelt mit
`./vendor-superpowers.sh`. Der Lizenztext liegt als
[`LICENSE.superpowers`](LICENSE.superpowers) bei.

Kopiert wird jeweils `SKILL.md` plus die inhaltlichen Begleitdateien.
Nicht kopiert werden Testdruck-Dateien, Entstehungsprotokolle und der
Node-Server der Brainstorming-Sichtbegleitung — Claude-Code-Werkzeug ohne
Entsprechung im Hermes-Worker.

## Das Tool-Mapping

In jedem Profilordner liegt `HERMES-TOOLS.md`: Die Superpowers-Skills sind
für Claude Code geschrieben und nennen dessen Werkzeuge. Die Datei übersetzt
sie auf das Hermes-Toolset. Vorbild ist `hermes-tools.md` aus dem
Community-Port
[satangel2222/obra-superpowers-hermes](https://github.com/satangel2222/obra-superpowers-hermes);
sie ist hier eigenständig geschrieben und gegen v0.20.0 gehalten.

## Zuordnung

| Profil | Skills |
|--------|--------|
| `esf-product-manager` | brainstorming · verification-before-completion |
| `esf-architect` | writing-plans · dispatching-parallel-agents · brainstorming |
| `esf-chief-of-staff` | writing-plans · dispatching-parallel-agents · brainstorming |
| `esf-dev-a`, `esf-dev-b` | test-driven-development · executing-plans · systematic-debugging · using-git-worktrees · receiving-code-review |
| `esf-reviewer` | requesting-code-review · verification-before-completion |
| `esf-qa-release` | verification-before-completion · systematic-debugging · finishing-a-development-branch |

Die vier übrigen Profile (`esf-market-scout`, `esf-market-analyst`,
`esf-estimator`, `esf-controller`) bekommen bewusst keine Superpowers-Skills:
Ihre Arbeit ist Erkennen, Bewerten und Messen, nicht Bauen. Ihre Präzision
wohnt in der `SOUL.md`.
