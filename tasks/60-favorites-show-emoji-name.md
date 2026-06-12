# 60 — Favorites editor: název emoji místo shortcode + odvozené názvy vlajek

**Status:** Done — 2026-06-13

**Priorita:** v1.x · **Úsilí:** S · **Dopad:** Medium (čitelnost Favorites editoru — sekundární řádek dnes u většiny emoji prázdný/„No shortcode")

## Cíl

V [`FavoriteEmojisEditorView`](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift) je dnes každý řádek **emoji + Slack shortcode**. Jenže shortcode má jen ~150 kurátorovaných emoji ([`SlackEmojiTable`](../KeyboardCore/Sources/Logic/SlackEmojiTable.swift)), takže drtivá většina favoritů ukazuje italic placeholder „No shortcode" — vypadá to nedodělaně.

Nahradit sekundární text **lidsky čitelným názvem emoji** (CLDR name), který máme pro **celý** katalog. Fallback řetězec: **název → shortcode → nic**.

Druhá, provázaná věc: **vlajky dnes nemají název** (`name: ""` — viz [EmojiCatalog.swift](../KeyboardCore/Sources/Models/EmojiCatalog.swift)), takže by u nich nový řádek byl prázdný. Vyřešit tak, že **zemním vlajkám dopočítáme název země** z jejich regional-indicator páru přes `Locale`, a hrstce ne-zemních vlajek dáme název z malé mapy.

Po dokončení: Settings → Favorite emojis → každý řádek ukazuje `emoji + Název` (např. `❤️ Red Heart`, `🚀 Rocket`, `🇨🇿 Czechia`, `🏴‍☠️ Pirate Flag`), žádné „No shortcode".

## Kontext

- **Řádek editoru** — [FavoriteEmojisEditorView.swift:101](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift) `row(for:)`. Dnes: `SlackEmojiTable.shortcode(for:)`; když je `nil`, ukáže `Texts.noShortcode` italic. Modul už importuje `KeyboardCore` (kde žije `EmojiCatalog` i `SlackEmojiTable`), takže žádná nová závislost.

- **Co máme za texty per emoji** ([Emoji.swift](../KeyboardCore/Sources/Models/Emoji.swift) + [EmojiData.json](../KeyboardCore/Resources/EmojiData.json), 1398 záznamů):
  | Zdroj | Pole | Pokrytí | Příklad 🚀 |
  |---|---|---|---|
  | **CLDR name** | `Emoji.name` | celý katalog (kromě vlajek — viz níže) | `rocket` |
  | Keywords | `Emoji.keywords` | většina | `fly, launch, nasa, …` |
  | Slack shortcode | `SlackEmojiTable.shortcode(for:)` | jen ~150 | `rocket` |

  → **CLDR name** je jasný vítěz: 100% pokrytí, čte se přirozeně, už je načtený. Keywords jsou ukecané a redundantní; shortcode řídký. Názvy jsou v JSON **lowercase** (`"red heart"`); search index ([EmojiCatalog.swift](../KeyboardCore/Sources/Models/EmojiCatalog.swift) `buildStorage`) na lowercase spoléhá — proto názvy ZŮSTÁVAJÍ lowercase v datech a kapitalizace se dělá až ve view.

- **Glyph → name lookup neexistuje.** Favorites se ukládají jen jako glyf (`String`), `EmojiCatalog` nemá veřejný lookup po glyfu — jen `all: [Emoji]` a `emojis(for category:)`. Přidat O(1) `emoji(for glyph:)` (cache `[String: Emoji]` postavená v `buildStorage`).

- **Vlajky nemají název.** `flagGlyphs` se v `buildStorage` mapují jako `Emoji(glyph: $0, name: "", keywords: [], category: .flags)`. Seznam je ~68 zemních vlajek (regional-indicator páry, např. `🇨🇿`) + 7 ne-zemních (`🏳️ 🏴 🏁 🚩 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️`). Komentář u `EmojiCatalog` přímo počítá s tím, že se názvy/keywords vlajek doplní později.

- **Odvození názvu země funguje a je ověřené.** Vlajka `🇨🇿` = dva regional-indicator scalary (`U+1F1E8` + `U+1F1FF`); přepočtem `scalar − 0x1F1E6 + 'A'` vznikne ISO 3166-1 alpha-2 kód `"CZ"`, z něj `Locale(identifier: "en_US").localizedString(forRegionCode:)` vrátí `"Czechia"`. Ověřeno na našem seznamu vč. hraničních:
  - `🇪🇺` → `EU` → `"European Union"` (Foundation to umí, žádný fallback netřeba)
  - `🇰🇵` → `"North Korea"`, `🇭🇰` → `"Hong Kong"`, `🇦🇪` → `"United Arab Emirates"`, `🇹🇼` → `"Taiwan"`
  - 7 ne-zemních vrací z dekodéru `nil` (nejsou to dva RI scalary) → spadnou na ruční mapu.

## Rozhodnutí

| Téma | Rozhodnutí |
|---|---|
| Primární text řádku | CLDR `Emoji.name`, **`.capitalized`** ve view |
| Fallback řetězec | **název → shortcode (`:code:`) → nic** (jen emoji, žádný placeholder) |
| „No shortcode" placeholder | **Zrušit** — sekundární text se prostě nevykreslí, když není co |
| Jazyk názvů | **Anglicky** (konzistentní s katalogem; v1 je English-only, viz `EmojiCategory.accessibilityLabel` komentář) |
| Kapitalizace | `.capitalized` (title case) — funguje pro víceslovné země („United States") i popisy; sentence case by rozbil „United states" |
| Názvy vlajek | Uložit do katalogu (single source of truth), **lowercase** (jako zbytek), aby `.capitalized` ve view fungoval jednotně |
| Zemní vlajky | Auto-odvození ISO kódu → `Locale.localizedString(forRegionCode:)`, fixní `en_US` locale (deterministicky, nezávisle na zařízení) |
| Ne-zemní vlajky | Ruční mapa 7 položek (white/black/chequered/triangular/rainbow/transgender/pirate flag) |
| Keywords vlajek | **Beze změny** (zůstávají `[]`) — task 39 §1 to odložil, nesaháme na to |
| Search jako bonus | Vlajky tím získají `name` → stanou se vyhledatelné podle země v `EmojiSearchIndex` (vedlejší žádoucí efekt, žádné extra úsilí) |

## Scope

### 1. `EmojiCatalog` — názvy vlajek + glyph lookup (`KeyboardCore`)

[KeyboardCore/Sources/Models/EmojiCatalog.swift](../KeyboardCore/Sources/Models/EmojiCatalog.swift):

- **`flagName(for:)` + dekodér** (private static):

  ```swift
  private static let englishLocale = Locale(identifier: "en_US")

  private static let specialFlagNames: [String: String] = [
      "🏳️": "white flag", "🏴": "black flag", "🏁": "chequered flag",
      "🚩": "triangular flag", "🏳️‍🌈": "rainbow flag",
      "🏳️‍⚧️": "transgender flag", "🏴‍☠️": "pirate flag"
  ]

  /// Lowercased název: země přes `Locale` u regional-indicator párů, jinak `specialFlagNames`.
  private static func flagName(for glyph: String) -> String {
      if let code = regionCode(from: glyph),
         let country = englishLocale.localizedString(forRegionCode: code) {
          return country.lowercased()
      }
      return specialFlagNames[glyph] ?? ""
  }

  /// `🇨🇿` → `"CZ"`; nil pro cokoli, co nejsou přesně dva regional-indicator scalary.
  private static func regionCode(from glyph: String) -> String? {
      let base: UInt32 = 0x1F1E6, top: UInt32 = 0x1F1FF
      var code = ""
      for scalar in glyph.unicodeScalars {
          guard (base...top).contains(scalar.value),
                let letter = UnicodeScalar(scalar.value - base + 0x41) else { return nil }
          code.unicodeScalars.append(letter)
      }
      return code.count == 2 ? code : nil
  }
  ```

- **`buildStorage`** — vlajkám předat dopočítaný název + postavit `byGlyph`:

  ```swift
  let flags = flagGlyphs.map { Emoji(glyph: $0, name: flagName(for: $0), keywords: [], category: .flags) }
  …
  let byGlyph = Dictionary(all.map { ($0.glyph, $0) }, uniquingKeysWith: { first, _ in first })
  return Storage(all: all, byCategory: byCategory, byGlyph: byGlyph, searchEntries: searchEntries)
  ```

  `Storage` dostane pole `let byGlyph: [String: Emoji]`.

- **Veřejný lookup** (vedle `emojis(for:)`):

  ```swift
  /// Catalog entry pro glyf, nebo nil když není v bundlu. O(1).
  public static func emoji(for glyph: String) -> Emoji? { storage.byGlyph[glyph] }
  ```

### 2. `FavoriteEmojisEditorView` — řádek s názvem (`Features/FavoriteEmojisEditor`)

[FavoriteEmojisEditorView.swift:101](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift) `row(for:)`:

```swift
private func row(for emoji: String) -> some View {
    let name = EmojiCatalog.emoji(for: emoji)?.name
    let shortcode = SlackEmojiTable.shortcode(for: emoji)
    let label = name.flatMap { $0.isEmpty ? nil : $0.capitalized }
    return HStack(spacing: 12) {
        Text(emoji).font(.system(size: 28)).frame(width: 40, alignment: .center)
        if let label {
            Text(label).font(.body).foregroundStyle(.primary).lineLimit(1)
        } else if let shortcode {
            Text(":\(shortcode):").font(.body.monospaced()).foregroundStyle(.secondary).lineLimit(1)
        }
    }
    .accessibilityElement()
    .accessibilityLabel(label.map { "\(emoji), \($0)" } ?? shortcode.map { "\(emoji), :\($0):" } ?? emoji)
}
```

`Texts.noShortcode` se přestane používat.

### 3. Lokalizace (úklid)

`"settings.favorites.noShortcode"` v [en.lproj/Localizable.strings:91](../KeymojiResources/Resources/en.lproj/Localizable.strings) je nově nepoužitý. **Nechat zatím být** (mrtvý klíč, neškodí; `TuistStrings` accessor zmizí sám při příštím `tuist generate`). Pokud se dělá úklid, smazat řádek *a* regenerovat — needitovat `Derived/` ručně.

### 4. Testy

**Unit ([KeyboardCore/Tests/EmojiCatalogTests.swift](../KeyboardCore/Tests/EmojiCatalogTests.swift)):**
- `testEmojiForGlyph_returnsEntry()` — `EmojiCatalog.emoji(for: "🚀")?.name == "rocket"`; `emoji(for: "ZZ_not_emoji") == nil`.
- `testFlag_countryName_derivedFromRegionCode()` — `emoji(for: "🇨🇿")?.name == "czechia"`, `"🇸🇰" → "slovakia"`, `"🇪🇺" → "european union"`.
- `testFlag_specialFlag_nameFromTable()` — `emoji(for: "🏴‍☠️")?.name == "pirate flag"`, `"🏳️‍🌈" → "rainbow flag"`.
- `testFlag_keywordsStillEmpty()` — existující `testFlags_areHardcoded_andIndependentOfJSON` už hlídá `keywords == []`; ověřit, že prošla beze změny (názvy přidáváme, keywords ne).

**Snapshot ([Features/FavoriteEmojisEditor/Tests/FavoriteEmojisEditorSnapshots.swift](../Features/FavoriteEmojisEditor/Tests/FavoriteEmojisEditorSnapshots.swift)):**
- `withFavorites` i `frequency` reference se změní (řádek nově ukazuje název místo shortcode). **Refresh referencí.** Zvážit přidat vlajku do `favorites` fixture (`["❤️", "😀", "🚀", "🎉", "🇨🇿"]`) jako doklad odvozeného názvu země.

### 5. Manuální verify

1. Settings → Favorite emojis → každý řádek ukazuje `emoji + Název` (`❤️ Red Heart`, `🚀 Rocket`, `🎉 Party Popper`).
2. Přidat vlajku (`🇨🇿`, `🇺🇸`, `🇪🇺`) → ukáže `Czechia` / `United States` / `European Union`.
3. Přidat ne-zemní vlajku (`🏴‍☠️`, `🏳️‍🌈`) → `Pirate Flag` / `Rainbow Flag`.
4. VoiceOver na řádku přečte `emoji, Název`.
5. (Bonus) V keyboardu emoji search „germany" → najde `🇩🇪` (vlajky nově vyhledatelné podle země).

## Mimo scope

- **Lokalizace názvů emoji.** Zůstává English-only (konzistentní s `EmojiCategory.accessibilityLabel`). Názvy zemí by `Locale.current` uměl lokalizovat zdarma, ale úmyslně držíme `en_US` kvůli konzistenci se zbytkem (anglické CLDR názvy). Až bude lokalizace katalogu samostatný task, řeší se tam i tohle.
- **Keywords vlajek.** Task 39 §1 to odložil; nesaháme.
- **Keywords / kategorie jako sekundární text.** Ukecané, zamítnuto ve prospěch názvu.
- **Vlastní/hezčí názvy** (např. „EU" místo „European Union", vlaječkové přezdívky). Bereme, co dá `Locale`.

## Hotovo když

- `EmojiCatalog.emoji(for:)` vrací O(1) lookup; vlajky mají dopočítaný lowercase název (země přes `Locale`, speciální z mapy), keywords zůstávají `[]`.
- Favorites editor řádek ukazuje `.capitalized` název; fallback název → shortcode → nic; `noShortcode` placeholder pryč; accessibility label sedí.
- Unit testy (lookup + názvy vlajek) a refreshnuté snapshoty zelené.
- Existující `EmojiCatalogTests` / `EmojiSearchIndex` testy zelené (přidání názvů vlajek nesmí nic rozbít).
- Manuální verify: běžná emoji i zemní i speciální vlajky ukazují čitelný název.

## Rizika

- **Search churn u vlajek.** Vlajky nově nesou `name` → `EmojiSearchIndex` je začne indexovat a vracet při hledání podle země. Žádaný bonus, ale je to změna chování search — ověřit, že žádný existující search test neočekával „vlajky nevyhledatelné" (grep: dnes žádný flag/region test v `EmojiSearchIndexTests` není, takže OK).
- **`.capitalized` u dlouhých názvů.** „rolling on the floor laughing" → „Rolling On The Floor Laughing" (title case, mírně přehnané, ale akceptovatelné a `lineLimit(1)` ořízne). Sentence case nelze — rozbil by víceslovné země („United States"). Ponecháno title case.
- **`Locale` názvy se můžou lišit napříč iOS verzemi.** Foundation může vrátit „Czech Republic" vs „Czechia" podle SDK/CLDR verze. Pro zobrazení nevadí; pokud by na tom visel test, asertovat tolerantně (contains/lowercased), ne přesnou shodu — nebo testovat jen jednoznačné (`"SK" → "slovakia"`).
- **Mrtvý L10n klíč.** `noShortcode` zůstane v `.strings` + generovaném accessoru dokud neproběhne `tuist generate`. Neškodí (nikdo ho nevolá), jen kosmetika.

## Reference

- [tasks/32-favorites-show-shortcodes.md](32-favorites-show-shortcodes.md) — předchozí iterace (zavedla shortcode v editoru); tento task ji reviduje.
- [tasks/18-favorite-emojis.md](18-favorite-emojis.md) — původní Favorites editor.
- [tasks/34-full-unicode-single-emoji-catalog.md](34-full-unicode-single-emoji-catalog.md) — generování `EmojiData.json` (zdroj `name`/`keywords`).
- [tasks/39-emoji-search.md](39-emoji-search.md) — `EmojiSearchIndex` (§1 odložil keywords vlajek).
- [KeyboardCore/Sources/Models/EmojiCatalog.swift](../KeyboardCore/Sources/Models/EmojiCatalog.swift) — `flagGlyphs`, `buildStorage`, `emojis(for:)`.
- [Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift:101](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift) — `row(for:)`.

## Codex review

**Volitelně.** Malý, ohraničený UI/data change. Hot path se nedotýká; jediná netriviální logika je dekódování regional-indicator páru (ošetřené nil cesty + ověřené na celém seznamu vlajek). Pokud review, tak cílit na `regionCode(from:)` edge-cases a snapshot diff.
</content>
</invoke>
