# 02 — Layout model (KeyboardCore)

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** Blokující

## Cíl

Definovat datový model klávesnicového layoutu — co je klávesa, co je řádek, co je stránka, jak se z konfigurace (`showNumberRow: Bool`) skládá konkrétní zobrazený layout. Žádné SwiftUI views, žádný input handling. Jen pure data structures + factory funkce + unit testy.

Po dokončení tohoto tasku jde z `KeyboardCore` zavolat funkci `letterPage(shift: .lower, showNumberRow: true)` a dostat zpět strukturu, kterou by view layer renderoval — kdyby existoval.

## Kontext

- Topologie projektu: `KeyboardCore` je pure-Swift framework bez SwiftUI. UI je v `KeyboardUI` (task 03) a používá `KeyboardCore` jako vstup.
- Layout pages v v1.0: **letters** (lower/upper/caps) + **symbols**. Žádná `#+=` třetí stránka (rozhodnuto v grilling Q5).
- Bottom row: `[123/ABC] [🌐] [   space   ] [.] [return]` na všech stránkách identický.
- Number row vždy nahoře, **toggleable**: `showNumberRow: Bool` parametr na top-level layout factory.
- Long-press symboly na číslech: `1 → !`, `2 → @`, ..., `0 → )`. Long-press accents na písmenech: implementuje se až v tasku 07, ale **model dat pro alternates už tady**.

## Scope

### 1. Klávesa — model

`KeyboardCore/Sources/Models/Key.swift`:

```swift
public struct Key: Identifiable, Sendable, Equatable {
    public let id: String                   // stable ID pro SwiftUI ForEach, např. "letter.a"
    public let primary: KeyContent          // co se vloží/zobrazí při tapu
    public let alternates: [KeyContent]     // long-press popover candidates (může být prázdné)
    public let action: KeyAction            // co tap udělá
    public let visualWeight: KeyWeight      // pro layout — letter = 1.0, shift = 1.5, space = 4.0, ...
    public let role: KeyRole                // .character / .system (.shift, .delete, .return, ...)
}
```

`KeyContent`:

```swift
public enum KeyContent: Sendable, Equatable {
    case text(String)                       // např. "a", "á", "!"
    case symbol(SystemSymbol)               // SF Symbol pro system keys — .shift, .delete, .return, .globe
}
```

`KeyAction`:

```swift
public enum KeyAction: Sendable, Equatable {
    case insertText(String)
    case backspace
    case shift
    case capsLockToggle                     // double-tap shift
    case nextKeyboard                       // globe
    case `return`
    case space
    case dismissKeyboard                    // (Future, ne v v1.0 — ale model už ano)
    case switchPage(KeyboardPage)           // 123/ABC toggle
}
```

`KeyRole`:

```swift
public enum KeyRole: Sendable {
    case character          // písmeno / číslo / symbol — vkládá text
    case system             // shift, delete, return, space, globe, 123-toggle, .
}
```

`KeyWeight`:

```swift
public struct KeyWeight: Sendable, Equatable {
    public let value: Double                // multiplier vůči base unit (1.0 = standardní písmeno)

    public static let standard = KeyWeight(value: 1.0)
    public static let wide = KeyWeight(value: 1.5)            // shift, delete
    public static let space = KeyWeight(value: 4.0)
    public static let small = KeyWeight(value: 1.25)          // 123, globe
    public static let dotKey = KeyWeight(value: 1.0)
    public static let returnKey = KeyWeight(value: 1.75)
}
```

### 2. Řádek a stránka — model

`KeyboardCore/Sources/Models/KeyboardRow.swift`:

```swift
public struct KeyboardRow: Sendable, Equatable {
    public let keys: [Key]
    public let id: String                   // např. "letter.row.2"
}
```

`KeyboardCore/Sources/Models/KeyboardPage.swift`:

```swift
public enum KeyboardPage: Sendable, Equatable {
    case letters(ShiftState)
    case symbols
}

public enum ShiftState: Sendable, Equatable {
    case lower
    case upper          // jednorázový upper
    case capsLock
}
```

`KeyboardCore/Sources/Models/KeyboardLayout.swift`:

```swift
public struct KeyboardLayout: Sendable, Equatable {
    public let page: KeyboardPage
    public let rows: [KeyboardRow]          // vč. number row pokud showNumberRow == true
    public let showsNumberRow: Bool
}
```

### 3. Factory — sestavení layoutu

`KeyboardCore/Sources/Logic/LayoutBuilder.swift`:

```swift
public enum LayoutBuilder {
    public static func layout(
        page: KeyboardPage,
        showNumberRow: Bool,
        returnKeyType: ReturnKeyType = .default
    ) -> KeyboardLayout
}
```

