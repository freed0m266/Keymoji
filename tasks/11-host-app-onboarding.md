# 11 — Host app onboarding (3-step flow)

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** L · **Dopad:** High

## Cíl

Plnohodnotný onboarding flow v host appce, který provede uživatele třemi kroky aktivace klávesnice. Po prvním spuštění appky se onboarding zobrazí; po dokončení (nebo přeskočení) ho znovu neukazujeme. Z hlavního Settings screen jde onboarding znovu otevřít („Setup instructions").

## Kontext

- Klávesnice v iOS vyžaduje 3 manuální kroky od uživatele:
  1. **Add Keyboard**: Settings.app → General → Keyboards → Keyboards → Add New Keyboard → Keybo.
  2. **Allow Full Access**: Settings.app → General → Keyboards → Keybo → Allow Full Access.
  3. **Select keyboard during typing**: v jakékoliv appce → tap globe key → vybrat Keybo.
- Detekce stavu:
  - Krok 1 *lze* detekovat přes `UITextInputMode.activeInputModes` — zda obsahuje input mode s naším extension bundle ID.
  - Krok 2 (Full Access) *nelze* spolehlivě detekovat. Nepřímo: pokus zapsat do shared App Group UserDefaults — pokud success, máme Full Access. Toto má edge cases (Full Access ovlivňuje další věci než jen storage). Pro v1.0 onboarding zobrazí krok 2 jako „já jsem to udělal" tlačítko, ne automatic detection.
  - Krok 3 nedetekujeme — uživatel ho udělá sám až bude potřebovat.
- Onboarding bydlí v `Features/Onboarding/` jako standardní Keybo feature framework (přes `Feature` factory v `Tuist/ProjectDescriptionHelpers/Targets/Feature.swift`).

## Scope

### 1. Onboarding feature framework

Vytvořit `Features/Onboarding/` přes `Feature(name: "Onboarding", ...)` v `Tuist/ProjectDescriptionHelpers/Targets/Features/Onboarding.swift`:

```swift
public let onboarding = Feature(
    name: "Onboarding",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name)
    ]
)
```

Registrovat v root `Project.swift` `features:` array.

Adresářová struktura:

```
Features/Onboarding/
├── Sources/
│   ├── OnboardingView.swift
│   ├── OnboardingViewModel.swift
│   ├── OnboardingDependencies.swift
│   └── OnboardingStep.swift
├── Testing/
│   └── OnboardingViewModelMock.swift
└── Tests/
    └── OnboardingSnapshots.swift
```

### 2. `OnboardingViewModel`

`Features/Onboarding/Sources/OnboardingViewModel.swift`:

```swift
@MainActor
public protocol OnboardingViewModeling {
    var currentStep: OnboardingStep { get }
    var isKeyboardActivated: Bool { get }
    func didConfirmKeyboardAdded()
    func didConfirmFullAccess()
    func didFinishOnboarding()
    func openSettings()
}
```

```swift
public enum OnboardingStep: Sendable, CaseIterable {
    case addKeyboard
    case allowFullAccess
    case selectKeyboard
}
```

Konkrétní `OnboardingViewModel`:

```swift
@Observable
@MainActor
public final class OnboardingViewModel: OnboardingViewModeling {
    public var currentStep: OnboardingStep = .addKeyboard
    public private(set) var isKeyboardActivated: Bool = false

    private let dependencies: OnboardingDependencies
    private var refreshTask: Task<Void, Never>?

    public init(dependencies: OnboardingDependencies) {
        self.dependencies = dependencies
        Task { @MainActor in
            await pollKeyboardStatusContinuously()
        }
    }

    public func didConfirmKeyboardAdded() {
        currentStep = .allowFullAccess
    }

    public func didConfirmFullAccess() {
        currentStep = .selectKeyboard
    }

    public func didFinishOnboarding() {
        dependencies.preferences.markOnboardingComplete()
    }

    public func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func pollKeyboardStatusContinuously() async {
        while !Task.isCancelled {
            isKeyboardActivated = checkKeyboardActivated()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func checkKeyboardActivated() -> Bool {
        UITextInputMode.activeInputModes
            .compactMap { $0.value(forKey: "identifier") as? String }
            .contains { $0.contains("com.freedommartin.keybo.keyboard") }
    }
}
```

Detekce krok 1 přes `UITextInputMode.activeInputModes` — non-public API workaround (KVC `value(forKey: "identifier")`). Apple to v keyboard tutorials zmiňuje. Pokud `value(forKey:)` byl by problém pro App Store review, fallback je: nedetekovat automaticky, mít „Done" tlačítko v každém kroku.

**Alternativně bezpečnější (bez KVC):**

```swift
private func checkKeyboardActivated() -> Bool {
    // Bezpečný: jen check že existuje > 1 active input mode (default je system).
    // Nepřesné — když uživatel přidá libovolnou klávesnici, detektujeme ji.
    UITextInputMode.activeInputModes.count > 1
}
```

**Doporučení:** použít safer variantu (count > 1) v v1.0. Pokud user přidá *jinou* third-party klávesnici, false positive — `currentStep` skočí na `.allowFullAccess` zbytečně. UX edge, není to závažné. KVC variant se může později přidat pokud bude potřeba precise detection.

### 3. `OnboardingDependencies`

```swift
public struct OnboardingDependencies: Sendable {
    public let preferences: OnboardingPreferencesProviding

    public init(preferences: OnboardingPreferencesProviding) {
        self.preferences = preferences
    }
}

public protocol OnboardingPreferencesProviding: Sendable {
    var isOnboardingComplete: Bool { get }
    func markOnboardingComplete()
}
```

Implementace `OnboardingPreferencesProviding` v `KeyboCore` — postaveno na `AppGroupStore` z task 10:

```swift
public struct OnboardingPreferences: OnboardingPreferencesProviding {
    private let store = AppGroupStore.shared

    public init() {}

    public var isOnboardingComplete: Bool {
        store.bool(forKey: .onboardingComplete, default: false)
    }

    public func markOnboardingComplete() {
        store.setBool(true, forKey: .onboardingComplete)
    }
}
```

Přidat `onboardingComplete` do `AppGroupStoreKey` enum (task 10 ho ještě neměl).

### 4. `OnboardingView`

`Features/Onboarding/Sources/OnboardingView.swift`:

```swift
public struct OnboardingView<ViewModel: OnboardingViewModeling>: View {
    @State private var viewModel: ViewModel

    typealias Texts = L10n.Onboarding

    public init(viewModel: ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        TabView(selection: $viewModel.currentStep) {
            stepView(.addKeyboard).tag(OnboardingStep.addKeyboard)
            stepView(.allowFullAccess).tag(OnboardingStep.allowFullAccess)
            stepView(.selectKeyboard).tag(OnboardingStep.selectKeyboard)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        switch step {
        case .addKeyboard:    AddKeyboardStepView(viewModel: viewModel)
        case .allowFullAccess: AllowFullAccessStepView(viewModel: viewModel)
        case .selectKeyboard:  SelectKeyboardStepView(viewModel: viewModel)
        }
    }
}
```

Layout per step:

- Velký nadpis (Texts.step1Title, etc.)
- Krátký popis (Texts.step1Description, ...)
- Visual placeholder (screenshot iOS Settings → třeba jen ilustrace, nedělat actual screenshot)
- Primary CTA — „Open Settings" (volá `openSettings()`)
- Secondary CTA — „I've done this, next step" (volá `didConfirmKeyboardAdded()` apod.)
- Footer indikátor (1/3, 2/3, 3/3)
- Na step 1: pokud `isKeyboardActivated == true`, auto-advance na step 2 + zobrazit zelený checkmark.

### 5. Konkrétní step views

Tři separate views, každý s vlastním obsahem. Pro stručnost:

**Step 1 — Add Keyboard:**

- Headline: „Add Keybo to your keyboards"
- Body: „Open Settings → General → Keyboards → Keyboards → Add New Keyboard → Keybo"
- CTA: „Open Settings" (open `UIApplication.openSettingsURLString`)
- Status (live): `viewModel.isKeyboardActivated` → checkmark ✓ + auto-advance.

**Step 2 — Allow Full Access:**

- Headline: „Enable Full Access for haptic feedback"
- Body: „In Settings → General → Keyboards → Keybo, turn on Allow Full Access. Keybo does not collect any data."
- Footer (důležité): „Why this is needed: iOS requires Full Access for haptic feedback in keyboards. Keybo doesn't access the internet, doesn't sync, doesn't collect typing data."
- CTA: „Open Settings"
- Secondary: „I've done this" → advance to step 3
- Žádná auto-detekce — uživatel musí klepnout na „I've done this".

**Step 3 — Select Keybo:**

- Headline: „Switch to Keybo when typing"
- Body: „In any text field, tap the globe icon on your keyboard and select Keybo."
- CTA: „Done" → volá `didFinishOnboarding()`, dismiss onboarding.
- Footer: „You can re-open this guide later from Settings."

### 6. Lokalizace

`KeyboResources/Resources/en.lproj/Localizable.strings`:

```strings
"onboarding.step1.title" = "Add Keybo to your keyboards";
"onboarding.step1.description" = "Open Settings → General → Keyboards → Keyboards → Add New Keyboard → Keybo";
"onboarding.step1.cta" = "Open Settings";

"onboarding.step2.title" = "Enable Full Access for haptic feedback";
"onboarding.step2.description" = "In Settings → General → Keyboards → Keybo, turn on Allow Full Access.";
"onboarding.step2.privacy" = "Why this is needed: iOS requires Full Access for haptic feedback in keyboards. Keybo doesn't access the internet, doesn't sync, doesn't collect typing data.";
"onboarding.step2.cta" = "Open Settings";
"onboarding.step2.confirm" = "I've done this";

"onboarding.step3.title" = "Switch to Keybo when typing";
"onboarding.step3.description" = "In any text field, tap the globe icon on your keyboard and select Keybo.";
"onboarding.step3.done" = "Done";
"onboarding.step3.footer" = "You can re-open this guide later from Settings.";
```

Po `tuist generate` se vygeneruje `L10n.Onboarding.step1Title` atd. (přes Tuist resource synthesizer).

### 7. Integration v root App

`Keybo/Sources/App/KeyboApp.swift` (existující scaffold přejmenovaný z `TemplateApp` v rámci renaming):

```swift
@main
struct KeyboApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    private let prefs = OnboardingPreferences()

    @State private var hasFinishedOnboarding: Bool

    init() {
        _hasFinishedOnboarding = State(initialValue: OnboardingPreferences().isOnboardingComplete)
    }

    var body: some View {
        if hasFinishedOnboarding {
            // Main content — Settings screen z tasku 12
            SettingsView(viewModel: SettingsViewModel(...))
        } else {
            OnboardingView(viewModel: dependencies.onboardingVM())
                .onDisappear {
                    hasFinishedOnboarding = prefs.isOnboardingComplete
                }
        }
    }
}
```

### 8. „Setup instructions" z hlavního Settings

V `SettingsView` (task 12) jedna row „Setup instructions" otevírá `OnboardingView` v sheet/modal. To umožní uživateli vrátit se k onboardingu kdyby chtěl.

### 9. `OnboardingViewModelMock` pro previews a snapshoty

`Features/Onboarding/Testing/OnboardingViewModelMock.swift`:

```swift
#if DEBUG
@Observable
@MainActor
public final class OnboardingViewModelMock: OnboardingViewModeling {
    public var currentStep: OnboardingStep
    public var isKeyboardActivated: Bool

    public init(currentStep: OnboardingStep = .addKeyboard, isKeyboardActivated: Bool = false) {
        self.currentStep = currentStep
        self.isKeyboardActivated = isKeyboardActivated
    }

    public func didConfirmKeyboardAdded() { currentStep = .allowFullAccess }
    public func didConfirmFullAccess() { currentStep = .selectKeyboard }
    public func didFinishOnboarding() {}
    public func openSettings() {}
}
#endif
```

### 10. Snapshot testy

`Features/Onboarding/Tests/OnboardingSnapshots.swift`:

- Step 1 (addKeyboard, isKeyboardActivated: false) × dark + light = 2
- Step 1 (addKeyboard, isKeyboardActivated: true) × dark = 1 (zelený checkmark)
- Step 2 (allowFullAccess) × dark + light = 2
- Step 3 (selectKeyboard) × dark = 1

~6 snapshotů.

### 11. AppDependency rozšíření

V `KeyboCore/Sources/Dependencies/AppDependency.swift` (existující ze scaffold):

```swift
extension AppDependency {
    public func onboardingVM() -> OnboardingViewModel {
        OnboardingViewModel(
            dependencies: OnboardingDependencies(
                preferences: OnboardingPreferences()
            )
        )
    }
}
```

## Mimo scope

- A/B testing různých onboarding flowů.
- Skip onboarding tlačítko hned na první screen (uživatel musí buď projít flow nebo aspoň proklikat „I've done this" 2× — chceme aby si přečetl Full Access vysvětlení).
- Detekce Full Access stavu (viz scope 2). v1.0 = trust user button.
- Animace mezi steps (TabView page style má basic swipe, žádný custom).
- Localizace mimo en. Future task.

## Hotovo když

- `Features/Onboarding/` framework existuje a buildne.
- Při prvním spuštění host appky se zobrazí OnboardingView.
- 3 stránkový swipeable flow funguje.
- Step 1 auto-detect (přes `activeInputModes.count > 1`) přepne dál.
- „Open Settings" volá `UIApplication.openSettingsURLString` a funguje.
- Po dokončení (step 3 Done) se onboarding už nezobrazí (perzistence v App Group).
- „Setup instructions" v Settings (task 12) otevírá onboarding znovu.
- 6 snapshot testů green.
- Manuální test na zařízení: full flow projít, ověřit auto-detect step 1.

## Rizika

- **`UITextInputMode.activeInputModes` přesnost** — fallback `count > 1` má false-positive pokud user má jinou TP klávesnici. Pokud to bude annoying, refaktor na KVC variant a otestovat se App Store review akceptovatelnost.
- **`UIApplication.openSettingsURLString`** otevírá *root* Settings, ne specific keyboard page. Apple nepovoluje deep-link do specific Settings sekce. To je iOS limit, ne náš bug. Vysvětlit krokmi v copy.
- **Onboarding screen velikost na malých zařízeních** (iPhone SE) — content musí scroll-fit. Vyzkoušet na simulátoru SE.

## Reference

- `~/Development/WidgetCoin/Features/Onboarding/Sources/*` — vzor onboarding feature
- `~/Development/WidgetCoin/Features/Onboarding/Sources/OnboardingView.swift` (analogická struktura)
- Apple: UIApplication.openSettingsURLString — <https://developer.apple.com/documentation/uikit/uiapplication/1623042-opensettingsurlstring>

## Codex review

**Ano** — onboarding má hodně UX kódu, edge cases (state machine, dependency lifecycle, settings deep link). Review chytí drobnosti které samostatně nezapadají.
