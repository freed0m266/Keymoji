# 45 — Přepínání QWERTY / QWERTZ layoutu

**Status:** Done — 2026-06-01

**Priorita:** v1.1 · **Úsilí:** S–M · **Dopad:** Medium

## Cíl

Umožnit uživateli zvolit pozici písmen **Y** a **Z** — buď anglický **QWERTY** (default), nebo
středoevropský **QWERTZ** (Y a Z prohozené). Volba žije v Settings, persistuje v `AppGroupStore`
a propisuje se do layoutu klávesnice.

Po dokončení: picker v Settings → Keyboard přepne layout a klávesnice po dalším otevření
(resp. po `refreshFromStore()`) renderuje písmena na nových pozicích.

## Kontext

- Layout je dnes čistě QWERTY, natvrdo v `LayoutBuilder`:
  [`LayoutBuilder.swift:96-98`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:96) —
  `letterRow1 = q w e r t y u i o p`, `letterRow3Letters = z x c v b n m`.
- Jediný rozdíl QWERTZ vs QWERTY je **prohození kláves Y ↔ Z**:
  - QWERTY: row1 `… t y u …`, row3 `z x c v b n m`
  - QWERTZ: row1 `… t z u …`, row3 `y x c v b n m`
- `letterAlternates` je klíčované `Character` ([`LayoutBuilder.swift:79`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:79)),
  takže diakritika (`y → ý ÿ`, `z → ž ź ż`) putuje s písmenem nezávisle na pozici — žádná
  změna v alternates není potřeba.
- Layout je pure funkce inputu — `KeyboardCore.makeLayout(page:showNumberRow:returnKeyType:)`
  ([`KeyboardCore.swift:9`](KeyboardCore/Sources/Public/KeyboardCore.swift:9)). Přidáváme jen
  jeden parametr, žádný stav.
- Settings UI vzor: `appearance` / `spaceDoubleTapAction` picker — string-backed `CaseIterable`
  enum, typed accessor v `AppGroupStore`, `Picker` v `SettingsView`
  ([`SettingsView.swift:85-105`](Features/Settings/Sources/SettingsView.swift:85)).
- **Pozn. k non-goalu „Více jazyků klávesnice"** ([README.md:80](tasks/README.md:80)):
  QWERTZ **není** nový jazyk — písmena jsou totožná (English-only), mění se jen pozice Y/Z.
  Tenhle task tedy non-goal neporušuje. README aktualizovat (viz Scope 7).

## Scope

### 1. `LetterLayout` enum (KeyboardCore)

`KeyboardCore/Sources/Models/LetterLayout.swift`, vzor podle `SpaceDoubleTapAction`:

```swift
import Foundation

/// Positional variant of the alphabetic keys. Differs only in where Y and Z sit —
/// the inserted characters, diacritics, and all other keys are identical.
/// Persisted as a string in `AppGroupStore` under `letterLayout`.
public enum LetterLayout: String, Sendable, CaseIterable {
    /// English layout: `… t y u …` on row 1, `z x c v b n m` on row 3. Default.
    case qwerty
    /// Central-European layout: `… t z u …` on row 1, `y x c v b n m` on row 3.
    case qwertz
}
```

### 2. `LayoutBuilder` — variantní letter rows

`letterRow1` / `letterRow3Letters` přestávají být konstanty a stávají se funkcí `LetterLayout`:

```swift
private static func letterRow1(_ layout: LetterLayout) -> [Character] {
    switch layout {
    case .qwerty: return ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    case .qwertz: return ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"]
    }
}

private static func letterRow3Letters(_ layout: LetterLayout) -> [Character] {
    switch layout {
    case .qwerty: return ["z", "x", "c", "v", "b", "n", "m"]
    case .qwertz: return ["y", "x", "c", "v", "b", "n", "m"]
    }
}
```

`letterLayout` parametr protáhnout:
- `layout(page:showNumberRow:returnKeyType:letterLayout:)` — nový poslední param s defaultem
  `= .qwerty` (zachová binární i source kompatibilitu existujících call sites v previews/testech).
- `makeLetterRows(shift:letterLayout:)` přebírá variantu.
- Volání v `case .letters`, `.emojiSearch` ([`LayoutBuilder.swift:25,36`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:25))
  předají variantu dál. **Emoji search** (`makeLetterRows(shift: .lower)`) má respektovat tutéž
  volbu — uživatel s QWERTZ čeká QWERTZ i při hledání emoji.

