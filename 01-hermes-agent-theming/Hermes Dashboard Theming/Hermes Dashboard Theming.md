# Hermes Dashboard Theming — was geht, was nicht

Recherche zur Frage: Wie weit lässt sich das **Web-Dashboard** (`hermes
dashboard`) an eigenes Branding anpassen? Dieselben Fragestellungen wie im
Schwesterdokument [Hermes Desktop Theming](../Hermes%20Desktop%20Theming/Hermes%20Desktop%20Theming.md):
das „HERMES AGENT"-Wordmark, ein eigenes Logo an fester Stelle, der
Anwendungsname und das Icon.

**Kurzfassung vorweg: das Dashboard ist der deutlich freundlichere Fall.** Wo
die Desktop-App auf Farben und Schriften begrenzt ist, kennt das Dashboard
freies `customCSS`, benannte Bild-Assets, Component-Style-Overrides,
Layout-Varianten und ein Plugin-Slot-System — alles ohne Rebuild, alles aus
`~/.hermes/`.

Alle Aussagen sind am lokalen Quellcode belegt, nicht an der Online-Doku.
Stellenangaben (`datei.ts:123`) beziehen sich auf `~/.hermes/hermes-agent/`,
Arbeitsstand 2026-08-11, Commit `c0106e50e7`, Arbeitsverzeichnis sauber.
Zeilennummern wandern mit jedem Update — im Zweifel nach dem zitierten
Bezeichner greppen.

## Testumgebung

| | |
|---|---|
| Hermes Agent | 0.20.0 (0.17.0), Installationsmethode `git` |
| Installationsort | `~/.hermes/hermes-agent` |
| Oberfläche | Web-Dashboard, Start via `hermes dashboard` |
| Quellen | `web/src/` (React-SPA), ausgeliefert aus `hermes_cli/web_dist/` |
| Server | `hermes_cli/web_server.py` (FastAPI) |
| Betriebssystem | macOS, Darwin 25.5.0 |
| Datum der Recherche | 2026-08-11 |

## Was verifiziert ist — und was nicht

**Am Quellcode belegt:** der vollständige Theme-Vertrag und — wichtiger — was
der **serverseitige Normalisierer** davon tatsächlich durchlässt; beide
Render-Stellen des Wordmarks; die vollständige Slot-Liste; der
Plugin-Discovery-Pfad; Seitentitel und Favicon; die Rebuild-Logik.

**Nicht verifiziert:** Es wurde **kein Theme und kein Plugin real angelegt und
im Browser geprüft.** Alle Aussagen sind Code-Lektüre. Insbesondere der
`customCSS`-Weg zum Ersetzen des Wordmarks ist plausibel hergeleitet, aber
nicht ausprobiert.

---

## 1. Das Theme-System — Umfang

Ein Dashboard-Theme ist eine YAML-Datei in `~/.hermes/dashboard-themes/<name>.yaml`.
Der Server scannt das Verzeichnis (`web_server.py:16703`) und liefert das Theme
über `GET /api/dashboard/themes` **vollständig** an den Client aus.

Aktivierung persistiert in `config.yaml` unter `dashboard.theme`:

```bash
# im Dashboard über den Theme-Switcher, oder per API:
curl -X PUT localhost:<port>/api/dashboard/theme -d '{"name":"mein-theme"}'
```

Der Vertrag (`web/src/themes/types.ts`) umfasst:

| Block | Inhalt |
|---|---|
| `palette` | 3-Schichten-Modell `background` / `midground` / `foreground`, je `hex` + `alpha` |
| `typography` | `fontSans`, `fontMono`, `fontDisplay`, **`fontUrl`** (externes Stylesheet), `baseSize`, `lineHeight`, `letterSpacing` |
| `layout` | `radius`, `density` (`compact` / `comfortable` / `spacious`) |
| `layoutVariant` | `standard` / `cockpit` / `tiled` — **`cockpit` blendet eine linke Sidebar-Leiste als Plugin-Slot ein** (`types.ts:77`) |
| `assets` | `bg`, `hero`, **`logo`**, `crest`, `sidebar`, `header` + beliebige `custom`-Schlüssel |
| `componentStyles` | 9 Buckets: `card`, `header`, `footer`, `sidebar`, `tab`, `progress`, `badge`, `backdrop`, `page` |
| `colorOverrides` | 19 shadcn-Tokens exakt pinnen |
| `customCSS` | **freies CSS**, als gescoptes `<style>` injiziert (`context.tsx:389`) |

