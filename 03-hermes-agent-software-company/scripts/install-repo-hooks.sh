#!/usr/bin/env bash
#
# ESF — Der Pre-Commit-Hook des Produkt-Repos
# ===========================================
#
#   scripts/install-repo-hooks.sh [--remove] [--status]
#
# Das Problem, an dem sonst jede Entwickler-Karte hängenbleibt:
#
#   Kaneos eigener Husky-Hook führt `pnpm exec biome ci .` über das GANZE Repo
#   aus, gefolgt von `pnpm run build`. Der Build dauert Minuten — bei jedem
#   einzelnen Commit. Das allein macht ihn als Agenten-Commit-Gate untauglich.
#
#   ⚠ Korrektur einer früheren Behauptung an dieser Stelle: `biome ci .` war
#   NICHT von vornherein rot. Auf dem Ausgangs-Commit ohne ESF-Worktrees endet
#   es mit Exit 0. Rot wurde es erst durch die ESF selbst — `biome.json` setzt
#   `vcs.enabled: false`, ignoriert damit `.gitignore`, läuft in den Worktree
#   unter `.worktrees/` und bricht dort an dessen `biome.json` ab ("nested root
#   configuration"). Behoben durch einen Ausschluss in `biome.json`, gefunden
#   von der Codebasis-Analyse des esf-architect.
#
#   Ein Worker, der daran scheitert, hat zwei schlechte Möglichkeiten: aufgeben
#   oder `--no-verify` benutzen. Das Zweite lernt er schnell, und dann gilt gar
#   kein Hook mehr — auch nicht für die Dateien, die er selbst kaputt macht.
#
# Die Antwort ist nicht, den Hook abzuschalten, sondern ihn auf das zu
# beschränken, was er verlässlich leisten kann: die GESTAGETEN Dateien linten.
# Gemessen wird damit die Regression, nicht der Absolutstand. Der volle
# Nachweis — Typecheck, Unit-Tests, ganze E2E-Suite — sitzt ohnehin im
# Merge-Riegel, und dort gehört er auch hin: einmal je Merge, nicht einmal je
# Commit.
#
# Umgesetzt über `core.hooksPath`. Das lässt Kaneos .husky/ unverändert liegen;
# --remove stellt den Ausgangszustand exakt wieder her.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
CADENCE="$ESF/workspace/company/cadence.yaml"
[ -f "$CADENCE" ] || CADENCE="$ESF/seed/company/cadence.yaml"
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$CADENCE" | head -1)"
HOOKS="$REPO/.esf-hooks"

[ -d "$REPO/.git" ] || { echo "FEHLER: '$REPO' ist kein Git-Repo."; exit 1; }

case "${1:-}" in
--status)
    aktuell="$(git -C "$REPO" config --get core.hooksPath || echo '<Standard: .git/hooks>')"
    echo "core.hooksPath = $aktuell"
    [ -d "$HOOKS" ] && echo "ESF-Hooks liegen unter $HOOKS" || echo "Keine ESF-Hooks installiert."
    exit 0 ;;
--remove)
    git -C "$REPO" config --unset core.hooksPath 2>/dev/null || true
    rm -rf "$HOOKS"
    echo "ESF-Hooks entfernt. Kaneos .husky/ gilt wieder unverändert."
    exit 0 ;;
esac

mkdir -p "$HOOKS"

cat > "$HOOKS/pre-commit" <<'HOOK'
#!/usr/bin/env bash
#
# ESF Pre-Commit — lintet die GESTAGETEN Dateien, sonst nichts.
#
# Bewusst NICHT hier: `biome ci .` über das ganze Repo (78 Warnungen und eine
# Schema-Abweichung, an denen kein Commit etwas ändert) und `pnpm run build`
# (Minuten je Commit). Beides gehört in den Merge-Riegel, einmal je Merge —
# hier würde es nur dazu führen, dass alle mit --no-verify committen.
#
set -euo pipefail

wurzel="$(git rev-parse --show-toplevel)"
cd "$wurzel"

dateien="$(git diff --cached --name-only --diff-filter=ACMR \
           | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|json)$' || true)"
[ -n "$dateien" ] || exit 0

# shellcheck disable=SC2086
if ! pnpm exec biome check $dateien; then
    cat >&2 <<'MSG'

Der Linter beanstandet Dateien, die DIESER Commit ändert.

Das ist keine Bestandsschuld — es sind deine Zeilen. Beheben:
    pnpm exec biome check --write <datei>

Umgehen ist keine Option: --no-verify hebt auch die Prüfung auf, die dich
gerade vor dem Review bewahrt hätte.
MSG
    exit 1
fi
HOOK
chmod +x "$HOOKS/pre-commit"

# commit-msg unverändert von Kaneo übernehmen, falls vorhanden — der
# Conventional-Commits-Zwang ist eine echte Repo-Konvention, keine Altlast.
if [ -f "$REPO/.husky/commit-msg" ]; then
    cp "$REPO/.husky/commit-msg" "$HOOKS/commit-msg"
    chmod +x "$HOOKS/commit-msg"
fi

# ABSOLUT, nicht relativ — und das ist der ganze Witz dieser Zeile.
#
# Git löst einen relativen core.hooksPath gegen die Wurzel des JEWEILIGEN
# Arbeitsbaums auf. `.esf-hooks` liegt aber nur im Hauptbaum und ist nicht im
# Git. In einem verlinkten Worktree zeigte der Pfad damit ins Leere: Git fand
# keinen Hook und committete ohne jede Prüfung — lautlos, ohne Warnung.
#
# Real aufgedeckt am 17.08.2026 durch das Review von R1-F5: Der Reviewer fand
# 11 biome-Fehler in einem Commit, den der Hook hätte blockieren müssen, und
# nannte zwei mögliche Ursachen — der Entwickler habe --no-verify benutzt, oder
# die Hook-Mechanik sei defekt. Es war die zweite. Der Entwickler hatte nichts
# umgangen; es gab nichts zu umgehen.
#
# Das ist die unangenehmere Sorte Lücke: In Phase 1 wurde der Hook im HAUPTBAUM
# nachgewiesen ("Commit 58310dc durch den schlanken Hook — ohne --no-verify")
# und galt seither als belegt. Genau dort, wo die Feature-Arbeit stattfindet —
# in den Worktrees —, hat er nie existiert.
#
# core.hooksPath steht in der gemeinsamen .git/config, die alle Worktrees
# teilen. Ein absoluter Pfad wirkt deshalb in allen zugleich, auch in denen,
# die der Dispatcher erst später anlegt.
git -C "$REPO" config core.hooksPath "$REPO/.esf-hooks"

# Der Hook-Ordner gehört nicht in die Produkt-Historie.
if ! grep -q '^\.esf-hooks/$' "$REPO/.gitignore" 2>/dev/null; then
    printf '\n# ESF: schlanker Pre-Commit-Hook (scripts/install-repo-hooks.sh)\n.esf-hooks/\n' \
        >> "$REPO/.gitignore"
fi

cat <<EOF

✓ ESF-Hooks installiert.

  core.hooksPath  = $REPO/.esf-hooks  (absolut — greift auch in Worktrees)
  pre-commit      = biome auf den gestageten Dateien
  commit-msg      = $( [ -f "$HOOKS/commit-msg" ] && echo "von Kaneo übernommen" || echo "keiner" )

  Kaneos .husky/ bleibt unverändert liegen.
  Zurück:  scripts/install-repo-hooks.sh --remove
EOF