> Pozn.: `letter.<lower>` ID kláves ([`LayoutBuilder.swift:128`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:128))
> jsou založené na písmenu, ne na pozici, takže zůstávají stabilní napříč variantami — SwiftUI
> `ForEach` diffne přesun klávesy korektně.

### 3. `KeyboardCore.makeLayout` entrypoint

Přidat `letterLayout: LetterLayout = .qwerty` param a předat do `LayoutBuilder.layout`
([`KeyboardCore.swift:9`](KeyboardCore/Sources/Public/KeyboardCore.swift:9)). Default zachová
existující 30+ call sites v previews a snapshot testech bez úprav.

### 4. `AppGroupStore` + key

- `AppGroupStoreKey` ([`AppGroupStoreKey.swift`](KeymojiCore/Sources/Shared/AppGroupStoreKey.swift)):
  přidat `case letterLayout`.
- Typed accessor, vzor podle `spaceDoubleTapAction`:

```swift
/// Positional layout of the alphabetic keys. Defaults to `.qwerty`. Unknown raw values
/// fall back to the default — defensive against corrupted defaults or future renames.
var letterLayout: LetterLayout {
    get {
        guard let raw = string(forKey: .letterLayout) else { return .qwerty }
        return LetterLayout(rawValue: raw) ?? .qwerty
    }
    set { setString(newValue.rawValue, forKey: .letterLayout) }
}
```

> `LetterLayout` musí být viditelné v `KeymojiCore` (kde žije `AppGroupStore`). Pokud je
> `LetterLayout` v `KeyboardCore`, je potřeba buď accessor přesunout, nebo enum dát do
> `KeymojiCore` a re-exportovat. **Doporučení:** dát `LetterLayout` do `KeymojiCore`
> (`Sources/Shared/`) po vzoru `AppearancePreference` / `SpaceDoubleTapAction`, které tam už
> žijí — `KeyboardCore` na `KeymojiCore` linkuje, takže `LayoutBuilder` k němu má přístup.
> Ověřit, kde přesně `AppearancePreference`/`SpaceDoubleTapAction` leží, a držet konzistenci.

### 5. `KeyboardState` + `KeyboardRoot` + `refreshFromStore`

- `KeyboardState` ([`KeyboardState.swift`](KeyboardCore/Sources/Models/KeyboardState.swift)):
  přidat `public var letterLayout: LetterLayout` (init default `.qwerty`), vedle `showNumberRow`.
- `KeyboardRoot` ([`KeyboardRoot.swift:22`](KeyboardExtension/Sources/KeyboardRoot.swift:22)):
  předat `letterLayout: state.letterLayout` do `makeLayout`.
- `KeyboardViewController.refreshFromStore()`
  ([`KeyboardViewController.swift:156`](KeyboardExtension/Sources/KeyboardViewController.swift:156)):
  číst `store.letterLayout` a aktualizovat `state.letterLayout` stejným diff patternem jako
  `showNumberRow` (`if state.letterLayout != stored { state.letterLayout = stored }`).
  Změna **nemá** vliv na výšku klávesnice, takže žádné `invalidateIntrinsicContentSize`.

### 6. Settings UI

- `SettingsViewModeling` + `SettingsViewModel`: přidat `var letterLayout: LetterLayout { get set }`
  s `didSet { store.letterLayout = letterLayout }` (vzor `appearance`).
- `SettingsViewModelMock`: `public var letterLayout: LetterLayout = .qwerty`.
- `SettingsView` keyboard section ([`SettingsView.swift:74`](Features/Settings/Sources/SettingsView.swift:74)):
  přidat `Picker` (segmented — jen 2 hodnoty), vzor podle appearance pickeru:

```swift
Section {
    Picker(Texts.Keyboard.letterLayout, selection: $viewModel.letterLayout) {
        ForEach(LetterLayout.allCases, id: \.self) { layout in
            Text(label(for: layout)).tag(layout)
        }
    }
    .pickerStyle(.segmented)
} footer: {
    Text(Texts.Keyboard.letterLayoutFooter)
}
```

`label(for:)` helper: `.qwerty → "QWERTY"`, `.qwertz → "QWERTZ"` (značkové názvy, nelokalizují se,
ale jdou přes `L10n` kvůli konzistenci — viz lokalizace níže).

### 7. Lokalizace + README

- `KeymojiResources/.../Localizable.strings`:

```strings
"settings.keyboard.letterLayout" = "Letter layout";
"settings.keyboard.letterLayout.qwerty" = "QWERTY";
"settings.keyboard.letterLayout.qwertz" = "QWERTZ";
"settings.keyboard.letterLayoutFooter" = "QWERTZ swaps the Y and Z keys, matching Central-European keyboards.";
```

  + odpovídající `L10n.Settings.Keyboard.*` accessory (dle generátoru, který projekt používá).
