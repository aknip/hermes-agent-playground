#!/usr/bin/env bash
#
# ESF — Superpowers-Skills profil-lokal einsammeln
# ================================================
#
# Wartungswerkzeug, kein Teil des Setups. Es kopiert die rollenspezifischen
# Teilmengen von obra/superpowers nach skills/<profil>/<skill>/ INS REPO —
# von dort verteilt setup.sh sie nach ~/.hermes/profiles/<p>/skills/.
#
# Warum vendored und nicht global installiert (Kapitel 6 des Konzepts):
#
#   Eine globale Installation gaebe jedem Profil alle vierzehn Skills. Dann hat
#   man keine Flotte, sondern elf Kopien desselben Agenten. Der Decomposer
#   routet ueber die Beschreibung, und die schaerft sich nur, wenn ein Profil
#   wirklich nur seine eigenen Skills kennt.
#
#   Ausserdem ist der profil-lokale Weg der einzige gegen v0.20.0 belegte
#   (Stories 10, 11). `hermes plugins install obra/superpowers --enable` steht
#   im Original-README, ist hier aber ungeprueft.
#
# Was NICHT mitkopiert wird: Testdruck-Dateien (test-pressure-*.md),
# Entstehungsprotokolle (CREATION-LOG.md) und der Node-Server der
# Brainstorming-Sichtbegleitung — Claude-Code-Werkzeug, das ein Hermes-Worker
# nicht starten kann.
#
# Quelle (Standard): das lokal installierte Superpowers-Plugin.
# Anderer Ort:       ./vendor-superpowers.sh /pfad/zu/superpowers/skills
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SRC="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
SRC="${1:-}"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

if [ -z "$SRC" ]; then
    # Ohne Argument: die hoechste installierte Version nehmen.
    [ -d "$DEFAULT_SRC" ] || {
        echo "FEHLER: $DEFAULT_SRC gibt es nicht."
        echo "        Gib den Skill-Ordner von obra/superpowers als Argument an."
        exit 1
    }
    VERSION="$(ls -1 "$DEFAULT_SRC" | sort -V | tail -1)"
    SRC="$DEFAULT_SRC/$VERSION/skills"
    LICENSE_SRC="$DEFAULT_SRC/$VERSION/LICENSE"
else
    VERSION="unbekannt"
    LICENSE_SRC="$(dirname "$SRC")/LICENSE"
fi
[ -d "$SRC" ] || { echo "FEHLER: '$SRC' ist kein Verzeichnis."; exit 1; }

say "Quelle: $SRC  (Version $VERSION)"

# ---------------------------------------------------------------------------
# Die Zuordnung aus Kapitel 6 des Konzepts.
# Format:  <profil> : <skill>[,<skill>…]
# ---------------------------------------------------------------------------
ZUORDNUNG=(
  "esf-product-manager  : brainstorming,verification-before-completion"
  "esf-architect        : writing-plans,dispatching-parallel-agents,brainstorming"
  "esf-chief-of-staff   : writing-plans,dispatching-parallel-agents,brainstorming"
  "esf-dev-a            : test-driven-development,executing-plans,systematic-debugging,using-git-worktrees,receiving-code-review"
  "esf-dev-b            : test-driven-development,executing-plans,systematic-debugging,using-git-worktrees,receiving-code-review"
  "esf-reviewer         : requesting-code-review,verification-before-completion"
  "esf-qa-release       : verification-before-completion,systematic-debugging,finishing-a-development-branch"
)

# Begleitdateien, die mitkommen duerfen — alles andere bleibt zurueck.
begleiter_von() {
    case "$1" in
        brainstorming)           echo "spec-document-reviewer-prompt.md" ;;
        writing-plans)           echo "plan-document-reviewer-prompt.md" ;;
        test-driven-development) echo "writing-good-tests.md" ;;
        systematic-debugging)    echo "root-cause-tracing.md condition-based-waiting.md defense-in-depth.md" ;;
        *)                       echo "" ;;
    esac
}