### Die eigentliche Grenze: der serverseitige Normalisierer

Entscheidend ist nicht das TypeScript-Interface, sondern
`_normalise_theme_definition()` (`web_server.py:16558`). Was dort nicht
durchgereicht wird, erreicht den Client nie — **auch wenn das Interface ein
Feld dafür hat.**

Durchgelassen: `palette`, `typography`, `layout`, `layoutVariant`,
`colorOverrides`, `assets`, `customCSS`, `componentStyles`.

**Stillschweigend verworfen** (im TS-Interface vorhanden, vom Normalisierer
nicht übernommen):

| Feld | Folge |
|---|---|
| `seriesColors` | Diagrammfarben in Analytics/Models nicht per YAML setzbar |
| `swatchColors` | Eigene Vorschau-Kacheln im Theme-Picker nicht setzbar |
| `terminalBackground` / `terminalForeground` | Farben des eingebetteten Terminals nicht setzbar |

Diese drei stehen nur Built-in-Themes offen (`web/src/themes/presets.ts`), also
nur mit Quellcode-Patch und Rebuild.

Weitere harte Grenzen:

- **`customCSS` ist auf 32 KiB begrenzt** (`_THEME_CUSTOM_CSS_MAX`,
  `web_server.py:16555`) und wird bei Überlänge **stillschweigend
  abgeschnitten** — keine Fehlermeldung.
- Das CSS wird **bewusst nicht saniert**. Begründung im Code: das Dashboard ist
  localhost-only, Theme-YAML hat dieselbe Vertrauensstufe wie `config.yaml`.
  Wer fremde Theme-Dateien einspielt, führt fremdes CSS aus.
- `assets`-Werte sind nur Strings (URL oder CSS-Ausdruck). Der Server lädt
  nichts herunter, er reicht durch.
- Nur die sechs benannten Asset-Schlüssel plus `custom` werden akzeptiert
  (`_THEME_NAMED_ASSET_KEYS`, `web_server.py:16537`).

---

## 2. Das „HERMES AGENT"-Wordmark

Es erscheint an **zwei Stellen**, die unterschiedlich funktionieren — das ist
die wichtigste Einzelheit dieses Abschnitts:

| Stelle | Quelle | Sichtbar |
|---|---|---|
| **Sidebar-Kopf** (groß, zweizeilig, `uppercase`) | **hartkodiertes JSX** (`App.tsx:607-611`) | Desktop-Breite; ausgeblendet, wenn die Sidebar eingeklappt ist |
| **Mobile Top-Bar** | i18n-String `t.app.brand` (`App.tsx:552`, definiert in `i18n/en.ts:56`) | schmale Viewports |

Das große Wordmark, das der Beschreibung „links in der Sidebar" entspricht, ist
also **kein i18n-String**, sondern literales JSX:

```jsx
// web/src/App.tsx:607-611
<Typography className="… text-midground uppercase">
  Hermes
  <br />
  Agent
</Typography>
```

Ein `brandShort: "HA"` existiert in allen Sprachdateien, wird aber **von keiner
Komponente gerendert** — toter Schlüssel.

### Zur Farbe: „blau" ist theme-abhängig, nicht Standard

Das Wordmark trägt `text-midground`, also die `palette.midground`-Farbe des
aktiven Themes. Der **Default** ist **nicht** blau, sondern Hermes-Creme
`#ffe6cb` (`presets.ts:47`). Blau (`#0053FD`) liefert das mitgelieferte Preset
**`nous-blue`** (`presets.ts:189`) — das ist derselbe Ton wie in der
Desktop-App. Wer im Dashboard ein blaues Wordmark sieht, hat `nous-blue`
(oder ein davon abgeleitetes Theme) aktiv.

**Farbe ändern** ist damit trivial: `palette.midground.hex` im eigenen Theme
setzen.

