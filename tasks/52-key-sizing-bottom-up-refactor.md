# 52 — Refaktor výšky a šířky kláves: model „zdola nahoru" + jedna konstanta

**Status:** Done — 2026-06-07

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** High

## Cíl

Přepsat výpočet rozměrů kláves tak, aby **výška každé klávesy byla pevná a řízená jednou konstantou**,
ne aby plavala podle toho, kolik místa zbylo. Dnes je model **„shora dolů"**: celková výška klávesnice
je zafixovaná (`260` / `216` + `51` za suggestion bar) a `VStack` zbylou výšku **rozpouští** mezi řádky
kláves. Důsledek — klávesy mají různou výšku podle stránky:

- Na **písmenech** je suggestion bar (+51 pt), takže 4 řádky kláves dostanou míň místa → klávesy nižší.
- Na **symbolech** bar není → klávesy vyšší.
- Rozdíl je ~2–3 pt, ale je vidět a vadí.

Cíl je **„zdola nahoru"**: definovat výšku viditelné klávesy konstantou, dát ji každému `KeyView`
napevno, a **celkovou výšku klávesnice z toho odvodit** (součet výšek řádků + bar + mezery). Klávesy pak
mají **vždy stejnou výšku** bez ohledu na stránku nebo přítomnost baru.

Zároveň opravit **drobný rozdíl šířky** písmen mezi řádkem 2 (`asdfghjkl`) a řádkem 3 (`zxcvbnm`).

> **Probliknutí na max výšku při přepínání klávesnic** (Keymoji ↔ nativní) je **samostatný task
> [53](53-keyboard-switch-height-flash.md)** — sem nepatří, i když se dotýká stejného height constraintu.

## Kontext

### Současný stav výšky (rozkolísaný)

- **`KeyView`** ([KeyView.swift:108-127](KeyboardUI/Sources/Views/KeyView.swift:108)) — viditelný cap je
  `ZStack` s `RoundedRectangle`, pak `.padding(.vertical, 6)` (mezera mezi řádky), pak
  `.frame(minHeight: 48)`. **Žádná pevná výška** — jen minimum. Vertikální padding je **uvnitř** hit-area
  (`.background(Color…)` + `.contentShape` jsou až za paddingem → kliknutí do mezery mezi řádky propadne
  na klávesu, task [42](42-inter-key-gap-hit-areas.md) — **toto chování zachovat**).
- **`KeyboardView.defaultKeyboard`** ([KeyboardView.swift:216-233](KeyboardUI/Sources/Views/KeyboardView.swift:216))
  — `ForEach(visibleRows)` v `VStack(spacing: 0)`; každý řádek `.frame(maxHeight: row.isNumberRow ? 48 : nil)`.
  Number row je tedy capnutá na 48, ostatní řádky plavou (`nil`) a roztáhnou se na zbytek.
- **`KeyboardView.keyboardHeight`** ([KeyboardView.swift:254-268](KeyboardUI/Sources/Views/KeyboardView.swift:254))
  — magická čísla `260` / `216`, `+ suggestionBarFootprint (51)`, `+ emojiSearchChromeHeight`.
- **`KeyboardViewController`** drží **DUPLIKÁT** týchž čísel:
  `regularHeightWithNumberRow = 260`, `regularHeightWithoutNumberRow = 216`,
  `emojiSearchChromeFootprint = 97`, `suggestionBarFootprint` (čte z `KeyboardView`)
  ([KeyboardViewController.swift:386-420](KeyboardExtension/Sources/KeyboardViewController.swift:386)).
  Host input view height constraint a SwiftUI frame se **musí ručně držet v synchronu** — když se
  rozejdou, obsah se ořízne (komentář o chybějícím search baru u `.emojiSearch`).

### Současný stav šířky (řádek 2 vs řádek 3)

- **Šířka se počítá vahami** v [`KeyRowView`](KeyboardUI/Sources/Views/KeyRowView.swift): `unitWidth =
  totalWidth / actualTotalWeight`, `width(for:) = unitWidth × visualWeight`. `referenceWeight` přidává
  symetrický inset, když je deklarovaná váha vyšší než součet ([KeyRowView.swift:57-95](KeyboardUI/Sources/Views/KeyRowView.swift:57)).
