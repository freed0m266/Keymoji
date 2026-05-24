# 04 — Input handling + adaptive return + double-tap space

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** Blokující

## Cíl

Drátování. Když uživatel ťukne na klávesu, příslušný text se objeví v aktivní text inputu. `KeyboardViewController` (extension entry point) hostuje `KeyboardView` v `UIHostingController`, drží shift state stub (full state machine přijde v task 05), routuje `Key` events do `UITextDocumentProxy`, propaguje `returnKeyType` z hostu do layoutu, a implementuje double-tap-space → ". ".

Po dokončení je klávesnice **funkčně použitelná** v Notes.app. Pouze ještě bez shift state machine (task 05), auto-cap (task 06), long-press popover (task 07), haptik (task 08) a delete repeat (task 09).

## Cox tento task NEdělá

- Shift logiku (přechod lower → upper → caps lock). Tap na shift v tomto tasku jen flipne mezi `lower` a `upper` (1-tap toggle), žádný caps lock, žádné auto-cap. Plnohodnotná state machine v tasku 05.

## Kontext

- `KeyboardViewController` byl v tasku 01 placeholderem. Tady ho rozšíříme o full lifecycle hook do `UIInputViewController` API.
- iOS volá `viewWillAppear` → `viewDidLayoutSubviews` → hosting view se ukáže.
- `textWillChange(_:)` a `textDidChange(_:)` jsou callbacks, kdy se mění active text field nebo cursor pozice. **Důležité pro adaptive return label**: re-read `textDocumentProxy.returnKeyType` v každém `textDidChange`.
- `UITextDocumentProxy` API: `insertText(_:)`, `deleteBackward()`, `documentContextBeforeInput`, `documentContextAfterInput`. To je všechno, co potřebujeme v v1.0.
- SwiftUI hostování v extensionu: použít `UIHostingController(rootView: KeyboardView(...))`, přidat ho jako child VC, constraints na `inputView`.

## Scope

### 1. `KeyboardViewController` — full implementace

`KeyboardExtension/Sources/KeyboardViewController.swift`:

```swift
import UIKit
import SwiftUI
import KeyboardCore
import KeyboardUI

@objc(KeyboardViewController)
public final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRoot>?
    private var state = KeyboardState()

    public override func viewDidLoad() {
        super.viewDidLoad()
        installHostingController()
    }

    public override func textWillChange(_ textInput: UITextInput?) { /* no-op */ }

    public override func textDidChange(_ textInput: UITextInput?) {
        // Re-read return key type ze hostu, re-renderuje layout
        let newType = mapReturnKey(textDocumentProxy.returnKeyType)
        if newType != state.returnKeyType {
            state.returnKeyType = newType
            rebuild()
        }
    }

    private func installHostingController() {
        let host = UIHostingController(rootView: KeyboardRoot(state: state, dispatch: handle))
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func rebuild() {
        hostingController?.rootView = KeyboardRoot(state: state, dispatch: handle)
    }

    private func handle(_ key: Key) {
        InputDispatcher.dispatch(key: key, state: &state, proxy: textDocumentProxy, controller: self)
        rebuild()
    }

    private func mapReturnKey(_ type: UIReturnKeyType) -> ReturnKeyType {
        switch type {
        case .default:        return .default
        case .go:             return .go
        case .google:         return .google
        case .join:           return .join
        case .next:           return .next
        case .route:          return .route
        case .search:         return .search
        case .send:           return .send
        case .done:           return .done
        case .emergencyCall:  return .emergencyCall
        case .continue:       return .continue
        case .yahoo:          return .yahoo
        @unknown default:     return .default
        }
    }
}
```

### 2. `KeyboardState` — runtime stav v extensionu

`KeyboardExtension/Sources/KeyboardState.swift`:

```swift
struct KeyboardState {
    var page: KeyboardPage = .letters(.lower)
    var returnKeyType: ReturnKeyType = .default
    var showNumberRow: Bool = true           // bude propojené s AppGroupStore v tasku 10
    var lastInsertWasSpace: Bool = false     // pro double-tap space → ". "
    var lastSpaceInsertedAt: Date? = nil     // pro window detekce double-tap
}
```

`KeyboardState` je struct, ne třída — jednodušší ownership, value semantics. V `KeyboardViewController` ho držíme jako `private var state` a předáváme do `KeyboardRoot` view.

### 3. `KeyboardRoot` — root SwiftUI view

`KeyboardExtension/Sources/KeyboardRoot.swift`:

```swift
struct KeyboardRoot: View {
    let state: KeyboardState
    let dispatch: (Key) -> Void

    var body: some View {
        let layout = KeyboardCore.makeLayout(
            page: state.page,
            showNumberRow: state.showNumberRow,
            returnKeyType: state.returnKeyType
        )
        KeyboardView(layout: layout, onKey: dispatch)
    }
}
```

Tenkost — task 03 už dělá vše ostatní.

### 4. `InputDispatcher` — co se stane při tapu

`KeyboardCore/Sources/Logic/InputDispatcher.swift`:

