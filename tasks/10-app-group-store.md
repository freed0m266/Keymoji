# 10 — `AppGroupStore` + cross-process settings

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** High

## Cíl

Implementovat sdílený storage mezi host appkou a keyboard extensionem. Pattern převzít z WidgetCoinu (`WidgetCoinCore/Sources/Shared/AppGroupStore.swift`). Two settings v v1.0: `showNumberRow: Bool` (default true), `hapticFeedbackEnabled: Bool` (default true). Žádná cross-process observation (Darwin notifications) — to je Future task. Klávesnice čte hodnoty při `viewWillAppear` / next launch.

## Kontext

- App Group `group.com.freedommartin.keybo` deklarován v entitlements obou targetů v tasku 01.
- WidgetCoin používá `UserDefaults(suiteName:)` wrapper s typed enum `AppGroupStoreKey`. Replicate ten pattern.
- Cross-process challenge: host appka zapíše → extension přečte. Bez Darwin notifications musí extension re-read **každý** `viewWillAppear`. Pro v1.0 stačí.

## Scope

### 1. `AppGroupStoreKey` enum

`KeyboCore/Sources/Shared/AppGroupStoreKey.swift`:

```swift
public enum AppGroupStoreKey: String, Sendable, CaseIterable {
    case showNumberRow
    case hapticFeedbackEnabled
    // Future: case appearance, case favoriteEmojis, ...
}
```

### 2. `AppGroupStore` wrapper

`KeyboCore/Sources/Shared/AppGroupStore.swift`:

```swift
import Foundation

public final class AppGroupStore: Sendable {
    public static let shared = AppGroupStore()

    private let suite: UserDefaults

    public init(suiteName: String = appGroupSuiteName) {
        guard let suite = UserDefaults(suiteName: suiteName) else {
            // Suite creation can fail if entitlements are misconfigured.
            // Crash early in DEBUG, soft-fail in RELEASE (use standard defaults).
            #if DEBUG
            fatalError("Failed to create UserDefaults(suiteName: \(suiteName)). Check App Group entitlements.")
            #else
            self.suite = .standard
            return
            #endif
        }
        self.suite = suite
    }

    // MARK: - Bool

    public func bool(forKey key: AppGroupStoreKey, default defaultValue: Bool) -> Bool {
        guard suite.object(forKey: key.rawValue) != nil else { return defaultValue }
        return suite.bool(forKey: key.rawValue)
    }

    public func setBool(_ value: Bool, forKey key: AppGroupStoreKey) {
        suite.set(value, forKey: key.rawValue)
    }

    // MARK: - String

    public func string(forKey key: AppGroupStoreKey) -> String? {
        suite.string(forKey: key.rawValue)
    }

    public func setString(_ value: String?, forKey key: AppGroupStoreKey) {
        suite.set(value, forKey: key.rawValue)
    }

    // Reset (debug only)
    public func reset() {
        AppGroupStoreKey.allCases.forEach { suite.removeObject(forKey: $0.rawValue) }
    }
}

public let appGroupSuiteName = "group.com.freedommartin.keybo"
```

**Proč `suite.object(forKey:) != nil` check** v `bool(...)`? `UserDefaults.bool(forKey:)` vrací `false` pokud klíč neexistuje — to je k nerozlišitelnému od „uloženo `false`". Pomocí `object(forKey:) != nil` rozeznáme „uloženo" od „neuloženo" a vrátíme default jen v druhém případě.

### 3. Typed accessory (volitelně, pro pohodlí)

`KeyboCore/Sources/Shared/AppGroupStore+TypedAccess.swift`:

```swift
public extension AppGroupStore {
    var showNumberRow: Bool {
        get { bool(forKey: .showNumberRow, default: true) }
        set { setBool(newValue, forKey: .showNumberRow) }
    }

    var hapticFeedbackEnabled: Bool {
        get { bool(forKey: .hapticFeedbackEnabled, default: true) }
        set { setBool(newValue, forKey: .hapticFeedbackEnabled) }
    }
}
```

Tento extension je nice-to-have. Callers můžou používat buď `store.showNumberRow` nebo `store.bool(forKey: .showNumberRow, default: true)`. Stejný výsledek, lepší autocomplete.

### 4. Integrace v `KeyboardViewController`

```swift
public final class KeyboardViewController: UIInputViewController {
    private let store = AppGroupStore.shared
    private var state = KeyboardState()

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFromStore()
    }

    private func refreshFromStore() {
        let showRow = store.showNumberRow
        let hapticEnabled = store.hapticFeedbackEnabled

        var needsRebuild = false
        if state.showNumberRow != showRow {
            state.showNumberRow = showRow
            needsRebuild = true
        }
        // hapticEnabled se aplikuje přes `isEnabled` closure v UIKitHaptics — žádný rebuild
        if needsRebuild { rebuild() }
    }

    private lazy var haptics: HapticFeedbackProviding = UIKitHaptics(isEnabled: { [weak self] in
        self?.store.hapticFeedbackEnabled ?? true
    })
}
```

**`viewWillAppear` se volá** každý raz, kdy uživatel klávesnici otevře (po background, po switch jiné klávesnice). To zaručí, že změna toggle z host appky se projeví **v dalším launch** klávesnice.

