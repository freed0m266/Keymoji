# 61 — Konstantní výška klávesnice + generalizovaný `topRegion`

**Status:** Done — 2026-06-13

**Status (původní):** Todo

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium (UX — klávesnice neposkakuje při přepínání stránek; víc místa pro emoji panel; popover headroom na default nastavení)

## Cíl

Klávesnice má mít **stejnou výšku napříč všemi stránkami** (letters, symbols, emoji, emoji-search) — konkrétně tu výšku, jakou má letters stránka **s** `SuggestionBarView`. Dnes se výška mezi stránkami mění a nejvíc bije do očí skok letters(`306`) ↔ emoji(`264`) = **42pt**.

Druhý, provázaný cíl: **zobecnit prostor nad klávesnicí** z „místo pro `SuggestionBarView`" na neutrální `topRegion` — rezervovaný horní region, který dnes hostí bar, ale do budoucna může hostit i jiný obsah.

Motivace (proč to chci):
- **Jednoduchost** — jedna výška, míň výškové matematiky, zmizí celá třída drift bugů (viz Návrh).
- **Víc prostoru pro emoji panel** — emoji stránka se zvýší o +42 a ten prostor jde do panelu (víc emoji).
- **Popover headroom** — viz [Popover: částečná výhra](#popover-částečná-výhra-task-21-zůstává).
- **Budoucí využití** — `topRegion` je obecný kontejner; do budoucna v něm může být i jiný obsah než suggestions.

## Co „vždy stejná výška" znamená (a co ne)

- Konstantní **napříč stránkami** při daném nastavení. Přepínání letters → symbols → emoji → search výšku nemění.
- **Není** konstantní napříč *nastaveními*: number row toggle (`showNumberRow`) a landscape (number row vynuceně off) výšku dál mění — to je správně, je to explicitní volba uživatele ušetřit místo.
- Region je rezervovaný **vždy**, nezávisle na `suggestionsEnabled` i na field eligibilitě. `suggestionsEnabled` / eligibilita nově řídí **jen obsah** regionu (bar vs prázdno), **ne jeho existenci ani výšku**. Tj. když uživatel suggestions vypne (nebo je v poli na heslo), region tam pořád je — jen prázdný.

## Klíčová zjištění z průzkumu kódu

### Výška se dnes počítá na dvou místech a musí se shodnout

Drift mezi nimi = iOS ořízne SwiftUI obsah (původní „chybí search bar na `.emojiSearch`" bug, dokola řešený v taskách 53/54/56):

1. **View** — [`KeyboardView.keyboardHeight`](../KeyboardUI/Sources/Views/KeyboardView.swift:257) přes `KeyboardMetrics.keyboardHeight(for:showsSuggestionBar: effectiveShowsBar)`.
2. **Host** — [`KeyboardViewController.desiredKeyboardHeight()`](../KeyboardExtension/Sources/KeyboardViewController.swift:432) přes `KeyboardMetrics.keyboardHeight(for:showsSuggestionBar: showsSuggestionBar)`.

Oba dnes počítají boolean `showsSuggestionBar` zvlášť ([`effectiveShowsBar`](../KeyboardUI/Sources/Views/KeyboardView.swift:96) vs [`showsSuggestionBar`](../KeyboardExtension/Sources/KeyboardViewController.swift:501)) a **musí** dát totéž.

> **Hlavní výhra refaktoru:** jakmile je region **vždy** rezervovaný (nezávisle na toggle/eligibilitě), výška přestane na `showsSuggestionBar` záviset. Bude záviset jen na **typu stránky + number row**, což oba konzumenti už dnes sdílí přes `layout`. Celý fragilní pár `effectiveShowsBar` / `showsSuggestionBar` jako *height driver* zmizí → drift se stane nemožným, ne jen „pohlídaným".

### Dnešní metriky ([`KeyboardMetrics.swift`](../KeyboardCore/Sources/Logic/KeyboardMetrics.swift))

| konstanta | hodnota | slot (cap + `rowGap` 12) |
|---|---|---|
| `keyCapHeight` | 42 | body row = **54** |
| `numberRowCapHeight` | 36 | number row = **48** |
| `suggestionBarFootprint` = `suggestionBarHeight 40` + `suggestionBarGap 2` | 42 | → `topRegionHeight` = **42** |
| `emojiSearchChromeHeight` | 86 | (search field 32 + results 44 + gapy) |

- Emoji stránka je dnes speciál: [`emojiPageHeight`](../KeyboardCore/Sources/Logic/KeyboardMetrics.swift:62) zrcadlí letters **bez** baru.
- Number row se na emoji i emoji-search **nikdy** nezobrazuje ([`LayoutBuilder.swift:25`](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:25)), proto emoji-search potřebuje vlastní chrome.

## Návrh

### 1. Výškový model — jeden kanonický vzorec

```
topRegionHeight = 42                      // = dnešní suggestionBarFootprint
bodyRow         = 54                       // keyCapHeight 42 + rowGap 12
numberRow       = 48                       // numberRowCapHeight 36 + rowGap 12
qwertyRows      = 4 × bodyRow = 216        // 3 letter rows + bottom row

canonicalHeight(showsNumberRow) = (showsNumberRow ? numberRow : 0) + qwertyRows + topRegionHeight
```

`KeyboardMetrics.keyboardHeight(for:)` **zahodí parametr `showsSuggestionBar`** a počítá per stránku:

| stránka | výška | vs dnes (number row ON) |
|---|---|---|
| **letters / symbols** | `rows + topRegionHeight` = `canonicalHeight` | beze změny (region už dnes svítí, když suggestions on) |
| **emoji** | `= canonicalHeight` | **+42** → jde do panelu (víc emoji) |
| **emoji-search** | `qwertyRows + chrome`, kde `chrome = max(86, canonicalHeight − qwertyRows)` | **+4** (chrome 86 → 90) |

Konkrétní čísla:

| stránka | number row ON | number row OFF |
|---|---|---|
| letters / symbols | 306 | 258 |
| emoji | 306 (`+42`) | 258 (`+42`) |
| emoji-search | 306 (chrome 90, `+4`) | **302** (chrome 86, **výjimka** — viz níže) |

### 2. Emoji-search výjimka (number row OFF)

`emojiSearchChromeHeight` přestane být magická konstanta a stane se **odvozenou**:
`chrome = max(minChrome 86, canonicalHeight − qwertyRows)`.

- **Number row ON:** `canonicalHeight − qwertyRows = 306 − 216 = 90 ≥ 86` → chrome 90, emoji-search **přesně** matchuje letters (zmizí dnešní 4pt drift).
- **Number row OFF:** `258 − 216 = 42 < 86` → chrome spadne na floor **86**, emoji-search = `302`. To je **víc** než letters (`258`).

Tahle výjimka je **záměrná a nevyhnutelná**: search chrome (search field 32 + results 44) je iredukovatelný a větší než bar (42). Když number row nedá nahoře dost prostoru (90pt), aby chrome pohltil, emoji-search je jediná stránka, co smí být vyšší. Number row OFF = buď uživatelská volba, nebo landscape. Invariant tedy zní:

> letters = symbols = emoji **vždy**; emoji-search se přidává jako rovný jen když má number row dost prostoru nahoře.

`.emojiSearchSymbols` se chová identicky jako `.emojiSearch` (sdílí `isEmojiSearch`).

### 3. Generalizace `topRegion` — rezervace + rename + tenký seam (žádný enum)

Záměrně **minimální** (YAGNI — žádná spekulativní plugin abstrakce):

- `KeyboardMetrics`: zavést `topRegionHeight = 42` (= dnešní `suggestionBarFootprint`). `suggestionBarHeight (40)` + `suggestionBarGap (2)` zůstávají jako **interní detail toho, jak bar region vyplňuje** (content 40 + gap 2 pod ním).
- [`KeyboardView.body`](../KeyboardUI/Sources/Views/KeyboardView.swift:100): horní `if effectiveShowsBar { SuggestionBarView … }` blok se stane pojmenovaným `topRegion` kontejnerem (pevná výška `topRegionHeight`), který **dnes** renderuje `SuggestionBarView`. Swap na jiný obsah ať je triviální místo (`@ViewBuilder` / malý switch) — ale **žádný `TopRegionContent` enum se nestaví**, dokud nevznikne reálný druhý typ obsahu.
- Region je na letters/symbols **vždy** přítomný. Emoji a emoji-search si **vyplní kanonickou výšku samy** svým obsahem (emoji panel roste; emoji-search má svůj chrome) — region jako samostatný slot tam *není* (rozhodnutí 3b, ne uniformní prázdný slot nad emoji panelem).
- `SuggestionBarView` zůstává beze změny jménem i chováním — je to *konkrétní* obsah (suggestions), jen nově sedí *uvnitř* `topRegion`.

> `topRegion` je obecný kontejner; do budoucna může hostit i jiný obsah než `SuggestionBarView`. Konkrétní budoucí featury tu **záměrně nevyjmenováváme** — jediná tvrdá podmínka je „cokoliv sem přijde, musí se vejít do `topRegionHeight` 42pt".

### 4. Obsah regionu — pravidla beze změny

Co se v regionu kreslí, zůstává **přesně jako dnes** (mění se jen rezervace výšky):

- suggestions ON & eligible & jsou chips → chips
- suggestions ON & eligible & žádné chips → favorites scroll
- suggestions ON & eligible & nic & žádné favorites → prázdno (silent)
- **suggestions OFF nebo neeligibilní pole → region je rezervovaný, ale prázdný/silent** (dřív se nekreslil vůbec a výška se lišila o 42)

Žádné nové vynořování favorites ve stavu, kdy uživatel bar vypnul. `KeyboardViewController.showsSuggestionBar` (a `makeRoot` / `favoritesVisible`) zůstává jako **content gate** (řídí, jestli se počítají suggestions a co se předá do baru) — jen **přestane řídit výšku**.

## Popover: částečná výhra (task 21 zůstává)

Long-press popover potřebuje **~56pt** nad horní hranou klávesy ([`KeyView.swift:148`](../KeyboardUI/Sources/Views/KeyView.swift) → `-cellHeight(44) - 12`). Co je nad QWERTY top row na letters stránce po této změně:

| stav | prostor nad top row | popover (56pt) |
|---|---|---|
| number row **ON** + region (nově vždy) | `48 + 42 = 90` | ✓ **ořez zmizí** (i dnešní 8pt suggestions-off case) |
| number row **OFF** + region | `42` | ✗ ořez **zmenšen z 56 na ~14pt**, ale nezmizí |

Tj. na **default nastavení (number row on) tato změna popover clipping vyřeší úplně**; v no-number-row případě (uživatelská volba / landscape) výrazně zmírní. **Plný fix no-number-row top row — a preview bubliny ([task 25](25-key-preview-popup.md), ~92pt) — pořád vyžaduje [task 21](21-popover-top-row-clipping.md)** (resize `inputView` nahoru). Region se **nedimenzuje uměle na ≥56pt** — zůstává 42pt (= výška baru, vizuálně čisté); no-number-row edge case má vlastní task.

## Mimo scope

- **`TopRegionContent` enum / plugin systém pro budoucí obsah.** Jen rezervace + rename + seam. Enum se naskicuje slovně, nestaví se.
- **Favorites bez suggestions / samostatný favorites toggle.** Když je bar vypnutý, region je prázdný. Favorites-quick-access bez word suggestions je samostatná featura.
- **Plný popover/preview fix v no-number-row top row.** Zůstává [task 21](21-popover-top-row-clipping.md).
- **Konstantní výška napříč *nastaveními*.** Number row toggle a landscape výšku dál mění (záměr).
- **Změna vzhledu baru, chips, favorites, emoji panelu nebo search chrome** nad rámec výšky. Mění se jen kolik vertikálního prostoru dostanou.

## Testy

- **Snapshoty** — emoji a emoji-search stránka v nové (vyšší) výšce; letters/symbols vizuálně beze změny (region už dnes svítí, když suggestions on).
- **Height-equality** — `letters+region == symbols == emoji` při daném number row stavu; `emoji-search == canonicalHeight` když number row ON.
- **Emoji-search výjimka** — number row OFF → emoji-search smí být vyšší (chrome floor 86); ověřit, že se nepokouší zkrátit pod minimum.
- **Decoupling** — výška letters je **stejná** pro `suggestionsEnabled` ON i OFF (dřív se lišila o 42); stejně pro eligible vs neeligibilní pole.
- **Host == view** — `desiredKeyboardHeight()` == `KeyboardView.keyboardHeight` na **všech** stránkách a obou number row stavech (klíčový anti-drift test).
- **`KeyboardMetricsTests`** — nové asserty na `canonicalHeight` a per-page vzorce.

## Závislosti

Žádné blokující. Staví na výškové infrastruktuře z tasků 52/53 (bottom-up model) a 56 (bar na symbol page). Aktualizuje cross-ref v [task 21](21-popover-top-row-clipping.md) a [task 25](25-key-preview-popup.md) (number-row-on popover/preview headroom je nově pokrytý; zůstává no-number-row reziduum).
