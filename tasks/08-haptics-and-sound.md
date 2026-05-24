# 08 — Haptika + key click sound

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Přidat haptický feedback na každý key tap a klávesnicový klikací zvuk. Haptika vyžaduje Full Access (uživatel musí povolit v iOS Settings → General → Keyboards → Keybo → Allow Full Access — host onboarding to vysvětlí v tasku 11). Toggle `hapticFeedback` v Settings (task 12) umožní haptiku vypnout. Zvuk je přes `UIInputViewAudioFeedback` protocol + `playInputClick()` — funguje *bez* Full Access.

## Kontext

- `UIImpactFeedbackGenerator` v keyboard extension procesu **negeneruje vibrace, dokud uživatel nezapne Full Access**. To je iOS sandbox restriction, nelze obejít.
- Bez Full Access: haptic API nic nezpůsobí (žádný error, jen no-op). Apple navenek nezpřístupňuje runtime check „mám Full Access?". Nepřímá detekce: pokus zapsat do shared App Group UserDefaults; pokud `synchronize()` vrátí `true`, pravděpodobně máme Full Access. Toto checkujeme až v `AppGroupStore` v tasku 10.
- Pro v1.0 budeme triggernout haptic API vždycky; pokud user nemá Full Access, nic se nestane (no-op). Žádná fallback strategie.
- Klikací zvuk přes `playInputClick()` funguje bez Full Access, ale vyžaduje, aby `KeyboardViewController` adoptoval `UIInputViewAudioFeedback` protokol.
- Toggle v Settings: defaultně oba ON. Hodnoty v App Group UserDefaults.

## Scope

### 1. `HapticFeedbackProviding` protokol v `KeyboardCore`

`KeyboardCore/Sources/Public/HapticFeedbackProviding.swift`:

```swift
public protocol HapticFeedbackProviding: Sendable {
    func keyTap()
    func popoverEntry()
    func popoverHighlightChanged()
}

public struct NoopHaptics: HapticFeedbackProviding {
    public init() {}
    public func keyTap() {}
    public func popoverEntry() {}
    public func popoverHighlightChanged() {}
}
```

Důvod protokolu (jako u `TextDocumentProxying` v tasku 04): `KeyboardCore` nedrží UIKit dep, haptic API je v `KeyboardUI` / `KeyboardExtension`.

### 2. `UIKitHaptics` v extension targetu

`KeyboardExtension/Sources/UIKitHaptics.swift`:

```swift
import UIKit
import KeyboardCore

final class UIKitHaptics: HapticFeedbackProviding {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selectionGen = UISelectionFeedbackGenerator()

    private let isEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        lightImpact.prepare()
        softImpact.prepare()
        selectionGen.prepare()
    }

    func keyTap() {
        guard isEnabled() else { return }
        lightImpact.impactOccurred()
    }

    func popoverEntry() {
        guard isEnabled() else { return }
        softImpact.impactOccurred(intensity: 0.7)
    }

    func popoverHighlightChanged() {
        guard isEnabled() else { return }
        selectionGen.selectionChanged()
    }
}
```

Tři intenzity:

- **Key tap** = `.light` impact — krátké, jemné, ne otravné.
- **Popover entry** = `.soft` s 70% intensity — odlišné od tap, signál „udělalo se něco jiného".
- **Popover highlight change** = selection feedback — minimalistický kvazi-cvak, jako native iOS picker.

### 3. `isEnabled` callback

Aktuální hodnota Settings toggle. Pro task 08 ho propojíme s `AppGroupStore` (task 10 dělá AppGroupStore). Pokud task 08 implementujeme **před** taskem 10, hardcode `isEnabled: { true }` a doplníme v 10.

Doporučené pořadí: 08 → 09 → 10 (10 závisí na konfigurabilitě haptic, ale 08 funguje stand-alone). Když přijde 10, refaktor `KeyboardViewController.init` aby čerpal toggle hodnotu.

### 4. Integrace v `KeyboardViewController`

```swift
public final class KeyboardViewController: UIInputViewController {
    private lazy var haptics: HapticFeedbackProviding = UIKitHaptics(isEnabled: { [weak self] in
        self?.isHapticEnabled() ?? true
    })

    private func isHapticEnabled() -> Bool {
        true                              // task 10 nahradí AppGroupStore.read
    }
}
```

`InputDispatcher.dispatch` (task 04) rozšíříme o parametr `haptics: HapticFeedbackProviding` a uvnitř volá `haptics.keyTap()` v `.insertText`, `.insertRawText`, `.backspace`, `.space`, `.return`. NE pro `.shift`, `.switchPage`, `.nextKeyboard` (system keys nemají haptic — Apple konvence).

Edit `InputDispatcher.dispatch` signature:

```swift
public static func dispatch(
    key: Key,
    state: inout KeyboardState,
    proxy: TextDocumentProxying,
    controller: any KeyboardControlling,
    haptics: any HapticFeedbackProviding
)
```

V `KeyView` (task 07) closures `onPopoverEntry` a `onHighlightChanged` propaguj nahoru až do `KeyboardViewController`, který volá `haptics.popoverEntry()` a `haptics.popoverHighlightChanged()`.

### 5. Klikací zvuk

`KeyboardViewController` adoptuje `UIInputViewAudioFeedback`:

```swift
extension KeyboardViewController: UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool { true }
}
```

V `InputDispatcher.dispatch`:

