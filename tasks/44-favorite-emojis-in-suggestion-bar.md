# 44 — Favorite emojis scrollview v SuggestionBarView

**Status:** Done — 2026-05-31

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Medium (daily-use: oblíbené emoji na jedno tapnutí přímo nad klávesnicí, bez přepínání na emoji panel)

## Souhrn

[`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift) dnes umí dva režimy podle prvního chipu: `.plain` (word completion, [SuggestionBarView.swift:50](../KeyboardUI/Sources/Views/SuggestionBarView.swift:50)) a `.pill` (Slack shortcode typeahead, [SuggestionBarView.swift:78](../KeyboardUI/Sources/Views/SuggestionBarView.swift:78)). Když je `suggestions` prázdné, bar zůstává ve svém slotu, ale nic nekreslí (C1 — always-on, vizuálně tichý, konstantní výška).

Přidáme **třetí režim: horizontální scrollview oblíbených emoji**. Vyplní právě ten dosud prázdný stav: místo prázdného baru se zobrazí uživatelovy favorites na jeden tap.

**Podmínka zobrazení (přesně dle zadání):** favorites scrollview se ukáže **právě tehdy, když `favoriteEmojis` NENÍ prázdné A ZÁROVEŇ `suggestions` JE prázdné**. Protože `suggestions` je už zmergovaný výstup [`SuggestionCoordinator`](../KeyboardCore/Sources/Logic/Suggestions/SuggestionCoordinator.swift) (Slack vyhrává wholesale, jinak word completions), `suggestions.isEmpty` pokrývá obě varianty najednou — žádné text suggestions *a* žádné Slack emoji suggestions. Jakmile se objeví jakýkoli suggestion (text nebo Slack), favorites ustoupí a vykreslí se suggestions.

Rozhodnutí potvrzená se zadavatelem:
- **Rozsah:** jen zobrazit. `favoriteEmojis` už existují (`AppGroupStore.favoriteEmojis`, threadnuté přes `KeyboardState` až do `KeyboardView`). Žádná nová perzistence ani editor — to řeší tasky [18](18-favorite-emojis.md) / [32](32-favorites-show-shortcodes.md).
- **Tap:** vloží emoji do textu (stejné chování jako tap na Slack emoji suggestion / tap v emoji panelu).
- **Vzhled:** jen samotný emoji glyf (žádné chip pozadí, na rozdíl od `.pill`).
- **Pořadí / počet:** všechny favorites v daném pořadí, bez limitu (scrollují horizontálně).
- **Gatování:** favorites se zobrazí jen když `suggestionsEnabled == true`. Jedou uvnitř suggestion baru a dědí jeho gatování — když uživatel vypne suggestions v Settings, zmizí i favorites row. Žádná samostatná větev pro „favorites bez suggestions".

## Kontext

- `favoriteEmojis: [String]` **už teče** do `KeyboardView` ([KeyboardView.swift:14](../KeyboardUI/Sources/Views/KeyboardView.swift:14), init na [:44](../KeyboardUI/Sources/Views/KeyboardView.swift:44)) z `KeyboardState.favoriteEmojis` přes [`KeyboardRoot`](../KeyboardExtension/Sources/KeyboardRoot.swift:31). Aktuálně ho konzumuje jen emoji panel ([KeyboardView.swift:160](../KeyboardUI/Sources/Views/KeyboardView.swift:160)). `SuggestionBarView` ho zatím nedostává — to je hlavní napojení tohoto tasku.
- Vkládání emoji už existuje: emoji panel syntetizuje transientní `Key` s akcí `.insertText(emoji)` a pošle ho přes `onKey` ([KeyboardView.swift:164-177](../KeyboardUI/Sources/Views/KeyboardView.swift:164)). Dispatch path v controlleru pak přes `recordRecentEmojiIfNeeded` ([KeyboardViewController.swift:567-581](../KeyboardExtension/Sources/KeyboardViewController.swift:567)) posune emoji na začátek `recentEmojis` a uloží. **Tutéž cestu použijeme i pro tap na favorite v baru** — tj. tapnutý favorite se konzistentně promítne i do recents (žádaný side-effect, stejně jako v panelu).
- Bar má fixní výšku 40 pt ([SuggestionBarView.swift:34](../KeyboardUI/Sources/Views/SuggestionBarView.swift:34)). Favorites režim ji musí dodržet — výška klávesnice se nikdy nesmí měnit podle obsahu baru (C1, viz `keyboardHeight` / `suggestionBarFootprint` v [KeyboardView.swift:251](../KeyboardUI/Sources/Views/KeyboardView.swift:251)).
- Bar se vůbec zobrazuje jen na letters pages, když je zapnutý master toggle a field je eligible (`effectiveShowsBar`, [KeyboardView.swift:91](../KeyboardUI/Sources/Views/KeyboardView.swift:91); controller gate `shouldShowSuggestionBar`, [KeyboardViewController.swift:422](../KeyboardExtension/Sources/KeyboardViewController.swift:422)). Favorites jedou **uvnitř** tohoto baru, takže dědí stejné gatování (viz Rizika — corner case s vypnutými suggestions).

## Scope

### 1. `SuggestionBarView` — nový favorites režim

V [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift):

- Přidat dvě nová `public` pole + parametry initu (s defaulty, ať existující call-sites a testy nepadnou):
  - `public let favoriteEmojis: [String]` — default `[]`.
  - `public let onSelectEmoji: (String) -> Void` — default `{ _ in }`.
- Upravit `body` ([:36](../KeyboardUI/Sources/Views/SuggestionBarView.swift:36)) tak, aby vybíral mezi třemi režimy. Pořadí priority:

  ```swift
  Group {
      if !suggestions.isEmpty {
          if suggestions.first?.renderStyle == .pill { pillBar } else { plainBar }
      } else if !favoriteEmojis.isEmpty {
          favoritesBar
      } else {
          plainBar   // prázdné → vizuálně tichý bar (C1)
      }
  }
  .frame(height: barHeight)
  .frame(maxWidth: .infinity)
  ```

  Tím zůstává prázdný-bar stav beze změny (`plainBar` s prázdným `suggestions` nekreslí nic) a favorites se vsunou přesně do dříve prázdného slotu.

- Nový `favoritesBar` — horizontální `ScrollView`, stejný layout skeleton jako `pillBar` (`ScrollView(.horizontal, showsIndicators: false)` + `HStack(spacing: chipSpacing)` + `.padding(.horizontal, horizontalPadding)`, viz [:78](../KeyboardUI/Sources/Views/SuggestionBarView.swift:78)), ale buňka je **jen glyf, bez `RoundedRectangle` pozadí**:

  ```swift
  private var favoritesBar: some View {
      ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: chipSpacing) {
              ForEach(favoriteEmojis, id: \.self) { emoji in
                  Button { selectEmoji(emoji) } label: {
                      Text(emoji)
                          .font(.system(size: 24))   // starting value, dolaď přes snapshot
                          .frame(minWidth: 36)         // komfortní hit target
                          .frame(maxHeight: .infinity)
                  }
                  .buttonStyle(.plain)
              }
          }
          .padding(.horizontal, horizontalPadding)
      }
  }
  ```

- `selectEmoji(_:)` helper — paralela k existujícímu `select(_:)` ([:114](../KeyboardUI/Sources/Views/SuggestionBarView.swift:114)) — fire `onKeyTapHaptic()`, `onKeyClick()`, pak `onSelectEmoji(emoji)`. Stejná haptika/zvuk jako u ostatních chipů.

- Přidat `#Preview` pro favorites režim (`suggestions: []`, `favoriteEmojis: ["❤️","😀","🚀","🎉","🐶","🍕","👍"]`) v `#if DEBUG` bloku ([:121](../KeyboardUI/Sources/Views/SuggestionBarView.swift:121)).