### Text ersetzen

| Weg | Möglich? | Anmerkung |
|---|---|---|
| Theme-Feld | ❌ | kein Branding-/Text-Feld im Theme-Vertrag |
| `customCSS` | ⚠️ ja, aber ungetestet | Wordmark per CSS ausblenden und eigenes Logo als `background-image` einsetzen — siehe unten |
| Plugin | ⚠️ teilweise | `header-left` fügt **davor** ein, ersetzt nicht |
| Quellcode | ✅ | `App.tsx:607-611` patchen + Rebuild |

---

## 3. Eigenes Logo an fester Stelle

Hier ist das Dashboard der Desktop-App klar überlegen — es gibt **drei** Wege.

### Weg A: Theme-Asset + `customCSS` (kein Code, kein Rebuild)

```yaml
# ~/.hermes/dashboard-themes/mein-brand.yaml
name: mein-brand
label: Mein Brand
description: Firmenlogo im Sidebar-Kopf

palette:
  background: "#0b0f14"
  midground:  "#c8102e"      # färbt u. a. das Wordmark
  foreground: "#ffffff"

assets:
  # data:-URI, damit dieser Weg wirklich ohne Plugin auskommt (s. u.).
  logo: "url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0i…')"

customCSS: |
  /* Beispielhaft — Selektoren gegen die laufende App prüfen. */
  #app-sidebar [class*="uppercase"] {
    visibility: hidden;
    position: relative;
  }
  #app-sidebar [class*="uppercase"]::after {
    content: "";
    visibility: visible;
    position: absolute;
    inset: 0;
    background-image: var(--theme-asset-logo);
    background-repeat: no-repeat;
    background-size: contain;
  }
```

**Wichtige Einschränkung, die der Feldname verschleiert:** `assets.logo`
allein bewirkt **nichts**. Der Kommentar im Vertrag sagt „header slot consumers
use this" (`types.ts:89`), aber **keine Shell-Komponente liest
`--theme-asset-logo`** — verifiziert, kein Treffer in `web/src`. Der Server
emittiert die Variable (`context.tsx:218`), verbrauchen muss sie Ihr eigenes
`customCSS` oder ein Plugin. Das Feld ist ein Transportmittel, kein
Feature.

Zweite Einschränkung: die Selektoren oben zielen auf generierte
Utility-Klassen. Das ist genauso brüchig wie der `<style>`-Trick in der
Desktop-App und kann bei jedem Update brechen. Wer es stabil will, nimmt Weg B.

**Dritte Einschränkung — wo liegt die Bilddatei?** Das Dashboard liefert
statische Dateien nur aus zwei Quellen aus: dem gebauten `web_dist/` (nicht
update-fest) und `/dashboard-plugins/<name>/…`, was ein **aktiviertes**
Plugin-Verzeichnis voraussetzt (`web_server.py:17402`). Ein Theme-YAML allein
hat keinen Ort für Binärdateien. Deshalb steht oben eine `data:`-URI: nur so
bleibt Weg A wirklich plugin-frei. Wer eine echte Datei referenzieren will,
braucht ohnehin ein Plugin-Verzeichnis — dann ist Weg B der ehrlichere Weg.
Beachten Sie: eine `data:`-URI in `assets` zählt nicht gegen das
32-KiB-Limit von `customCSS`, dieselbe URI direkt in `customCSS` dagegen schon.

### Weg B: Dashboard-Plugin im Slot `header-left` (der saubere Weg)

Die Shell rendert benannte Slots. `header-left` ist ausdrücklich dokumentiert
als *„injected before the Hermes brand in the top bar"* (`slots.ts:24`) und
sitzt unmittelbar vor dem Wordmark (`App.tsx:605`).

Verfügbare Shell-Slots (`slots.ts:61`, `KNOWN_SLOT_NAMES`):

