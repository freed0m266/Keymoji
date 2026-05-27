# 33 — Refactor: splitnout Favorites na 2 moduly, rename + sjednotit ViewModel pattern

**Status:** Todo

**Priorita:** Tech debt · **Úsilí:** M · **Dopad:** None (čistý refactor, žádná uživatelská změna)

## Souhrn

Tři související věci, které drhnou na existujících feature modulech:

**(A) Favorites editor a Emoji catalog picker patří do dvou samostatných feature modulů.** Konvence projektu (viz [CLAUDE.md](CLAUDE.md) → *Feature Module Structure*) říká, že **každá obrazovka je samostatná feature**. Aktuálně máme:

| Obrazovka | Stav |
|---|---|
| Settings | ✅ vlastní module `Features/Settings` |
| About | ✅ vlastní module `Features/About` |
| EmojiCodes | ✅ vlastní module `Features/EmojiCodes` |
| Onboarding | ✅ vlastní module `Features/Onboarding` |
| **FavoritesEditor** | ❌ subfolder uvnitř `Features/Settings/Sources/FavoritesEditor/` |
| **EmojiCatalogPicker** | ❌ stejný subfolder, navíc `internal` typ |

Obojí byly přidány mimo `scripts/new_feature.sh` workflow a nemají vlastní snapshot test target.

**(B) Rename `FavoritesEditor` → `FavoriteEmojisEditor`.** Aktuální název je dvojznačný — „favorites" může být cokoliv. Nový název jasně říká, co se edituje. Aplikuje se napříč: filename, struct, protocol, factory, mock.

**(C) ViewModels nedodržují canonical pattern.** Šablona [Features/Example/Sources/ExampleViewModel.swift](Features/Example/Sources/ExampleViewModel.swift) ukazuje, jak má VM vypadat — a žádný z reálných VM (About, Settings, EmojiCodes, Onboarding, FavoriteEmojisEditor) ten pattern nedodržuje. Konkrétní deviace níže v Scope.

**Logika app se nemění** — pouze přesun souborů, modifikátory viditelnosti, factory return typy, MARK komentáře a přejmenování symbolů. Žádné API změny, žádné UX změny, žádné nové stringy, žádné renamování L10n klíčů.

## Canonical VM pattern (z Example)

Reference: [ExampleViewModel.swift](Features/Example/Sources/ExampleViewModel.swift), [BaseViewModel.swift](KeyboCore/Sources/ViewModels/BaseViewModel.swift) pro MARK strukturu.

```swift
@MainActor
public protocol FooViewModeling: Observable, AnyObject {
    // properties + methods
}

@MainActor
public func fooVM() -> some FooViewModeling {
    FooViewModel()
}

@Observable
final class FooViewModel: BaseViewModel, FooViewModeling {

    // stored properties (any visibility)

    // MARK: - Init

    init(...) {
        ...
        super.init()
    }

    // MARK: - Public API

    func somePublicOrInternalMethod() { ... }

    // MARK: - Private API

    private func somePrivateMethod() { ... }
}
```

Pravidla:

1. **Factory vrací `some <Name>ViewModeling`** (opaque protocol type), **ne** konkrétní `<Name>ViewModel`.
2. **Konkrétní `<Name>ViewModel` class je `internal`** (žádné `public`).
3. **Stored properties, init, methods jsou `internal`** (žádné `public`). Mock i call sites závisí jen na protokolu, který je `public`.
4. **Žádný `override init()`** — pokud VM nepotřebuje nic injectovat, prostě se zdědí `BaseViewModel.init()`. Žádný no-op override.
5. **MARK sekce** v tomto pořadí: `// MARK: - Init`, `// MARK: - Public API` (public + internal funkce), `// MARK: - Private API` (private funkce). Stored properties patří před init bez vlastního MARKu (mirror [BaseViewModel](KeyboCore/Sources/ViewModels/BaseViewModel.swift)).
6. **Protocol zůstává `public`** — to je API surface feature modulu, ten musí ven.
7. **Mocky (`<Name>ViewModelMock`) zůstávají `public`** — implementují protokol přímo, ne dědí concrete VM, takže internal concrete je nikdy nezasáhne.

