# 06 — Auto-capitalization

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Když uživatel napíše větu končící `. `, `? `, nebo `! ` a začne psát další písmeno, klávesnice automaticky přepne do `letters(.upper)` aby další písmeno bylo velké. Stejně na začátku dokumentu a po dvou newlines. Žádné heuristiky pro `Mr.`, ellipsis, ani jiné edge-cases.

## Kontext

- `UITextDocumentProxy.documentContextBeforeInput` vrací text vlevo od kurzoru. Detekce sentence boundary čte poslední 1–3 znaky.
- `UITextInputTraits.autocapitalizationType` říká, jakou auto-cap chce hosting appka (`.none`, `.words`, `.sentences`, `.allCharacters`). V Keymoji v1.0 implementujeme jen `.sentences`. `.words` a `.allCharacters` jsou Future (nebo wontfix).
- Hooky v `KeyboardViewController`: `textDidChange` — po každé změně cursor pozice / dokumentu.

## Scope

### 1. `AutoCapitalizer` v `KeyboardCore`

`KeyboardCore/Sources/Logic/AutoCapitalizer.swift`:

```swift
public enum AutoCapitalizer {
    /// Decide whether next character should be capitalized based on text before cursor.
    /// Returns true ↔ shift should be elevated to `.upper`.
    public static func shouldCapitalize(
        documentContextBeforeInput: String?,
        autocapitalizationType: AutocapitalizationType
    ) -> Bool {
        guard autocapitalizationType == .sentences else { return false }

        let context = documentContextBeforeInput ?? ""

        // Začátek dokumentu = prázdný kontext nebo jen whitespace
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return true
        }

        // Po terminátoru + jedné mezeře (nebo víc)
        if context.hasSuffix(". ") || context.hasSuffix("? ") || context.hasSuffix("! ") {
            return true
        }

        // Po dvou newlines (nový paragraph)
        if context.hasSuffix("\n\n") {
            return true
        }

        // Po jediném newline (nový řádek) — taky cap? Apple: jen po double newline.
        // Nedoporučuju single newline trigger — chat appky vkládají \n často.

        return false
    }
}

public enum AutocapitalizationType: Sendable, Equatable {
    case none
    case words
    case sentences
    case allCharacters
}
```

### 2. Integrace v `KeyboardViewController`

V `KeyboardViewController.textDidChange(_:)` z tasku 04:

```swift
public override func textDidChange(_ textInput: UITextInput?) {
    let newReturnType = mapReturnKey(textDocumentProxy.returnKeyType)
    let newAutoCap = mapAutoCap(textDocumentProxy.autocapitalizationType)

    var needsRebuild = false

    if newReturnType != state.returnKeyType {
        state.returnKeyType = newReturnType
        needsRebuild = true
    }

    // Auto-cap evaluace
    let shouldCap = AutoCapitalizer.shouldCapitalize(
        documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput,
        autocapitalizationType: newAutoCap
    )

    if shouldCap, case .letters(.lower) = state.page {
        state.page = .letters(.upper)
        state.autoCapitalized = true              // pro distinct chování v dalším kroku
        needsRebuild = true
    } else if !shouldCap, state.autoCapitalized, case .letters(.upper) = state.page {
        // Auto-cap se přestal aplikovat (uživatel např. smazal terminator) — vrátit na lower
        state.page = .letters(.lower)
        state.autoCapitalized = false
        needsRebuild = true
    }

    if needsRebuild { rebuild() }
}
```

`KeyboardState.autoCapitalized: Bool` (nové pole) — flag, který odlišuje user-initiated upper od auto-cap upper. Důvod: chceme, aby auto-cap měl distinct UX (např. backspace okamžitě po auto-cap by neměl smazat písmeno ale vrátit shift).

### 3. Edge case — backspace ihned po auto-cap písmeni

Apple: pokud uživatel napíše `. A` (kde `A` bylo auto-capitalizováno), pak stiskne backspace, smaže to **písmeno `A` ale nikoli auto-cap state** — shift zůstane v `.upper`, takže další tap zase napíše velké písmeno. To je „undo my auto-cap" interaction.

V Keymoji v1.0 **toto neimplementujeme** — backspace prostě smaže předchozí znak, shift se přirozeně přizpůsobí přes `textDidChange` (pokud kontext před cursorem zase končí `. `, auto-cap re-triggerne).

To je čistší řešení a v praxi se chová správně, jen má jiný interakční model než Apple. Pro v1.0 OK.

### 4. Mapping `UITextAutocapitalizationType` → `AutocapitalizationType`

V `KeyboardViewController`:

```swift
private func mapAutoCap(_ type: UITextAutocapitalizationType) -> AutocapitalizationType {
    switch type {
    case .none:          return .none
    case .words:         return .words            // nemáme — chovat se jako .none
    case .sentences:     return .sentences
    case .allCharacters: return .allCharacters    // nemáme — chovat se jako .none
    @unknown default:    return .none
    }
}
```