- README non-goal „Více jazyků klávesnice" ([README.md:80](tasks/README.md:80)) doplnit o větu,
  že **positional QWERTY/QWERTZ varianta je v scope** (task 45) a nepočítá se jako další jazyk —
  písmena zůstávají English-only, mění se jen pozice Y/Z.

### 8. Testy

**`LayoutBuilderTests` (KeyboardCore):**
- QWERTZ letters lower: row1 obsahuje `z` na indexu 5 (mezi `t` a `u`), `y` **není** v row1.
- QWERTZ letters lower: row3 letters začínají `y` (po shift klávese), `z` **není** v row3.
- QWERTY default (bez explicitního param) = původní pořadí — regression guard.
- QWERTZ upper/capsLock: prohozené pozice + uppercase (`Z` v row1, `Y` v row3).
- Alternates beze změny: `y` klávesa má alternates `ý ÿ`, `z` klávesa `ž ź ż` v obou variantách.
- Equality/idempotence: dva calls se stejným `letterLayout` vrátí equal layout.

**Snapshot testy (KeyboardUI):** přidat 1–2 snapshoty QWERTZ letters lower (dark) do
`KeyboardViewSnapshots.swift` — vizuální důkaz, že Y/Z sedí na nových pozicích.

**Settings snapshot:** keyboard section nově obsahuje letter-layout picker → re-record dotčených
`SettingsSnapshots` referencí (`fbsnapshot`/`AssertSnapshot` record run).

## Mimo scope

- **Další jazykové layouty** (AZERTY, Dvorak, cyrilice, …) — pořád out of scope. Jen QWERTY/QWERTZ.
- **Plný hardware QWERTZ** (odlišná interpunkce, `ß`, dead keys) — ne. Měníme **jen pozice Y/Z**,
  zbytek (interpunkce, symboly, diakritika přes long-press) zůstává identický.
- **Per-app layout** — globální volba, ne per-textfield.
- **Animace přesunu kláves** při přepnutí — layout se přebuduje při dalším `refreshFromStore()`,
  žádná in-place animace prohození.

## Hotovo když

- `LetterLayout` enum existuje, `makeLayout` přijímá `letterLayout` param (default `.qwerty`).
- QWERTZ renderuje `z` mezi `t`/`u` na row1 a `y` jako první písmeno row3; QWERTY beze změny.
- Diakritika Y/Z funguje v obou variantách (long-press popover).
- Volba persistuje v `AppGroupStore.letterLayout` a přežije restart appky/klávesnice.
- Settings picker přepne layout; klávesnice po re-open / `refreshFromStore()` respektuje volbu.
- Emoji search QWERTY layout respektuje stejnou volbu.
- `LayoutBuilderTests` pokrývají obě varianty, všechny green.
- QWERTZ snapshot(y) + re-recorded Settings snapshoty green.
- `tuist build` projde; existující call sites (default param) se nemusely měnit.

## Rizika

- **Umístění `LetterLayout` enumu** (KeymojiCore vs KeyboardCore) — accessor v `AppGroupStore`
  i `LayoutBuilder` ho oba musí vidět. Vyřešit dle toho, kde leží `AppearancePreference` /
  `SpaceDoubleTapAction` (Scope 4 pozn.). Špatná volba = circular/ chybějící import.
- **Stabilita key ID** — `letter.<lower>` ID jsou per-písmeno, ne per-pozice, takže přesun je
  pro SwiftUI jen reorder, ne nové klávesy. Ověřit, že popover/haptika/highlight nadále fungují
  po přesunu (žádný hardcoded „y je vždy v row1" předpoklad nikde dál v UI vrstvě).
- **Snapshot drift** — přidání pickeru do keyboard section posune Settings layout → očekávaný
  re-record, ne bug. Zkontrolovat diff vizuálně před commitem.

## Reference

- [02 — Layout model](02-layout-model.md) — původní QWERTY rozhodnutí a row model.
- [12 — Host app Settings](12-host-app-settings.md) — Settings VM/View/picker vzor.
- `SpaceDoubleTapAction` / `AppearancePreference` — vzor string-backed enum + accessor + picker.

## Codex review

**Ano** — dotýká se pure layout logiky (dobře testovatelné) i cross-process persistence.
Spustit `codex review --uncommitted` před closing commitem, primárně na umístění enumu
a na regresní pokrytí QWERTY defaultu.
