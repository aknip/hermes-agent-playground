# Hermes Desktop Theming — was geht, was nicht

Recherche zur Frage: Wie weit lässt sich die Hermes-Desktop-App (macOS) optisch
an eigenes Branding anpassen? Konkret untersucht: das große blaue
„HERMES AGENT"-Logo, ein eigenes Logo an fester Stelle, der erste
Hauptmenüeintrag und das App-Icon.

Alle Aussagen sind am **lokalen Quellcode der installierten Version** belegt,
nicht an der Online-Doku. Stellenangaben in der Form `datei.ts:123` beziehen
sich auf `~/.hermes/hermes-agent/` beim Commit **`c0106e50e7`** (2026-08-10).
Zeilennummern wandern mit jedem `hermes update` — im Zweifel nach dem
zitierten Bezeichner greppen, nicht nach der Zeile.

## Testumgebung

| | |
|---|---|
| Hermes Agent | 0.20.0 (0.17.0), Installationsmethode `git` (`.install_method`) |
| Installationsort | `~/.hermes/hermes-agent` |
| Laufende App | `apps/desktop/release/mac-arm64/Hermes.app` (lokal gebaut, via `ps` verifiziert) |
| Desktop-Build | `desktop-build-stamp.json`, gebaut 2026-08-10, `sourceMode: false` (d. h. fertig gebautes Bundle, kein Dev-Server — ein Rebuild ist trotzdem jederzeit möglich) |
| Betriebssystem | macOS, Darwin 25.5.0 |
| Datum der Recherche | 2026-08-11 |

## Was verifiziert ist — und was nicht

**Am Quellcode belegt:** die Herkunft des Wordmarks und seiner Farbe, der
Umfang des Skin-/Theme-Modells, die vollständige Liste der Plugin-Slots und
deren Datentypen, die Trennung von Web-UI- und Desktop-Theming, die Herkunft
des Menünamens, die beiden Icon-Stellen und der `asarUnpack`-Mechanismus.
Zusätzlich empirisch geprüft: das Info.plist des gebauten Bundles (`plutil`),
der laufende Prozess (`ps`) und der Bildinhalt von `assets/icon.png`.

**Nicht verifiziert (bewusst offen gelassen):**

