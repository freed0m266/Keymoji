# 39 — Emoji search v keyboardu (`.emojiSearch` mode)

**Status:** Done — 2026-05-29

**Priorita:** v1.1 · **Úsilí:** L · **Dopad:** High (discovery napříč 1 400 emoji, parity s nativní iOS klávesnicí)

## Souhrn

Native iOS emoji picker má v horní části search input („Search Emoji"). Tap aktivuje QWERTY layout + horizontal scrollable bar s matching emoji a vrátí se po `×` zpět do gridu. Po expansi catalogu na ~1 400 emoji v tasku [34](34-full-unicode-single-emoji-catalog.md) je objevení specifického emoji bez search prakticky nemožné — task 34 to v Mimo scope explicitně označil jako future UX task.

Tento task přidává tu samou capability do Keymoji's [`EmojiPanelView`](KeyboardUI/Sources/Views/EmojiPanelView.swift): trvale viditelný search bar nad gridem (mode `.emojis`) a po jeho tapu mode switch do nového `.emojiSearch` (QWERTY pro typing query + horizontal results bar nahoře). Search algoritmus je prefix-match přes CLDR keywords + emoji name + Slack shortcode, multi-word AND.

## Předpoklady (rozhodnutí z grill session 2026-05-28)

- **Scope:** jen `EmojiPanelView` (keyboard). [`EmojiCatalogPickerView`](Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift) v host appce zůstává bez search — to je samostatný future task.
- **Data model:** `EmojiCatalog` API se mění z `[String]` na `[Emoji]`. Struct nese `glyph`, `keywords`, `category`. Slack shortcode **není** field v structu (zůstává v [`SlackEmojiTable`](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) jako jediný zdroj pravdy, konzistentní s task 34 separací zdrojů).
- **Keyword zdroj:** [unicode-emoji-json](https://github.com/muan/unicode-emoji-json) — stejný upstream co task 34 navrhoval pro samotný catalog. `keywords` pole má CLDR anotace (5-15 keywords per emoji, EN).
- **Bundling:** `KeyboardCore/Resources/EmojiData.json` (lazy parse při prvním přístupu). Vracíme se k původnímu pipeline plánu z task 34, který nakonec skončil inline ve Swift — pro keywords ale je dat o řád víc a inline by zafailoval na incremental compile times.
- **Match style:** prefix-match na keywords + name (jako [`SlackEmojiSuggester`](KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) line 56). Multi-word query → AND přes tokeny.
- **Mode model:** nový case `KeyboardPage.emojiSearch`. State machine, layout builder a input dispatcher se ho dotknou.
- **Locale:** EN only. Konzistentní s [`EmojiCategory.accessibilityLabel`](KeyboardCore/Sources/Models/EmojiCatalog.swift:23) a fixací z task 34 Mimo scope.

## Scope

### 1. `Emoji` struct + redesign `EmojiCatalog`

Nový soubor [`KeyboardCore/Sources/Models/Emoji.swift`](KeyboardCore/Sources/Models/Emoji.swift):

```swift
public struct Emoji: Sendable, Equatable, Hashable, Identifiable {
    public let glyph: String
    public let keywords: [String]
    public let category: EmojiCategory

    public var id: String { glyph }
}
```

Změny v [`EmojiCatalog`](KeyboardCore/Sources/Models/EmojiCatalog.swift):

- `public static func emojis(for category: EmojiCategory) -> [Emoji]` (signaturu měníme z `[String]`).
- Nový `public static var all: [Emoji]` — flat collection napříč všemi static kategoriemi (lazy z JSON), plus hardcoded flags.
- Interně: `private static let staticEntries: [Emoji]` lazy-loaded z `Bundle.module.url(forResource: "EmojiData", withExtension: "json")` při prvním přístupu. Cached `[EmojiCategory: [Emoji]]` partition pro O(1) per-category lookup.
- `flags` kategorie zůstává hardcoded (regional indicator pairs, viz task 34 bod 7) — stejný seznam co dnes, jen wrap do `Emoji(glyph:, keywords: [], category: .flags)`. Pro flags můžeme přidat minimální keyword set ručně (`"czech"`, `"slovak"`, …) v separátním follow-upu — v rámci tohoto tasku jen prázdné keywords pro vlajky.

### 2. Build skript + JSON resource

- `scripts/generate_emoji_search_data.sh` — wget nebo curl stáhne `data-by-emoji.json` z pinned verze [unicode-emoji-json](https://github.com/muan/unicode-emoji-json) (verze v scriptu hardcoded), filtruje single-base-codepoint emoji (stejný filtr co task 34), mapuje `group → EmojiCategory`, vytvoří minimalizovaný JSON s `{glyph, keywords, category}` per entry. Použít `jq` pro minimalizaci.
- Výstup: `KeyboardCore/Resources/EmojiData.json` — pole objektů `{"g": "😀", "k": ["grinning", "face"], "c": "smileys"}`. Krátké keys protože ~1 400 entries × redundantní field names jsou KB navíc.
- **Checked-in**, build sám nestahuje (task 34 reference: scripts/generate_emoji_catalog.sh paradigm).
- `KeyboardCore` target v `Tuist/ProjectDescriptionHelpers/Targets/KeyboardCore.swift` (nebo wherever) musí přidat `resources: ["Resources/**"]` aby se JSON dostal do bundle.

### 3. `EmojiSearchIndex`

Nový [`KeyboardCore/Sources/Logic/EmojiSearchIndex.swift`](KeyboardCore/Sources/Logic/EmojiSearchIndex.swift):

```swift
public enum EmojiSearchIndex {
    public static let defaultLimit: Int? = nil // unlimited horizontal scroll

    public static func search(
        query: String,
        catalog: [Emoji] = EmojiCatalog.all,
        slackTable: [String: String] = SlackEmojiTable.defaultTable,
        limit: Int? = defaultLimit
    ) -> [Emoji]
}
```

Algoritmus:

1. Trim + lowercase query. Pokud empty → vrátit `[]` (caller si pak rozhodne fallback na recents).
2. Tokenize po whitespace → `tokens: [String]`.
3. Pro každý `Emoji` v catalogu:
   - Vyrobit množinu searchovaných stringů: name (převedeno z `keywords` nebo bundlované zvlášť — pokud `unicode-emoji-json` neukládá `name` v `keywords`, přidat name jako další pole v JSONu a tedy do `Emoji.searchableFields`) + jednotlivé keywords. Plus slack shortcode pokud `slackTable.reverseLookup[emoji.glyph]` vrátí non-nil.
   - **Match condition (multi-word AND):** každý token musí prefix-matchnout aspoň jeden ze searchovaných stringů.
4. Ranking (deterministic):
   - **Tier 1:** query == celý name (jednoho slovesa) → exact name match.
   - **Tier 2:** name `.hasPrefix(query)` (single-token query only).
   - **Tier 3:** aspoň jeden keyword `.hasPrefix(query/first-token)`.
   - **Tier 4:** slack shortcode `.hasPrefix(query)`.
   - Uvnitř tier: pořadí z upstream catalogu (Unicode order = `EmojiCatalog.all` index).
5. `limit` → `Array(results.prefix(limit ?? Int.max))`.

Pre-computed lowercased pole na `Emoji`: pro perf nestačí lowercaseovat za běhu. Buď na bundle-load lowercaseovat všechny keywords + name (memory hit ~50KB strings, OK), nebo separátní helper `EmojiSearchEntry` cached vedle `Emoji`. **Volba:** lowercaseovat při bundle-load do private `searchableTokens: [String]` array uvnitř `EmojiCatalog`, držet `parallel` array `[Emoji]` × `[searchableTokens]` indexovaný stejně. `Emoji` struct samotný zůstává minimalistický a public (žádný cache field).

### 4. `KeyboardPage.emojiSearch` + state model

[`KeyboardPage`](KeyboardCore/Sources/Models/KeyboardPage.swift):

```swift
public enum KeyboardPage: Sendable, Equatable {
    case letters(ShiftState)
    case symbols(SymbolPage)
    case emojis
    case emojiSearch  // NEW
}
```

[`KeyboardState`](KeyboardCore/Sources/Models/KeyboardState.swift):

- Přidat `public var searchQuery: String = ""` — transient, neperzistuje se do AppGroupStore.

Transitions:

- `.emojis` → `.emojiSearch`: tap na search bar v `EmojiPanelView`. `KeyboardState.searchQuery` zůstává prázdný (nový search session).
- `.emojiSearch` → `.emojis`: tap `×` v search bar. Vyčistí `searchQuery` a vrátí `page = .emojis`.
- `.emojiSearch` → ostatní pages: zatím **nezávazné** (user musí nejdřív `×` exit). Zjednodušuje state machine — pokud později chceme „smiley" toggle v search-mode bottom row, lze rozšířit.

[`ShiftStateMachine`](KeyboardCore/Sources/Logic/ShiftStateMachine.swift) update: `.emojiSearch` mode má vlastní shift management nezávislý na `.letters` — query je case-insensitive při matchování, ale QWERTY UX musí podporovat lowercase typing. Doporučení: `.emojiSearch` ignoruje shift toggle (search není o psaní caps), nebo přijme shift jen pro vizuální feedback a query je vždy lowercaseována.

### 5. `LayoutBuilder` rozšíření

[`LayoutBuilder.makeRows(page:)`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:8) — přidat case `.emojiSearch`:

- Vrátí stejný QWERTY layout jako `.letters(.lower)` v lower row varianta — ale **bottom row** je upravený:
  - `123` toggle (jako standard)
  - **emoji** key na bottom row JE: **NE** — exit ze search modu jde výhradně přes `×` v search bar. (Q13 odpověď.)
  - space + return (return = jen visual confirm pro user, akce = noop nebo exit search?). **Rozhodnutí:** return v `.emojiSearch` modu = noop, ne insert newline. Search není autorování textu.
- Top section nad keyboardem nedělá `LayoutBuilder` — to je čistě SwiftUI view layer (search bar + horizontal results bar).

### 6. `InputDispatcher` rozšíření

[`InputDispatcher`](KeyboardCore/Sources/Logic/InputDispatcher.swift) — když je `state.page == .emojiSearch`:

- **Character key tap:** append char do `state.searchQuery`, **nevkládat do host appce** (žádné `textDocumentProxy.insertText`).
- **Backspace tap:** pop poslední znak z `state.searchQuery`. Pokud query je prázdné, backspace je noop (NE backspace v host appce — search modu nesmí destruktivně mazat host text).
- **Backspace long-press / repeat:** nepodporujeme v search modu (zjednodušuje implementaci). Pro v1 long-press v search modu = single delete.
- **Space tap:** insert space do `searchQuery` (pro multi-word query).
- **Page switch (123 toggle):** OK switchnout do `.symbols(.primary)` během search? **Rozhodnutí:** zachovat `searchQuery` při switch a vrátit se po dalším switchnutí zpět do `.emojiSearch`. Lze ale udělat zjednodušení: 123 v search modu se NE zobrazuje (vyřazené z bottom row v `.emojiSearch` layout). **Volba:** pro v1 vyřadit `123` toggle z `.emojiSearch` layout — uživatel nepotřebuje digits/symbols v search query.

### 7. UI: `EmojiPanelView` rozšíření + nový `EmojiSearchView`

[`EmojiPanelView`](KeyboardUI/Sources/Views/EmojiPanelView.swift):

- Přidat top section: read-only search bar (visual TextField look, ale není to TextField). Tap callback `onEnterSearch: () -> Void`.
- Search bar = `Image(systemName: "magnifyingglass") + Text("Search Emoji")` + dimmed background (mimicking `iOS .searchable` empty look).
- `EmojiPanelView` zůstává plug-in pro page `.emojis`. Když je page `.emojiSearch`, `KeyboardRoot` renderuje nový `EmojiSearchView` místo toho.

Nový [`KeyboardUI/Sources/Views/EmojiSearchView.swift`](KeyboardUI/Sources/Views/EmojiSearchView.swift):

```swift
public struct EmojiSearchView: View {
    let query: String
    let recents: [String]
    let onSelectEmoji: (String) -> Void
    let onClearSearch: () -> Void
    let onKeyTapHaptic: () -> Void
    let onKeyClick: () -> Void
}
```

Layout:

- **Top:** search bar showing `query` (s blinking cursor — `Text("|")` s `.opacity` animací nebo `TimelineView`). `×` button vpravo. Tap `×` → `onClearSearch()`.
- **Middle:** horizontal scrollable LazyHStack:
  - Pokud `query.isEmpty` → emoji z `recents` (per Q9: jen recents fallback, ne favorites). Pokud i recents prázdné → empty placeholder (subtle `Text("…")` nebo prostě prázdná řada).
  - Pokud `query.isEmpty == false` → `EmojiSearchIndex.search(query: query)` → glyph extraction → render. Pokud žádné results → empty placeholder.
- **Bottom:** QWERTY layout. `KeyboardRoot` nebo `KeyboardView` ho vyrenderuje na základě `LayoutBuilder.makeRows(page: .emojiSearch)`.

Cell behavior (per Q14):

- **Tap:** insert emoji, append to recents, query zůstává, mode zůstává `.emojiSearch`. User může tappnout další result nebo psát další query.
- **Long-press:** žádná akce (per Q14 second sub-question).
- Žádný favorite toggle v search results — kdo chce favoritovat, musí přes grid mode.

### 8. `KeyboardRoot` glue

[`KeyboardExtension/Sources/KeyboardRoot.swift`](KeyboardExtension/Sources/KeyboardRoot.swift) — switch na `state.page`:

- `.letters(_) / .symbols(_)`: existing `KeyboardView`.
- `.emojis`: `EmojiPanelView` (s novou search bar + tap → enter search).
- `.emojiSearch`: composition — `EmojiSearchView` top + middle, `KeyboardView` bottom (QWERTY). `EmojiSearchView` propaguje selection do controller (insert text + append recents).

### 9. Tests

**Unit:**

- `EmojiSearchIndexTests`:
  - Single-token prefix match (`rain` → 🌧, ☔, 🌈, …).
  - Multi-word AND (`red heart` → ❤️ ale ne 💚).
  - Slack shortcode prefix (`thumbsup` → 👍).
  - Ranking — exact name first, then prefix name, then prefix keyword, then prefix slack.
  - Empty query → `[]`.
  - No matches → `[]`.
- `EmojiCatalogTests` (rozšířit existující):
  - JSON bundle loads correctly, `EmojiCatalog.all.count` ≈ 1 400 (±50).
  - Per-category counts > 50 (sanity floor — task 34 vzor).
  - `EmojiCatalog.emojis(for: .flags)` vrací hardcoded set (nezávisí na JSON).

**Snapshot:**

- `EmojiPanelView` s novým search bar (no query, default emoji grid pod ním) — Dark + Light.
- `EmojiSearchView` empty query + no recents — Dark.
- `EmojiSearchView` empty query + s recents — Dark.
- `EmojiSearchView` query `"rain"` — Dark + Light.
- `EmojiSearchView` query `"xyz123"` (no results) — Dark.

**Manual:**

- Otevřít keyboard v host appce, switchnout na emoji panel, tap search bar → `.emojiSearch` mode aktivuje, QWERTY se zobrazí.
- Napsat „rain" → horizontal bar zobrazí 💧☔🌧🌦🌈… Tap některé → insert do host text + recents append.
- Napsat „red heart" → ❤️ (multi-word AND).
- Napsat „thumbsup" → 👍 (slack shortcode).
- `×` → vrátí se zpět do `.emojis` mode s clean state.
- Backspace v prázdném query NESMÍ delete v host appce.
- Po restartu klávesnice search query nepřežívá (transient).

### 10. Migrace existujících call sites

Změna `EmojiCatalog.emojis(for:)` z `[String]` na `[Emoji]` dotkne:

- [`EmojiPanelView`](KeyboardUI/Sources/Views/EmojiPanelView.swift) line 73 — `currentEmojis` musí být `[Emoji]`, `ForEach` extrahuje `.glyph`.
- [`EmojiCatalogPickerView`](Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift) line 48 — stejně, `.glyph` access.
- AppGroupStore (recents, favorites) zůstává `[String]` — žádná migrace persistence (per task 34 bod 8 logika: glyph strings stay valid).

## Mimo scope

- **Search v [`EmojiCatalogPickerView`](Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift) v host appce.** Stejná data infrastruktura by se dala použít (`EmojiSearchIndex`), ale UX je jiný (vertical layout, `.searchable()` modifier funguje protože host app má system keyboard). Separátní task — task 34 Mimo scope ho avizoval.
- **Lokalizovaná emoji jména a keywords.** EN only, fixace z task 34. CLDR-cs data existují, pokud přijde request — separátní task.
- **Fuzzy matching (Levenshtein, typo tolerance).** Power user feature, ne v1.
- **Voice search (mic ikona).** Keyboard extension nemá voice infrastructure. Native screenshoty mic mají, my ho ignorujeme.
- **Slack shortcode jako field v `Emoji` structu.** [`SlackEmojiTable`](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) zůstává jediným zdrojem pravdy. Konzistentní s task 34 separací.
- **Favorites/Smileys fallback v empty query state.** Per Q9 odpověď: jen recents (nativní pattern).
- **Long-press na search result → toggle favorite.** Per Q14: jen tap = insert. Favoritování probíhá v grid modu.
- **123 toggle a smiley toggle v `.emojiSearch` bottom row.** Vyřazené pro zjednodušení — exit jen přes `×`.
- **Caps lock / shift v search modu.** Query je case-insensitive; shift ignorujeme nebo cosmetic-only.
- **Long-press backspace repeat v search modu.** Single delete jen.
- **Animace mode transition `.emojis ↔ .emojiSearch`.** Instant page swap, žádné `.transition()`. Task 34 a podobné tasky animace neřeší.

## Závislosti

- **Task 34** (full Unicode emoji catalog) — done, dodává 1 400 emoji baseline. Bez něj by search neměl co indexovat.
- **Task 19** (Slack-style emoji typing) — done, dodává `SlackEmojiTable` jako sekundární data zdroj pro search.
- **Task 32** (favorites show shortcodes) — done, `SlackEmojiTable.shortcode(for:)` API už existuje a search ho znovu používá.
- Volný vztah na **task 33** (modulový refactor) — `EmojiSearchView` patří do `KeyboardUI` modulu, `EmojiSearchIndex` do `KeyboardCore`. Žádný refactor není blocker.

## Hotovo když

- `KeyboardCore/Resources/EmojiData.json` existuje, checked-in, generovaný `scripts/generate_emoji_search_data.sh`.
- `Emoji` struct + `EmojiCatalog.emojis(for:) -> [Emoji]` API. Call sites updated (`.glyph` access pro string rendering).
- `EmojiSearchIndex.search(query:)` funguje pro single-word prefix, multi-word AND, slack shortcode union; ranking dle bodu 3 algoritmu.
- `KeyboardPage.emojiSearch` case existuje, `KeyboardState.searchQuery` field, `LayoutBuilder` produkuje QWERTY pro `.emojiSearch`, `InputDispatcher` routuje keys do query bufferu.
- `EmojiPanelView` má search bar nahoře, tap aktivuje `.emojiSearch` mode.
- `EmojiSearchView` renderuje search bar (s `×`), horizontal results bar (recents fallback pro empty query), QWERTY pod ním.
- Tap emoji v results → insert + recents append, query stays.
- `×` clear → query + `.emojis` mode.
- Manuální test (bod 9) prochází.
- Snapshots regenerated a checked-in.
- Žádné memory leaks při opakovaném vstupu/výstupu ze search modu (KeyboardCore stress 50× transition).

## Reference

- [unicode-emoji-json](https://github.com/muan/unicode-emoji-json) — keyword data source (`data-by-emoji.json`)
- [Task 34](34-full-unicode-single-emoji-catalog.md) — předchůdce, plánoval JSON pipeline (nakonec inlinoval). Tento task vrací k JSON.
- [Task 19](19-slack-emoji-typing.md) — Slack shortcode infrastruktura, kterou search reuses
- [Task 32](32-favorites-show-shortcodes.md) — `SlackEmojiTable.shortcode(for:)` API
- [EmojiPanelView.swift](KeyboardUI/Sources/Views/EmojiPanelView.swift) — current emoji panel
- [EmojiCatalog.swift](KeyboardCore/Sources/Models/EmojiCatalog.swift) — current catalog
- [SlackEmojiSuggester.swift](KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) — prefix-match precedent
- Native iOS emoji search — referenční UX (screenshoty grill session)
