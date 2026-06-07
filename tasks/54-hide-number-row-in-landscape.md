# 54 — Skrýt number row v landscape orientaci

**Status:** Done — 2026-06-07

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Medium (UX v landscape)

## Cíl

Když je iPhone na šířku (landscape), je vertikální místo extrémně omezené a klávesnice
zabírá nepřiměřeně velkou část obrazovky. Nativní iOS klávesnice v landscape **number row
nezobrazuje** — digity jsou dostupné přes `123` page toggle. Keymoji to má replikovat:

- **Portrait** — beze změny. Number row se řídí výhradně uživatelským přepínačem
  `showNumberRow` ([`SettingsView`](Features/Settings/Sources/SettingsView.swift:66)).
- **Landscape** — number row se **nikdy nezobrazí**, bez ohledu na hodnotu `showNumberRow`.
  Uživatelská preference se nemění (zůstává uložená v `AppGroupStore`) — jen se v landscape
  ignoruje. Po rotaci zpět do portrait se number row vrátí přesně podle preference.

## Klíčová zjištění z průzkumu kódu

- **Number row dnes vzniká jen z `showNumberRow`.** Jediná podmínka pro jeho zařazení je
  v [`LayoutBuilder.layout`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:21):
  `let includeNumberRow = showNumberRow && page != .emojis && !page.isEmojiSearch`.
  `LayoutBuilder` je *pure* — orientaci nezná, dostane jen `showNumberRow: Bool`.

- **Orientace se nikde nesleduje.** V projektu není žádná detekce landscape/portrait
  (`grep` na `landscape`/`orientation`/`verticalSizeClass` nic nenajde). Bude se muset zavést.

- **Tři spotřebitelé `showNumberRow` musí zůstat konzistentní** — jinak se rozejdou výška
  hostu a výška SwiftUI obsahu a iOS obsah ořízne (stejný typ bugu, jako už je okomentovaný
  u `.emojiSearch` v [`KeyboardViewController`](KeyboardExtension/Sources/KeyboardViewController.swift:382)):
  1. [`KeyboardRoot`](KeyboardExtension/Sources/KeyboardRoot.swift:28) → `makeLayout(showNumberRow:)`
  2. [`KeyboardView.keyboardHeight`](KeyboardUI/Sources/Views/KeyboardView.swift:255) →
     čte `layout.showsNumberRow` (260 vs 216 pt)
  3. [`KeyboardViewController.desiredKeyboardHeight()`](KeyboardExtension/Sources/KeyboardViewController.swift:411) →
     čte `state.showNumberRow` (height constraint hostu)

  Pokud landscape sníží layout, musí o tom vědět **všechny tři** — proto je čistší zavést
  jednu *effective* hodnotu, ne podmínku rozsázet na tři místa.

- **`KeyboardLayout.showsNumberRow` schválně propaguje preferenci** kvůli konzistenci výšky
  napříč stránkami (viz komentář v `LayoutBuilder.swift:19`). V landscape ale chceme i nižší
  klávesnici — takže do `showsNumberRow` musí jít **effective** hodnota (false v landscape),
  ne čistá preference.

## Návrh

1. **Detekce orientace v `KeyboardViewController`.** Na iPhone landscape je
   `traitCollection.verticalSizeClass == .compact` — to je nejspolehlivější signál pro
   keyboard extension (bounds.width se dá použít jako fallback, ale size class je primární).
   Sledovat v `traitCollectionDidChange(_:)` (+ úvodní set ve `viewDidLayoutSubviews`),
   uložit do nového pole `KeyboardState.isLandscape`.

2. **Effective hodnota na jednom místě.** Přidat na `KeyboardState` computed property, např.:
   ```swift
   /// Number row se v landscape nikdy nezobrazí (málo vertikálního místa), bez ohledu
   /// na uživatelskou preferenci `showNumberRow`. Tohle je hodnota, kterou čtou všichni
   /// spotřebitelé (layout builder i obě výpočty výšky), aby se výška hostu a SwiftUI
   /// obsahu nikdy nerozešly.
   public var effectiveShowsNumberRow: Bool { showNumberRow && !isLandscape }
   ```
   Použít ji v `KeyboardRoot` (místo `state.showNumberRow`) i v `desiredKeyboardHeight()`.
   `KeyboardView.keyboardHeight` zůstane beze změny — čte `layout.showsNumberRow`, do kterého
   `LayoutBuilder` zapíše effective hodnotu automaticky.

3. **`LayoutBuilder` se nemění.** Zůstává pure; dál dostává jen `showNumberRow: Bool`,
   jen mu volající předá effective hodnotu. Komentář na `LayoutBuilder.swift:19` doplnit, že
   „preference“ je teď už effective (po zohlednění landscape).

4. **Rebuild + height update po rotaci.** `traitCollectionDidChange` musí spustit `rebuild()`
   a `updateKeyboardHeightConstraint()`, aby se number row a výška překreslily okamžitě.

## Mimo scope

- **iPad.** iPad je [mimo scope celého projektu](tasks/README.md) — tahle logika cílí výhradně
  na iPhone landscape (compact height). Na iPadu by size-class heuristika stejně neplatila.
- **Změna výšky kláves v landscape.** Tady jen mizí number row; přepočet proporcí kláves /
  landscape-specifické rozměry řešit nebudeme (number row pryč už sám o sobě klávesnici sníží).
- **Nový uživatelský přepínač.** Žádné nové nastavení — chování je implicitní a kopíruje
  nativní iOS. `showNumberRow` v Settings se týká dál jen portrait.

## Testy

- `KeyboardStateTests`: `effectiveShowsNumberRow` = false když `isLandscape == true` (i při
  `showNumberRow == true`); = `showNumberRow` když `isLandscape == false`.
- `LayoutBuilderTests`: žádné nové — builder se nemění, stávající `showNumberRow: false` testy
  pokrývají „bez number row“ tvar layoutu.
- Snapshot v [`KeyboardViewSnapshots`](KeyboardUI/Tests/KeyboardViewSnapshots.swift): landscape
  šířka + layout bez number row, ověřit nižší výšku a chybějící digit řadu.

## Závislosti

Žádné blokující. Staví na existující `showNumberRow` infrastruktuře (task 02 layout model,
task 12 host settings).
