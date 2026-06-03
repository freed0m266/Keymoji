# 32 — Favorite emojis: zobrazit shortcode místo druhé kopie emoji

**Status:** Done — 2026-05-27

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Low (UI polish + edukace shortcodes)

## Souhrn

V aktuální podobě řádek v „Favorite emojis" obrazovce ukazuje **dvakrát ten samý emoji** — jednou velký (28pt), jednou menší v `.secondary` barvě ([FavoritesEditorView.swift:73-83](Features/Settings/Sources/FavoritesEditor/FavoritesEditorView.swift:73)). Sekundární kopie nic nepřidává — je to vizuální balast.

Místo ní zobrazit **shortcode** daného emoji (`:smile:`, `:rocket:`, …), stejným stylem jako v [EmojiCodesView.swift:64-78](Features/EmojiCodes/Sources/EmojiCodesView.swift:64) (monospace, primary). Uživatel tak v jednom screenu vidí svoje favorites *a zároveň* se učí, jakým shortcodem každý napsat přes Slack-style typing — drobná synergie mezi tasky 18 a 19.

## Scope

1. **`FavoritesEditorView.favoritesList`** ([FavoritesEditorView.swift:70-90](Features/Settings/Sources/FavoritesEditor/FavoritesEditorView.swift:70))
   - Smazat druhý `Text(emoji)` s `.secondary` foreground.
   - Místo něj vykreslit shortcode wrappnutý dvojtečkami (`:\(shortcode):`) ve stylu `.body.monospaced()`, `.primary`.
   - Layout zachovat — `HStack(spacing: 12)`, emoji 28pt vlevo, shortcode za ním. Sjednotit šířku emoji sloupce (`.frame(width: 40, alignment: .center)`) s `EmojiCodesView`, ať to vizuálně pasuje, pokud uživatel přepíná mezi obrazovkami.

2. **Reverse lookup `emoji → shortcode`**
   - `SlackEmojiTable.defaultTable` je `[shortcode: String → emoji: String]` ([SlackEmojiTable.swift:11](KeyboardCore/Sources/Logic/SlackEmojiTable.swift:11)). Pro Favorites potřebujeme opačný směr.
   - Přidat do `SlackEmojiTable` lazy/static `reverseLookup: [String: String]` (emoji → první shortcode). Build na app launch / lazy při prvním přístupu, ne per-row recompute.
   - **Pozor na duplicitní mapping:** několik shortcodes může mapovat na stejný emoji (např. `+1` a `thumbsup` oba → 👍). Pravidlo: vzít **kratší** shortcode; při rovnosti alfabetické pořadí (deterministické). Definovat jako sort criterion ve build helpru.
   - Doporučená API: `SlackEmojiTable.shortcode(for emoji: String) -> String?`. Nilovost = emoji není v tabulce.

3. **Fallback pro emoji bez shortcode**
   - Tabulka má ~150 entries, ale `EmojiCatalogPickerView` umožní vybrat libovolný emoji z většího katalogu. Tj. spousta favorites *žádný* shortcode v tabulce mít nebude.
   - **Nezobrazit `nil` ani prázdný string** — to vypadá jako bug. Místo toho dim placeholder: `Text(L10n.Settings.Favorites.noShortcode)` v `.secondary` italic (např. „No shortcode"). Localized string v Localizable.strings (`"settings.favorites.noShortcode" = "No shortcode";`).
   - Alternativně: zobrazit jen samotný emoji bez druhého sloupce, ale to porušuje konzistenci řádků (variable layout). Placeholder lepší.

4. **Tap interakce — *out of scope, viz Mimo scope***
   - V `EmojiCodesView` tap kopíruje shortcode do pasteboardu. Tady to zatím nezavádět — primární akce favorites editoru je *editace seznamu*, ne lookup codes. Edukativní hodnota je v samotném zobrazení.

5. **Accessibility**
   - Současné `.accessibilityLabel(emoji)` rozšířit o shortcode, pokud existuje: `"\(emoji), :\(shortcode):"`. Bez shortcode zůstává jen emoji.

6. **Snapshot testy**
   - `FavoritesEditorView` má snapshot testy v [Features/Settings/Tests](Features/Settings/Tests). Po změně regenerovat. Mock VM (`FavoritesEditorViewModelMock`) může zůstat beze změny — používá hardcoded favorites jako `["❤️", "😀", "🚀", "🎉", "🐶"]`, všechny mají shortcode v tabulce, takže snapshot pokryje happy path. **Přidat snapshot variantu** s emoji mimo tabulku (např. nějaký méně častý emoji jako 🪅 nebo 🫨) ať pokryje i fallback case.

## Mimo scope

- **Tap-to-copy shortcode** v Favorites editoru. Pokud se to ukáže jako wanted feature po release, přidá se v separátním tasku — pasteboard write + toast je už hotový pattern v `EmojiCodesView`, dá se reusnout, ale teď ne.
- **Rozšíření `SlackEmojiTable`** o víc emojis, aby méně favorites spadlo do „No shortcode" fallbacku. Tabulka je curated subset — rozhodnutí o jejím rozsahu patří do separátního produktového rozhodnutí, ne UI polish tasku.
- **Search v Favorites editoru.** EmojiCodes obrazovka má `.searchable`, Favorites zatím ne. Pokud user roste přes 30 favorites, řeší se separátně.
- **Indikace v `EmojiCatalogPickerView`**, které emojis mají shortcode. Mohlo by pomoct uživateli při výběru, ale to je jiná obrazovka a jiný UX. Out.

## Závislosti

- Task 19 (Slack emoji typing) — `SlackEmojiTable` musí existovat. **Hotovo** (task 19 done 2026-05-25, viz [SlackEmojiTable.swift](KeyboardCore/Sources/Logic/SlackEmojiTable.swift)).
- Task 18 (Favorite emojis editor) — UI screen musí existovat. **Hotovo** (task 18 done 2026-05-25).

## Hotovo když

- V Favorites editoru každý řádek ukazuje emoji vlevo a `:shortcode:` napravo (monospace), místo dvojí kopie emoji.
- Emoji, které v `SlackEmojiTable` nejsou, ukazují kurzivní „No shortcode" placeholder, ne prázdný řádek nebo `nil`.
- Reverse lookup je deterministický — pro emoji se dvěma shortcodes (`+1` / `thumbsup` → 👍) vrátí pokaždé ten samý.
- Snapshot testy aktualizované, projíždí včetně varianty s fallback emoji.
- Manuální test: přidat 3 emojis přes catalog picker (jeden běžný typu 😄, jeden bez shortcode typu 🫨), zavřít sheet, ověřit, že list vykreslí oba správně.

## Reference

- [FavoritesEditorView.swift:70-90](Features/Settings/Sources/FavoritesEditor/FavoritesEditorView.swift:70) — aktuální `favoritesList` k přepsání
- [EmojiCodesView.swift:64-78](Features/EmojiCodes/Sources/EmojiCodesView.swift:64) — referenční styl řádku (emoji + monospace shortcode)
- [SlackEmojiTable.swift](KeyboardCore/Sources/Logic/SlackEmojiTable.swift) — zdrojová tabulka, sem přidat `shortcode(for:)`
- [Localizable.strings:41-48](KeymojiResources/Resources/en.lproj/Localizable.strings:41) — existující `settings.favorites.*` klíče, přidat `noShortcode`
