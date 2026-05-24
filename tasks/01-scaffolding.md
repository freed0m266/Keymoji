# 01 — Scaffolding: Tuist targety, entitlements, Info.plist

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** Blokující

## Cíl

Připravit veškerou Tuist a Xcode infrastrukturu nutnou pro custom keyboard extension. Po dokončení tohoto tasku se projekt buildne, klávesnice se objeví v iOS Settings → General → Keyboards → Add New Keyboard, a uživatel ji může (prázdnou) přidat. Žádný keyboard kód se ještě neimplementuje — to je task 02 a dál.

## Kontext

- Stávající `Project.swift` registruje targety `app`, `core`, `design`, `resources`, `testing` + features. Chybí: `KeyboardCore`, `KeyboardUI`, `KeyboardExtension`.
- `Tuist/ProjectDescriptionHelpers/Targets/` obsahuje per-target soubory (`App.swift`, `Core.swift`, ...). Přidáme tři nové: `KeyboardCore.swift`, `KeyboardUI.swift`, `KeyboardExtension.swift`.
- Existing `Tuist/ProjectDescriptionHelpers/Targets/Feature.swift` factory generuje feature framework + test target — pro `KeyboardUI` toho využijeme analogicky (potřebujeme test target pro snapshoty).
- App Group ID: `group.com.freedommartin.keybo` (viz `tasks/README.md` rozhodnutí). I když ho v v1.0 začneme reálně používat až v tasku 10, entitlements se nastavují teď — pozdější úprava entitlements vyžaduje re-provisioning.
- `RequestsOpenAccess = YES` je v `Info.plist` extension targetu — bez něj se v iOS Settings nezobrazí toggle pro Full Access a haptika v tasku 08 nepoběží.

## Scope

### 1. Nový target `KeyboardCore` (framework, čistá logika)

`Tuist/ProjectDescriptionHelpers/Targets/KeyboardCore.swift`:

- Framework target, iPhone-only, bundle ID `\(appBundleId).keyboardcore`.
- Sources: `KeyboardCore/Sources/**`.
- Dependencies: pouze `resources` (pro `L10n`) a `core` (`KeyboCore` — bude se hodit pro shared utility později). Zatím **žádný SwiftUI import** v tomto frameworku — pure Swift + Foundation.
- Bez `SwiftLint` build phase script — drobné frameworky nepotřebují (analogicky `KeyboCore`).

Adresářová struktura na disku:

```
KeyboardCore/
├── Sources/
│   ├── Models/             # KeyboardLayout, Key, KeySymbol, ShiftState...
│   ├── Logic/              # ShiftStateMachine, AutoCapitalizer, InputDispatcher...
│   └── Public/             # public API entrypointy, factory funkce
└── Tests/                  # unit testy (vytvoří se v rámci tasků 02+)
```

`Tests/` adresář pro tento target potřebuje samostatný unit test target — viz bod 4.

### 2. Nový target `KeyboardUI` (Feature framework s testy)

`Tuist/ProjectDescriptionHelpers/Targets/KeyboardUI.swift`:

- Použít existující `Feature` factory z `Tuist/ProjectDescriptionHelpers/Targets/Feature.swift` (dostane test target zdarma). Ne, nemůžeme — `Feature` factory předpokládá adresář `Features/<Name>/...`, ale `KeyboardUI` je top-level framework, ne feature. Takže napsat dedicated `KeyboardUI` target ručně, analogicky `design`/`Design.swift`.
- Framework target, iPhone-only, bundle ID `\(appBundleId).keyboardui`.
- Sources: `KeyboardUI/Sources/**`.
- Dependencies: `core`, `design` (`KeyboUI`), `resources`, **`keyboardCore`**, `testing` v test targetu.
- `APPLICATION_EXTENSION_API_ONLY = YES` — protože KeyboardUI bude linkován z `appExtension` targetu a Apple vyžaduje, aby framework v extension nepoužíval nedovolené API (např. `UIApplication.shared`). Bez tohoto flagu xcodebuild propustí, ale App Store validation zabije buildu.
- Dedicated `KeyboardUI_Tests` target (analogicky `Feature` factory), unit test product, dep na `keyboardUI` + `testing`. Sources: `KeyboardUI/Tests/**`.

Struktura:

```
KeyboardUI/
├── Sources/
│   ├── Views/              # KeyView, RowView, KeyboardView, NumberRowView...
│   ├── Modifiers/          # pressed state, long-press gesture wrappers
│   └── Style/              # KeyStyle (semantic colors, fonty)
└── Tests/                  # snapshot testy
```

