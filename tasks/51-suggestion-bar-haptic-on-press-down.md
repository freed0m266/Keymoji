# 51 — Suggestion bar: haptika na začátku stisku (parita s klávesami)

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Low–Medium (jemný „native feel" detail, ale nekonzistence je hmatatelná)

## Cíl

Tlačítka v `SuggestionBarView` (word-completion chipy, Slack pill chipy i favorite-emoji glyphy)
dnes hrají haptiku **na konci stisku** (touch-up), protože jsou to obyčejné `Button`y a haptika se
volá v jejich akci. Naproti tomu `KeyView` hraje haptiku **na začátku stisku** (touch-down) —
ve chvíli, kdy prst dosedne, ne když se zvedne. Cílem je sjednotit chování: suggestion bar má
hrát haptiku **na touch-down**, stejně jako klávesy.

Po dokončení: tap na jakýkoli chip / emoji v suggestion baru vibruje ve stejný okamžik jako tap
na klávesu (na dosednutí prstu), takže celá klávesnice má konzistentní hmatovou odezvu.

## Kontext

- `KeyView` haptiku řeší přes `DragGesture(minimumDistance: 0)` a fire na touch-down v
  `handleTouchDown(...)`:
  [`KeyView.swift:150-199`](../KeyboardUI/Sources/Views/KeyView.swift:150). Komentář u
  [`KeyView.swift:184-190`](../KeyboardUI/Sources/Views/KeyView.swift:184) explicitně popisuje
  záměr — „feedback when the finger lands, not when it lifts" (parita s Apple / SwiftKey).
- `SuggestionBarView` používá `Button { … } label: { … }` + `.buttonStyle(.plain)` a volá
  `onKeyTapHaptic()` v akci tlačítka, tj. **na touch-up**:
  - word/plain chip: [`SuggestionBarView.swift:88-109`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:88) → `select(_:)` [`:149-153`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:149)
  - Slack pill chip: [`SuggestionBarView.swift:124-147`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:124) → `select(_:)`
  - favorite emoji: [`SuggestionBarView.swift:157-180`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:157) → `selectEmoji(_:)` [`:182-186`](../KeyboardUI/Sources/Views/SuggestionBarView.swift:182)
- Haptika teče přes `onKeyTapHaptic` closure až do
  [`KeyboardViewController.swift:413`](../KeyboardExtension/Sources/KeyboardViewController.swift:413)
  (`onKeyTapHaptic: { self?.haptics.keyTap() }`), protokol
  [`HapticFeedbackProviding.swift`](../KeyboardCore/Sources/Public/HapticFeedbackProviding.swift).

## Klíčová technická překážka

SwiftUI `Button` je z principu **touch-up** — jeho akce se fire až při zvednutí prstu (a to je
správně pro samotnou *akci*, tu na touch-up chceme nechat, aby šla zrušit odtažením prstu). Je
potřeba oddělit **haptiku** (chce touch-down) od **akce** (zůstává touch-up).

Možné přístupy — vybrat při implementaci:

1. **`ButtonStyle` s `configuration.isPressed`** (preferováno, nejmenší zásah do struktury):
   vlastní `ButtonStyle`, který sleduje přechod `isPressed` `false → true` a tehdy fire haptiku.
   Akce tlačítka (`select`/`selectEmoji`) zůstane na touch-up, jen z ní odpadne `onKeyTapHaptic()`.
   Pozor: `isPressed` jde do `true` na touch-down a zpět do `false` při zrušení (odtažení prstu)
   — haptiku fire jen na náběžné hraně, ne při každé změně.
2. **Souběžný `DragGesture(minimumDistance: 0)`** přes chip (jako `KeyView`), který fire haptiku
   na `onChanged` první události, bez konzumace tapu Buttonu. Riziko konfliktu gest se scrollem
   (pill bar i favorites jsou ve `ScrollView`/`TabView`) — proto je `ButtonStyle` čistší.

Rozhodnutí mezi 1 a 2 udělat s ohledem na to, aby se **nerozbil scroll/paging** v pill baru
(`ScrollView(.horizontal)`) a favorites baru (`TabView` paging, task 49).

## Scope

1. **Oddělit haptiku od akce.** Z `select(_:)` a `selectEmoji(_:)` odstranit `onKeyTapHaptic()`
   (klik/`onKeyClick()` ponechat tam, kde je — viz „Mimo scope" k jeho timingu) a haptiku fire
   na touch-down přes zvolený mechanismus (preferovaně sdílený `ButtonStyle`).
2. **Pokrýt všechny tři druhy chipů** — plain (word), pill (Slack), favorite emoji. Všechny tři
   musí hrát haptiku na touch-down.
3. **Respektovat scroll/paging.** Touch-down haptika nesmí fire při pouhém scrollu/swipe-paging
   přes bar (kde uživatel nechce vybrat chip, jen listuje). Tzn. fire na začátku stisku konkrétního
   chipu, ne na drag celého baru. (S `ButtonStyle` to řeší SwiftUI sám — `isPressed` jde do `true`
   jen na chip; ověřit, že paging gesto v `TabView` nepřetéká do haptiky.)
4. **Respektovat haptics toggle.** Haptika nadále teče přes `onKeyTapHaptic` → `haptics.keyTap()`,
   tedy app-side haptics toggle ji stále vypne (žádná nová cesta mimo `HapticFeedbackProviding`).

## Mimo scope

- **Změna timingu `onKeyClick()` (zvuku).** Tento task je čistě o haptice. Pokud chceme i zvuk na
  touch-down, je to samostatné rozhodnutí (zvážit konzistenci s KeyView, kde click i haptika jdou
  spolu na touch-down — ale ať to neblokuje tento task).
- **`EmojiPanelView` a `EmojiSearchView`.** Mají stejný `Button`-na-touch-up pattern
  ([`EmojiPanelView.swift`](../KeyboardUI/Sources/Views/EmojiPanelView.swift),
  [`EmojiSearchView.swift`](../KeyboardUI/Sources/Views/EmojiSearchView.swift)) a zaslouží stejné
  sjednocení — pokud vznikne sdílený `ButtonStyle`, je levné je přidat, ale primární cíl je
  **suggestion bar**. Pokud se nepřidají teď, založit follow-up.
- Změna chování `KeyView` (ten už haptiku na touch-down má) — nedotčené.
- Jakýkoli nový uživatelský toggle.

## Závislosti

- Task [31](31-haptic-feedback-for-every-key.md) (haptika pro každou klávesu) — done; definuje
  touch-down haptiku v `KeyView`, se kterou tady děláme paritu.
- Task [49](49-favorites-bar-tabview-paging.md) (favorites TabView paging) — done; ověřit, že
  touch-down haptika nekoliduje s paging gestem.
- Task [44](44-favorite-emojis-in-suggestion-bar.md) (favorites v suggestion baru) — done.

## Hotovo když

- [ ] Tap na word-completion chip vibruje na dosednutí prstu (touch-down), ne na zvednutí.
- [ ] Tap na Slack pill chip vibruje na touch-down.
- [ ] Tap na favorite emoji v baru vibruje na touch-down.
- [ ] Timing haptiky je side-by-side nerozeznatelný od tapu na klávesu (`KeyView`).
- [ ] Scroll pill baru ani paging favorites baru nespouští haptiku (vibruje jen výběr chipu).
- [ ] Akce výběru (insert textu / emoji) stále proběhne korektně na touch-up a jde zrušit odtažením prstu.
- [ ] Haptics toggle (`AppGroupStore` přes `HapticFeedbackProviding`) stále veškerou haptiku vypne.
- [ ] Žádná regrese ve výběru chipů, scrollu, pagingu ani v ostatních klávesách.

## Reference

- [`KeyboardUI/Sources/Views/SuggestionBarView.swift`](../KeyboardUI/Sources/Views/SuggestionBarView.swift) — cíl změny (`select`/`selectEmoji`, tři druhy chipů).
- [`KeyboardUI/Sources/Views/KeyView.swift:175-212`](../KeyboardUI/Sources/Views/KeyView.swift:175) — vzor touch-down haptiky (`handleTouchDown`, `firesKeyTapFeedback`).
- [`KeyboardCore/Sources/Public/HapticFeedbackProviding.swift`](../KeyboardCore/Sources/Public/HapticFeedbackProviding.swift) — haptický protokol (`keyTap()`).
- [`KeyboardExtension/Sources/KeyboardViewController.swift:413`](../KeyboardExtension/Sources/KeyboardViewController.swift:413) — `onKeyTapHaptic` hook.
- Související (mimo scope): [`EmojiPanelView.swift`](../KeyboardUI/Sources/Views/EmojiPanelView.swift), [`EmojiSearchView.swift`](../KeyboardUI/Sources/Views/EmojiSearchView.swift) — stejný pattern.
- Task [31](31-haptic-feedback-for-every-key.md), [49](49-favorites-bar-tabview-paging.md).