1. Ob ein Ändern **nur** von `extendInfo.CFBundleDisplayName` bei
   unverändertem `productName` den Menünamen umbenennt, ohne den
   Bundle-Ordner umzubenennen. Das kostet einen vollständigen Rebuild der
   laufenden App — siehe [Testrezept](#der-ein-build-test).
2. Ob `HERMES_DESKTOP_APP_NAME` den macOS-Menütitel tatsächlich bewegt.
   Erwartung: nein (macOS liest den Titel aus dem Bundle-Plist), aber nicht
   gemessen.
3. Der `<style>`-Injection-Workaround (Abschnitt 3) wurde nicht ausprobiert.

---

## 1. Das Theme-System — Umfang und harte Grenze

Ein **Skin** ist eine YAML-Datei in `~/.hermes/skins/<name>.yaml` und färbt
CLI, TUI **und** Desktop gleichzeitig. Der Gateway-Watcher repaintet alle
Oberflächen live in etwa einer Sekunde.

```bash
hermes skin list
hermes config set display.skin <name>     # aktivieren (nie config.yaml von Hand editieren)
hermes skin set ui_accent "#c8102e"       # eine einzelne Farbe im aktiven Skin ändern
```

Der Desktop kennt ein reicheres Modell als die CLI
(`apps/desktop/src/themes/types.ts:13`): `background`, `foreground`, `card`,
`muted`, `popover`, `primary`, `secondary`, `accent`, `border`, `input`,
`ring`, `midground`, `composerRing`, `destructive`, **`sidebarBackground`**,
**`sidebarBorder`**, `userBubble` — jeweils in Hell- und Dunkelvariante, dazu
`typography` (`fontSans`, `fontMono`, `fontUrl`) und eine vollständige
Terminal-ANSI-Palette.

**Die Grenze steht als Kommentar im Code selbst** (`themes/types.ts:9`):

> *„Everything else (layout, sizing, radius, line-height) lives in styles.css."*

Theming heißt hier also: **Farben und Schriftfamilien**. Kein Layout, keine
Abstände, keine Geometrie, keine Bilder. Die Desktop-Theme-Definition hat
**kein Custom-CSS-Feld**.

Zwei weitere Grenzen:

- `branding.agent_name` aus dem Skin (der CLI-Anzeigename) erreicht die
  Desktop-UI **nicht** — kein einziger Treffer für `agent_name` in
  `apps/desktop/src`.
- Ein Skin darf nicht heißen wie ein Desktop-Built-in (`mono`, `slate`,
  `cyberpunk`, `nous`, `midnight`, `ember`), sonst gewinnt das Built-in.

---

## 2. Das große blaue „HERMES AGENT"-Logo

Es ist **kein Bild, sondern Text** — und hardkodiert:

```
apps/desktop/src/components/chat/intro.tsx:147
const WORDMARK = 'HERMES AGENT'
```

| Aspekt | Änderbar? | Wie |
|---|---|---|
| **Farbe** | ✅ ja | `--theme-midground`, Default `#0053fd` (`styles.css:150`). Skin-Key `ui_accent` wird darauf gemappt (`themes/skin.ts:97`) → `hermes skin set ui_accent "#..."` |
| **Text** | ❌ nein | Konstante im Quellcode, kein Config-Punkt, kein Contribution-Point |
| **Schrift** | ❌ nein | Fest auf `font-['Collapse']` (`styles.css:36`); `typography.fontSans` greift hier nicht |
| **Durch Bild ersetzen** | ❌ nein | Kein vorgesehener Weg |

Zu beachten: **derselbe Wordmark erscheint an zwei Stellen** — im
Chat-Empty-State (`components/assistant-ui/thread/index.tsx:152`) *und* auf dem
Kanban-Board (`plugins/kanban/board.tsx:1367`). Wer ihn ändert, ändert beide.

---

## 3. Eigenes Logo an fester Stelle

Die maßgebliche Slot-Liste steht in `apps/desktop/src/sdk/index.ts:250-261`:

| Slot | Contribution-Typ | Eigenes Bild möglich? |
|---|---|---|
| `titleBar.left` / `.center` / `.right` | `render()` | ✅ **beliebiges React, also `<img>`** |
| `statusBar.left` / `.right` | `render()` | ✅ |
| `panes` | `render()` | ✅, aber vom Nutzer verschieb- und schließbar |
| `sidebar.nav` | **nur `data`** | ❌ nur Codicon-Name + Label + Route |
| `routes` | `render()` + `data.path` | eigene Vollbild-Seite |
| `themes` | `data` | eigenes Theme beisteuern (`themes/user-themes.ts:153`) |
| `palette`, `keybinds`, `layouts` | `data` | ⌘K-Befehl, Tastenkürzel, Layout-Preset |

**Die Sidebar scheidet für ein Logo aus.** Sie rendert stur
`<Codicon name={codicon}/>` (`app/chat/sidebar/index.tsx:317`) und ignoriert ein
`render()`. Die Nutzlast ist auf drei Strings begrenzt
(`app/routes.ts:111` ff.): `codicon`, `label`, `path`. Ein eigenes Asset ist
dort nicht vorgesehen.

**Der saubere Weg ist `titleBar.left`.** Deployment ohne Rebuild: eine Datei
nach `~/.hermes/desktop-plugins/<name>/plugin.js` legen — sie wird fs-watched
und hot-reloaded (`contrib/runtime-loader.ts:182`). Dass dieser Weg trägt,
belegt das bereits installierte `markdown-editor`-Plugin.

Ein Plugin bekommt einen gescopten Kontext (`contrib/plugin.ts:59`) mit
eigenem REST-Namespace, WebSocket, `storage`, `i18n` und einer kuratierten
OS-Tür (`openExternal`, `revealPath`, `writeClipboard`, native Notifications).

### Escape-Hatch (ungetestet, fragil)

Ein Plugin-`render()` kann ein `<style>`-Element einschleusen. Der Intro-Block
trägt den Hook `data-slot="aui_intro"` (`intro.tsx:166`) — damit ließe sich der
Wordmark ausblenden und ein eigenes Logo überlagern. Das ist **kein
vorgesehener Erweiterungspunkt**: es hängt an internen Klassen und Attributen
und kann bei jedem Update brechen. Als Workaround gangbar, nicht als
Empfehlung.

---

## 4. Wichtige Verwechslung: Web-UI ≠ Desktop-App

Es existiert ein **zweites, deutlich mächtigeres** Theming-System — aber für
eine andere Oberfläche.

`~/.hermes/dashboard-themes/*.yaml` (Beispiel: `clean-webui.yaml`) unterstützt:

```yaml
palette:          # Grundfarben
typography:       # fontSans, fontMono, fontDisplay, baseSize, lineHeight, letterSpacing
layout:           # radius, density
assets:           # z. B. bg
colorOverrides:   # feingranulare Token-Overrides
componentStyles:  # card, header, backdrop …
customCSS: |      # ← freies CSS
```

Damit ließe sich ein Logo per CSS tatsächlich austauschen. **Nur:** Diese
Dateien liest `hermes_cli/web_server.py:16714` für die **Browser-UI**. Die
Electron-Desktop-App nutzt sie nicht. Wer im Browser arbeitet, hat also
erheblich mehr Freiheit als in der Desktop-App.

---

## 5. Der erste Hauptmenüeintrag „Hermes"

Zwei Stellen setzen diesen Namen, und sie sind nicht gleichwertig.

**Das Electron-Menü-Template** baut den Eintrag aus einer Env-Variablen:

```
apps/desktop/electron/main.ts:680   const APP_NAME = process.env.HERMES_DESKTOP_APP_NAME || 'Hermes'
apps/desktop/electron/main.ts:5458  { label: APP_NAME, submenu: [ … ] }
apps/desktop/electron/main.ts:5460  { label: `About ${APP_NAME}` … }
apps/desktop/electron/main.ts:979   app.setName(APP_NAME)
```

**Das App-Bundle** pinnt den Namen zusätzlich im Info.plist:

```
apps/desktop/package.json:212-215
"extendInfo": { "CFBundleDisplayName": "Hermes",
                "CFBundleExecutable":  "Hermes",
                "CFBundleName":        "Hermes" }
```

Verifiziert: das gebaute Bundle trägt `CFBundleName` = `CFBundleDisplayName` =
`Hermes`. Unter macOS zieht die Menüleiste den fettgedruckten ersten Eintrag
aus dem Bundle-Plist, nicht aus dem Menü-Template. Erwartung daher:
`HERMES_DESKTOP_APP_NAME` bewegt den Menütitel **nicht** (wohl aber „About …"
und den Über-Dialog).

### Warum die Env-Variable der falsche Hebel ist

Sie ist kein Branding-Schalter, sondern ein **Test-Isolationsknopf**:

- `apps/desktop/e2e/fixtures.ts:220` — *„unique-ish per test (avoids
  single-instance lock)"*
- `apps/desktop/scripts/dev-mock.mjs:217` — dasselbe Muster

Sie greift über `app.setName()` in die Identität der App ein und kann den
userData-Pfad verschieben. Konsequenz: der localStorage mit **User-Themes und
Plugin-Schaltern** wäre weg.

### Der Stolperstein

Die CLI sucht die App mit einem hartkodierten Glob:

```
hermes_cli/main.py:6001
candidates = list(release_dir.glob("mac*/Hermes.app/Contents/MacOS/Hermes"))
```

Ein schlichtes Umbenennen von `productName` (`apps/desktop/package.json:3`)
benennt das Bundle in `<IhrName>.app` um — **`hermes desktop` findet es dann
nicht mehr.**

### Der Ein-Build-Test

Naheliegend, aber **ungeprüft**: nur `extendInfo.CFBundleDisplayName` /
`CFBundleName` ändern und `productName: "Hermes"` stehen lassen. Dann bliebe
das Bundle `Hermes.app` (CLI-Glob intakt), während die Menüleiste den eigenen
Namen zeigt. Ob electron-builder das so durchreicht oder die Keys aus
`productName` überschreibt, entscheidet ein Durchlauf:

```bash
# in apps/desktop/package.json NUR extendInfo.CFBundleDisplayName ändern, dann:
hermes desktop --force-build

# 1) Heißt der Bundle-Ordner noch "Hermes.app"?  (CLI-Glob überlebt?)
ls ~/.hermes/hermes-agent/apps/desktop/release/mac-arm64/

# 2) Ist der Plist-Key wirklich geändert?
plutil -extract CFBundleDisplayName raw \
  ~/.hermes/hermes-agent/apps/desktop/release/mac-arm64/Hermes.app/Contents/Info.plist
```

Danach ggf. `touch` aufs Bundle oder `lsregister -f`, weil macOS App-Namen und
-Icons aggressiv cached.

---

## 6. Das App-Icon (das „Hermes-Mädchen")

Verifiziert: `apps/desktop/assets/icon.png` (1024×1024) **ist** genau dieses
Bild, und `build.icon` (`package.json:178`) zeigt auf `assets/icon`.

Das Motiv steckt an **zwei unabhängigen Stellen**:

### a) Dock-/Finder-Icon — Rebuild nötig

Quelle `apps/desktop/assets/icon.icns` (daneben `icon.png` und `icon.ico` für
andere Plattformen), im Bundle unter `Contents/Resources/icon.icns`.

- **Sauber:** Datei ersetzen → `hermes desktop --force-build`
- **Ohne Rebuild:** die `.icns` im Bundle direkt überschreiben. Achtung: die App
  wird ad-hoc signiert (`hermes_cli/main.py:6896`) — ein Eingriff ins Bundle
  kann die Signatur brechen. Anschließend Icon-Cache anstoßen.

### b) In-App-Badge und Fenster-Favicon — **ohne Rebuild tauschbar**

| Datei | Wo sichtbar |
|---|---|
| `public/nous-girl.jpg` (256×256 JPEG) | Brand-Badge im UI (`src/components/brand-mark.tsx:16`) |
| `public/apple-touch-icon.png` (180×180 PNG) | Fenster-Favicon (`index.html:8-10`) + Onboarding (`src/components/onboarding/providers.tsx:45`) |

Weil `asarUnpack` das gesamte `dist/**` ausnimmt (`package.json:206`), liegen
beide im gebauten Bundle als **echte, beschreibbare Dateien**:

```
Hermes.app/Contents/Resources/app.asar.unpacked/dist/nous-girl.jpg
Hermes.app/Contents/Resources/app.asar.unpacked/dist/apple-touch-icon.png
```

Einfach überschreiben, App neu starten — fertig. Dateinamen und Formate
beibehalten.

---

## 7. Update-Fragilität

Die Installation ist ein **Git-Checkout** (`.install_method` = `git`). Jedes
`hermes update` macht einen `git pull` und überschreibt **sämtliche
Datei-Patches**: Icons, `package.json`, `intro.tsx`.

Was das überlebt:

| Anpassung | Update-fest? |
|---|---|
| Skin in `~/.hermes/skins/` | ✅ ja (liegt außerhalb des Checkouts) |
| Desktop-Plugin in `~/.hermes/desktop-plugins/` | ✅ ja |
| Dashboard-Theme in `~/.hermes/dashboard-themes/` | ✅ ja |
| Dateien im Bundle (`app.asar.unpacked/…`) | ⚠️ bis zum nächsten Rebuild |
| Patches im Checkout (`intro.tsx`, `package.json`, `assets/`) | ❌ nein |

Für dauerhafte Quellcode-Änderungen: eigener Branch oder ein Patch-Skript, das
nach jedem Update erneut läuft.

---

## Fazit und Empfehlung

| Ziel | Weg | Aufwand | Update-fest |
|---|---|---|---|
| Logo-Farbe + Akzentfarben ändern | `hermes skin set ui_accent "#..."` | Minuten | ✅ |
| Sidebar-Farben | Skin bzw. Desktop-Theme (`sidebarBackground`, `sidebarBorder`) | Minuten | ✅ |
| Eigenes Logo an fester Stelle | Plugin in `titleBar.left`, abgelegt in `~/.hermes/desktop-plugins/` | ~30 Zeilen | ✅ |
| In-App-Badge / Favicon tauschen | 2 Dateien in `app.asar.unpacked/dist/` überschreiben | Minuten | ⚠️ |
| Dock-Icon tauschen | `assets/icon.icns` ersetzen + `--force-build` | 1 Build | ❌ |
| Wordmark-Text ersetzen | CSS-Overlay-Plugin **oder** `intro.tsx` patchen + Build | hoch | ❌ / ⚠️ |
| Menüeintrag umbenennen | `extendInfo` + Build, siehe Ein-Build-Test | 1 Build + Risiko | ❌ |

**Reihenfolge nach Aufwand-Nutzen:** Zuerst Skin-Farben (sofort, risikolos,
update-fest). Dann das In-App-Badge (zwei Dateien kopieren). Dann das
Titlebar-Logo als Plugin — das ist der einzige Weg zu eigenem Bildmaterial an
fester Stelle, der ein Update übersteht. Dock-Icon als Teil eines ohnehin
fälligen Rebuilds. Menüeintrag und Wordmark-Text zuletzt: dort ist das
Verhältnis von Aufwand zu Update-Fragilität am schlechtesten.

---

## Quellenverzeichnis

Alle Pfade relativ zu `~/.hermes/hermes-agent/`.

| Thema | Datei |
|---|---|
| Wordmark | `apps/desktop/src/components/chat/intro.tsx:147,166` |
| Wordmark-Fundstellen | `apps/desktop/src/components/assistant-ui/thread/index.tsx:152`, `apps/desktop/src/plugins/kanban/board.tsx:1367` |
| Farbtoken | `apps/desktop/src/styles.css:36,150` |
| Skin → Theme-Mapping | `apps/desktop/src/themes/skin.ts:97` |
| Theme-Modell + Grenze | `apps/desktop/src/themes/types.ts:9,13` |
| User-/Backend-Themes | `apps/desktop/src/themes/user-themes.ts:153`, `themes/backend-sync.ts` |
| Plugin-Vertrag | `apps/desktop/src/contrib/plugin.ts:59`, `contrib/types.ts:17` |
| Slot-Konstanten | `apps/desktop/src/sdk/index.ts:250-261`, `app/routes.ts:82,111` |
| Sidebar-Rendering | `apps/desktop/src/app/chat/sidebar/index.tsx:300,317` |
| Plugin-Beispiel | `apps/desktop/src/plugins/kanban/plugin.tsx:115` |
| Plugin-Loader | `apps/desktop/src/contrib/runtime-loader.ts:182` |
| Web-UI-Themes | `hermes_cli/web_server.py:16714`, `~/.hermes/dashboard-themes/clean-webui.yaml` |
| Menüname | `apps/desktop/electron/main.ts:680,979,5458,5460`, `apps/desktop/package.json:3,212-215` |
| CLI-App-Suche | `hermes_cli/main.py:6001`, Signierung `:6896` |
| Icons | `apps/desktop/assets/icon.icns`, `package.json:178,206`, `src/components/brand-mark.tsx:16` |
| Skin-Doku (mitgeliefert) | `skills/autonomous-ai-agents/hermes-agent/references/themes.md` |
