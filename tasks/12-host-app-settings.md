# 12 — Host app Settings screen

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Hlavní (a v v1.0 jediná) plně funkční obrazovka host appky kromě onboardingu. Form-style UI s toggly pro klávesnicové preferences, link na onboarding znovu otevřít, link na About. Žádný custom design, plain SwiftUI `Form`.

## Kontext

- Defaultní landing screen po dokončení onboardingu.
- Preferences žijí v `AppGroupStore` z task 10.
- About link na task 13.
- Onboarding znovu otevíratelný — viz task 11 scope 8.

## Scope

### 1. Settings feature framework

`Features/Settings/` přes `Feature` factory analogicky onboarding (task 11 scope 1):

```swift
public let settings = Feature(
    name: "Settings",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name),
        .target(name: onboarding.target.name)        // pro otevření onboardingu sheet-modal
    ]
)
```

Adresářová struktura jako u Onboardingu (Sources/Testing/Tests).

### 2. `SettingsViewModeling`

```swift
@MainActor
public protocol SettingsViewModeling {
    var showNumberRow: Bool { get set }
    var hapticFeedbackEnabled: Bool { get set }
    var versionString: String { get }
    func openOnboarding()
    func openAbout()
}
```

### 3. `SettingsViewModel`

```swift
@Observable
@MainActor
public final class SettingsViewModel: SettingsViewModeling {
    public var showNumberRow: Bool {
        didSet {
            store.showNumberRow = showNumberRow
        }
    }

    public var hapticFeedbackEnabled: Bool {
        didSet {
            store.hapticFeedbackEnabled = hapticFeedbackEnabled
        }
    }

    public let versionString: String

    private let store: AppGroupStore
    private let navigation: SettingsNavigating

    public init(dependencies: SettingsDependencies) {
        self.store = dependencies.store
        self.navigation = dependencies.navigation
        self.showNumberRow = dependencies.store.showNumberRow
        self.hapticFeedbackEnabled = dependencies.store.hapticFeedbackEnabled
        self.versionString = Self.makeVersionString()
    }

    public func openOnboarding() { navigation.openOnboarding() }
    public func openAbout() { navigation.openAbout() }

    private static func makeVersionString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
```

### 4. `SettingsView`

```swift
public struct SettingsView<ViewModel: SettingsViewModeling>: View {
    @State private var viewModel: ViewModel

    typealias Texts = L10n.Settings

    public init(viewModel: ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Form {
                keyboardSection
                supportSection
                aboutSection
            }
            .navigationTitle(Texts.title)
        }
    }

    private var keyboardSection: some View {
        Section {
            Toggle(Texts.showNumberRow, isOn: $viewModel.showNumberRow)
            Toggle(Texts.hapticFeedback, isOn: $viewModel.hapticFeedbackEnabled)
        } header: {
            Text(Texts.keyboardHeader)
        } footer: {
            Text(Texts.hapticFooter)               // „Requires Allow Full Access in iOS Settings."
        }
    }

    private var supportSection: some View {
        Section {
            Button(Texts.setupInstructions, action: viewModel.openOnboarding)
        }
    }

    private var aboutSection: some View {
        Section {
            Button(Texts.about, action: viewModel.openAbout)
            Text(Texts.versionLabel(viewModel.versionString))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

### 5. `SettingsDependencies` a navigation

```swift
public struct SettingsDependencies: Sendable {
    public let store: AppGroupStore
    public let navigation: SettingsNavigating

    public init(store: AppGroupStore = .shared, navigation: SettingsNavigating) {
        self.store = store
        self.navigation = navigation
    }
}

public protocol SettingsNavigating: Sendable {
    func openOnboarding()
    func openAbout()
}
```

Konkrétní `SettingsNavigator` v host appce (`Keymoji/Sources/App/SettingsNavigator.swift`):

Drží reference na sheet state v root view (`RootView`):

```swift
final class SettingsNavigator: SettingsNavigating {
    let onboardingPresented = CurrentValueSubject<Bool, Never>(false)
    let aboutPresented = CurrentValueSubject<Bool, Never>(false)

    func openOnboarding() { onboardingPresented.value = true }
    func openAbout() { aboutPresented.value = true }
}
```

Alternativně přes `@State Bool` v `RootView` propagované jako binding. SwiftUI sheets management. Konkrétní pattern volit podle příjemnosti — `Combine.CurrentValueSubject` je trochu over-engineered pro 2 sheety. Doporučení: jednoduchý `@State var presentedSheet: SheetKind?` enum.

```swift
enum SheetKind: Identifiable {
    case onboarding, about
    var id: String { String(describing: self) }
}