### 2. `KeyboardView` — napojení favorites do baru

V [`KeyboardView.body`](../KeyboardUI/Sources/Views/KeyboardView.swift:97) předat do `SuggestionBarView` ([:100](../KeyboardUI/Sources/Views/KeyboardView.swift:100)):

- `favoriteEmojis: favoriteEmojis` (už je k dispozici jako property).
- `onSelectEmoji:` — closure, která syntetizuje transientní `Key` **identicky** jako emoji panel ([:164-177](../KeyboardUI/Sources/Views/KeyboardView.swift:164)) a zavolá `onKey`:

  ```swift
  onSelectEmoji: { emoji in
      let key = Key(
          id: "emoji.\(emoji)",
          primary: .text(emoji),
          alternates: [],
          action: .insertText(emoji),
          visualWeight: .standard,
          role: .character
      )
      onKey(key)
  }
  ```

  Routováním přes `onKey` (dispatch) dostaneme zdarma vložení textu, haptiku/zvuk z dispatch path *a* update recents (`recordRecentEmojiIfNeeded`) — konzistentní s panelem. Faktor out tohoto Key-buildingu do malého privátního helperu (`insertEmojiKey(_:)`), ať to není duplikované mezi emoji panelem a barem.

- **Žádné změny v controlleru** ([KeyboardViewController](../KeyboardExtension/Sources/KeyboardViewController.swift) / [KeyboardRoot](../KeyboardExtension/Sources/KeyboardRoot.swift)) nejsou potřeba — `favoriteEmojis` už teče a emoji-insert path už existuje.