| Slot | Lage |
|---|---|
| `backdrop` | Vollbild-Hintergrund hinter der Chrome, z-0 (`App.tsx:523`) |
| **`header-left`** | **vor dem Marken-Schriftzug** (`App.tsx:605`) |
| `header-right` | vor Theme-/Sprachumschalter |
| `header-banner` | volle Breite unter der Navigationsleiste (`App.tsx:568`) |
| `pre-main` / `post-main` | über bzw. unter dem Routen-Outlet (`App.tsx:758`, `:813`) |
| `overlay` | fixierte Ebene über allem (Scanlines, Vignette) |
| ~~`sidebar`~~ | **dokumentiert, aber nicht verdrahtet** — siehe unten |
| ~~`footer-left`~~ / ~~`footer-right`~~ | **dokumentiert, aber nicht verdrahtet** |

Die letzten drei Zeilen sind ein geprüftes Ergebnis, keine Vermutung: `App.tsx`
rendert genau sieben `<PluginSlot>`-Elemente (523, 568, 605, 716, 758, 813,
819). Ein `<PluginSlot name="sidebar">`, `"footer-left"` oder `"footer-right"`
existiert **nirgends** in `web/src`. Wer diese Slots belegt, sieht nichts.

Dazu 20 seitenbezogene Slots (`sessions:top`, `analytics:bottom`, `logs:top`, …)
zum Einhängen eigener Widgets in bestehende Seiten.

Registrierung aus dem Plugin-Bundle:

```js
window.__HERMES_PLUGINS__.registerSlot("mein-brand", "header-left", MyLogo);
```

Mehrere Plugins dürfen denselben Slot belegen; sie rendern gestapelt in
Registrierungsreihenfolge. Eine erneute Registrierung desselben Paares
`(plugin, slot)` ersetzt die vorherige.

### Weg C: Cockpit-Layout — kann weniger, als die Doku verspricht

Der Kommentar in `slots.ts:27` verspricht bei `layoutVariant: cockpit` eine
linke Seitenleiste aus dem `sidebar`-Slot. **Das stimmt nicht.** Geprüft:

- `layoutVariant` wird angewandt — es landet als `data-layout-variant` am
  Wurzelelement (`themes/context.tsx:282`) und an einem Container
  (`App.tsx:514`).
- Eine Seitenleiste rendert dabei **niemand**. Es gibt keinen
  `<PluginSlot name="sidebar">`, und `"cockpit"` kommt außerhalb der beiden
  Kommentare in `slots.ts` und `types.ts` im gesamten Frontend nicht vor.

`cockpit` ist also **nur ein CSS-Haken**: Ihr `customCSS` kann
`[data-layout-variant="cockpit"] { … }` adressieren und sich damit selbst eine
Fläche bauen. Ein fertiges Rail bekommen Sie nicht.

### Ein Muster, das in diesem Codebase dreimal auftrat

Drei dokumentierte Dinge liefern weniger als ihr Kommentar behauptet:

| Versprechen | Realität |
|---|---|
| `assets.logo` — „header slot consumers use this" (`types.ts:89`) | kein Shell-Konsument; nur eine CSS-Variable |
| `sidebar` / `footer-*`-Slots (`slots.ts:27`) | nirgends gerendert |
| `brandShort` (`i18n/en.ts`) | von keiner Komponente benutzt |

Nehmen Sie Kommentare in diesem Bereich als Absichtserklärung, nicht als
Zusage — und prüfen Sie vor dem Bauen mit einem `grep` nach dem Konsumenten.

---

## 4. Das Plugin-System

**Achtung, die mitgelieferten Tipps sind falsch.** `tips.py:386` und `:474`
sagen, man solle Dateien nach `~/.hermes/dashboard-plugins/` legen. Der
tatsächliche Discovery-Pfad ist ein anderer (`web_server.py:16873`):

| | |
|---|---|
| **Auf der Platte** | `~/.hermes/plugins/<name>/dashboard/manifest.json` |
| **Ausgeliefert unter** | `/dashboard-plugins/<name>/…` (nur die URL, `web_server.py:17402`) |

`~/.hermes/dashboard-plugins/` ist der **URL**-Präfix, kein Verzeichnis. Der
Tipp verwechselt beides.

Weitere geprüfte Randbedingungen:

- Ein Plugin muss in `plugins.enabled` stehen, sonst werden seine Assets nicht
  ausgeliefert (Sicherheitsfix GHSA-mcfc-hp25-cjv7).