## Scope

### 1. Vytvořit dva nové feature moduly přes script

```bash
./scripts/new_feature.sh EmojiCatalogPicker
./scripts/new_feature.sh FavoriteEmojisEditor
```

Pro každý feature script automaticky:
- Vytvoří `Features/<Name>/` ze šablony `Features/Example/` (Sources/, Testing/, Tests/).
- Vyrobí `Tuist/ProjectDescriptionHelpers/Targets/Features/<Name>.swift` s default deps `core + design + resources`.
- Vloží `<name>` (camelCase: `emojiCatalogPicker`, `favoriteEmojisEditor`) do `let features: [Feature]` v `Project.swift` (abecedně).
- Vloží `.target(<name>)` do `App.swift` dependencies (abecedně).

**Po doběhnutí scriptu pro každý nový feature** smazat ze `Sources/` placeholder `<Name>View.swift` a `<Name>ViewModel.swift`, a smazat `<Name>Dependencies.swift` (oba moduly bez DI containeru — VM si singletony bere přes default init params). Ze `Testing/` smazat placeholder mock.

> **EmojiCatalogPicker nemá VM** — je to stateless view se třemi inputy (`selectedEmojis`, `onToggle`, `onDone`). V Tuist manifestu nastavit `hasTesting: false` (nemáme co mockovat), v `Sources/` zůstane jen `EmojiCatalogPickerView.swift`, v `Tests/` jen `EmojiCatalogPickerSnapshots.swift`, žádný `Testing/` adresář.

### 2. Doplnit deps v Tuist manifestech nových modulů

#### 2a. `Tuist/.../Features/EmojiCatalogPicker.swift`

Picker používá `EmojiCatalog` z `KeyboardCore` a `L10n.Settings.Favorites.Picker.*` z `KeyboResources`.

```swift
public let emojiCatalogPicker = Feature(
    name: "EmojiCatalogPicker",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name),
        .target(name: keyboardCore.name)
    ],
    hasTesting: false
)
```

#### 2b. `Tuist/.../Features/FavoriteEmojisEditor.swift`

Editor používá `AppGroupStore`, `SettingsChangeNotifier` z `KeyboardCore`, a `EmojiCatalogPickerView` z nového `EmojiCatalogPicker` modulu.

```swift
public let favoriteEmojisEditor = Feature(
    name: "FavoriteEmojisEditor",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name),
        .target(name: keyboardCore.name),
        .target(emojiCatalogPicker)
    ]
)
```

### 3. Přesunout zdrojáky + rename

#### 3a. EmojiCatalogPicker

| Source | Destination |
|---|---|
| `Settings/Sources/FavoritesEditor/EmojiCatalogPickerView.swift` | `EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift` |

Změny v souboru:
- Header `//  Settings` → `//  EmojiCatalogPicker`.
- `struct EmojiCatalogPickerView: View` (řádek 16) → `public struct EmojiCatalogPickerView: View`.
- Pole `selectedEmojis / onToggle / onDone` → přidat `public`.
- Přidat `public init(selectedEmojis: Set<String>, onToggle: @escaping (String) -> Void, onDone: @escaping () -> Void)` (Swift nevygeneruje implicit memberwise init na `public struct` jako `public`).
- `var body` ponechat — Swift dovolí `public struct` mít `internal var body` přes `View` protocol requirement.

#### 3b. FavoriteEmojisEditor (rename + přesun)