- **Řádek 2** (`asdfghjkl`): 9 kláves, `referenceWeight: 10` → každá klávesa `= W/10`
  ([LayoutBuilder.swift:125-129](KeyboardCore/Sources/Logic/LayoutBuilder.swift:125)).
- **Řádek 3** (`shift + zxcvbnm + delete`): `shift(1.5)` + `0.3 mezera` + `7×1.0` + `0.3 mezera` +
  `delete(1.5)` = **10.6** váhových jednotek → písmeno `= W/10.6` (≈ 5,7 % užší než řádek 2)
  ([LayoutBuilder.swift:130-136](KeyboardCore/Sources/Logic/LayoutBuilder.swift:130)). Mezery
  (`symbolEdgeGapWeight = 0.3`) jsou převzaté ze symbolového řádku C.
- Prior art: task [14](14-equal-letter-key-widths.md) (`referenceWeight` na ASDF řádku) a
  [15](15-symbol-page-parity.md) (symbol parita) — tenhle task na ně navazuje.

### Co je mimo (KeyView-derived vs special)

Konstanta výšky řídí **jen klávesy vykreslené přes `KeyView`** v řádcích: písmena, symboly, číslice
a **spodní řádek** (space, return, `123`/`ABC`, emoji přepínač, tečka). **Mimo** je `EmojiPanelView`
(emoji panel se roztahuje) a chrome emoji hledání — ty si výšku počítají vlastně.

## Rozhodnutí z grill-me session (zafixovaná)

1. **Model zdola nahoru** — výška klávesy pevná, total = součet. (Ne ladit starý top-down model.)
2. **Jediný zdroj pravdy = enum v `KeyboardCore`** (`KeyboardMetrics`), sdílí ho `KeyboardView`
   (SwiftUI render) i `KeyboardViewController` (host height constraint). Duplicita `260`/`216`/`51`/`97`
   **zmizí nadobro**.
3. **Total výška se mezi stránkami mění** (přijato) — symboly zůstanou nižší o výšku baru, jako dnes
   (311 vs 260). Klávesnice se při `123`/`ABC` o ten kus zvětší/zmenší. **Nepřidávat** prázdný pruh na
   symboly kvůli konstantní total výšce.
4. **Šířka řádku 3** — mezery `0.3` **ponechat**, ale **snížit váhu shift/delete** tak, aby total = 10:
   `1.2 + 0.3(gap) + 7×1.0 + 0.3(gap) + 1.2 = 10.0` → písmeno `= W/10`, zarovnané s řádky 1/2,
   shift/delete o kus užší. (Ne rušit mezery, ne pinovat šířku přes přepis layout-mathu.)
5. **Rozsah `keyCapHeight`** — letter + symbol + **bottom** řádky. Number row dostane **vlastní menší
   konstantu**. Spodní řádek sdílí `keyCapHeight` s písmeny (jako stock).
6. **Význam konstanty** — `keyCapHeight` = **výška viditelného capu** (barevný obdélník), `rowGap` =
   **svislá mezera mezi řádky** (zvlášť). Slot řádku = `cap + rowGap`. Uživatel ladí přímo to, co vidí.
7. **Výchozí hodnoty** — **zachovat dnešní vzhled** (slot písmen ~54 pt, number ~48 pt); pak doladit
   jednou konstantou na zařízení.

## Scope

### 1. `KeyboardMetrics` — jediný zdroj pravdy (KeyboardCore)

Nový public enum (vedle `LayoutBuilder` v `KeyboardCore/Sources/Logic/`). Hodnoty jsou **startovní**,
laděné na zařízení — cíl je vizuálně shodné s dneškem:

