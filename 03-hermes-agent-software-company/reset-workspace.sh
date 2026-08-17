#!/usr/bin/env bash
#
# ESF — Arbeitskopie des Firmen-Vaults frisch aus seed/
# =====================================================
#
#   ./reset-workspace.sh          workspace/ neu aus seed/ aufbauen
#   ./reset-workspace.sh --git    nur zeigen, was im Vault-Repo passiert ist
#
# seed/ ist der Master, workspace/ die Wegwerfkopie. Ohne diese Trennung wäre
# der Durchlauf einmalig: Worker überschreiben auch Startdateien, und der
# zweite Lauf startete auf dem Ergebnis des ersten.
#
# Der Vault ist selbst ein Git-Repository. Das ist keine Zierde — die
# Produkthistorie der Organisation soll dieselbe Nachvollziehbarkeit haben wie
# ihr Code, und jede Vault-Änderung ist ein Commit mit Karten-Bezug.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/workspace"
VAULT="$WS/company"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
if [ "${1:-}" = "--git" ]; then
    [ -d "$VAULT/.git" ] || { echo "Es gibt noch keinen Vault. Erst ./setup.sh"; exit 1; }
    say "Vault-Historie"
    git -C "$VAULT" log --oneline --stat | head -60
    say "Nicht committet"
    git -C "$VAULT" status --short
    exit 0
fi

command -v git >/dev/null || { echo "FEHLER: 'git' fehlt."; exit 1; }

# ---------------------------------------------------------------------------
say "Arbeitskopie neu aufbauen"
# ---------------------------------------------------------------------------
rm -rf "$WS"
mkdir -p "$WS"
cp -R "$HERE/seed/company" "$WS/company"
cp -R "$HERE/seed/lint-selbsttest" "$WS/lint-selbsttest"

# Die leeren Ordner der Vault-Struktur überleben ein `cp -R` nur mit Inhalt.
for ordner in roadmap decisions analysis sources specs reports ledger; do
    mkdir -p "$VAULT/$ordner"
done
[ -f "$VAULT/ledger/estimates.jsonl" ] || : > "$VAULT/ledger/estimates.jsonl"

cat > "$VAULT/.gitignore" <<'EOF'
# Traces und Screenshots eines E2E-Laufs sind Akten, keine Quellen — sie
# werden pro Lauf neu erzeugt und blähen die Historie auf.
reports/e2e-*/
EOF

echo "  workspace/company/     — der Firmen-Vault"
echo "  workspace/lint-selbsttest/ — die Fixture des Vault-Linters"

# ---------------------------------------------------------------------------
say "Vault als Git-Repository"
# ---------------------------------------------------------------------------
git -C "$VAULT" init -q -b main
git -C "$VAULT" add -A
git -C "$VAULT" -c user.name="ESF Setup" -c user.email="esf@local" \
    commit -q -m "Vault-Gerüst: AGENTS.md, cadence.yaml, Ordnerstruktur"
echo "  $(git -C "$VAULT" log --oneline -1)"

# ---------------------------------------------------------------------------
say "Vault-Linter auf dem frischen Vault"
# ---------------------------------------------------------------------------
# Ein frischer Vault MUSS sauber sein. Ist er es nicht, ist seed/ verstellt.
if python3 "$HERE/scripts/vault-lint.py" "$VAULT" >/dev/null 2>&1; then
    printf '\033[32m  sauber ✓\033[0m\n'
else
    printf '\033[31m  FEHLER: der frische Vault ist nicht sauber:\033[0m\n'
    python3 "$HERE/scripts/vault-lint.py" "$VAULT" | sed 's/^/    /'
    exit 1
fi
