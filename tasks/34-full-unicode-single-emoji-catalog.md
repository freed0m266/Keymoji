# 34 — Rozšířit `EmojiCatalog` na všechny single-codepoint emoji z Wikipedie

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium (uživatel může v favorites picku jakýkoliv "běžný" emoji, ne jen curated subset)

## Souhrn

Aktuální [EmojiCatalog](KeyboardCore/Sources/Models/EmojiCatalog.swift) je ručně poskládaný subset ~1 100 emoji rozdělený do 9 kategorií. Komentář v souboru to popisuje jako záměr ([EmojiCatalog.swift:40-42](KeyboardCore/Sources/Models/EmojiCatalog.swift:40)): „keeps the binary small and avoids font-coverage gotchas on older iOS releases". V1.1 ale cílí výhradně na **iOS 26+** (viz [CLAUDE.md](CLAUDE.md) → *Build*), který plně podporuje Unicode 17.0 (3 953 emoji, viz Wikipedia). Důvod ručního omezení padá.

Cílem je pokrýt **všechny single-codepoint emoji** z Wikipedia tabulky [List of emojis](https://en.wikipedia.org/wiki/List_of_emojis) — tj. ~1 400 emoji v hlavní *List of Unicode single emoji* tabulce plus ~37 rozesetých v menších blocích (Arrows, Basic Latin, Geometric Shapes, …). Dohromady ~1 438 jednotlivých code-pointů. Žádné ZWJ sekvence, žádné skin-tone varianty, žádné regional indicator vlajky — ty jsou samostatný problém a v současné podobě stačí (viz Mimo scope).

Vedlejší motivace: v tasku 32 jsme zavedli "No shortcode" placeholder ve Favorites editoru. Když uživatel pickne 🪅 nebo 🫨, vidí placeholder. Rozšíření samotného catalogu situaci nezhoršuje (catalog ≠ shortcode tabulka), ale ukazuje, že tahle dvě data ujíždí různým tempem. Tento task řeší jen catalog, [SlackEmojiTable](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) zůstává nedotčená (viz Mimo scope).

## Scope

1. **Zdroj pravdy: lokální JSON resource, ne Wikipedia scrape.**
   - Wikipedia tabulka je *reference*, ne build-time závislost. Scrapování HTML přes `URLSession` v build scriptu by bylo flaky (struktura tabulky se mění, jména sekcí v překladu, atd.).
   - Použít **[unicode-emoji-json](https://github.com/muan/unicode-emoji-json)** (npm `unicode-emoji-json`) jako kanonický zdroj. Má `data-by-emoji.json` s name, group, subgroup, skin tone variants atd. — strukturovaně. Verze sledují Unicode releases.
   - Bundle relevantní JSON jako resource do `KeyboardCore` (`KeyboardCore/Resources/EmojiData.json`). Velikost po stripped fields ~200-400 KB; akceptovatelné.
   - Alternativně: **[CLDR annotations](https://github.com/unicode-org/cldr-json)** pro lokalizovaná jména. Mimo scope tohohle tasku — v1.1 zůstává anglicky-only catalog (viz [EmojiCategory.accessibilityLabel](KeyboardCore/Sources/Models/EmojiCatalog.swift:23)).

2. **Strip pipeline: build-time skript.**
   - Vytvořit `scripts/generate_emoji_catalog.sh` (nebo `.swift` jako swift script). Vstup: stažený `data-by-emoji.json` z npm package nebo upstream raw URL (verze pinned v commit). Výstup: minimalizovaný `EmojiData.json` v `KeyboardCore/Resources/`.
   - **Co odfiltrovat:**
     - emoji s `length(.unicodeScalars) > 1` (vyřazuje ZWJ sekvence, skin tone varianty, keycaps, regional indicator flagy)
     - **výjimka:** ponechat *emoji presentation* znaky, které potřebují VS-16 (`\u{FE0F}`) — tj. text-default znaky jako ☀️, ⭐, ❤️, kde druhý scalar je variation selector. Filtr má být na **base code-point count**, ne `unicodeScalars.count` čistě. Konkrétně: pokud první scalar je v Emoji property a druhý je `FE0F`, count = 1.
     - jediná regional-indicator dvojice se v hlavní tabulce nemá, takže výjimka výše to vyřeší.
   - **Co ponechat:** `emoji`, `name` (lowercase, snake_case pro shortcode kompatibilitu), `group`, `subgroup`. Nic dalšího.
   - Skript checked-in, **output JSON checked-in** taky (ne v `.gitignore`). Build samotného Xcode targetu nesmí spouštět npm/curl — to si dělá vývojář ručně před commitem (jako u tasku 28 s app iconou).

3. **`EmojiCatalog` přepsat z hardcoded arrays na lazy load z resource.**
   - Zachovat `public static func emojis(for category: EmojiCategory) -> [String]` API — call sites se nemění.
   - Nově: `private static let allEntries: [EmojiEntry]` lazy-loaded z `EmojiData.json` přes `Bundle.module`. Cachovaný `[EmojiCategory: [String]]` index pro O(1) per-category lookup.
   - `EmojiEntry` privátní struct `{ emoji: String, group: String }`. **Není public** — externí API zůstává `[String]`.

4. **Mapování `unicode-emoji-json` groups → `EmojiCategory`.**
   - Upstream má groups: `Smileys & Emotion`, `People & Body`, `Animals & Nature`, `Food & Drink`, `Activities`, `Travel & Places`, `Objects`, `Symbols`, `Flags`. **1:1 s našimi 9 kategoriemi.** Mapping je triviální `switch`.
   - **Edge case:** `People & Body` v upstreamu obsahuje *všechny* skin-tone varianty osob, které jsme filtrovali. Po stripu zbydou jen base hands/people (~80 entries). To je OK a víceméně dnešní stav.
   - Subgroup v rámci kategorie *ignorovat* — pořadí v gridu si určujeme my (viz dnešní katalog: lexikální / vizuální skupiny). **Použít pořadí z upstreamu** — je to oficiální Unicode emoji order, mnohem konzistentnější než ruční sort.

5. **Verifikace pokrytí proti Wikipedii.**
   - Po vygenerování `EmojiData.json` má skript print `Total emoji: N` a per-category breakdown. Cílový **N ≈ 1 400-1 438** (Wikipedia hlavní tabulka).
   - Pokud výrazně méně (< 1 300) nebo víc (> 1 500), filtr je špatně — investigate before commit.
   - Test: `EmojiCatalogTests.testCoverageMatchesUpstream()` čte JSON, verifikuje že každá `EmojiCategory.staticCategories` má `> 50` entries (sanity floor; flag se zvlášť kontroluje že má pevný hardcoded seznam — viz bod 7).

6. **Snapshot testy aktualizovat.**
   - `EmojiCatalogPickerView` snapshot (pokud existuje v [Features/Settings/Tests](Features/Settings/Tests)) — bude vypadat hodně jinak, regenerovat. Ověřit, že grid renderuje smysluplně i pro `.symbols` (která bude největší — Wikipedia ji má hodně).
   - **Performance:** picker dnes vykresluje ~200 emoji per kategorie v gridu bez lazy renderingu. Pro symbols / objects ~400+ je potřeba ověřit, že `LazyVGrid` opravdu lazy-ne (rolovat v previu, sledovat ms na frame). Pokud jank, vyřešit `LazyVStack` per sekce nebo paginací — *ale primárně* změřit, ne preemptivně optimalizovat.

7. **Flags kategorie zůstává hardcoded.**
   - Vlajky jsou regional indicator sequences (2 code-points), filtr je odřízne. Současný seznam ~70 vlajek v [EmojiCatalog.swift:202-209](KeyboardCore/Sources/Models/EmojiCatalog.swift:202) zůstává **mimo JSON load** — `case .flags: return hardcodedFlags`. Důvod: chceme curated set evropských + relevantních vlajek nahoře, ne všechny 250 ISO kódů.

8. **Migrace dat ve `RecentEmojis` / `FavoriteEmojis`.**
   - Žádná migrace nutná. Uložené emoji jsou jen Stringy v AppGroupStore; pokud byly platné Unicode emoji předtím, jsou platné i teď. Picker je sice rozšířený, ale existující picky se nikam neztratí.

## Mimo scope

- **Rozšíření [SlackEmojiTable](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) o 1 400 shortcodů.** To je separátní task — zdroj pro shortcodes je jiný (iamcal/emoji-data má GitHub/Slack shortcodes, unicode-emoji-json má CLDR names ale ne shortcodes). Plus produktové rozhodnutí: chceme cizí jména typu `:money_mouth_face:` nebo curated subset? Řešíme až bude reálný feedback z usage. Task 32 fallback "No shortcode" tu mezitím slouží.
- **ZWJ sekvence (rodiny, profese, srdíčka s gendery), skin-tone varianty.** Mimo v1.1. Mají kombinatoriku — 5 odstínů × profese × gender = stovky variant — a UX (skin tone picker per emoji, jako iOS stock) je full feature, ne datový task.
- **Lokalizovaná emoji jména.** v1.1 EN-only (viz [EmojiCategory.accessibilityLabel](KeyboardCore/Sources/Models/EmojiCatalog.swift:22)). CLDR data jsou k dispozici pokud se rozhodne lokalizovat — separátní task.
- **Vyhledávání emoji podle jména v `EmojiCatalogPickerView`.** Catalog picker dnes nemá `.searchable`. S 1 400 emoji by to dávalo velký smysl, ale je to UX task, ne datový. Řešíme separátně, pokud feedback ukáže že je potřeba.
- **Použít systémový `NSAttributedString.emojiData` / iOS 17 emoji picker SDK.** Nesnažíme se ohnout AppKit/UIKit pickery. Vlastní catalog dává konzistenci napříč keyboard extension i host app (extension nemůže prezentovat system emoji picker).
- **Variation selector handling v keyboardu jako takovém.** Když uživatel ťukne na ☀️, vložíme `\u{2600}\u{FE0F}` (jak je v JSONu). Nepokoušíme se inteligentně rozhodovat o text vs emoji presentaci.

## Závislosti

- **Žádné blokující.** Task 32 (favorites shortcodes) je hotový, takže existující "No shortcode" placeholder absorbuje rozšířený catalog bez další práce na Favorites UI.
- **Volný vztah na task 33** (refactor Favorites → 2 moduly). Pokud se 33 dělá *před* tímhle, `EmojiCatalogPicker` má vlastní modul a snapshot test target, kam můžu přidat coverage test čisté. Pokud *po* tomhle, snapshot regenerace se musí udělat ještě jednou. Doporučení: udělat **33 první**, ale není to hard blocker.

## Hotovo když

- `KeyboardCore/Resources/EmojiData.json` existuje, checked-in, vygenerovaný skriptem z `scripts/generate_emoji_catalog.sh`.
- `EmojiCatalog.emojis(for:)` vrací data z JSONu pro `.smileys, .people, .animals, .food, .activity, .travel, .objects, .symbols` (8 kategorií). `.flags` zůstává hardcoded.
- Pro `.symbols` (typicky největší kategorie po expansi) catalog vrací > 200 emoji; pro `.smileys` > 100; pro `.people` > 70.
- `EmojiCatalogPickerView` snapshot test projíždí s novými daty (regenerated).
- **Manuální test:** v host appce otevřít Settings → Favorites → "+ Add emoji" → ověřit, že lze nascrollovat na ~ 1 400 emoji napříč kategoriemi. Vybrat 3 dříve nedostupné (např. 🫨, 🪅, 🪻), uložit, ověřit že se zobrazí v editoru s "No shortcode" placeholderem správně.
- Build script lze re-spustit s novou verzí `unicode-emoji-json` a generuje deterministický diff (pořadí, formátování).

## Reference

- [Wikipedia — List of emojis](https://en.wikipedia.org/wiki/List_of_emojis) — referenční tabulka, cíl pokrytí
- [unicode-emoji-json](https://github.com/muan/unicode-emoji-json) — navržený data source
- [EmojiCatalog.swift](KeyboardCore/Sources/Models/EmojiCatalog.swift) — současný hardcoded catalog
- [EmojiCatalogPickerView.swift](Features/Settings/Sources/FavoritesEditor/EmojiCatalogPickerView.swift) — UI consumer
- [SlackEmojiTable.swift](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) — související, ale *out of scope* (viz Mimo scope)
- [Task 32](tasks/32-favorites-show-shortcodes.md) — "No shortcode" fallback, který tenhle task implicitně víc využije