| Source | Destination |
|---|---|
| `Settings/Sources/FavoritesEditor/FavoritesEditorView.swift` | `FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift` |
| `Settings/Sources/FavoritesEditor/FavoritesEditorViewModel.swift` | `FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift` |
| `Settings/Testing/FavoritesEditorViewModelMock.swift` | `FavoriteEmojisEditor/Testing/FavoriteEmojisEditorViewModelMock.swift` |

Smazat prázdný adresář `Settings/Sources/FavoritesEditor/`.

**Symbol rename** (search & replace v přesunutých souborech + v Settings):

| Starý symbol | Nový symbol |
|---|---|
| `FavoritesEditorView` | `FavoriteEmojisEditorView` |
| `FavoritesEditorViewModel` | `FavoriteEmojisEditorViewModel` |
| `FavoritesEditorViewModeling` | `FavoriteEmojisEditorViewModeling` |
| `favoritesEditorVM()` | `favoriteEmojisEditorVM()` |
| `FavoritesEditorViewModelMock` | `FavoriteEmojisEditorViewModelMock` |

Headers v souborech: `//  Settings` → `//  FavoriteEmojisEditor`.

V `FavoriteEmojisEditorView.swift` přidat `import EmojiCatalogPicker` (kvůli `EmojiCatalogPickerView` v sheet bodě, řádek 49 původního souboru).

Lokalizační klíče `L10n.Settings.Favorites.*` **NEpřejmenovávat** — to je separátní change, mimo scope. `typealias Texts = L10n.Settings.Favorites` zůstává.

#### 3c. Smazat z Settings

| Soubor / adresář | Akce |
|---|---|
| `Features/Settings/Sources/FavoritesEditor/` | Smazat (po přesunu všech 3 souborů jinam) |
| `Features/Settings/Testing/FavoritesEditorViewModelMock.swift` | Smazat (přesunuto) |

### 4. Settings depend na FavoriteEmojisEditor

V [Tuist/.../Features/Settings.swift](Tuist/ProjectDescriptionHelpers/Targets/Features/Settings.swift) přidat `.target(favoriteEmojisEditor)` do dependencies (abecedně mezi `emojiCodes` a `onboarding`):

```swift
public let settings = Feature(
    name: "Settings",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name),
        .target(name: keyboardCore.name),
        .target(onboarding),
        .target(about),
        .target(emojiCodes),
        .target(favoriteEmojisEditor)
    ]
)
```

Settings **nemá** depend na `emojiCatalogPicker` přímo — picker je interní implementační detail editoru, který Settings nepoužívá. Tranzitivní dep stačí pro link-time, Swift module imports nejsou tranzitivní.

V [SettingsView.swift](Features/Settings/Sources/SettingsView.swift):
- Přidat `import FavoriteEmojisEditor` k existujícím `import About / EmojiCodes / Onboarding`.
- Na řádku 83 přejmenovat `FavoritesEditorView(viewModel: favoritesEditorVM())` → `FavoriteEmojisEditorView(viewModel: favoriteEmojisEditorVM())`.

### 5. Sjednotit ViewModel pattern napříč všemi features

Aplikovat canonical pattern (viz výše) na všechny VM: About, Settings, EmojiCodes, Onboarding, FavoriteEmojisEditor.

#### 5a. [AboutViewModel.swift](Features/About/Sources/AboutViewModel.swift)

| Problém | Akce |
|---|---|
| `public func aboutVM() -> AboutViewModel` (řádek 21) | Return type na `some AboutViewModeling` |
| `public final class AboutViewModel` (řádek 26) | Odebrat `public` |
| `public var versionString` (řádek 28) | Odebrat `public` |
| `public override init() { super.init() }` (řádek 34-36) | **Celé smazat** — BaseViewModel.init() se zdědí zadarmo |
| `public func openPrivacyPolicy` (řádek 38), `public func openSourceCode` (řádek 43) | Odebrat `public` |
| Chybí MARK sekce | `// MARK: - Public API` před `openPrivacyPolicy`. (`// MARK: - Init` vynechat, protože init už neexistuje. `// MARK: - Private API` vynechat, žádné private methody.) |

