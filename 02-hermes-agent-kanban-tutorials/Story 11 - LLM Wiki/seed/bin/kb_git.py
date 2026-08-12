#!/usr/bin/env python3
"""kb_git.py — duenner Git-Helfer fuer die Wissensbasis.

Wozu ueberhaupt ein Helfer, wenn der Agent doch `git` aufrufen koennte:

    Weil er es dann auch tut — mit `git add -A`, `git commit --amend`,
    `git checkout .` und gelegentlich `git reset --hard` auf einem echten
    Repository. Dieses Skript gibt ihm genau sechs Verben, und jedes einzelne
    prueft vorher, ob es erlaubt ist. Die Commit-Phase ist damit
    deterministisch, und der Agent hantiert nicht frei mit Git.

Der wichtigste Riegel steckt in `merge`: ein Merge nach main laeuft nur, wenn
bin/kb_lint.py fehlerfrei durchlaeuft. Das ist kein Ratschlag, den ein Modell
ueberlesen kann — es ist eine Vorbedingung im Code.

    python3 bin/kb_git.py status
    python3 bin/kb_git.py branch  kb/ingest-<slug>
    python3 bin/kb_git.py commit  -m "ingest: <slug>"
    python3 bin/kb_git.py changed kb/ingest-<slug>
    python3 bin/kb_git.py merge   kb/ingest-<slug>
    python3 bin/kb_git.py discard kb/ingest-<slug>
    python3 bin/kb_git.py log

Exit-Code:  0 = erledigt,  1 = abgewiesen (mit Begruendung),  2 = Aufruffehler.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HAUPTBRANCH = "main"
BRANCH_PRAEFIX = "kb/ingest-"


def git(wiki: Path, *args: str, check: bool = True) -> str:
    """git im Repository ausfuehren und stdout zurueckgeben."""
    p = subprocess.run(["git", "-C", str(wiki), *args],
                       capture_output=True, text=True)
    if check and p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}\n{p.stderr.strip()}")
    return p.stdout.strip()


def nein(text: str) -> int:
    print(f"ABGEWIESEN — {text}", file=sys.stderr)
    return 1


def repo_pruefen(wiki: Path) -> None:
    if not wiki.is_dir():
        raise RuntimeError(f"{wiki} ist kein Verzeichnis")
    try:
        git(wiki, "rev-parse", "--git-dir")
    except RuntimeError:
        raise RuntimeError(
            f"{wiki} ist kein Git-Repository. ./setup.sh bzw. "
            f"./reset-workspace.sh legt es an.")


def aktueller_branch(wiki: Path) -> str:
    return git(wiki, "rev-parse", "--abbrev-ref", "HEAD")


def ist_schmutzig(wiki: Path) -> list[str]:
    return [z for z in git(wiki, "status", "--porcelain").splitlines() if z.strip()]


def branches(wiki: Path) -> list[str]:
    return [z.strip() for z in
            git(wiki, "for-each-ref", "--format=%(refname:short)",
                "refs/heads").splitlines() if z.strip()]


def unverschmolzene_ingests(wiki: Path) -> list[str]:
    """Ingest-Branches, die noch nicht in main enthalten sind.

    Das ist der Konkurrenzschutz: solange ein fremder Ingest offen ist, darf
    kein zweiter anfangen — beide wuerden im SELBEN Arbeitsbaum schreiben.
    """
    offen = []
    for b in branches(wiki):
        if not b.startswith(BRANCH_PRAEFIX):
            continue
        enthalten = git(wiki, "branch", "--merged", HAUPTBRANCH,
                        "--format=%(refname:short)").splitlines()
        if b not in [z.strip() for z in enthalten]:
            offen.append(b)
    return offen


def lint(wiki: Path, strict: bool = False) -> tuple[int, str]:
    """bin/kb_lint.py auf dieselbe Wissensbasis anwenden."""
    linter = wiki.parent / "bin" / "kb_lint.py"
    if not linter.is_file():
        return 2, f"kb_lint.py nicht gefunden unter {linter}"
    cmd = [sys.executable, str(linter), str(wiki)]
    if strict:
        cmd.append("--strict")
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


# ---------------------------------------------------------------------------
# Verben
# ---------------------------------------------------------------------------
def cmd_status(wiki: Path, _a: argparse.Namespace) -> int:
    print(f"Repository:      {wiki}")
    print(f"Branch:          {aktueller_branch(wiki)}")
    schmutz = ist_schmutzig(wiki)
    print(f"Arbeitsbaum:     {'schmutzig' if schmutz else 'sauber'}")
    for z in schmutz:
        print(f"                 {z}")
    offen = unverschmolzene_ingests(wiki)
    print(f"Offene Ingests:  {', '.join(offen) if offen else '(keine)'}")
    print(f"Branches:        {', '.join(branches(wiki))}")
    return 0


def cmd_branch(wiki: Path, a: argparse.Namespace) -> int:
    name = a.name
    if not name.startswith(BRANCH_PRAEFIX):
        return nein(f"Branchname muss mit '{BRANCH_PRAEFIX}' beginnen "
                    f"(war: '{name}'). Jeder Ingest bekommt einen eigenen "
                    f"Branch, und er ist an seinem Namen erkennbar.")
    if schmutz := ist_schmutzig(wiki):
        return nein("der Arbeitsbaum ist nicht sauber. Ein neuer Ingest "
                    "startet nur von einem sauberen main:\n  "
                    + "\n  ".join(schmutz))
    if name in branches(wiki):
        if aktueller_branch(wiki) == name:
            print(f"Branch '{name}' existiert und ist ausgecheckt — nichts zu tun.")
            return 0
        git(wiki, "checkout", name)
        print(f"Branch '{name}' existierte bereits, ausgecheckt.")
        return 0
    if offen := [b for b in unverschmolzene_ingests(wiki) if b != name]:
        return nein(f"es ist noch ein Ingest offen: {', '.join(offen)}. "
                    f"Zwei Ingests im selben Arbeitsbaum wuerden sich "
                    f"gegenseitig ueberschreiben. Erst den offenen "
                    f"abschliessen (merge) oder wegwerfen (discard).")
    git(wiki, "checkout", HAUPTBRANCH)
    git(wiki, "checkout", "-b", name)
    print(f"Branch '{name}' von {HAUPTBRANCH} angelegt und ausgecheckt.")
    return 0


def cmd_commit(wiki: Path, a: argparse.Namespace) -> int:
    branch = aktueller_branch(wiki)
    if branch == HAUPTBRANCH:
        return nein(f"du stehst auf {HAUPTBRANCH}. In {HAUPTBRANCH} wird nie "
                    f"direkt committet — erst 'branch', dann 'commit', dann "
                    f"'merge' nach der Freigabe.")
    if not ist_schmutzig(wiki):
        return nein("es gibt nichts zu committen. Der Ingest hat keine Datei "
                    "veraendert — das ist fast immer ein Fehler und keine "
                    "erfolgreiche Leerarbeit.")
    git(wiki, "add", "-A")
    git(wiki, "-c", "user.name=kb-ingestor",
        "-c", "user.email=kb-ingestor@localhost",
        "commit", "-m", a.message)
    print(f"Committet auf '{branch}':")
    print(git(wiki, "show", "--stat", "--oneline", "-s", "HEAD"))
    for z in git(wiki, "show", "--name-status", "--format=", "HEAD").splitlines():
        print(f"  {z}")
    return 0


def cmd_changed(wiki: Path, a: argparse.Namespace) -> int:
    """Was aendert dieser Branch gegenueber main? Fuettert den Torgrund."""
    if a.name not in branches(wiki):
        return nein(f"Branch '{a.name}' existiert nicht.")
    diff = git(wiki, "diff", "--name-status", f"{HAUPTBRANCH}...{a.name}")
    if not diff:
        print(f"'{a.name}' aendert gegenueber {HAUPTBRANCH} nichts.")
        return 0
    print(f"'{a.name}' gegenueber {HAUPTBRANCH}:")
    for z in diff.splitlines():
        print(f"  {z}")
    stat = git(wiki, "diff", "--shortstat", f"{HAUPTBRANCH}...{a.name}")
    print(f"  {stat}")
    return 0


def cmd_merge(wiki: Path, a: argparse.Namespace) -> int:
    name = a.name
    if name not in branches(wiki):
        return nein(f"Branch '{name}' existiert nicht.")
    if schmutz := ist_schmutzig(wiki):
        return nein("der Arbeitsbaum ist nicht sauber — erst 'commit':\n  "
                    + "\n  ".join(schmutz))

    # Der Riegel: es wird gelintet, was gemergt werden soll — nicht main.
    if aktueller_branch(wiki) != name:
        git(wiki, "checkout", name)
    rc, ausgabe = lint(wiki, strict=a.strict)
    print(ausgabe.rstrip())
    if rc != 0:
        return nein(f"kb_lint.py hat den Branch '{name}' nicht bestanden "
                    f"(Exit {rc}). In {HAUPTBRANCH} landet nur eine "
                    f"Wissensbasis, die den Vertrag aus AGENTS.md erfuellt. "
                    f"Befunde beheben, erneut committen, erneut mergen.")

    git(wiki, "checkout", HAUPTBRANCH)
    try:
        git(wiki, "-c", "user.name=kb-orchestrator",
            "-c", "user.email=kb-orchestrator@localhost",
            "merge", "--no-ff", name, "-m", a.message or f"merge {name}")
    except RuntimeError as e:
        git(wiki, "merge", "--abort", check=False)
        git(wiki, "checkout", name, check=False)
        return nein(f"Merge fehlgeschlagen, {HAUPTBRANCH} unveraendert:\n{e}")
    git(wiki, "branch", "-d", name)
    print(f"\n'{name}' nach {HAUPTBRANCH} verschmolzen, Branch entfernt.")
    print(git(wiki, "log", "--oneline", "-3"))
    return 0


def cmd_discard(wiki: Path, a: argparse.Namespace) -> int:
    name = a.name
    if name not in branches(wiki):
        return nein(f"Branch '{name}' existiert nicht.")
    if aktueller_branch(wiki) == name:
        git(wiki, "checkout", "-f", HAUPTBRANCH)
    git(wiki, "branch", "-D", name)
    git(wiki, "checkout", "-f", HAUPTBRANCH)
    git(wiki, "clean", "-fd")
    print(f"'{name}' verworfen. {HAUPTBRANCH} unveraendert:")
    print(git(wiki, "log", "--oneline", "-1"))
    return 0


def cmd_log(wiki: Path, a: argparse.Namespace) -> int:
    print(git(wiki, "log", "--oneline", "--graph", f"-{a.n}"))
    return 0


def main(argv: list[str]) -> int:
    hier = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(
        prog="kb_git",
        description="Sechs geprueft Verben fuer das Git der Wissensbasis. "
                    "Alles andere ist absichtlich nicht moeglich.")
    ap.add_argument("--wiki", default=str(hier.parent / "wiki"),
                    help="Pfad auf das wiki/-Repository "
                         "(Standard: ../wiki neben bin/)")
    sub = ap.add_subparsers(dest="verb", required=True)

    sub.add_parser("status", help="Branch, Arbeitsbaum, offene Ingests")

    p = sub.add_parser("branch", help=f"'{BRANCH_PRAEFIX}<slug>' anlegen")
    p.add_argument("name")

    p = sub.add_parser("commit", help="alles auf dem Ingest-Branch committen")
    p.add_argument("-m", "--message", required=True)

    p = sub.add_parser("changed", help=f"Diff gegen {HAUPTBRANCH}")
    p.add_argument("name")

    p = sub.add_parser("merge", help=f"nach {HAUPTBRANCH} — nur wenn Lint besteht")
    p.add_argument("name")
    p.add_argument("-m", "--message", default="")
    p.add_argument("--strict", action="store_true",
                   help="STALE-Befunde sperren den Merge ebenfalls")

    p = sub.add_parser("discard", help="Ingest-Branch wegwerfen")
    p.add_argument("name")

    p = sub.add_parser("log", help="Historie")
    p.add_argument("-n", type=int, default=10)

    a = ap.parse_args(argv)
    wiki = Path(a.wiki).expanduser().resolve()

    try:
        repo_pruefen(wiki)
        return {
            "status": cmd_status, "branch": cmd_branch, "commit": cmd_commit,
            "changed": cmd_changed, "merge": cmd_merge, "discard": cmd_discard,
            "log": cmd_log,
        }[a.verb](wiki, a)
    except RuntimeError as e:
        print(f"kb_git: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
