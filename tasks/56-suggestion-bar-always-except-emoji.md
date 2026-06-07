# 56 — SuggestionBar: zobrazovat vždy kromě emoji / emoji-search stránek

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Medium (UX — bar dostupný i na symbol page)

## Cíl

Změnit podmínku viditelnosti `SuggestionBarView` na jedno jednoduché pravidlo:

> Suggestion bar se zobrazuje **vždy**, **kromě** případů, kdy je aktivní emoji panel
> (`KeyboardView.isEmojiKeyboard`) nebo emoji search (`KeyboardView.isEmojiSearchKeyboard`).

Tím odpadají všechny dnešní dílčí podmínky pro viditelnost samotného baru:

- už se neomezuje jen na `.letters` stránky — **nově je vidět i na symbol page** (`.symbols`),
- už ho neschovává vypnutý master toggle (`suggestionsEnabled`) ani neeligibilní pole
  (`currentEligibility.allowDisplay`).

Bar se stává trvalou plochou nad klávesnicí (word/Slack suggestions, případně favorites,
případně prázdný slot) — viditelnou všude mimo emoji režimy.

## Klíčová zjištění z průzkumu kódu

Viditelnost baru je dnes řešená **na dvou paralelních místech**, která musí dávat stejnou
odpověď, jinak se rozejde výška hostu a výška SwiftUI obsahu a iOS obsah ořízne (stejná třída
bugu, jako už řešil task 53/54 a komentář u `.emojiSearch`):

1. **View-side gate** — [`KeyboardView.effectiveShowsBar`](KeyboardUI/Sources/Views/KeyboardView.swift:93):
   ```swift
   guard showsSuggestionBar, !isEmojiKeyboard, !isEmojiSearchKeyboard else { return false }
   if case .letters = layout.page { return true }
   return false
   ```
   Řídí jak **renderování** baru ve `body`, tak **výšku SwiftUI framu** přes
   [`keyboardHeight`](KeyboardUI/Sources/Views/KeyboardView.swift:257)
   (`KeyboardMetrics.keyboardHeight(for:showsSuggestionBar: effectiveShowsBar)`).

2. **Controller-side gate** — [`KeyboardViewController.showsSuggestionBar`](KeyboardExtension/Sources/KeyboardViewController.swift:501):
   ```swift
   guard state.suggestionsEnabled, state.currentEligibility.allowDisplay else { return false }
   if case .letters = state.page { return true }
   return false
   ```
   Řídí (a) **výšku height constraintu hostu** přes
   [`desiredKeyboardHeight()`](KeyboardExtension/Sources/KeyboardViewController.swift:432),
   (b) jestli se vůbec počítají suggestions a co se předá do `KeyboardRoot`
   ([`makeRoot`](KeyboardExtension/Sources/KeyboardViewController.swift:440)),
   (c) viditelnost favorites (`favoritesVisible`).

Obě místa dnes kódují **stejnou logiku**. Po změně musí být obě podmínky pro **viditelnost**
opět identické — jinak drift výšky → clipping.

- **`KeyboardMetrics.keyboardHeight(for:showsSuggestionBar:)`** přičítá
  `suggestionBarFootprint` (= `suggestionBarHeight 40 + suggestionBarGap 2`) jen když je
  `showsSuggestionBar == true` ([`KeyboardMetrics.swift:49`](KeyboardCore/Sources/Logic/KeyboardMetrics.swift:49)).
  Tudíž jakmile bar nově svítí i na symbol page, **musí o tom vědět oba výpočty výšky**.

- **`SuggestionBarView` je už dnes content-agnostické** ([SuggestionBarView.swift:5](KeyboardUI/Sources/Views/SuggestionBarView.swift:5)):
  prázdné `suggestions` → fallback na favorites scroll; prázdné suggestions i favorites →
  bar zabírá slot, ale nic nekreslí (decision C1). Takže „vždy viditelný“ bar je už teď
  vizuálně bezpečný i bez obsahu — nehrozí prázdný rámeček s artefakty.

## Návrh

### Rozdělit „je bar vidět“ od „čím je naplněný“

Dnešní `showsSuggestionBar` míchá dvě věci dohromady: *viditelnost slotu* a *jestli se mají
nabízet suggestions*. Po této změně se rozcházejí:

- **Viditelnost** (řídí výšku + render) = `!isEmojiKeyboard && !isEmojiSearchKeyboard`.
- **Obsah** (suggestions vs. favorites vs. prázdno) zůstává řízený `suggestionsEnabled` +
  `currentEligibility.allowDisplay` jako dnes.

1. **View** — zjednodušit [`effectiveShowsBar`](KeyboardUI/Sources/Views/KeyboardView.swift:93) na:
   ```swift
   private var effectiveShowsBar: Bool {
       !isEmojiKeyboard && !isEmojiSearchKeyboard
   }
   ```
   Property `showsSuggestionBar` na `KeyboardView` se tím přestane podílet na viditelnosti —
   zůstane už jen jako vstup pro *obsah* baru (předané `suggestions` jsou prázdné, když je
   toggle off). Aktualizovat doc komentář na [řádku 89–92](KeyboardUI/Sources/Views/KeyboardView.swift:89).

2. **Controller — nové dělení.** V [`KeyboardViewController`](KeyboardExtension/Sources/KeyboardViewController.swift:501)
   zavést dvě hodnoty, aby host height i SwiftUI height braly **stejnou** viditelnost:
   ```swift
   /// Bar zabírá svůj slot všude kromě emoji panelu a emoji search — řídí výšku
   /// (host constraint i SwiftUI frame), musí být identické s KeyboardView.effectiveShowsBar.
   private var suggestionBarVisible: Bool {
       state.page != .emojis && !state.page.isEmojiSearch
   }

   /// Jestli bar nabízí word/Slack suggestions. Když je false, bar je pořád vidět,
   /// jen ukazuje favorites (nebo nic).
   private var suggestionsActive: Bool {
       state.suggestionsEnabled && state.currentEligibility.allowDisplay
   }
   ```
   - [`desiredKeyboardHeight()`](KeyboardExtension/Sources/KeyboardViewController.swift:432) →
     `showsSuggestionBar: suggestionBarVisible`.
   - [`makeRoot()`](KeyboardExtension/Sources/KeyboardViewController.swift:440):
     `showsSuggestionBar: suggestionBarVisible`, `suggestions = suggestionsActive ? currentSuggestions() : []`,
     `favoritesVisible = (suggestionBarVisible && suggestions.isEmpty) || state.page == .emojis`.

   > Pozor na konzistenci: `suggestionBarVisible` (controller) a `effectiveShowsBar` (view)
   > musí vrátit **totéž** pro každou stránku. Obě = „není emoji ani emoji search“. Když se
   > v budoucnu jedna změní, druhá musí taky — jinak clipping.

3. **`page.isEmojiSearch` / `page == .emojis`** je už existující API používané jinde
   (LayoutBuilder, desiredKeyboardHeight) — žádné nové signály se nezavádějí.

## Mimo scope

- **Změna obsahu baru na symbol page.** Tady jen *zviditelňujeme* slot. Na symbol page
  nejsou word suggestions relevantní (suggestiony se počítají z textu, ne ze symbolů) —
  bar tam tedy reálně ukáže favorites, případně bude prázdný. Žádnou symbol-specific nabídku
  nevymýšlíme.
- **Odstranění `suggestionsEnabled` toggle.** Master toggle zůstává; nově ale neřídí
  viditelnost slotu, jen jestli se nabízejí word/Slack suggestions (vs. favorites/prázdno).
- **Nový height/spacing.** `suggestionBarHeight` (40) + `suggestionBarGap` (2) beze změny.

## Testy

- **`KeyboardViewSnapshots`** — nový snímek: symbol page (`.symbols`) **s** suggestion barem
  (dnes by tam bar nebyl). Ověřit, že se bar renderuje a výška sedí (footprint přičten).
- **Konzistence výšky** — test (nebo aspoň manuální ověření), že `desiredKeyboardHeight()` a
  `KeyboardView.keyboardHeight` dají stejnou hodnotu na symbol page i letters page (oba berou
  `suggestionBarVisible == true`).
- **Emoji / emoji-search** — bar **není** vidět (regrese): existující emoji snímky musí zůstat
  beze změny (žádný bar, žádná změna výšky).
- **Toggle off** — bar je vidět i s `suggestionsEnabled == false`, ukazuje favorites
  (nebo prázdný slot), výška stabilní.

## Závislosti

Žádné blokující. Staví na stávající `showsSuggestionBar` / favorites infrastruktuře
(task 40 word completion, task 44 favorites v baru, task 49 favorites paging).
Pozor na společnou výškovou logiku zavedenou v tasku 53/54.