#### 5b. [SettingsViewModel.swift](Features/Settings/Sources/SettingsViewModel.swift)

| Problém | Akce |
|---|---|
| `public func settingsVM() -> SettingsViewModel` (řádek 22) | Return type na `some SettingsViewModeling` |
| `public final class SettingsViewModel` (řádek 27) | Odebrat `public` |
| `public var showNumberRow / hapticFeedbackEnabled / keyClickSoundEnabled / appearance / versionString` | Odebrat `public` (všech 5) |
| `public init(store:, notifier:)` (řádek 62) | Odebrat `public` |
| Chybí MARK sekce | `// MARK: - Init` před init, `// MARK: - Private API` před `makeVersionString`. (`// MARK: - Public API` vynechat, žádné non-private metody.) |

#### 5c. [EmojiCodesViewModel.swift](Features/EmojiCodes/Sources/EmojiCodesViewModel.swift)

| Problém | Akce |
|---|---|
| `public func emojiCodesVM() -> EmojiCodesViewModel` (řádek 36) | Return type na `some EmojiCodesViewModeling` |
| `public final class EmojiCodesViewModel` (řádek 41) | Odebrat `public` |
| `public var searchQuery`, `public private(set) var entries / copiedShortcode` | Odebrat `public` |
| `public init(table:, pasteboard:, toastDuration:)` (řádek 55) | Odebrat `public` |
| `public func copy(_:)` (řádek 70) | Odebrat `public` |
| Chybí MARK sekce | `// MARK: - Init`, `// MARK: - Public API` (před `copy`), `// MARK: - Private API` (před `recomputeEntries`). |

**Pozor:** `EmojiCodeEntry`, `PasteboardWriting`, `SystemPasteboard` (řádky 14-25, 94-104) **zůstávají `public`** — jsou součástí veřejného API modulu (protokol je odkazuje v signaturách, `SystemPasteboard` je default pro init).

#### 5d. [OnboardingViewModel.swift](Features/Onboarding/Sources/OnboardingViewModel.swift)

| Problém | Akce |
|---|---|
| Komentář na řádcích 24-26 *„Concrete view model is exposed publicly so the host app can hold a single instance in `@State`"* | **Smazat** — opaque return type `some OnboardingViewModeling` v `@State private var viewModel: ViewModel` (generic) funguje stejně dobře. Důvod nevolat factory per body re-render je *call site* (`@State` capture once), ne visibility VM. |
| `public func onboardingVM() -> OnboardingViewModel` (řádek 28) | Return type na `some OnboardingViewModeling` |
| `public final class OnboardingViewModel` (řádek 33) | Odebrat `public` |
| `public var currentStep`, `public private(set) var isKeyboardActivated` | Odebrat `public` |
| `public init(dependencies:)` (řádek 41) | Odebrat `public` |
| `public func didConfirmKeyboardAdded / didConfirmFullAccess / didFinishOnboarding / openSettings` | Odebrat `public` (všech 4) |
| Existující `// MARK: - Status polling` (řádek 69) | Sjednotit do canonical struktury: `// MARK: - Init` před init, `// MARK: - Public API` před `didConfirmKeyboardAdded`, `// MARK: - Private API` před `startPollingKeyboardStatus` (pokrývá `startPollingKeyboardStatus`, `refreshKeyboardStatus`, `detectKeyboardActivated`). |

#### 5e. `FavoriteEmojisEditorViewModel.swift` (po přesunu + rename)

| Problém | Akce |
|---|---|
| `public func favoriteEmojisEditorVM() -> FavoriteEmojisEditorViewModel` | Return type na `some FavoriteEmojisEditorViewModeling` |
| `public final class FavoriteEmojisEditorViewModel` | Odebrat `public` |
| `public private(set) var favorites` | Odebrat `public` |
| `public init(store:, notifier:)` | Odebrat `public` |
| `public func toggle / remove / move` | Odebrat `public` |
| Chybí MARK sekce | `// MARK: - Init`, `// MARK: - Public API` (před `toggle`), `// MARK: - Private API` (před `persist`). |