### 3. Snapshot testy

Do [`SuggestionBarViewSnapshots`](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift) přidat sekci „Favorite emojis" (favorites jsou `[String]`, žádný nový builder v [`SuggestionSnapshotSupport`](../KeyboardUI/Tests/SuggestionSnapshotSupport.swift) netřeba):

- `testFavorites_shownWhenSuggestionsEmpty` — `suggestions: []`, `favoriteEmojis: ["❤️","😀","🚀","🎉","🐶"]`, dark + light.
- `testFavorites_overflowScrolls` — víc favorites, než se vejde na šířku (např. 15), na `iPhoneWidth`; ověří, že to scrolluje a neořezává výšku.
- `testFavorites_hiddenWhenSuggestionsPresent` — `favoriteEmojis` neprázdné **a zároveň** neprázdné `suggestions` (word i Slack varianta) → musí se vykreslit suggestions, ne favorites. Tím zafixujeme prioritu z bodu 1.
- Stávající `testEmptyBar_alwaysShown` ([:43](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift:43)) ponechat beze změny — s default `favoriteEmojis: []` musí dál renderovat tichý prázdný bar (žádný regres C1).

Volitelně: do [`KeyboardViewSnapshots`](../KeyboardUI/Tests/KeyboardViewSnapshots.swift) přidat letters-page snapshot s `favoriteEmojis` + prázdnými `suggestions` + `showsSuggestionBar: true`, ať je pokrytá i integrace na úrovni celé klávesnice (a výška sedí).

### 4. Housekeeping

- Přidat task do roadmapy v [tasks/README.md](README.md) (sekce v1.1) a po dokončení přepnout **Status** na `Done — <datum>`.
- Regenerovat dashboard: `python3 scripts/generate_dashboard.py`.

## Mimo scope

- **Žádná správa favorites** — přidávání/odebírání/řazení řeší editor (task [18](18-favorite-emojis.md)) a emoji panel long-press. Tady jen čteme `favoriteEmojis`.
- **Žádné recents v baru.** Bar ukazuje jen *favorites*, ne recents (recents má panel).
- **Žádný limit/ořez počtu** favorites — všechny, scrollují.
- **Žádné chip pozadí** ani shortcode label u favorites (to je `.pill` / editor record). Jen glyf.
- **Žádná změna logiky `SuggestionCoordinator`** — favorites nejsou `Suggestion`, neprochází coordinatorem; jsou paralelní vstup do baru.
- **Žádné zobrazení mimo letters pages** ani když je bar vypnutý/field neeligible — favorites dědí existující gatování baru (viz Rizika).