- Auslieferung nur für eine Suffix-Allowlist: JS, CSS, JSON, HTML, **SVG, PNG,
  JPG**, WOFF. Logos sind also abgedeckt; `plugin_api.py` bleibt geschützt.
- Manifest-Felder (`web/src/plugins/types.ts`): `name`, `label`, `description`,
  `icon`, `version`, `tab` (`path`, `position`, `override`, `hidden`), `slots`,
  `entry`, `css`, `has_api`, `integrity` (SRI-Hash), `source`.
- **`tab.override`** ersetzt eine eingebaute Seite komplett durch die eigene
  (`types.ts:16`) — dafür gibt es in der Desktop-App keine Entsprechung.
- `tab.hidden: true` erlaubt reine Slot-Plugins ohne eigenen Navigationseintrag
  — genau das, was ein Logo-Plugin braucht.
- Projektbezogene Plugins (`./.hermes/plugins/`) sind standardmäßig aus und
  brauchen `HERMES_ENABLE_PROJECT_PLUGINS`.

---

## 5. Anwendungsname und Icon

Die Entsprechungen zu „Menüeintrag" und „App-Icon" der Desktop-App:

| Element | Quelle | Änderbar |
|---|---|---|
| Browser-Titel „Hermes Agent - Dashboard" | `<title>` in `web/index.html`, gebaut nach `hermes_cli/web_dist/index.html` | nur per Datei-Patch |
| Favicon | `/favicon.ico`, ausgeliefert aus `hermes_cli/web_dist/favicon.ico` | Datei ersetzen |

Beides liegt als **statische Datei** in `hermes_cli/web_dist/` und lässt sich
direkt überschreiben — kein Rebuild nötig, nur Neuladen im Browser.

Anders als bei der Desktop-App gibt es hier **keinen** Env-Schalter
(kein Pendant zu `HERMES_DESKTOP_APP_NAME`) und keine Info.plist-Mechanik.

---

## 6. Update-Fragilität

`hermes_cli/web_dist/` ist **nicht** in Git — verifiziert, greift
`.gitignore:79`. Ein `hermes update` überschreibt es also nicht direkt. **Aber:**
`hermes dashboard` ruft `_build_web_ui()` auf (`main.py:5666`), das per
Staleness-Prüfung gegen `web/` neu baut. Da ein Update frische Quellen
einspielt, wird `web_dist/` beim nächsten Dashboard-Start **neu erzeugt** — und
Ihr Patch ist weg.

| Anpassung | Ort | Update-fest |
|---|---|---|
| Theme-YAML | `~/.hermes/dashboard-themes/` | ✅ ja |
| Dashboard-Plugin | `~/.hermes/plugins/<name>/dashboard/` | ✅ ja |
| Titel / Favicon | `hermes_cli/web_dist/` | ❌ Rebuild beim nächsten Start |
| Wordmark-Patch | `web/src/App.tsx` | ❌ `git pull` überschreibt |

**Konsequenz:** Alles, was update-fest sein soll, gehört nach `~/.hermes/` —
also in ein Theme oder ein Plugin. Das ist im Dashboard leicht, weil dort
`customCSS` und Slots zur Verfügung stehen.

---

## 7. Dashboard vs. Desktop im Direktvergleich

| Fähigkeit | Web-Dashboard | Desktop-App |
|---|---|---|
| Farben | ✅ Palette + 19 Token-Overrides | ✅ ausführliches Token-Set |
| Schriften | ✅ inkl. `fontUrl` + `fontDisplay` | ✅ `fontSans`/`fontMono`/`fontUrl` |
| Layout (Radius, Dichte) | ✅ `layout.radius`, `density` | ❌ fest in `styles.css` |
| Layout-Variante | ⚠️ nur als `data-`Attribut für eigenes CSS | ❌ |
| Freies CSS | ✅ `customCSS`, 32 KiB | ❌ kein Hook |
| Bild-Assets im Theme | ✅ 6 benannte + `custom` | ❌ |
| Component-Styles | ✅ 9 Buckets | ❌ |
| Logo an fester Stelle | ✅ `header-left`-Slot | ✅ `titleBar.left`-Slot |
| Eingebaute Seite ersetzen | ✅ `tab.override` | ❌ |
| Wordmark-Text ersetzen | ⚠️ nur per `customCSS`-Trick | ⚠️ nur per CSS-Trick |
| Terminal-/Diagrammfarben | ❌ nicht per YAML (Normalisierer verwirft sie; nur Built-ins) | ✅ volle ANSI-Palette |

