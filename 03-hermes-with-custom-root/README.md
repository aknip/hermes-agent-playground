# Hermes mit eigenem Root-Verzeichnis

Ein interaktives Skript, das die laufenden Gateways der Standard-Installation
beendet und Hermes anschließend mit einer eigenen `HERMES_HOME`-Root startet.

**Stand:** 14.09.2026 · geprüft an der installierten **v0.21.2 (2026.9.11)** unter
macOS, Bash 3.2. Die Begründung für jeden Schalter steht in
[`../00-hermes-FAQ/Hermes-Custom-Root.md`](../00-hermes-FAQ/Hermes-Custom-Root.md).

```bash
./start-custom-root.sh
```

## Was es tut

1. **Gateways beenden.** Zeigt `hermes gateway list` der Standard-Root
   `~/.hermes` und beendet auf ein `y` hin jeden laufenden Gateway einzeln, weil
   das launchd-Label profilgebunden ist. Ein `n` lässt alles laufen.
2. **Root wählen und starten.** Vorgabe ist `~/hermes-test`, der Pfad ist
   editierbar. Danach wahlweise CLI-Chat, Desktop-App oder nur eine Shell mit
   gesetztem `HERMES_HOME`.

Die Desktop-Variante ergänzt selbstständig die drei Angaben, ohne die ein Start
in einer fremden Root scheitert: `--hermes-root` auf den geteilten Checkout,
`--skip-build` gegen den fehlenden Build-Stempel und ein eigenes
`HERMES_DESKTOP_USER_DATA_DIR`.

## Was es nicht tut

- **Die Desktop-App nicht beenden.** Schritt 1 betrifft nur die Gateways. Läuft
  die App, weist das Skript darauf hin, dass sie eigene Backend-Prozesse hält.
- **Die launchd-Definitionen nicht entfernen.** Nach dem nächsten Login laufen
  die Gateways wieder. Dauerhaft: `hermes [-p <profil>] gateway uninstall`.
- **`~/.hermes` nicht verändern**, abgesehen vom bestätigten Stopp in Schritt 1.

Eine Root unterhalb von `~/.hermes` lehnt das Skript ab. Sie fiele auf
`~/.hermes` zurück, und Kanban-Board wie Profilregistry blieben geteilt.

## Nicht verifiziert

Kein protokollierter Lauf. Geprüft sind die Syntax (`bash -n`), das Parsen der
echten Ausgabe von `hermes gateway list` und die Pfadnormalisierung samt
Ablehnungsregel, beides isoliert und ohne Nebenwirkungen. Der Stopp-Pfad, `hermes
setup` in einer neuen Root und der Desktop-Start wurden nicht ausgeführt.