```swift
public enum InputDispatcher {
    public static func dispatch(
        key: Key,
        state: inout KeyboardState,
        proxy: UITextDocumentProxy,                  // viz typealias níže
        controller: any KeyboardControlling
    ) {
        switch key.action {
        case .insertText(let text):
            proxy.insertText(textWithShiftApplied(text, state: state))
            updateShiftAfterCharacter(state: &state)
            updateSpaceTracking(insertedText: text, state: &state)

        case .space:
            handleSpace(state: &state, proxy: proxy)

        case .backspace:
            proxy.deleteBackward()
            state.lastInsertWasSpace = false

        case .shift:
            handleShiftTap(state: &state)

        case .capsLockToggle:
            // emitted by KeyView při double-tap; v tasku 04 stub — task 05 doplní
            state.page = .letters(.capsLock)

        case .return:
            proxy.insertText("\n")
            state.lastInsertWasSpace = false

        case .nextKeyboard:
            controller.advanceToNextInputMode()

        case .switchPage(let page):
            state.page = page

        case .dismissKeyboard:
            controller.dismissKeyboard()
        }
    }
}
```

**Problém s `UITextDocumentProxy` v `KeyboardCore`:** ten framework je čistě Swift bez UIKit. Musíme:

- (a) buď linknout UIKit do `KeyboardCore` (lehčí, ale špiní pure Swift framework),
- (b) nebo abstrahovat `UITextDocumentProxy` přes protokol v `KeyboardCore` a v extension targetu udělat adapter.

**Zvolíme (b)** — abstraktní `TextDocumentProxying` protokol v `KeyboardCore` + UIKit adapter v `KeyboardExtension`. Důvody: pure Swift framework, snadná unit testovatelnost dispatch funkce s mock proxy.

```swift
// KeyboardCore/Sources/Public/TextDocumentProxying.swift
public protocol TextDocumentProxying {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}

// KeyboardCore/Sources/Public/KeyboardControlling.swift
public protocol KeyboardControlling: AnyObject {
    func advanceToNextInputMode()
    func dismissKeyboard()
}
```

V `KeyboardExtension/Sources/UITextDocumentProxy+Adapter.swift`:

```swift
extension UITextDocumentProxy: TextDocumentProxying {}        // shape už pasuje
```

`UIInputViewController` má native `advanceToNextInputMode()` a `dismissKeyboard()` → `KeyboardViewController: KeyboardControlling` extension je triviální.

### 5. Shift apply na vkládaný text

```swift
private static func textWithShiftApplied(_ text: String, state: KeyboardState) -> String {
    guard case .letters(let shift) = state.page else { return text }
    switch shift {
    case .lower:          return text
    case .upper, .capsLock: return text.uppercased(with: Locale(identifier: "en_US_POSIX"))
    }
}
```

### 6. Shift downshift po písmeni (jen v tasku 04: 1-tap toggle)

```swift
private static func updateShiftAfterCharacter(state: inout KeyboardState) {
    if case .letters(.upper) = state.page {
        state.page = .letters(.lower)            // jednorázový upper → zpět dolů
    }
    // caps lock se NEsnižuje
}
```

Plná state machine v tasku 05 tohle nahradí.

### 7. Double-tap space → ". "

```swift
private static func handleSpace(state: inout KeyboardState, proxy: TextDocumentProxying) {
    let now = Date()
    let isDoubleTap = state.lastInsertWasSpace
        && state.lastSpaceInsertedAt.map { now.timeIntervalSince($0) < 0.5 } == true

    if isDoubleTap {
        // Smazat trailing space, vložit ". "
        proxy.deleteBackward()
        proxy.insertText(". ")
        state.lastInsertWasSpace = true        // za ". " je už mezera
        state.lastSpaceInsertedAt = now
    } else {
        proxy.insertText(" ")
        state.lastInsertWasSpace = true
        state.lastSpaceInsertedAt = now
    }
}

private static func updateSpaceTracking(insertedText: String, state: inout KeyboardState) {
    state.lastInsertWasSpace = (insertedText == " ")
    state.lastSpaceInsertedAt = nil            // písmeno přerušilo space sequence
}
```

Threshold 500 ms je standard Apple-like.

### 8. `123/ABC` toggle

`Key` má `KeyAction.switchPage(.symbols)` na `[123]` button a `.switchPage(.letters(.lower))` na `[ABC]` button. `InputDispatcher.dispatch` jen přepíše `state.page`. Layout se re-buildne automaticky.

### 9. Unit testy

`KeyboardCore/Tests/InputDispatcherTests.swift`:

Použít `MockTextProxy: TextDocumentProxying` + `MockController: KeyboardControlling`:

```swift
final class MockTextProxy: TextDocumentProxying {
    var inserted: [String] = []
    var backspaceCount = 0
    var documentContextBeforeInput: String? = nil
    var documentContextAfterInput: String? = nil

    func insertText(_ text: String) { inserted.append(text) }
    func deleteBackward() { backspaceCount += 1 }
}
```

Pokrýt:

- Tap na letter „a" v lower page → `inserted == ["a"]`, page zůstane `.letters(.lower)`.
- Tap na letter „a" v upper page → `inserted == ["A"]`, page se vrátí na `.letters(.lower)`.
- Tap na letter „a" v capsLock page → `inserted == ["A"]`, page zůstane `.letters(.capsLock)`.
- Tap na backspace → `backspaceCount == 1`.
- Tap na shift z lower → page = `.letters(.upper)`.
- Tap na shift z upper → page = `.letters(.lower)`.
- Tap na switchPage(.symbols) → page = `.symbols`.
- Tap na return → `inserted == ["\n"]`.
- Single tap space → `inserted == [" "]`, `lastInsertWasSpace == true`.
- Double tap space (do 500 ms) → druhý tap dispatchne `deleteBackward` + `insertText(". ")`. Final inserted history: `[" ", ". "]`, backspaceCount = 1.
- Double tap space (>500 ms) → dva normální spaces, žádný period substitution.
- Letter inserted po space → `lastInsertWasSpace == false`, příští space dělá single space.
- Triple-tap space (3× rychle): první mezera → druhá nahradí na ". " → třetí má `lastInsertWasSpace == true` z předchozího ". " (poslední char je space), takže by triggerla další substituci → vyústí v ". . " což je špatně. **Řešení:** po period substituci přepsat `lastInsertWasSpace = false`, NE true. Korigovat výše uvedený kód podle toho a testem ošetřit.

### 10. Adaptive return label — refresh on text input change

`KeyboardViewController.textDidChange(_:)` re-reads `textDocumentProxy.returnKeyType`, mapuje na `ReturnKeyType` enum z `KeyboardCore`, pokud se změnil oproti `state.returnKeyType`, updatne state a re-buildne hosting controller view.

**Pozor:** `textDidChange` se volá hodně — i při každém keystroke. Re-build pokud `returnKeyType` nezměnil je no-op. Conditional update v kódu výše to ošetřuje.

### 11. Logger

V `KeyboardViewController` a `InputDispatcher` přidat **minimální** logging pomocí `KeyboCore`-poskytnutého SwiftyBeaver wrapperu (v `KeyboCore/Sources/Shared/Logger.swift`, viz Template scaffold):

- `Logger.debug("Keyboard appeared")` v `viewDidLoad`.
- Žádné logy v dispatch hot path (žádné `log(key)` per stisk — performance + privacy).
- `Logger.warn(...)` při unexpected state (např. `dispatch` dostane `.dismissKeyboard` — to v v1.0 neemitujeme).

## Mimo scope

- Full shift state machine — task 05.
- Auto-capitalization — task 06.
- Long-press popover — task 07.
- Haptics — task 08.
- Delete repeat-on-hold — task 09.
- Number row toggle čtení ze `AppGroupStore` — task 10. V tomto tasku `state.showNumberRow = true` hardcoded.

## Hotovo když

- `KeyboardViewController` hostuje `KeyboardView` přes `UIHostingController`.
- `InputDispatcher` v `KeyboardCore` routuje `Key` events do `TextDocumentProxying`.
- Tap na letter klávesy vkládá písmena. Backspace maže. Space vkládá mezeru. Return vkládá newline. Globe přepíná klávesnice.
- 1-tap shift toggle funguje (upper na jedno písmeno, pak zpět na lower).
- 123/ABC toggle přepíná stránky.
- Double-tap space (do 500 ms) vloží ". " a smaže předchozí mezeru.
- Return key label se mění podle `returnKeyType` z hosting appky (otestováno v Safari adresním řádku → „Go", v Mail subject → „Done").
- Triple-tap space NEvkládá `. . ` (regression test pokryt).
- ~12 unit testů pro `InputDispatcher` green.
- Manuální smoke test v Notes.app: napsat „hello world. this is keybo." a uvidět očekávaný text.

## Rizika

- **SwiftUI hosting controller v keyboard extensionu**: na starších iOS verzích to bývalo problematické (memory, performance). Na iOS 26+ s deployment target = 26 by mělo být v pohodě. Pokud uvidíme lag / freeze, fallback je `UIKit` `UIView` jako root, ale to by znamenalo přepsat task 03.
- **`textDocumentProxy.documentContextBeforeInput` může být `nil`** v některých inputech (např. password fields, secure text). `InputDispatcher` to musí umět snášet (nil-safe). V v1.0 jen `space` handler na to sahá (a to ne — sahá až task 06 auto-cap).
- **Re-build hosting controller při každém `textDidChange`** může být drahý. Pokud nameříme jank, optimalizovat na granulární update přes `@Observable` viewmodelu místo full rebuild. Pro v1.0 baseline OK.

## Reference

- `KeyboCore/Sources/Shared/Logger.swift` — log wrapper
- Apple: UIInputViewController — <https://developer.apple.com/documentation/uikit/uiinputviewcontroller>
- Apple: UITextDocumentProxy — <https://developer.apple.com/documentation/uikit/uitextdocumentproxy>

## Codex review

**Ano** — `InputDispatcher` je hot path s netriviální state machine (space tracking edge case, shift downshift, return label re-fetch). Stojí za review.