### 3. Nový target `KeyboardExtension` (.appex)

`Tuist/ProjectDescriptionHelpers/Targets/KeyboardExtension.swift`:

- `product: .appExtension`, iPhone-only, bundle ID `\(appBundleId).keyboard`.
- Sources: `KeyboardExtension/Sources/**`.
- Resources: žádné v v1.0 (žádné custom assety; UI bydlí v KeyboardUI).
- Dependencies: `keyboardCore`, `keyboardUI`, `resources`, `core`.
- Bez `SwiftLint` script v BuildPhases (drobné, lint pokrytý přes `KeyboardUI`).
- `APPLICATION_EXTENSION_API_ONLY` se nenastavuje (extension target sám tomu už podléhá implicitně).
- **Info.plist** (psaný přes `infoPlist: .extendingDefault(with: ...)`):
  - `CFBundleDisplayName = "Keybo"`
  - `NSExtension`:
    - `NSExtensionPointIdentifier = "com.apple.keyboard-service"`
    - `NSExtensionAttributes`:
      - `IsASCIICapable = false`
      - `PrefersRightToLeft = false`
      - `PrimaryLanguage = "en-US"`
      - `RequestsOpenAccess = true`
    - `NSExtensionPrincipalClass = "$(PRODUCT_MODULE_NAME).KeyboardViewController"` — třída se vytvoří v tasku 04, teď stačí placeholder.
- **Entitlements**:
  - `com.apple.security.application-groups = ["group.com.freedommartin.keybo"]`

Placeholder `KeyboardExtension/Sources/KeyboardViewController.swift`:

```swift
import UIKit

@objc(KeyboardViewController)
public final class KeyboardViewController: UIInputViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
    }

    public override func textWillChange(_ textInput: UITextInput?) {}
    public override func textDidChange(_ textInput: UITextInput?) {}
}
```