### 6. Snapshot testy pro nové moduly

#### 6a. `Features/FavoriteEmojisEditor/Tests/FavoriteEmojisEditorSnapshots.swift`

- **`testFavoriteEmojisEditor_withFavorites_dark`** — mock `["❤️", "😀", "🚀", "🎉", "🐶"]` (stejné jako `#Preview "With favorites"` v původním [FavoritesEditorView.swift:96](Features/Settings/Sources/FavoritesEditor/FavoritesEditorView.swift:96)).
- **`testFavoriteEmojisEditor_empty_dark`** — `favorites: []`, ověří `ContentUnavailableView`.

#### 6b. `Features/EmojiCatalogPicker/Tests/EmojiCatalogPickerSnapshots.swift`

- **`testEmojiCatalogPicker_noSelection_dark`** — picker s prázdným `selectedEmojis`.
- **`testEmojiCatalogPicker_someSelected_dark`** — picker s ~5 selected, ověří checkmark badges.

Použít `AssertSnapshot` helper z `KeyboTesting` (viz [SettingsSnapshots.swift:56-77](Features/Settings/Tests/SettingsSnapshots.swift:56)). Wrap views v `NavigationStack` kvůli toolbaru. `SettingsSnapshots` ponechat beze změny.

### 7. Ověřit, že nic nespadlo

- `tuist generate` projde bez warningu.
- Xcode build pass (Settings vidí `FavoriteEmojisEditorView` přes nový `import FavoriteEmojisEditor`; FavoriteEmojisEditor vidí `EmojiCatalogPickerView` přes `import EmojiCatalogPicker`; všechny call sites factory funkcí typecheckují s opaque return).
- Všechny existující snapshot suites (Settings, About, EmojiCodes, Onboarding) projedou beze změny obrázků.

## Mimo scope

- **Rozdělit existující moduly** (About/EmojiCodes/Settings/Onboarding) na sub-features. Mají jednu obrazovku, jeden module — to je správně.
- **Retroaktivně přegenerovat About/EmojiCodes/Settings/Onboarding přes `new_feature.sh`.** Strukturu už mají, jen historicky nevznikly přes script. Předělávat je je churn bez hodnoty — script je nástroj pro **nové** features, ne purity check. VM pattern fix (sekce 5) řeší to, co je reálně rozbité.
- **Přidat `<Feature>Dependencies.swift` všude.** Onboarding ho má (real DI use case), Example ho má jako šablonu. Ostatní (About, Settings, EmojiCodes, FavoriteEmojisEditor, EmojiCatalogPicker) ho nepotřebují — VM si singletony berou přes default init parametry. Nepřidávat prázdné Dependencies struct kvůli konzistenci.
- **Změnit `BaseViewModel`.** Zůstává `open class` s `public init()` (musí, aby ho subclassy v jiných modulech mohly subclassovat).
- **Změnit visibility `<Name>ViewModeling` protokolů.** Zůstávají `public` — to je API modulu.
- **Změnit visibility mocků (`<Name>ViewModelMock`).** Zůstávají `public` — používané z previews jiných modulů.
- **Přejmenovat L10n klíče** `settings.favorites.*` → `favoriteEmojisEditor.*`. Funkční změna nula, riziko překlepu velké, mimo scope. Klíče zůstávají, `typealias Texts = L10n.Settings.Favorites` v `FavoriteEmojisEditorView` zůstává. `L10n.Settings.Favorites.Picker.*` v `EmojiCatalogPickerView` analogicky zůstává.
- **Měnit UX, ikony, layout, copy.** Nula viditelných změn pro uživatele.
- **Přidávat unit testy logiky VM** (ne snapshot). Mimo scope.

