# 49 — Favorites bar: TabView paging místo free-scroll

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** S–M · **Dopad:** Low–Medium (UX polish: swipe na favorites baru lístkuje po stránkách místo plynulého scrollu — předvídatelnější, „klávesnicovější" pocit, oblíbené emoji se nepřescrollují o půl glyfu)

## Souhrn

`favoritesBar` v [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:145) je dnes horizontální `ScrollView` — favorites se plynule scrollují prstem ([SuggestionBarView.swift:146](../KeyboardUI/Sources/Views/SuggestionBarView.swift:146)). Změníme ho na **`TabView` se stránkovým stylem**: swipe gesto posune obsah o **jednu stránku = pevný počet emoji na tab**, ne plynule o pixely.

**Vizuálně na screenshotu vypadá identicky** — stejné glyfy, stejná velikost, stejné rozestupy, stejná 40pt výška, žádné tečky/index dole. Mění se jen **gesto**: místo free-scrollu se obsah lístkuje po stránkách (jako stránky homescreenu / nativní emoji panel klávesnice). Jeden swipe = posun o `emojisPerPage` emoji.

Rozhodnutí k potvrzení se zadavatelem (sepiš odpověď do tasku, ať to není otevřené):
- **Index dots:** skryté (`indexDisplayMode: .never`) — aby screenshot zůstal vizuálně identický s dnešním scrollview. (Výchozí předpoklad. Pokud chceš tečky jako affordance „je toho víc", uveď.)
- **Počet emoji na stránku:** odvozený z dostupné šířky baru (kolik se jich vejde na řádek), ne fixní konstanta — viz Scope bod 2. Tím se chování přizpůsobí šířce zařízení a stránka je vždy „plná".
- **Zbytek na poslední stránce:** poslední stránka může být neúplná (méně než `emojisPerPage`), zarovnaná doleva — stejně jako dnes končí scroll.

## Kontext

- `favoritesBar` je jeden ze tří režimů baru; vybírá se v `body`, když `suggestions.isEmpty && !favoriteEmojis.isEmpty` ([SuggestionBarView.swift:57](../KeyboardUI/Sources/Views/SuggestionBarView.swift:57)). Tahle volba se **nemění** — měníme jen vnitřek `favoritesBar`.
- Dnešní layout buňky (zachovat 1:1, ať je screenshot identický): `Text(emoji).font(.system(size: 24)).frame(minWidth: 36).frame(maxHeight: .infinity)`, `HStack(spacing: chipSpacing)` (`chipSpacing = 6`, [:96](../KeyboardUI/Sources/Views/SuggestionBarView.swift:96)), `.padding(.horizontal, horizontalPadding)` (`horizontalPadding = 6`, [:97](../KeyboardUI/Sources/Views/SuggestionBarView.swift:97)).
- Bar má fixní výšku 40 pt (`barHeight`, [:47](../KeyboardUI/Sources/Views/SuggestionBarView.swift:47)) a `.frame(maxWidth: .infinity)` ([:66](../KeyboardUI/Sources/Views/SuggestionBarView.swift:66)). `TabView` musí tuhle výšku přesně dodržet — žádné dopočítání výšky podle indexu/obsahu (C1: výška klávesnice se nikdy nemění).
- Tap handler (`selectEmoji`, haptika + zvuk + `onSelectEmoji`) zůstává beze změny ([:164](../KeyboardUI/Sources/Views/SuggestionBarView.swift:164)).

## Scope

### 1. `favoritesBar` → `TabView` se stránkovým stylem

V [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:145) přepsat `favoritesBar`:

- Obalit do `GeometryReader`, aby byla k dispozici dostupná šířka baru (potřeba pro výpočet `emojisPerPage` — bod 2).
- `favoriteEmojis` rozkouskovat na stránky po `emojisPerPage` (pomocný helper, bod 3).
- Vykreslit `TabView`, kde každý `.tag(index)` je jedna stránka = `HStack(spacing: chipSpacing)` s buňkami **identickými jako dnes** (glyf, font 24, minWidth 36), zarovnaný doleva (`Spacer()` na konci HStacku, ať poslední neúplná stránka netáhne buňky na celou šířku).
- Styl: `.tabViewStyle(.page(indexDisplayMode: .never))`.

  ```swift
  private var favoritesBar: some View {
      GeometryReader { geo in
          let perPage = Self.emojisPerPage(availableWidth: geo.size.width)
          let pages = Self.paginate(favoriteEmojis, perPage: perPage)
          TabView {
              ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                  HStack(spacing: chipSpacing) {
                      ForEach(page, id: \.self) { emoji in
                          Button { selectEmoji(emoji) } label: {
                              Text(emoji)
                                  .font(.system(size: 24))
                                  .frame(minWidth: 36)
                                  .frame(maxHeight: .infinity)
                          }
                          .buttonStyle(.plain)
                      }
                      Spacer(minLength: 0)   // poslední stránka zarovnaná doleva
                  }
                  .padding(.horizontal, horizontalPadding)
                  .tag(index)
              }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
      }
  }
  ```

  > Pozn.: `TabView` page style je `UIPageViewController` pod kapotou — má vlastní gesture recognizer pro swipe. Ověř, že nekoliduje s tap gesty na buňkách (tap musí dál vkládat emoji, swipe musí stránkovat). Pokud by tap „prosakoval" do swipe nebo naopak, zvážit `.contentShape(Rectangle())` na buňce / úpravu hit testu.

### 2. Výpočet `emojisPerPage` z dostupné šířky

Pure statická funkce (testovatelná bez UI), např.:

```swift
/// Kolik favorite glyfů se vejde na jednu stránku při dané šířce baru.
/// Buňka = `cellWidth` (≈ minWidth 36), mezi buňkami `chipSpacing`, po krajích `horizontalPadding`.
static func emojisPerPage(availableWidth: CGFloat, cellWidth: CGFloat = 36) -> Int {
    let usable = availableWidth - 2 * horizontalPadding + chipSpacing
    let per = Int(floor(usable / (cellWidth + chipSpacing)))
    return max(1, per)   // vždy aspoň 1, ať se nestane prázdná stránka / dělení nulou
}
```

(`horizontalPadding`/`chipSpacing` musí být dosažitelné jako `static`/konstanty pro tenhle výpočet — pokud jsou dnes instanční `let`, povýšit na `static let` nebo zduplikovat hodnotu s komentářem.)

### 3. Pure `paginate(_:perPage:)` helper

Rozkouskování pole na stránky — pure, unit-testovatelné:

```swift
static func paginate<T>(_ items: [T], perPage: Int) -> [[T]] {
    guard perPage > 0 else { return items.isEmpty ? [] : [items] }
    return stride(from: 0, to: items.count, by: perPage).map {
        Array(items[$0 ..< min($0 + perPage, items.count)])
    }
}
```

### 4. Testy

- **Unit testy `emojisPerPage` + `paginate`** (čistá logika, žádný snapshot): pár šířek (SE 320, iPhone 393) → očekávaný počet na stránku; `paginate` na hraničních vstupech (prázdné pole, počet < perPage, přesný násobek, zbytek). Tohle je hlavní pojistka, protože swipe gesto samo se snapshotem netestuje.
- **Snapshot — vizuální parita.** Do [`SuggestionBarViewSnapshots`](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift) v sekci favorites: ověřit, že **první stránka** vypadá pixelově stejně jako dnešní scrollview varianta (stejné glyfy, rozestupy, výška), dark + light. Index dots nesmí být vidět.
  - Pokud existují referenční snapshoty dnešního favorites scrollview ([task 44](44-favorite-emojis-in-suggestion-bar.md)), porovnat, že se nezměnily — případně re-recordnout, pokud TabView posune layout o subpixel (a v PR popisu zdůvodnit).
- **Overflow stránkování:** `favoriteEmojis` s víc emoji, než se vejde na jednu stránku (např. 15) → ověřit, že první stránka ukáže `emojisPerPage` glyfů a výška zůstane 40 pt (žádný posun výšky klávesnice).
- Stávající `testEmptyBar_alwaysShown` ([:43](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift:43)) a ostatní suggestion snapshoty musí zůstat zelené beze změny (favorites režim se aktivuje jen pro `suggestions: []` + neprázdné favorites).

### 5. Housekeeping

- Přidat task do [tasks/README.md](README.md) (sekce v1.1 polish, vedle [44](44-favorite-emojis-in-suggestion-bar.md)).
- Po dokončení přepnout **Status** na `Done — <datum>` a regenerovat dashboard: `python3 scripts/generate_dashboard.py`.

## Mimo scope

- **Žádná změna výběru režimu baru.** `body` ([:49](../KeyboardUI/Sources/Views/SuggestionBarView.swift:49)) i podmínka `suggestions.isEmpty && !favoriteEmojis.isEmpty` zůstávají. Měníme jen vnitřek `favoritesBar`.
- **Žádné stránkování pro `pillBar` (Slack) ani `plainBar`.** Ty zůstávají, jak jsou (`pillBar` dál free-scroll). Týká se to **jen** favorites režimu.
- **Žádná správa/řazení/perzistence favorites** — čteme `favoriteEmojis` jak přicházejí (řeší tasky [18](18-favorite-emojis.md) / [32](32-favorites-show-shortcodes.md)).
- **Žádné index dots / page control UI** (pokud se zadavatel nerozhodne jinak v Souhrnu) — cíl je vizuální parita s dnešním scrollview.
- **Žádná změna tap chování** — vložení emoji + haptika/zvuk + recents zůstává přes `selectEmoji` / `onSelectEmoji` beze změny.

## Hotovo když

- Swipe doleva/doprava na favorites baru lístkuje obsah po stránkách (posun o `emojisPerPage` emoji na jeden swipe), ne plynulým scrollem.
- Bar vizuálně vypadá identicky jako dnes (stejné glyfy, velikost, rozestupy, 40pt výška, žádné tečky) — screenshot první stránky se nemění oproti dnešnímu scrollview.
- Tap na favorite dál vkládá emoji + hraje haptiku/zvuk + posune do recents (beze změny).
- Výška klávesnice se v žádném přechodu (favorites ↔ suggestions ↔ prázdný bar) nemění (C1).
- Unit testy `emojisPerPage` / `paginate` a favorites snapshoty jsou zelené; stávající suggestion snapshoty zůstaly beze změny.
- Build `xcodebuild -workspace Keymoji.xcworkspace -scheme Keymoji -destination 'generic/platform=iOS Simulator' build` projde zelený.

## Rizika

- **Gesture konflikt tap vs. swipe.** `TabView` page style (`UIPageViewController`) má vlastní pan recognizer. Ověřit, že tap na glyf spolehlivě vkládá emoji a swipe stránkuje — ne že jeden požírá druhý. Případně doladit `contentShape`/hit test buňky.
- **Výška `TabView`.** `TabView` má tendenci roztáhnout se / rezervovat místo pro index. S `indexDisplayMode: .never` a tvrdým `barHeight` framem to musí sednout přesně na 40 pt — vizuálně ověřit přes snapshot, ne jen že to „nebliká".
- **`emojisPerPage` na hraně.** Velmi úzký bar / velký glyf → `per` může vyjít 0; `max(1, …)` to drží, ale ohlídat, ať stránka s 1 emoji nevypadá rozbitě. Subpixelové rozdíly v šířce mohou na různých zařízeních dát jiný počet na stránku — to je OK (stránka se přizpůsobí), ale unit test ať fixuje konkrétní očekávané hodnoty pro SE/iPhone šířky.
- **Re-record snapshotů.** Přechod ScrollView → TabView může posunout layout o subpixel a rozbít existující favorites referenční snapshoty z [tasku 44](44-favorite-emojis-in-suggestion-bar.md). Pokud ano, vědomě re-recordnout a zmínit v commitu (📸).

## Reference

- Cílový soubor: [SuggestionBarView.swift](../KeyboardUI/Sources/Views/SuggestionBarView.swift) — konkrétně `favoritesBar` ([:145](../KeyboardUI/Sources/Views/SuggestionBarView.swift:145)) a konstanty `chipSpacing`/`horizontalPadding`/`barHeight`.
- Snapshoty: [SuggestionBarViewSnapshots.swift](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift)
- Předchozí favorites task (zavedl `favoritesBar` jako ScrollView): [44 — Favorite emojis v SuggestionBarView](44-favorite-emojis-in-suggestion-bar.md)
- Související favorites tasky: [18 — Favorite emojis editor](18-favorite-emojis.md), [32 — Favorites: shortcode místo druhé kopie emoji](32-favorites-show-shortcodes.md)
</content>
</invoke>
