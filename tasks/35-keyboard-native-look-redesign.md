# 35 — Redesign klávesnice: vizuální parita s nativní iOS klávesnicí

**Status:** Done — 2026-05-27

**Priorita:** v1.1 polish · **Úsilí:** M-L · **Dopad:** Medium (vizuální, ne funkční)

## Souhrn

Keymoji dnes „připomíná" iOS klávesnici, ale ne dost přesvědčivě, aby vedle stock Apple klávesy v dark mode neprozradil, že je z jiné dílny. Cíl tasku: vizuálně doladit klávesnici tak, aby vedle nativní (viz reference screenshoty přiložené k tomuto tasku v chatu) působila jako nerozeznatelná — stejná hierarchie barev, corner radius, paddings, font, row heights. **Funkčně se nic nemění** — number row, suggestion bar, emoji panel, long-press popover, trackpad-on-space, delete repeat atd. zůstávají všechno na svém místě.

Nejviditelnější odchylka je v [KeyStyle.swift](KeyboardUI/Sources/Style/KeyStyle.swift): mapping barev je obrácený proti Apple. Dnes je `characterKey` *tmavší* (systemGray4) než `systemKey` (systemGray2). Apple to má naopak — písmenkové klávesy jsou *světlejší*, system klávesy (shift / delete / 123) *tmavší*, a wide „function" klávesy (space, return, ABC switch) ještě tmavší / víc translucent. Plus jsou tam menší odchylky v paddings, row spacing, fontu space labelu a výšce number row.

## Scope

### 1. Audit konkrétních odchylek proti referenci

Před změnou kódu změřit (z přiložených reference screenshotů + side-by-side v simulátoru s nativní Apple klávesnicí ve stejném dark mode kontextu) každé z těchto čísel a zapsat je do PR description:

- top padding klávesnice (mezi top edge a první řádkou)
- horizontal padding (mezi side edge a krajní klávesou)
- row spacing (mezi řádky kláves)
- key spacing (horizontální mezera mezi klávesami v řádce)
- corner radius klávesy
- výška number row vs letter row vs bottom row
- font size letter klávesy
- font size + weight system glyph (shift, delete)
- font size + weight labelu na space („space")
- font size labelu na return key (Search / Go / Done)

Bez tohohle kroku celý task degraduje na „tweaknu to a uvidíme". Chceme audit s čísly, ne s intuicí.

### 2. Přepsat [KeyStyle.swift](KeyboardUI/Sources/Style/KeyStyle.swift) na 3 vrstvy

Apple klávesnice rozlišuje **tři** hladiny darkness, ne dvě:

| Vrstva | Kde | Apple dark mode |
|---|---|---|
| **Character** | a-z, 0-9, symboly | nejsvětlejší (~systemGray3) |
| **System** | shift, delete, 123/ABC | středně tmavá (~systemGray5) |
| **Function** | space, return, emoji, switchPage | nejtmavší / translucent — splývá s pozadím |

V dnešním kódu jsou jen `characterKey()` a `systemKey()` (+ `shiftActive()`). Přidat třetí variantu (např. `functionKey()`) a v `style(for:page:)` dispatchnout podle `key.action`:

- `.space`, `.return`, `.switchPage`, `.dismissKeyboard` → function
- `.shift`, `.backspace`, `.deleteWord` → system
- `.insertText`, `.insertRawText`, `.cursorOffset` → character

Hodnoty barev: Apple-přesné tints jsou private (`_UIKBColorKey*`) — **nepoužívat**, App Store risk. Najít vizuální match přes public `UIColor.systemGray{3,4,5,6}` nebo `Color(white:..., opacity:...)` over keyboard background. Vyzkoušet i `.regularMaterial` / `.thinMaterial` jako fill — translucent feel Apple kláves se přes material často dohoní levněji než trefit konkrétní šedý odstín.

Stejné posouzení pro **light mode** — barvy nejsou jen inverzí dark mode, projít zvlášť.

### 3. Klávesnice background

Aktuálně `Color(.systemBackground)` ([KeyboardView.swift:166](KeyboardUI/Sources/Views/KeyboardView.swift:166)). Apple keyboard background je v dark mode lehce *odlišný* od `systemBackground` — má vlastní tint, který udrží kontrast s function keys. Vyzkoušet `UIColor.systemGray6` nebo material background s mírným tintem. Validovat side-by-side, ne intuicí.

### 4. Corner radius

Dnešní `cornerRadius: 5` na všech variantách. Apple klávesy vypadají na ~5-6pt — pravděpodobně blízko. Pixel-přesně změřit z reference screenshotu, posunout o 1-2pt jen pokud rozdíl je viditelný.

### 5. Spacing a paddings

Aktuální hodnoty:
- [KeyboardView.swift:67-69](KeyboardUI/Sources/Views/KeyboardView.swift:67): `horizontalPadding: 3`, `topPadding: 4`, `rowSpacing: 10`
- [KeyRowView.swift:18](KeyboardUI/Sources/Views/KeyRowView.swift:18): HStack `spacing: 4`

Sladit s naměřenými hodnotami z bodu 1. Tipuju, že rowSpacing je u Apple menší (~7-8pt) a key spacing podobný (~5pt), ale je to věc změření.

### 6. Number row výška a font

Number row dnes má `maxHeight: 38` ([KeyboardView.swift:159](KeyboardUI/Sources/Views/KeyboardView.swift:159)) a používá `characterKey` font (22pt regular). Apple číslíčka v number row vypadají vizuálně menší (~20pt) a řádek tenčí (~36pt). Pokud audit potvrdí, zavést `numberRowStyle()` variantu nebo podmíněně tweaknout font v KeyView pro keys v `isNumberRow` řádce.

### 7. Bottom row labely (space / return)

[KeyView.swift:441-471](KeyboardUI/Sources/Views/KeyView.swift:441) renderuje Text labely se `style.font` z KeyStyle. Apple má:
- „space" — ~17pt **regular**, ne semibold
- „Search" / „Go" / „Done" — semibold

Dnešní `systemKey().font` je 16pt semibold — pro return key OK, pro space ne. Buď zavést `function` font variantu (slabší weight), nebo podmíněně override fontWeight v KeyView pro `.space`.

### 8. Snapshot testy regenerovat

[KeyboardUI/Tests](KeyboardUI/Tests) drží snapshoty `KeyboardView` a `LongPressPopover`. Všechny budou diff. Vizuálně překontrolovat každý před acceptem — chceme nové vizuály *protože je to redesign*, ne accept-all rubber-stamp na něčem rozbitém.

### 9. Akceptační kritérium — side-by-side

Finální verifikace: screenshot Keymoji a screenshot Apple stock klávesnice ve stejné scéně (Spotlight nebo Safari search bar, dark mode, stejný device), překryté v Preview / Pixelmator. Per-vrstva backgroundový rozdíl < 5 % RGB; geometrie kláves se nesmí lišit o víc než 1pt na žádné dimenzi.

Stejný test i v light mode.

## Mimo scope

- **Jiné funkce klávesnice.** Number row toggle, emoji panel, suggestion bar, long-press popover, trackpad mode, delete repeat, haptika, sound — všechno zůstává. Měníme jen vzhled.
- **Custom themes / barevné palety.** Apple-like je *jedna* hardcoded paleta (per dark/light). User-customizable themes jsou separátní téma, mimo v1.x.
- **Press animace.** Dnešní `pressedBackgroundColor` swap je adekvátní. Apple-style „scale + shadow + zvedlý preview" patří do tasku [25](tasks/25-key-preview-popup.md), ne sem.
- **Globe key.** [Task 30](tasks/30-remove-globe-key.md) ho odstranil záměrně. Že je v reference screenshotech, není důvod ho vracet.
- **Layout / klávesy samotné.** Měníme jen styl — ne pořadí kláves, ne weights, ne alternates v long-press popoveru.
- **Pixel-perfect RGB match.** Cíl je „na první pohled nepoznáš". Ne identický hash screenshotu.
- **Použít private `_UIKBColor*` API.** App Store risk, mimo scope. Vystačit si s public color API.

## Závislosti

- **Žádné blokující.** Task běží nad existujícím layoutem a key dispatchem; nezávisí na [33](tasks/33-feature-modules-and-vm-refactor.md) ani [34](tasks/34-full-unicode-single-emoji-catalog.md).
- **Reference screenshoty** uživatel přiloží k chatu při spuštění `/task 35`. **Bez nich nelze provést audit z bodu 1** — pokud screenshoty nejsou v promptu, *zastavit a vyžádat si je*, ne hádat hodnoty.

## Hotovo když

- [KeyStyle.swift](KeyboardUI/Sources/Style/KeyStyle.swift) rozlišuje 3 vrstvy (character / system / function), aplikováno přes `key.action`-based dispatch v `style(for:page:)`.
- Paddings / row spacing / key spacing v [KeyboardView.swift](KeyboardUI/Sources/Views/KeyboardView.swift) a [KeyRowView.swift](KeyboardUI/Sources/Views/KeyRowView.swift) sladěné s naměřenými hodnotami z reference screenshotů (audit zapsaný v PR description).
- Side-by-side screenshot (Keymoji vlevo, Apple stock vpravo, oboje dark mode, stejná scéna) — rozdíl backgroundu < 5 % RGB, geometrie kláves se neliší o víc než 1pt na žádné dimenzi.
- Stejné side-by-side i pro light mode.
- Snapshot testy aktualizované; každý nový snapshot vizuálně překontrolovaný.
- **Manuální test:** instalovat extension, povolit v Settings, otevřít Messages (dark + light mode) — Keymoji splývá s Apple toolbarem nad ní (suggestion bar, accessory views) bez „aha, jiná dílna" momentu.

## Reference

- [KeyStyle.swift](KeyboardUI/Sources/Style/KeyStyle.swift) — hlavní místo změny
- [KeyboardView.swift](KeyboardUI/Sources/Views/KeyboardView.swift) — paddings, background, rowSpacing
- [KeyRowView.swift](KeyboardUI/Sources/Views/KeyRowView.swift) — HStack spacing mezi klávesami
- [KeyView.swift](KeyboardUI/Sources/Views/KeyView.swift) — corner radius render, font aplikace, label content
- [KeyboardUI/Tests](KeyboardUI/Tests) — snapshoty k regeneraci
- Apple HIG — Custom Keyboards: <https://developer.apple.com/design/human-interface-guidelines/custom-keyboards>
- **Reference screenshoty Apple klávesnice — uživatel je přiloží k chatu při spuštění `/task 35`**