```swift
import CoreGraphics

/// Single source of truth for keyboard key/row dimensions. Consumed by `KeyboardView` (SwiftUI render)
/// AND `KeyboardViewController` (host input-view height constraint) so the two never disagree.
///
/// Model is bottom-up: cap heights are fixed; total keyboard height is *derived* from them. Tune
/// `keyCapHeight` (and `numberRowCapHeight`) to resize keys — everything else follows.
public enum KeyboardMetrics {
    /// Visible cap height of a standard key (letters, symbols, bottom row). THE knob to tune key height.
    public static let keyCapHeight: CGFloat = 42
    /// Visible cap height of a number-row key — intentionally a touch shorter than `keyCapHeight`.
    public static let numberRowCapHeight: CGFloat = 36
    /// Vertical gap between rows. Applied as `rowGap/2` padding top+bottom inside each `KeyView`, so the
    /// gap stays inside the key's hit area (task 42). Row slot height = cap + rowGap.
    public static let rowGap: CGFloat = 12

    /// Suggestion bar's own height (the chips/favorites strip).
    public static let suggestionBarHeight: CGFloat = 40
    /// Gap below the suggestion bar, above the first key row.
    public static let suggestionBarGap: CGFloat = 11   // 40 + 11 = dnešní footprint 51

    /// Horizontal padding on the keyboard VStack (mimo emoji panel).
    public static let horizontalPadding: CGFloat = 3

    // MARK: - Derived

    /// Slot height (cap + gap) for a row, picking the number-row cap when `isNumberRow`.
    public static func rowSlotHeight(isNumberRow: Bool) -> CGFloat {
        (isNumberRow ? numberRowCapHeight : keyCapHeight) + rowGap
    }

    /// Total host/input-view height for a built layout. SINGLE place that computes it — both the SwiftUI
    /// frame and the UIInputView height constraint call this, so they can't drift.
    public static func keyboardHeight(for layout: KeyboardLayout, showsSuggestionBar: Bool) -> CGFloat {
        let rows = layout.rows.reduce(0) { $0 + rowSlotHeight(isNumberRow: $1.isNumberRow) }
        let bar = showsSuggestionBar ? (suggestionBarHeight + suggestionBarGap) : 0
        let chrome = layout.page.isEmojiSearch ? emojiSearchChromeHeight : 0
        return rows + bar + chrome
    }

    /// Emoji-search chrome (search bar + results bar + intra-row gap) stacked above the QWERTY rows.
    public static let emojiSearchChromeHeight: CGFloat = 86   // 32 + 44 + 4 + 6 (dnešní rozpad)
}
```

> **`keyboardHeight(for:)` bere `KeyboardLayout`** (má `rows` + `page`), takže počet řádků nemusí nikdo
> hardcodovat — sečte se z reálných řádků. To zabíjí magická `260`/`216` a dělá výpočet robustní vůči
> změně počtu řádků na stránce.
>
> **Emoji panel** (`page == .emojis`) má v `layout.rows` jen bottom row (panel se vykresluje mimo `rows`).
> Aby panel dostal rozumnou výšku, vrátit pro emoji stránku **stejnou výšku jako písmena-bez-baru** —
> buď speciální větev v `keyboardHeight`, nebo nech `EmojiPanelView` vyplnit zbytek a měř total proti
> dnešnímu vzhledu. Ověřit, že emoji panel nezmění velikost (regrese).

### 2. `KeyView` — pevná výška capu (KeyboardUI)

- Přidat parametr `capHeight: CGFloat` (default kvůli previews/snapshotům, např. `KeyboardMetrics.keyCapHeight`).
- Nahradit `.frame(minHeight: 48)` → cap vykreslit na **přesně `capHeight`**, vertikální padding =
  `KeyboardMetrics.rowGap / 2` (místo natvrdo `6`), celkový slot = `capHeight + rowGap`. Padding zůstává
  **před** `.background`/`.contentShape`, aby mezera dál patřila do hit-area (task 42 — neporušit).

```swift
// schéma (ne doslovně):
ZStack { /* cap */ }
    .frame(height: capHeight)                 // ← pevná výška viditelného capu
    .padding(.horizontal, 3)
    .padding(.vertical, KeyboardMetrics.rowGap / 2)
    .padding(.leading, leadingGapWidth)
    .padding(.trailing, trailingGapWidth)
    // hit-area: background + contentShape AŽ TADY (zachovat pořadí kvůli task 42)
```

- Preview helper `KeyViewPreview` ([:553](KeyboardUI/Sources/Views/KeyView.swift:553)) — `.frame(height: 44)`
  nahradit slotem z metrik.

### 3. `KeyRowView` — předat správnou výšku (KeyboardUI)