# ---------------------------------------------------------------------------
say "Skills verteilen"
# ---------------------------------------------------------------------------
anzahl=0
for eintrag in "${ZUORDNUNG[@]}"; do
    profil="$(printf '%s' "$eintrag" | cut -d: -f1 | tr -d ' ')"
    skills="$(printf '%s' "$eintrag" | cut -d: -f2 | tr -d ' ')"

    printf '  %s\n' "$profil"
    for skill in ${skills//,/ }; do
        [ -f "$SRC/$skill/SKILL.md" ] || {
            echo "FEHLER: '$skill' gibt es in der Quelle nicht."; exit 1
        }
        ziel="$HERE/skills/$profil/$skill"
        rm -rf "$ziel"; mkdir -p "$ziel"

        # SKILL.md mit ergaenzter Frontmatter: Hermes-Skills tragen version und
        # platforms; die Superpowers-Originale haben nur name und description.
        python3 - "$SRC/$skill/SKILL.md" "$ziel/SKILL.md" "$VERSION" <<'PY'
import sys, re
quelle, ziel, version = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(quelle, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    raise SystemExit(f"{quelle}: keine Frontmatter gefunden")
kopf, rest = m.group(1), text[m.end():]
if "version:" not in kopf:
    kopf += f"\nversion: {version}"
if "platforms:" not in kopf:
    kopf += "\nplatforms: [linux, macos]"
open(ziel, "w", encoding="utf-8").write(f"---\n{kopf}\n---\n{rest}")
PY

        for datei in $(begleiter_von "$skill"); do
            [ -f "$SRC/$skill/$datei" ] && cp "$SRC/$skill/$datei" "$ziel/"
        done
        printf '      %-32s %s\n' "$skill" "$(ls "$ziel" | tr '\n' ' ')"
        anzahl=$((anzahl + 1))
    done

    # Das Tool-Mapping: Superpowers spricht von Claude-Code-Werkzeugen, ein
    # Hermes-Worker hat andere. Ohne diese Uebersetzung laufen die Skills in
    # Anweisungen, die es hier nicht gibt.
    cp "$HERE/templates/HERMES-TOOLS.md" "$HERE/skills/$profil/HERMES-TOOLS.md"
done

# ---------------------------------------------------------------------------
say "Lizenz"
# ---------------------------------------------------------------------------
# MIT verlangt, dass der Copyright-Hinweis mit der Kopie reist.
if [ -f "$LICENSE_SRC" ]; then
    cp "$LICENSE_SRC" "$HERE/skills/LICENSE.superpowers"
    echo "  LICENSE.superpowers uebernommen"
else
    echo "  ⚠ LICENSE nicht gefunden unter $LICENSE_SRC — bitte von Hand ergaenzen."
fi

cat > "$HERE/skills/README.md" <<EOF
# Profil-lokale Skills der ESF

Die Unterverzeichnisse sind **Profilnamen**, nicht Skillnamen:
\`skills/<profil>/<skill>/SKILL.md\`. \`setup.sh\` kopiert jedes davon nach
\`~/.hermes/profiles/<profil>/skills/\`. Ein Profil sieht nur, was seine Rolle
braucht — das ist der Flotten-Hebel aus Kapitel 4 des Konzepts.

## Herkunft

Die Skills stammen aus [obra/superpowers](https://github.com/obra/superpowers)
(MIT, Copyright (c) 2025 Jesse Vincent), Version **$VERSION**, eingesammelt mit
\`./vendor-superpowers.sh\`. Der Lizenztext liegt als
[\`LICENSE.superpowers\`](LICENSE.superpowers) bei.

Kopiert wird jeweils \`SKILL.md\` plus die inhaltlichen Begleitdateien.
Nicht kopiert werden Testdruck-Dateien, Entstehungsprotokolle und der
Node-Server der Brainstorming-Sichtbegleitung — Claude-Code-Werkzeug ohne
Entsprechung im Hermes-Worker.

## Das Tool-Mapping

In jedem Profilordner liegt \`HERMES-TOOLS.md\`: Die Superpowers-Skills sind
für Claude Code geschrieben und nennen dessen Werkzeuge. Die Datei übersetzt
sie auf das Hermes-Toolset. Vorbild ist \`hermes-tools.md\` aus dem
Community-Port
[satangel2222/obra-superpowers-hermes](https://github.com/satangel2222/obra-superpowers-hermes);
sie ist hier eigenständig geschrieben und gegen v0.20.0 gehalten.

## Zuordnung

| Profil | Skills |
|--------|--------|
| \`esf-product-manager\` | brainstorming · verification-before-completion |
| \`esf-architect\` | writing-plans · dispatching-parallel-agents · brainstorming |
| \`esf-chief-of-staff\` | writing-plans · dispatching-parallel-agents · brainstorming |
| \`esf-dev-a\`, \`esf-dev-b\` | test-driven-development · executing-plans · systematic-debugging · using-git-worktrees · receiving-code-review |
| \`esf-reviewer\` | requesting-code-review · verification-before-completion |
| \`esf-qa-release\` | verification-before-completion · systematic-debugging · finishing-a-development-branch |

Die vier übrigen Profile (\`esf-market-scout\`, \`esf-market-analyst\`,
\`esf-estimator\`, \`esf-controller\`) bekommen bewusst keine Superpowers-Skills:
Ihre Arbeit ist Erkennen, Bewerten und Messen, nicht Bauen. Ihre Präzision
wohnt in der \`SOUL.md\`.
EOF
echo "  README.md geschrieben"

printf '\n\033[32m✓ %s Skill-Kopien in skills/ — jetzt ./setup.sh\033[0m\n' "$anzahl"
