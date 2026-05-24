# 15 — Symbol page parity se SwiftKey (dvě stránky, stejná výška jako letters)

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** High (UX parita se SwiftKey)

## Cíl

Po přepnutí klávesnice na symboly musí mít stránka **stejnou strukturu (počet řádků a tím pádem výšku kláves) jako letter page**, takže klávesy nevyrostou. A musí nabídnout víc znaků — ve Keybo dnes uživatel po `[123]` toggle vidí jen ~15 znaků; SwiftKey/Apple nabízejí ~30+ rozdělených do dvou stránek s `[#+=]` togglem mezi nimi.

V referenčních screenshotech ze SwiftKey:
- Numberrow nahoře (když ho má uživatel zapnutý).
- 2 řádky symbolů.
- 1 řádek interpunkce + `[#+=]` toggle vlevo + delete vpravo.
- Bottom row beze změny.

## Kontext

Aktuální Keybo symbol page (`KeyboardCore/Sources/Logic/LayoutBuilder.swift:makeSymbolRows`):

- Row 2: `- / : ; ( ) $ & @ "`
- Row 3: `[ABC] . , ? ! ' [delete]`

Celkem 2 řádky obsahu + bottom = 3 řádky. Letter page má 3 řádky obsahu (qwerty/asdf/zxcv) + bottom = 4 řádky. Tj. symbol page má **o 1 řádek méně**, takže keyboard height controller distributuje stejnou výšku na méně řádků — symboly jsou vyšší než písmena. Nepříjemné vizuálně.

Druhý chybějící prvek: `[#+=]` toggle a druhá stránka s `_ \ | ~ < > € £ ¥ ·` etc.

## Scope

### 1. Rozšířit `KeyboardPage` o druhou symbol stránku

`KeyboardCore/Sources/Models/KeyboardPage.swift`:

```swift
public enum KeyboardPage: Sendable, Equatable {
    case letters(ShiftState)
    case symbols                // alias pro .symbols(.primary)? Decision below.
    case symbolsAlt              // #+= stránka
}
```

**Decision:** rozšířit `symbols` na `symbols(SymbolPage)` enum kde `SymbolPage` má `.primary` a `.alternate`. Cleaner než dva top-level cases. Pak:

```swift
public enum KeyboardPage: Sendable, Equatable {
    case letters(ShiftState)
    case symbols(SymbolPage)
}

public enum SymbolPage: Sendable, Equatable {
    case primary
    case alternate
}
```

Migration: všechny existing callers `case .symbols` → `case .symbols(.primary)`. Test suite update.

### 2. Layout — Symbol page primary

`LayoutBuilder.makeSymbolRows(_:)` přijímá `SymbolPage`:

**Primary:**
- Row A: `[ ] { } # % ^ * + =` (10 keys, plain `.character` role)
- Row B: `- / : ; ( ) $ & @ "` (10 keys)
- Row C: `[#+=] . , ? ! ' [delete]` (toggle akce `.switchPage(.symbols(.alternate))`, 5 punctuation, delete)

Celkem 3 řádky obsahu + bottom row = 4 řádky (s numberRow nahoře = 5, odpovídá letter page se zapnutým numberRow).

**Alternate:**
- Row A: `_ \ | ~ < > € £ ¥ ·` (10 keys)
- Row B: `± ≠ ≈ ≤ ≥ « » „ " ' ` nebo jiný useful set (10 keys) — finální výběr u implementace
- Row C: `[123] . , ? ! ' [delete]` (toggle akce `.switchPage(.symbols(.primary))`)

### 3. Bottom row toggle

`makeBottomRow(page:)` — pro letters → `123`, pro `symbols(_)` → `ABC`. Beze změny shape, jen extension switch case.

### 4. Layout row counts

S numberRow on:
- Letters: numberRow + 3 content + bottom = **5 řádků**
- Symbols (primary): numberRow + 3 content + bottom = **5 řádků** ✓
- Symbols (alternate): numberRow + 3 content + bottom = **5 řádků** ✓

S numberRow off:
- Letters: 3 content + bottom = **4 řádky**
- Symbols: 3 content + bottom = **4 řádky** ✓