- Spočítat `capHeight` pro řádek: `row.isNumberRow ? KeyboardMetrics.numberRowCapHeight :
  KeyboardMetrics.keyCapHeight` a předat do každého `KeyView`.

### 4. `KeyboardView` — odvodit total z metrik (KeyboardUI)

- `keyboardHeight` ([:254-281](KeyboardUI/Sources/Views/KeyboardView.swift:254)) zahodit magická čísla →
  `KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: effectiveShowsBar)`.
- `defaultKeyboard` ([:231](KeyboardUI/Sources/Views/KeyboardView.swift:231)) — zrušit
  `.frame(maxHeight: row.isNumberRow ? 48 : nil)`; výšku teď nese `KeyView` capem. Řádky se už
  neroztahují — `VStack` má jen součet slotů, takže žádné plavání.
- `horizontalPadding` ([:79](KeyboardUI/Sources/Views/KeyboardView.swift:79)) a `suggestionBarFootprint`
  ([:249](KeyboardUI/Sources/Views/KeyboardView.swift:249)) → přesunout do `KeyboardMetrics` (footprint =
  `suggestionBarHeight + suggestionBarGap`).
- `SuggestionBarView` výška `barHeight = 40` ([SuggestionBarView.swift:33](KeyboardUI/Sources/Views/SuggestionBarView.swift:33))
  → číst `KeyboardMetrics.suggestionBarHeight`.

### 5. `KeyboardViewController` — host constraint z metrik (KeyboardExtension)

- Smazat `regularHeightWithNumberRow`, `regularHeightWithoutNumberRow`, `emojiSearchChromeFootprint`
  ([:386-390](KeyboardExtension/Sources/KeyboardViewController.swift:386)).
- `desiredKeyboardHeight()` ([:411-420](KeyboardExtension/Sources/KeyboardViewController.swift:411)) →
  postavit `KeyboardLayout` ze současného `state` (přes `LayoutBuilder.layout(...)`, stejné parametry
  jako `makeRoot`) a vrátit `KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: showsSuggestionBar)`.
  Tím host input view a SwiftUI frame **počítají z jednoho vzorce** → nemůžou se rozejít.

### 6. Šířka řádku 3 — vyrovnat písmena (KeyboardCore)

V [`makeLetterRows`](KeyboardCore/Sources/Logic/LayoutBuilder.swift:118) dát shift/delete na **řádku
písmen** užší váhu, aby total = 10 i s mezerami `0.3`:

```swift
// jen pro letter row 3 — shift/delete = 1.2 (ne .wide 1.5), aby:
// 1.2 + 0.3(gap) + 7×1.0 + 0.3(gap) + 1.2 = 10.0 → písmeno = W/10, zarovnané s řádky 1 a 2.
private static let letterRowEdgeKeyWeight = KeyWeight(1.2)
```

- Pozor: `.wide` (1.5) zůstává na **symbolovém** řádku C (toggle/delete) i na shift/delete jinde — nový
  weight použít **jen** na letter row 3. Symbolový řádek C (`1.5 + 0.3 + 5×1.5 + 0.3 + 1.5 = 11.1`) se
  **nemění** — nemá se s ničím zarovnávat.
- Ověřit, že popover alignment math ([KeyRowView.swift:68-88](KeyboardUI/Sources/Views/KeyRowView.swift:68))
  s novou vahou pořád trefuje správné klávesy (počítá z `unitWidth × váhy`, takže by mělo sednout samo).

### 7. Testy + snapshoty

- **`KeyboardMetrics`** (KeyboardCore tests): `rowSlotHeight` pro number vs ne-number; `keyboardHeight`
  pro letters+bar / letters+number / symbols / emojiSearch vrací očekávané součty; změna `keyCapHeight`
  proporčně mění total.
- **Šířka řádku 3** — pokud existuje test šířek (task 14), přidat assert, že písmeno v řádku 3 `= W/10`
  (shodné s řádkem 2) na dané `totalWidth`.