V `AutoCapitalizer.shouldCapitalize` kdykoliv `autocapitalizationType != .sentences`, return false. `.words` a `.allCharacters` jsou no-op v v1.0.

### 5. Unit testy

`KeyboardCore/Tests/AutoCapitalizerTests.swift`:

- `documentContextBeforeInput = nil, type = .sentences` → true (začátek dokumentu).
- `documentContextBeforeInput = "", type = .sentences` → true.
- `documentContextBeforeInput = "   ", type = .sentences` → true (jen whitespace).
- `documentContextBeforeInput = "Hello", type = .sentences` → false.
- `documentContextBeforeInput = "Hello. ", type = .sentences` → true.
- `documentContextBeforeInput = "Hello! ", type = .sentences` → true.
- `documentContextBeforeInput = "Hello? ", type = .sentences` → true.
- `documentContextBeforeInput = "Hello.", type = .sentences` → false (musí být mezera za teminátorem).
- `documentContextBeforeInput = "Hello.  ", type = .sentences` → true (víc mezer OK; `hasSuffix(". ")` matchne i s dvěma mezerami protože „. " je suffix).
  - Pozor: `"Hello.  ".hasSuffix(". ")` matchne? `.hasSuffix(". ")` = end of string `[..., '.', ' ']`. „Hello.  " končí na ' ' ' ' (dvě mezery), předposlední je space, ne tečka. Takže `hasSuffix(". ")` false. ✓ Apple chování (single-mezera trigger).
  - Pokud chceme tolerantnější — `trimmingCharacters(.whitespaces).hasSuffix(".")` + check že kontext končí whitespace. To je hezčí, ale komplexnější. **Nechat single-mezera matching pro v1.0.**
- `documentContextBeforeInput = "Hello\n\n", type = .sentences` → true (double newline).
- `documentContextBeforeInput = "Hello\n", type = .sentences` → false (single newline, viz scope).
- `documentContextBeforeInput = "Hello. ", type = .none` → false (auto-cap vypnutý).
- `documentContextBeforeInput = "Hello. ", type = .words` → false (nepodporujeme `.words` v v1.0).

~10 testů.

### 6. Manuální test v Notes.app a Safari

- Začít psát v prázdném Notes → první písmeno je velké. ✓
- Napsat „hello.<space>" → další písmeno auto-velké. ✓
- Napsat „hello?<space>" → další velké. ✓
- Smazat poslední velké, vrátit zpět malé → po dalším space + písmenu auto-cap zase zapne (přes `textDidChange` cycle). ✓
- V Safari adresním řádku — auto-cap se chová podle `autocapitalizationType` který Safari nastavuje (`.none` typicky pro URL bary). ✓ Nezasahujeme.

## Mimo scope

- Heuristiky pro abbreviations (`Mr.`, `Dr.`, `etc.`, `e.g.`, `i.e.`). Apple to nemá; nemusíme ani my.
- Ellipsis `...` jako sentence terminator. Apple to taky nemá.
- `autocapitalizationType.words` a `.allCharacters`. Nepodporujeme — chovají se jako `.none`.
- „Undo auto-cap by backspace" interaction (viz scope 3). Implicitně řeší re-evaluation.

## Hotovo když

- `AutoCapitalizer.shouldCapitalize(...)` je čistá funkce v `KeyboardCore`.
- `KeyboardViewController.textDidChange` triggerne re-evaluation a updatuje `state.page`.
- Manuál test: po `. ` se další písmeno velké v Notes.app.
- Manuál test: na začátku dokumentu první písmeno velké.
- Manuál test: v Safari adresním řádku auto-cap NEzasahuje (`autocapitalizationType = .none`).
- ~10 unit testů green.

## Rizika

- **`documentContextBeforeInput` může být `nil` v secure text fields** (passwords). `AutoCapitalizer` to handle: nil → return true (začátek dokumentu, ale pravděpodobně password kde nezáleží). Acceptable.
- **Re-evaluation per každý `textDidChange`** — pokud cap state mění → rebuild hosting view. Při rychlém typing to znamená rebuild na každé písmeno. Měřit perf; pokud jank, optimize.
- **Subtle UX divergence z Apple chování**: scope 3 (backspace neprezervuje auto-cap state). Pokud někdo Apple-power-user, může to vnímat jako bug. Wontfix v v1.0.

## Reference

- `KeyboardCore/Sources/Logic/InputDispatcher.swift`
- `KeyboardCore/Sources/Logic/ShiftStateMachine.swift`
- Apple: UITextInputTraits.autocapitalizationType — <https://developer.apple.com/documentation/uikit/uitextinputtraits/1624434-autocapitalizationtype>

## Codex review

**Ano** — sentence boundary detekce má dost subtilní edge cases, druhé oko se hodí.