Bemerkenswert: die Desktop-App gewinnt nur bei den Terminal- und
Diagrammfarben. In jeder anderen Hinsicht ist das Dashboard offener.

---

## Fazit und Empfehlung

| Ziel | Weg | Aufwand | Update-fest |
|---|---|---|---|
| Wordmark-Farbe ändern | `palette.midground` im eigenen Theme | Minuten | ✅ |
| Komplettes Reskin (Farben, Schrift, Radius, Dichte) | ein Theme-YAML | ~1 Stunde | ✅ |
| Eigenes Logo an fester Stelle | Plugin im Slot `header-left`, `tab.hidden: true` | ~30 Zeilen | ✅ |
| Logo ohne Plugin | `assets.logo` als `data:`-URI + `customCSS` | Minuten | ✅, aber selektor-brüchig |
| Freie Fläche links | `layoutVariant: cockpit` + **eigenes** `customCSS` (kein fertiges Rail) | mittel | ✅ |
| Wordmark-Text ersetzen | `customCSS`-Trick oder `App.tsx`-Patch | mittel | ⚠️ / ❌ |
| Titel & Favicon | Dateien in `web_dist/` ersetzen | Minuten | ❌ |

**Empfohlene Reihenfolge:** Erst ein eigenes Theme-YAML anlegen — es deckt
Farben, Schriften, Radius, Dichte und Component-Styles in einer Datei ab, liegt
update-fest in `~/.hermes/` und braucht keinen Build. Dann, wenn ein echtes
Bildlogo dazukommen soll, ein schlankes Plugin mit `tab.hidden: true`, das
`header-left` belegt. Den `customCSS`-Trick zum Ausblenden des Wordmarks nur,
wenn das Logo den Schriftzug wirklich ersetzen (nicht ergänzen) soll — und mit
dem Wissen, dass die Selektoren ein Update nicht garantiert überleben.

---

## Quellenverzeichnis

Alle Pfade relativ zu `~/.hermes/hermes-agent/`.

| Thema | Datei |
|---|---|
| Wordmark Sidebar (hartkodiert) | `web/src/App.tsx:607-611` |
| Wordmark Mobile (i18n) | `web/src/App.tsx:552`, `web/src/i18n/en.ts:56` |
| Slot `header-left` gerendert | `web/src/App.tsx:605` |
| Slots `backdrop` / `overlay` | `web/src/App.tsx:523`, `:819` |
| Default-Route | `web/src/App.tsx:126` |
| Theme-Vertrag | `web/src/themes/types.ts` (Assets `:89`, Layout-Variante `:77`, ComponentStyles `:107`, customCSS `:171`) |
| customCSS-Injektion | `web/src/themes/context.tsx:389`, Asset-Vars `:218` |
| Default-Palette / `nous-blue` | `web/src/themes/presets.ts:47`, `:189` |
| Slot-Registry + Doku | `web/src/plugins/slots.ts:24,61` |
| Plugin-Manifest | `web/src/plugins/types.ts:16` |
| Theme-Normalisierer (das Gate) | `hermes_cli/web_server.py:16558` |
| Asset-Whitelist / CSS-Limit | `hermes_cli/web_server.py:16537`, `:16555` |
| Theme-Discovery | `hermes_cli/web_server.py:16703` |
| Plugin-Discovery-Pfad | `hermes_cli/web_server.py:16873` |
| Plugin-Asset-Auslieferung | `hermes_cli/web_server.py:17402` |
| Falscher Pfad-Tipp | `hermes_cli/tips.py:386` |
| Web-UI-Rebuild-Logik | `hermes_cli/main.py:5666` |
| `web_dist` ignoriert | `.gitignore:79` |