- **Re-record celé KeyboardUI snapshot sady** — výšky kláves se sjednotí (letters/symbols teď stejné),
  šířka řádku 3 se srovná. Drift je **očekávaný, ne bug** — projít diffy vizuálně, ověřit že:
  - písmena a symboly mají **stejně vysoké** klávesy,
  - number row je **mírně nižší**,
  - řádek 3 písmen je **stejně široký** jako řádek 2,
  - emoji panel a emoji search vypadají jako dřív.

## Mimo scope

- **Probliknutí na max výšku při přepnutí klávesnice** → samostatný task [53](53-keyboard-switch-height-flash.md).
- **Konstantní total výška napříč stránkami** (prázdný pruh na symbolech) — vědomě odmítnuto, total se
  smí měnit o výšku baru.
- **Změna vzhledu / proporcí** oproti dnešku — cíl je *sjednotit*, ne redesignovat. Ladění jedné
  konstanty pro nový look je až follow-up.
- **Emoji panel / emoji search rozměry** — řídí se vlastní logikou; tenhle task je jen napojí na sdílené
  metriky tam, kde už dnes čísla má, beze změny vzhledu.
- **iPad / landscape** — pořád iPhone portrait only.

## Hotovo když

- Existuje **`KeyboardMetrics.keyCapHeight`** — jediná konstanta, kterou změním výšku **všech** kláves
  z `KeyView` (písmena, symboly, spodní řádek), a **`numberRowCapHeight`** zvlášť pro číslice.
- **Klávesy mají stejnou výšku** na písmenech i symbolech (nezávisle na suggestion baru).
- **Number row je mírně nižší** než ostatní řádky, podle své konstanty.
- **Písmena v řádku 3** (`zxcvbnm`) jsou **stejně široká** jako v řádku 2 (`asdfghjkl`) = `W/10`.
- Magická čísla `260` / `216` / `51` / `97` **neexistují duplicitně** — host constraint i SwiftUI frame
  počítají z `KeyboardMetrics.keyboardHeight(for:showsSuggestionBar:)`.
- Mezera mezi řádky pořád patří do hit-area klávesy (task 42 neporušen).
- Emoji panel a emoji search vypadají a fungují jako dřív.
- Nové unit testy green; re-recorded snapshoty green a vizuálně ověřené.

## Rizika

- **Hit-area mezery (task 42).** Vertikální padding musí zůstat **před** `.background`/`.contentShape`,
  jinak kliknutí do mezery mezi řádky propadne. Snadno se rozbije při přepisu `KeyView` frame.
- **Drift host vs SwiftUI.** Pokud `desiredKeyboardHeight()` a `KeyboardView.keyboardHeight` nezačnou
  volat **tutéž** funkci, vrátí se původní bug (ořezaný obsah / mezera). Oba **musí** jít přes `KeyboardMetrics`.
- **Emoji stránka nemá klávesové řádky** v `layout.rows` (jen bottom row) → `keyboardHeight` ji spočítá
  moc nízko, pokud se nedá speciální větev. Ověřit emoji panel výšku proti dnešku.
- **`.wide` weight sdílený.** Snížení shift/delete na 1.2 se nesmí protáhnout do symbolového řádku C ani
  jinam — použít dedikovaný weight jen na letter row 3.
- **Snapshot drift je rozsáhlý** (mění se skoro každý keyboard snapshot). Re-record po jednom, diffy
  číst pozorně — odlišit zamýšlené sjednocení od náhodné regrese.
- **Startovní hodnoty.** `42 / 36 / 12` jsou odhad „zachovat dnešek"; nejdřív změřit reálné dnešní výšky
  (letters slot vs number slot) a hodnoty doladit, ať není při releasu vidět skok.

## Reference

- [14 — Stejná šířka kláves v ASDF řádku](14-equal-letter-key-widths.md) — vznik `referenceWeight`.
- [15 — Symbol page parity (stejná výška)](15-symbol-page-parity.md) — symbolové řádky.
- [35 — Redesign: vizuální parita s nativní klávesnicí](35-keyboard-native-look-redesign.md) — current look.
- [42 — Kliknutí do mezery mezi klávesami nesmí propadnout](42-inter-key-gap-hit-areas.md) — hit-area
  mezer, **neporušit**.
- [53 — Probliknutí na max výšku při přepnutí klávesnice](53-keyboard-switch-height-flash.md) — navazující
  samostatný task na stejném height constraintu.