### 5. `ReferenceWeight` na symbol řádcích

Row A (10 keys × 1.0 = 10.0) → no reference weight needed.
Row B (10 keys × 1.0 = 10.0) → no reference weight needed.
Row C (7 keys: 1.5 toggle + 5×1.0 + 1.5 delete = 10.0) → no reference weight needed.

Visuálně se klávesy zarovnají na stejnou per-key width jako letter row 1 a row 3 (které mají též weight 10).

### 6. Unit testy

`LayoutBuilderTests`:

- `testSymbolsPrimary_hasFiveRowsWithNumberRow()`
- `testSymbolsAlternate_hasFiveRowsWithNumberRow()`
- `testSymbolsPrimary_row1HasBracketsAndMath()`
- `testSymbolsPrimary_row2HasPunctuation()`
- `testSymbolsPrimary_row3HasAltToggleAndPunctAndDelete()`
- `testSymbolsAlternate_row3HasPrimaryToggle()`
- `testSwitchPageToggle_fromPrimaryToAlternate()`
- `testSwitchPageToggle_fromAlternateToPrimary()`
- `testLayoutHeight_lettersAndSymbolsHaveEqualRowCount()` — explicit symmetry check

### 7. Snapshot testy

Refresh všech KeyboardView snapshotů (symbol page se zásadně mění):
- `testSymbols_withNumberRow_dark/light` → re-record
- Přidat `testSymbolsAlternate_withNumberRow_dark/light`
- Přidat `testSymbolsPrimary_withoutNumberRow_dark`

### 8. Bottom row toggle label cycling

V `LayoutBuilder.makeBottomRow(page:)` — pro letters → `123`, pro `symbols(_)` → `ABC`. (Ne `123` ↔ `ABC` ↔ něco třetího — `[#+=]` vs `[123]` je v row C, ne v bottom row.)

### 9. `InputDispatcher` test update

`testSwitchPage_toSymbols` → `testSwitchPage_toSymbolsPrimary`. Stejný pattern, jen update na `KeyboardPage.symbols(.primary)`.

## Mimo scope

- Třetí symbol stránka (`#+=` má jen 2 v Apple/SwiftKey). Žádná Keybo `symbols(.thirdPage)`.
- Custom symbol order / user preference. Hard-coded layouts pro v1.0.
- Live preview během switch (animace mezi pages). Instant cut.

## Hotovo když

- Letters i obě symbol stránky mají stejnou výšku kláves (přes stejný počet řádků).
- `[#+=]` toggle na primary symbol page přepne na alternate.
- `[123]` toggle na alternate symbol page přepne zpět na primary.
- `[ABC]` toggle v bottom row na obou symbol stránkách přepne na letters.
- Symbol page 1 nabízí `[ ] { } # % ^ * + =`, `- / : ; ( ) $ & @ "`, punctuation.
- Symbol page 2 nabízí `_ \ | ~ < > € £ ¥ ·`, jiný set, punctuation.
- ~9 nových unit testů + refresh snapshotů green.
- Manuální verify v simulátoru: psaní `(test) [foo]` jde rychle, switching pages je intuitivní.

## Rizika

- **Velký refaktor `KeyboardPage` enum** ovlivní každý matching switch v projektu. `KeyboardCore` a `KeyboardUI` mají ~15 míst kde `case .symbols`. Všechna potřebují update na `.symbols(.primary)` nebo wildcard `case .symbols(_)`.
- **Snapshot drift**: refresh musí být intentional, ne automatický. Vizuálně překontrolovat každý snapshot.
- **Test `testLayoutHeight_lettersAndSymbolsHaveEqualRowCount`**: explicitní invariant, který tento task fixuje a od teď bude regression-guarded.

## Reference

- `KeyboardCore/Sources/Models/KeyboardPage.swift` — enum to extend
- `KeyboardCore/Sources/Logic/LayoutBuilder.swift` — `makeSymbolRows`, `makeBottomRow`
- SwiftKey screenshoty ze user feedbacku (uloženo v image attachments)
- Apple iOS stock keyboard symbol pages — visual reference

## Codex review

**Ano** — netriviální refactor enum case + asymmetry test je dobré druhé oko.