## Hotovo když

- Na letters page s eligible fieldem a zapnutými suggestions, když nejsou žádné text ani Slack suggestions a `favoriteEmojis` je neprázdné, se nad klávesnicí zobrazí horizontální scrollview oblíbených emoji (jen glyfy, bez pozadí).
- Tap na favorite vloží emoji do textu, zahraje haptiku/zvuk a posune emoji do recents (stejně jako tap v emoji panelu).
- Jakmile se objeví jakýkoli suggestion (text nebo Slack), favorites zmizí a vykreslí se suggestions; po jejich zmizení se favorites zase vrátí.
- Když je `favoriteEmojis` prázdné a `suggestions` prázdné, bar je vizuálně tichý jako dnes (C1) — výška klávesnice se v žádném z přechodů nemění.
- Snapshot testy z bodu 3 jsou zelené; stávající suggestion-bar snapshoty zůstaly beze změny (default `favoriteEmojis: []` nic nerozbil).
- Build `xcodebuild -workspace Keymoji.xcworkspace -scheme Keymoji -destination 'generic/platform=iOS Simulator' build` projde zelený.

## Rizika

- **Vypnuté suggestions = žádné favorites (potvrzené chování).** Favorites jedou uvnitř baru, který se na letters page zobrazí jen když `state.suggestionsEnabled == true` a field je eligible ([KeyboardViewController.swift:422](../KeyboardExtension/Sources/KeyboardViewController.swift:422)). Když uživatel vypne suggestions v Settings, zmizí i favorites row — to je záměr, ne bug. Žádná samostatná větev v controlleru, která by bar zobrazovala při `suggestionsEnabled == false`. `effectiveShowsBar` ([KeyboardView.swift:91](../KeyboardUI/Sources/Views/KeyboardView.swift:91)) ani `shouldShowSuggestionBar` se nemění.
- **Konzistence recents.** Routování přes `onKey` znamená, že favorite tapnutý v baru se objeví i v recents. To je záměr (parita s panelem), ale potvrdit, že to nevadí — recents kapacita je řízená v `recordRecentEmojiIfNeeded` ([:577](../KeyboardExtension/Sources/KeyboardViewController.swift:577)).
- **Velikost glyfu / hit target.** `font(size: 24)` + `minWidth: 36` jsou výchozí hodnoty; dolaď přes snapshot, ať favorites opticky sednou k 40pt baru a tapy se dobře trefují.
- **Default parametry initu.** Nové parametry `SuggestionBarView` musí mít defaulty, jinak spadnou existující call-sites (`KeyboardView`) a všechny stávající snapshot testy, které volají init bez favorites.

## Reference

- Cílový soubor: [SuggestionBarView.swift](../KeyboardUI/Sources/Views/SuggestionBarView.swift)
- Napojení: [KeyboardView.swift](../KeyboardUI/Sources/Views/KeyboardView.swift), [KeyboardRoot.swift](../KeyboardExtension/Sources/KeyboardRoot.swift)
- Emoji-insert + recents path: [KeyboardViewController.swift:485-581](../KeyboardExtension/Sources/KeyboardViewController.swift:485)
- Suggestion model & merge: [Suggestion.swift](../KeyboardCore/Sources/Logic/Suggestions/Suggestion.swift), [SuggestionCoordinator.swift](../KeyboardCore/Sources/Logic/Suggestions/SuggestionCoordinator.swift)
- Snapshoty: [SuggestionBarViewSnapshots.swift](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift), [SuggestionSnapshotSupport.swift](../KeyboardUI/Tests/SuggestionSnapshotSupport.swift)
- Související favorites tasky: [18 — Favorite emojis editor](18-favorite-emojis.md), [32 — Favorites: shortcode místo druhé kopie emoji](32-favorites-show-shortcodes.md)
</content>
</invoke>