`ReturnKeyType` v `KeyboardCore` (mirror `UIReturnKeyType`, ale Sendable, žádný UIKit dep):

```swift
public enum ReturnKeyType: Sendable, Equatable {
    case `default`, go, google, join, next, route, search, send, done, emergencyCall, `continue`, yahoo
}
```

Konkrétní obsah řádků (písemne — odpovídá Apple US QWERTY):

**Number row** (jen pokud `showNumberRow == true`):

| primary | alternates (long-press) |
|---|---|
| 1 | ! |
| 2 | @ |
| 3 | # |
| 4 | $ |
| 5 | % |
| 6 | ^ |
| 7 | & |
| 8 | * |
| 9 | ( |
| 0 | ) |

**Letters page — lower (3 řádky pod number row):**

```
q w e r t y u i o p
a s d f g h j k l
[shift]  z x c v b n m  [delete]
```

Long-press alternates pro letters (vždy stejné pro lower i upper, popover pak respektuje shift):

| letter | alternates |
|---|---|
| a | á à â ä ã å ā æ |
| c | č ç ć ĉ |
| d | ď |
| e | é ě è ê ë ē ė ę |
| i | í ì î ï ī į |
| l | ł |
| n | ñ ň |
| o | ó ò ô ö õ ø ō œ |
| r | ř |
| s | š ś ŝ |
| t | ť |
| u | ú ù û ü ū ů |
| y | ý ÿ |
| z | ž ź ż |

Diakritická mapování pokrývají českou + běžné západoevropské jazyky. Pořadí v alternates: nejdřív česká diakritika, pak ostatní (aby v UI byla česká hned napravo od základního písmene).

**Letters page — upper / capsLock:** stejný layout, písmena jako uppercase. Alternates respective uppercase (`a → Á À Â Ä Ã Å Ā Æ`). Auto-uppercasing alternates je čistá `String.uppercased(with: Locale(identifier: "en_US_POSIX"))` operace nad textovým obsahem v `KeyContent.text`.

**Symbols page (3 řádky pod number row):**

```
- / : ; ( ) $ & @ "
. , ? ! ' [empty - shift slot je hidden / disabled, nebo místo něj #+=?]
[123→ABC]  z x c v b n m  [delete]
```

Tady se ale crashujeme do designové neshody: na symbol page nemá smysl mít písmena `z x c v b n m` (jsou tam jen pro vizuální stabilitu shift-row na letter page). Apple symbol page má místo nich symboly:

**Skutečný layout symbols page v1.0:**

```
1 2 3 4 5 6 7 8 9 0      ← number row (vždy)
- / : ; ( ) $ & @ "      ← row 2
. , ? ! '                ← row 3 (kratší)
[ABC] [🌐] [space] [.] [return]   ← bottom row
```

Row 3 má méně kláves; layout je nevyvážený. Apple to řeší tak, že row 3 má i `#+=` toggle a `delete`:

```
[#+=]  . , ? ! '  [delete]
```

Pro Keybo bez `#+=` třetí stránky to bude:

```
[ABC]  . , ? ! '  [delete]
```

Tj. `[ABC]` je vlevo místo `[#+=]`, plní funkci „přepni zpět na písmena". Delete je vpravo. Mezi nimi pět symbolů s mírně menší šířkou.

**Bottom row (identický pro letters i symbols):**

```
[123/ABC] [🌐] [          space          ] [.] [return]
```

- `[123/ABC]`: tap = switchPage. Label je `"123"` na letter page, `"ABC"` na symbol page.
- `[🌐]`: tap = `advanceToNextInputMode()`, long-press v iOS otevírá keyboard picker (system handled).
- `[space]`: tap = insertText(" ").
- `[.]`: dedicated dot — tap = insertText(".").
- `[return]`: tap = newline / přesměrovat dle returnKeyType. Label se mění v UI vrstvě podle `ReturnKeyType`.

### 4. Veřejné API entrypointy

`KeyboardCore/Sources/Public/KeyboardCore.swift`:

```swift
public enum KeyboardCore {
    public static func makeLayout(
        page: KeyboardPage,
        showNumberRow: Bool,
        returnKeyType: ReturnKeyType
    ) -> KeyboardLayout {
        LayoutBuilder.layout(page: page, showNumberRow: showNumberRow, returnKeyType: returnKeyType)
    }
}
```

Vstup pro UI vrstvu je tento jeden statický call. Žádný stav v `KeyboardCore` API nedržíme — layout je čistá funkce inputu.

### 5. Unit testy

`KeyboardCore/Tests/LayoutBuilderTests.swift` — pokrýt:

- **Letters page lower:**
  - Počet rows = 4 (s number row) nebo 3 (bez).
  - Row 1 (number row) má 10 kláves, primary `0..9`, alternates `!@#$%^&*()`.
  - Row 2 má 10 kláves: q w e r t y u i o p.
  - Row 3 má 9 kláves: a s d f g h j k l.
  - Row 4 má 9 kláves: shift + zxcvbnm + delete.
  - Row 5 (bottom) má 5 kláves: 123, globe, space, dot, return.
  - Všechny letter keys mají `KeyRole.character`.
  - Shift má `KeyAction.shift`. Delete má `.backspace`. Atd. — assert každá system key.
- **Letters page upper:** primary letters jsou uppercase, alternates jsou uppercase.
- **Letters page capsLock:** stejné jako upper.
- **Symbols page:**
  - Row 1 = number row (stejný jako u letters).
  - Row 2 obsahuje `- / : ; ( ) $ & @ "` v tomto pořadí.
  - Row 3 obsahuje `[ABC]  . , ? ! '  [delete]` v tomto pořadí.
  - Row 4 (bottom) identický s letters.
- **`showNumberRow: false`:**
  - Počet rows o 1 menší pro obě stránky.
  - První row (po vyloučení number row) je správně letters/symbols row 2.
- **`ReturnKeyType` se propaguje do return key:** layout obsahuje return key s odpovídající `KeyContent`. Konkrétní label rendering je v UI vrstvě, ale model musí umět ReturnKeyType uložit. Doplnit pole `returnKeyType: ReturnKeyType` do `KeyboardLayout` nebo do return key samotného (preferuju to mít na `KeyboardLayout` jako kontext, view pak při renderu return key vybere správný label).
- **Idempotence/equality:** dva calls se stejnými parametry vrátí stejný `KeyboardLayout` (Equatable conformance funguje).

Cílem je ~20 testů. Každý jednotlivý test < 10 řádků. Use `XCTAssertEqual` na primitive properties, ne na celé struktury (lépe lokalizovaný failure message).

### 6. Logging

`KeyboardCore` linkuje `KeyboCore` který bringe SwiftyBeaver. **Nepoužívat v KeyboardCore žádný logging** — je to čistá synchronní logika, log je tu zbytečný a v extension procesu jsou každé bajty paměti drahé. Logger zavedeme až ve task 04 (InputDispatcher) nebo 11 (host onboarding).

## Mimo scope

- SwiftUI views — to je task 03.
- Input handling, drátování na `textDocumentProxy` — to je task 04.
- Shift state machine *logika* (přechody states) — to je task 05. V tomto tasku jen *enum* `ShiftState` existuje, transition logika ne.
- Auto-capitalization — task 06.
- Long-press popover UI a interakce — task 07. V tomto tasku jen *data* (`alternates: [KeyContent]`) jsou v modelu.
- Žádný `#+=` třetí symbol page — vědomé non-goal v v1.0.

## Hotovo když

- `KeyboardCore/Sources/Models/*.swift` definuje `Key`, `KeyContent`, `KeyAction`, `KeyRole`, `KeyWeight`, `KeyboardRow`, `KeyboardPage`, `ShiftState`, `KeyboardLayout`, `ReturnKeyType`.
- `KeyboardCore/Sources/Logic/LayoutBuilder.swift` obsahuje pure factory pro všechny kombinace `(page, showNumberRow, returnKeyType)`.
- `KeyboardCore/Sources/Public/KeyboardCore.swift` exportuje `KeyboardCore.makeLayout(...)` entrypoint.
- `KeyboardCore_Tests` target obsahuje ~20 testů, všechny green.
- `tuist build` projde.
- Diakritická mapování pro 14 base letters jsou hotová (česká + západoevropská).

## Rizika

- **Pojmenování enums.** `KeyboardPage`, `KeyRole`, `KeyAction` mají potenciál pro conflict s framework namy v dalších tasch. Držet je v `KeyboardCore` namespace, nebrát jako global typealias.
- **Diakritická mapování** je subjektivní volba. Pokud po prvním reálném používání zjistíš, že některé alternates jsou v jiném pořadí, je úprava jeden řádek v `LayoutBuilder`. Není to architektonický bug, jen data tweak.
- **`Sendable` conformance** — pokud cokoliv z těch typů nakonec drží reference type (např. NSAttributedString), kompilátor zařve. Drž typy striktně value-only.

## Reference

- Apple US QWERTY layout (zdroj pravdy pro pořadí kláves)
- `~/Development/WidgetCoin/WidgetCoinCore/Sources/Models/FiatCurrency.swift` — vzor pro Codable+Sendable value type
- Apple Human Interface Guidelines: Keyboards — <https://developer.apple.com/design/human-interface-guidelines/keyboards>

## Codex review

**Ano** — pure logika, dobře testovaná, klíčový datový model na který se zbytek projektu váže. Spustit `codex review --uncommitted` před closing commitem.