```swift
// V handle character/space/return/backspace:
UIDevice.current.playInputClick()
```

Ale `UIDevice` je v UIKit, ne v `KeyboardCore`. Stejný pattern jako haptics — protokol + adapter:

```swift
public protocol KeyClickSounding: Sendable {
    func playClick()
}
```

Adapter v extensionu, předaný do `InputDispatcher.dispatch`.

Alternativně **vynechat sound v v1.0** úplně. Důvody:

- Klikací zvuk je v defaultu vypnutý na zařízeních se silenced ringer; uživatelé málokdy si ho zapínají.
- Není v původním promptu zmíněný (haptika je, zvuk ne).
- Apple stock klávesnice ho má jen pokud je „Keyboard Clicks" v Settings → Sounds & Haptics zapnuté.

**Doporučení:** vynechat klikací zvuk z v1.0. `enableInputClicksWhenVisible` ano (protocol conformance, žádný škoda), ale `playInputClick()` v dispatch **neimplementovat**.

Pokud po release zjistíš, že chceš zvuk, je to ~10 řádků v Future tasku „Sound feedback toggle" (už je v `tasks/README.md`).

### 6. Haptic feedback toggle propagace z Settings

Settings task (12) bude mít `Toggle("Haptic feedback", isOn: $hapticEnabled)`. Hodnota v `AppGroupStore` pod klíčem `.hapticFeedbackEnabled`. Default `true`.

V `KeyboardViewController.isHapticEnabled()`:

```swift
private func isHapticEnabled() -> Bool {
    AppGroupStore.shared.bool(forKey: .hapticFeedbackEnabled, default: true)
}
```

(Vyžaduje task 10 hotové. V task 08 standalone return true.)

### 7. Unit testy

Logic haptiky netestujeme — `UIImpactFeedbackGenerator` neumíme assertovat. Test je:

- `NoopHaptics` neselže (smoke test že protokol existuje).
- `InputDispatcher.dispatch` volá `haptics.keyTap()` při `.insertText` (přes `MockHaptics: HapticFeedbackProviding` s counter). ~5 testů: insertText, insertRawText, backspace, space, return — všechny musí trigger keyTap; shift, switchPage, nextKeyboard NEsmí trigger.

`KeyboardCore/Tests/HapticDispatchTests.swift`:

```swift
final class MockHaptics: HapticFeedbackProviding {
    var keyTapCount = 0
    var popoverEntryCount = 0
    var popoverHighlightCount = 0
    func keyTap() { keyTapCount += 1 }
    func popoverEntry() { popoverEntryCount += 1 }
    func popoverHighlightChanged() { popoverHighlightCount += 1 }
}

func testKeyTapTriggersHaptic_onInsertText() { ... }
func testKeyTapTriggersHaptic_onBackspace() { ... }
func testKeyTapTriggersHaptic_onSpace() { ... }
func testKeyTapTriggersHaptic_onReturn() { ... }
func testNoHaptic_onShift() { ... }
func testNoHaptic_onSwitchPage() { ... }
func testNoHaptic_onNextKeyboard() { ... }
```

### 8. Manuální test

Zařízení (NE simulátor — haptika v simulátoru nefunguje, je to hardware feature):

1. Zapnout Full Access pro Keybo v Settings.
2. Napsat v Notes několik písmen → cítit `.light` impact na každém.
3. Long-press na `e` → cítit `.soft` impact na entry.
4. Slide přes alternates → cítit selection feedback při změně highlighted.
5. Vypnout `Haptic feedback` toggle v Settings (po hotovém tasku 12) → žádné vibrace.

## Mimo scope

- Klikací zvuk (viz scope 5; Future task).
- Custom haptic patterns (např. trvalejší vibrace na backspace hold). Standard `.light` impact pro v1.0.
- Detekce Full Access stavu a fallback messaging. Pokud user nemá Full Access, haptika prostě nehraje a žádný error. Host onboarding (task 11) tento požadavek vysvětlí.

## Hotovo když

- `UIKitHaptics` v extensionu konformuje `HapticFeedbackProviding`.
- `InputDispatcher.dispatch` volá `haptics.keyTap()` při character / space / return / backspace; NE při system keys.
- Long-press popover (task 07) volá `popoverEntry` a `popoverHighlightChanged`.
- 7 unit testů green.
- Manuální test na zařízení s Full Access: cítit haptic.
- Manuální test bez Full Access: žádný crash, žádný haptic, klávesnice funguje jinak normálně.

## Rizika

- **Bez Full Access haptic API silently no-op** — uživatel by si mohl myslet, že haptika nefunguje. Host onboarding (task 11) musí Full Access explicitně vysvětlit.
- **`UIImpactFeedbackGenerator.prepare()` v extensionu** — `prepare()` má cost; lazy-load v `lazy var` je v scope. Pokud uvidíme launch lag, refaktor na `prepare()` v `viewDidLoad`.
- **Performance**: každý keystroke trigger haptic má negligible CPU/RAM cost. Žádné riziko.

## Reference

- `KeyboardCore/Sources/Logic/InputDispatcher.swift` (task 04)
- Apple: UIImpactFeedbackGenerator — <https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator>
- Apple: UIInputViewAudioFeedback — <https://developer.apple.com/documentation/uikit/uiinputviewaudiofeedback>

## Codex review

**Skip** — mechanické UIKit drátování bez netriviální logiky. Pokud něco ulítne, zachytí to manuální test.