**Co se nestane:** pokud klávesnice běží a uživatel přepne toggle (v host appce nebo přímo v iOS Settings → Keyboards), klávesnice si toho nevšimne, dokud ji uživatel nezavře a znovu neotevře. To je v `Future: cross-process settings observation` task.

### 5. Reactive update v host appce

Host Settings UI (task 12) bude SwiftUI `Toggle` s bindingem na `AppGroupStore`. Když uživatel toggle změní, hodnota se okamžitě zapíše. Žádný `synchronize()` call potřeba (iOS UserDefaults sync automaticky).

```swift
// Pseudo, plný kód v tasku 12:
@State private var showNumberRow = AppGroupStore.shared.showNumberRow

Toggle("Always show number row", isOn: $showNumberRow)
    .onChange(of: showNumberRow) { _, newValue in
        AppGroupStore.shared.showNumberRow = newValue
    }
```

### 6. Unit testy

`KeyboCore_Tests` *(nebo nový test target — viz task 01 — `KeyboardCore_Tests`)*: `AppGroupStore` testovatelný snadno s custom suite name (in-memory style):

```swift
final class AppGroupStoreTests: XCTestCase {
    var store: AppGroupStore!
    let testSuite = "group.com.freedommartin.keybo.tests"

    override func setUp() {
        store = AppGroupStore(suiteName: testSuite)
        store.reset()
    }

    func testReturnsDefault_WhenKeyMissing() {
        XCTAssertTrue(store.bool(forKey: .showNumberRow, default: true))
        XCTAssertFalse(store.bool(forKey: .showNumberRow, default: false))
    }

    func testReturnsStoredValue_WhenKeyExists() {
        store.setBool(false, forKey: .showNumberRow)
        XCTAssertFalse(store.bool(forKey: .showNumberRow, default: true))
    }

    func testTypedAccessor_showNumberRow() {
        store.showNumberRow = false
        XCTAssertFalse(store.showNumberRow)
    }

    func testReset_ClearsAllKeys() {
        store.showNumberRow = false
        store.hapticFeedbackEnabled = false
        store.reset()
        XCTAssertTrue(store.showNumberRow)              // default
        XCTAssertTrue(store.hapticFeedbackEnabled)      // default
    }
}
```

~6 testů.

### 7. Resilience proti misconfiguration

Pokud uživatel nainstaluje host appku ale entitlements jsou rozbité (provisioning bug), `UserDefaults(suiteName:)` vrátí `nil`. V `AppGroupStore.init` v DEBUG fatalError, v RELEASE fallback na `.standard`. Fallback znamená, že host appka i extension čtou ze *separátních* UserDefaults (každý proces má svůj) — cross-process toggling nepůjde fungovat, ale klávesnice nepadne.

V RELEASE-mode toto je preferable nad crash. Žádná production aplikace by neměla padat kvůli misconfig.

## Mimo scope

- Cross-process observability (Darwin notifications) — Future task `future-cross-proc-settings-observation.md`.
- Settings migration (např. když rename `showNumberRow` → `numberRowVisible`). v1.0 první release, nic k migrate.
- Codable model storage. v1.0 jen Bool. Future taskem (favorite emojis) přijdou strings array → potřebuje `Codable` serialization. To je v dedicated Future tasku, ne tady.

## Hotovo když

- `AppGroupStore` v `KeyboCore/Sources/Shared/`.
- `AppGroupStoreKey` enum s `showNumberRow`, `hapticFeedbackEnabled`.
- Typed accessors `.showNumberRow` a `.hapticFeedbackEnabled`.
- `KeyboardViewController.viewWillAppear` re-reads `showNumberRow` ze store.
- `UIKitHaptics.isEnabled` closure čte `hapticFeedbackEnabled` ze store.
- 6 unit testů green.
- Manuální test: změnit toggle v host appce (po dokončení tasku 12) → re-open klávesnice → změna se projeví.

## Rizika

- **Default values divergence** — pokud někde defaultně čteme `false` místo `true`, klávesnice po prvním spuštění bez nastavení v host appce nebude mít number row / haptic. Striktně držet default `true` v obou typed accessors.
- **Suite name typo** — `appGroupSuiteName` konstanta musí PŘESNĚ odpovídat entitlements deklaraci. Jedno písmeno mimo = silent fail. V DEBUG to chytíme fatalErrorem.
- **`UserDefaults.synchronize` deprecation** — od iOS 12 deprecated, nevolat. iOS sync automaticky.

## Reference

- `~/Development/WidgetCoin/WidgetCoinCore/Sources/Shared/AppGroupStore.swift` — vzor
- `~/Development/WidgetCoin/WidgetCoinCore/Sources/Models/FiatCurrency.swift` (sekce `fromAppGroupStore`) — vzor typed accessor
- Apple: UserDefaults suite — <https://developer.apple.com/documentation/foundation/userdefaults/1409957-init>

## Codex review

**Ano** — cross-process storage je easy to get subtly wrong, hlavně kolem default fallback a nil entitlements. Druhé oko se hodí.