Tento placeholder vědomě **obsahuje `@objc`** — `NSExtensionPrincipalClass` ho vyžaduje. Toto je jediné místo, kde `@objc` v projektu používáme (uživatelská preference z prompt: „Do not use `@objc` unless absolutely unavoidable").

### 4. Test target pro `KeyboardCore`

`Feature` factory neaplikujeme (jak výše); ručně napsat `keyboardCoreTests` target v `KeyboardCore.swift`:

```swift
public let keyboardCoreTests: Target = .target(
    name: "KeyboardCore_Tests",
    destinations: [.iPhone],
    product: .unitTests,
    bundleId: "\(appBundleId).keyboardcore.tests",
    sources: "KeyboardCore/Tests/**",
    dependencies: [
        .target(keyboardCore),
        .target(testing)
    ]
)
```

### 5. Aktualizace `Project.swift`

V root `Project.swift`:

- Přidat `keyboardCore`, `keyboardCoreTests`, `keyboardUI`, `keyboardUITests`, `keyboardExtension` do `targets:` arrayu.
- App target (`Tuist/ProjectDescriptionHelpers/Targets/App.swift`) dostane novou dependency: `.target(keyboardExtension)` — aby host appka extension nesla bundlem. Také dostane entitlements `com.apple.security.application-groups = ["group.com.freedommartin.keybo"]` (host i extension musí být ve stejné App Group).
- Scheme `Keybo` ostává funkční. Doplnit do scheme `buildAction.targets` i `keyboardExtension` (aby `tuist build` budoval všechno).

### 6. App Group identifier jako Tuist konstanta

V `Tuist/ProjectDescriptionHelpers/Targets/App.swift` nebo nově v `Tuist/ProjectDescriptionHelpers/Constants.swift` (nový soubor):

```swift
public let appGroupIdentifier = "group.com.freedommartin.keybo"
```

Použít na obou targetech (host + extension) v entitlements. **Nezavádět to přes `$(APP_GROUP_IDENTIFIER)` xcconfig macro** (jak má WidgetCoin) — zbytečná indirekce pro Keybo, kde nemáme `Configuration/*.xcconfig`. Plain Swift konstanta v ProjectDescriptionHelpers stačí.

### 7. Provisioning a podpis

`DEVELOPMENT_TEAM` v root `Project.swift` je prázdný (`""`). Po `tuist generate` se Xcode pokusí provisioning vyřešit automaticky. Pro keyboard extension to může selhat (vyžaduje paid Apple Dev account pro App Groups). Reálný workflow:

1. V Xcode v root projektu → Signing & Capabilities → vybrat Tým.
2. Pro host app target i extension target — zkontrolovat „App Groups" capability je zapnutá a vybraná `group.com.freedommartin.keybo`.
3. Pokud Xcode hlásí „No matching provisioning profile" — re-generovat profile přes Apple Developer Portal nebo nechat Xcode „Try Again".

Tento krok se **neautomatizuje v Tuistu** — Tuist `entitlements:` deklaruje capability, ale provisioning profile vytvoří Xcode/Developer Portal. Stačí to zdokumentovat v tomto tasku jako manual step.

### 8. `tuist generate` + verifikace

Po všech změnách:

```bash
cd /Users/martin/Development/Keybo
tuist install
tuist generate
xcodebuild -workspace Keybo.xcworkspace -scheme Keybo -destination 'generic/platform=iOS Simulator' build
```

Build musí projít zelený. Pokud entitlements / signing fail, doložit v Xcode UI a re-run.

### 9. Smoke test v simulátoru

1. Spustit host appku v iOS simulátoru.
2. Otevřít Settings.app v simulátoru → General → Keyboards → Add New Keyboard.
3. „Keybo" by se mělo objevit v seznamu „Third-Party Keyboards".
4. Vybrat ho → zapnout „Allow Full Access" prompt (i když ho ještě nemáme onboarding).
5. Otevřít Notes.app → globe key → vybrat Keybo → klávesnice se zobrazí jako prázdná šedá plocha (placeholder `KeyboardViewController` nic nerenderuje).

Pokud se Keybo zobrazí v seznamu a po výběru se objeví prázdná plocha — task hotový.

## Mimo scope

- Žádný keyboard layout, žádné klávesy, žádný input (to je task 02–04).
- Žádné assety, žádný app icon (placeholder app icon je v `Keybo/Resources/Assets.xcassets/AppIcon.appiconset` ze scaffoldu; real icon je Future task).
- Žádný onboarding UI v hostu (task 11). Placeholder `ContentView` z Template scaffoldu zůstává.
- Žádné settings (task 12).
- Žádný `AppGroupStore` implementační kód (task 10). Pouze entitlements deklarace.

## Hotovo když

- `tuist generate` projde bez chyby.
- `xcodebuild build` schémy `Keybo` na iOS Simulator destination projde zelený.
- `KeyboardCore`, `KeyboardUI`, `KeyboardExtension` targety existují v Xcode projektu.
- Klávesnice „Keybo" je dostupná v iOS Settings → General → Keyboards → Add New Keyboard po instalaci host appky.
- Po výběru v globe keyi se zobrazí prázdná šedá keyboard plocha v Notes.app.
- App Group `group.com.freedommartin.keybo` je deklarovaný v entitlements host appky i extensionu.
- Žádný `@objc` mimo `KeyboardViewController` placeholder.

## Rizika

- **Provisioning profil pro App Groups** vyžaduje paid Apple Dev account (resp. nějaké free account omezení můžou bránit). Pokud se to teď nepodaří, App Group lze docasně zakomentovat a doplnit později — ale je lepší to vyřešit teď, jinak to zablokuje task 10.
- **Tuist verze** se může lišit od verze, kterou používá WidgetCoin (kde fungují identické patterny). Pokud `tuist install` selže, ověřit `tuist version` a porovnat s Mintfile/CI.
- `APPLICATION_EXTENSION_API_ONLY = YES` na `KeyboardUI` může vyhodit warning při buildu, pokud KeyboardUI omylem importuje API zakázané v extensionech. To je *fíčura*, ne bug — řeš okamžitě. Žádný `UIApplication.shared`, žádné `openURL`, žádné `applicationState`.

## Reference

- `Tuist/ProjectDescriptionHelpers/Targets/App.swift` — host app target setup
- `Tuist/ProjectDescriptionHelpers/Targets/Core.swift` — framework target pattern
- `Tuist/ProjectDescriptionHelpers/Targets/Feature.swift` — feature factory
- `~/Development/WidgetCoin/Tuist/ProjectDescriptionHelpers/Targets/Widget.swift` — appExtension pattern reference
- Apple: Creating a Custom Keyboard — <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Keyboard.html>
- Apple: Information Property List → NSExtension — <https://developer.apple.com/documentation/bundleresources/information-property-list/nsextension>