## Závislosti

- Task 18 (Favorite emojis editor) — FavoritesEditor kód musí existovat. **Hotovo**.
- Task 19 (Slack emoji typing) — `EmojiCatalog` v `KeyboardCore` musí existovat. **Hotovo**.

## Hotovo když

**Module split:**
- `Features/EmojiCatalogPicker/` existuje s `Sources/EmojiCatalogPickerView.swift` a `Tests/EmojiCatalogPickerSnapshots.swift` (žádný `Testing/`).
- `Features/FavoriteEmojisEditor/` existuje s `Sources/` (view + VM), `Testing/<...>Mock.swift`, `Tests/<...>Snapshots.swift`.
- `Tuist/.../Features/EmojiCatalogPicker.swift` má deps `core + design + resources + keyboardCore`, `hasTesting: false`.
- `Tuist/.../Features/FavoriteEmojisEditor.swift` má deps `core + design + resources + keyboardCore + emojiCatalogPicker`.
- `Features/Settings/Sources/FavoritesEditor/` neexistuje.
- `Features/Settings/Testing/FavoritesEditorViewModelMock.swift` neexistuje.
- `Settings.swift` Tuist target má `.target(favoriteEmojisEditor)`; `SettingsView.swift` má `import FavoriteEmojisEditor`.

**Rename:**
- `grep -rn "FavoritesEditor" Features/` vrací prázdno.
- `grep -rn "favoritesEditor" Features/` vrací prázdno.
- Všechny symboly `FavoriteEmojisEditor*` / `favoriteEmojisEditorVM`.

**VM pattern:**
- Žádný factory (`aboutVM`, `settingsVM`, `emojiCodesVM`, `onboardingVM`, `favoriteEmojisEditorVM`) nevrací konkrétní `<Name>ViewModel` — všechny vrací `some <Name>ViewModeling`.
- Žádná konkrétní `<Name>ViewModel` class není `public`.
- `grep -rn "override init" Features/` vrací prázdno.
- Každý VM má MARK sekce `// MARK: - Init` (kde existuje custom init), `// MARK: - Public API` (kde existují non-private methody), `// MARK: - Private API` (kde existují private methody).

**Snapshoty:**
- 2 testy v `FavoriteEmojisEditorSnapshots`, 2 testy v `EmojiCatalogPickerSnapshots`, všechny pass.
- Settings/About/EmojiCodes/Onboarding snapshoty pass beze změny.

**Globální sanity:**
- `tuist generate` projde, Xcode build pass.
- Manuální smoke test v simulátoru: Settings → Favorite emojis row → editor otevře → "+" → catalog picker → toggle 2 emojis → done → list ukazuje 2 nové favorites. About a Onboarding sheety se otevřou normálně.

## Reference

- [scripts/new_feature.sh](scripts/new_feature.sh) — generátor (kopíruje Example, přejmenuje, vloží do Project.swift + App.swift)
- [Features/Example/Sources/ExampleViewModel.swift](Features/Example/Sources/ExampleViewModel.swift) — **canonical VM pattern** k zrcadlení
- [KeyboCore/Sources/ViewModels/BaseViewModel.swift](KeyboCore/Sources/ViewModels/BaseViewModel.swift) — referenční MARK struktura
- [Tuist/.../Features/EmojiCodes.swift](Tuist/ProjectDescriptionHelpers/Targets/Features/EmojiCodes.swift) — vzor Tuist manifestu s `keyboardCore`
- [Tuist/.../Features/Settings.swift](Tuist/ProjectDescriptionHelpers/Targets/Features/Settings.swift) — sem přidat `.target(favoriteEmojisEditor)`
- [Features/Settings/Sources/FavoritesEditor/](Features/Settings/Sources/FavoritesEditor/) — zdroj přesunu
- [CLAUDE.md](CLAUDE.md) — *Feature Module Structure* a *Code Style* konvence