@State private var presentedSheet: SheetKind?

var body: some View {
    SettingsView(viewModel: vm)
        .sheet(item: $presentedSheet) { kind in
            switch kind {
            case .onboarding: OnboardingView(viewModel: dependencies.onboardingVM())
            case .about:      AboutView(viewModel: dependencies.aboutVM())
            }
        }
}
```

`SettingsNavigator` pak je struct s closures setting `presentedSheet`:

```swift
struct SettingsNavigator: SettingsNavigating {
    let openOnboardingAction: () -> Void
    let openAboutAction: () -> Void

    func openOnboarding() { openOnboardingAction() }
    func openAbout() { openAboutAction() }
}
```

V `RootView`:

```swift
SettingsNavigator(
    openOnboardingAction: { presentedSheet = .onboarding },
    openAboutAction: { presentedSheet = .about }
)
```

### 6. Lokalizace

`KeymojiResources/Resources/en.lproj/Localizable.strings`:

```strings
"settings.title" = "Keymoji";

"settings.keyboard.header" = "Keyboard";
"settings.keyboard.showNumberRow" = "Always show number row";
"settings.keyboard.hapticFeedback" = "Haptic feedback";
"settings.keyboard.hapticFooter" = "Haptic feedback requires Allow Full Access in iOS Settings → General → Keyboards → Keymoji.";

"settings.setupInstructions" = "Setup instructions";
"settings.about" = "About";
"settings.versionLabel" = "Version %@";
```

### 7. `SettingsViewModelMock`

```swift
#if DEBUG
@Observable
@MainActor
public final class SettingsViewModelMock: SettingsViewModeling {
    public var showNumberRow: Bool = true
    public var hapticFeedbackEnabled: Bool = true
    public var versionString: String = "1.0 (1)"

    public func openOnboarding() {}
    public func openAbout() {}
}
#endif
```

### 8. Snapshot testy

`Features/Settings/Tests/SettingsSnapshots.swift`:

- Default state (all toggles ON) × dark + light = 2 snapshoty
- All toggles OFF × dark = 1 snapshot

~3 snapshoty.

### 9. AppDependency rozšíření

```swift
extension AppDependency {
    public func settingsVM(navigation: any SettingsNavigating) -> SettingsViewModel {
        SettingsViewModel(
            dependencies: SettingsDependencies(navigation: navigation)
        )
    }
}
```

### 10. Manuální test

- Otevřít host appku (po onboarding done).
- Vidět Settings screen s 2 toggly + 2 buttons.
- Kliknout „Setup instructions" → onboarding sheet otevřený, swipeable.
- Kliknout „About" → about screen.
- Toggle „Always show number row" off → klávesnice si toho **při dalším otevření** všimne (přes `viewWillAppear` re-read v task 10).
- Toggle „Haptic feedback" off → příští typing nemá haptic.

## Mimo scope

- Reset to defaults button. Nice-to-have, ne v v1.0.
- Theme picker (light/dark/system) — Future task `future-light-dark-override.md`.
- Sound feedback toggle — Future task `future-sound-feedback.md`.
- Long-press delay slider — wontfix.
- Emoji favorites editor — Future.
- Žádný in-app rating prompt, žádné Support email link.

## Hotovo když

- `Features/Settings/` framework existuje a buildne.
- `SettingsView` zobrazí Form s 2 toggly + 2 buttons + version řádek.
- Toggling změní hodnotu v `AppGroupStore` okamžitě.
- „Setup instructions" otevírá onboarding v sheet.
- „About" otevírá about (task 13) v sheet.
- 3 snapshot testy green.
- Manuální test: toggle v Settings → klávesnice po re-open respektuje hodnotu.

## Rizika

- **Sheet dependencies** — `OnboardingView` a `AboutView` musí být buildovatelné v Settings test target, takže `Settings` framework dep na `Onboarding` a `About` features. Cíl v `Tuist/.../Targets/Features/Settings.swift` musí být explicitní.
- **Version string fallback** „0.0 (0)" v případě, že `Bundle.main` Info.plist nemá keys. To by mělo selhat na build (`SetVersions.sh` script v `BuildPhases/`), ale fallback je safety net.

## Reference

- `~/Development/WidgetCoin/Features/Settings/Sources/SettingsView.swift` — vzor structure
- `~/Development/WidgetCoin/Features/Settings/Sources/SettingsViewModel.swift` — vzor VM
- Apple SwiftUI Form documentation

## Codex review

**Skip** — standardní SwiftUI Form s minimálním VM. Bug riziko nízké, manuální test pokryje.
