# 13 — About screen + privacy policy HTML

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Plain About screen s app name, version, copyright, a linkem na privacy policy. Privacy policy je HTML soubor v `marketing/` (mimo aplikační bundle, ne v `KeyboResources`), který se hostuje na webu — link v About screen jen otevírá `URL` v Safari.

Toto je posledník v1.0 task. Po něm má App Store-ready bundle vše, co potřebuje (kromě skutečné ikony — Future task).

## Kontext

- Apple App Store **vyžaduje** privacy policy URL při submission přes App Store Connect.
- Pro Keybo, kde fakticky nesbíráme žádná data, je policy text krátký — 5–10 odstavců.
- Hosting policy: na osobním webu uživatele. Repo obsahuje HTML zdroj v `marketing/privacy-policy.html`, ten se ručně nahraje.

## Scope

### 1. About feature framework

`Features/About/` přes `Feature` factory:

```swift
public let about = Feature(
    name: "About",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name)
    ]
)
```

Adresářová struktura analogicky onboarding/settings.

### 2. `AboutViewModeling`

```swift
@MainActor
public protocol AboutViewModeling {
    var versionString: String { get }
    func openPrivacyPolicy()
    func openSourceCode()                    // optional — open GitHub repo if public
}
```

### 3. `AboutViewModel`

```swift
@Observable
@MainActor
public final class AboutViewModel: AboutViewModeling {
    public let versionString: String

    public init() {
        self.versionString = Self.makeVersionString()
    }

    public func openPrivacyPolicy() {
        guard let url = URL(string: Constants.URLs.privacyPolicy) else { return }
        UIApplication.shared.open(url)
    }

    public func openSourceCode() {
        guard let url = URL(string: Constants.URLs.sourceCode) else { return }
        UIApplication.shared.open(url)
    }

    private static func makeVersionString() -> String {
        // jako v SettingsViewModel — Bundle.main Info.plist
        ...
    }
}
```

### 4. Constants

V `KeyboCore/Sources/Shared/Constants.swift` (nový soubor nebo extension existujícího):

```swift
public enum Constants {
    public enum URLs {
        public static let privacyPolicy = "https://freedommartin.example.com/keybo/privacy"
        public static let sourceCode = "https://github.com/freed0m266/Keybo"
    }
}
```

Konkrétní URL placeholder — Martin upraví na své aktuální URL před první App Store submission.

### 5. `AboutView`

```swift
public struct AboutView<ViewModel: AboutViewModeling>: View {
    @State private var viewModel: ViewModel

    typealias Texts = L10n.About

    public init(viewModel: ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Form {
            headerSection
            privacySection
            legalSection
        }
        .navigationTitle(Texts.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Assets.appIconLarge.swiftUIImage    // placeholder z asset catalog
                    .size(72)

                Text(L10n.General.title)
                    .font(.title2.weight(.bold))

                Text(Texts.versionLabel(viewModel.versionString))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }

    private var privacySection: some View {
        Section {
            Text(Texts.privacyStatement)
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            Text(Texts.privacyHeader)
        }
    }

    private var legalSection: some View {
        Section {
            Button(action: viewModel.openPrivacyPolicy) {
                ChevronLinkRow(title: Texts.privacyPolicyLink)
            }
            Button(action: viewModel.openSourceCode) {
                ChevronLinkRow(title: Texts.sourceCodeLink)
            }
        } header: {
            Text(Texts.legalHeader)
        } footer: {
            Text(Texts.copyright(currentYear))
        }
    }

    private var currentYear: String {
        let year = Calendar.current.component(.year, from: Date())
        return String(year)
    }
}
```

`ChevronLinkRow` reusable z `KeyboUI` (analogicky WidgetCoin má `WidgetCoinUI/Sources/Components/ChevronLinkRow.swift` — ověřit, jestli scaffold ho má, jinak vytvořit).

### 6. Lokalizace

```strings
"about.title" = "About Keybo";
"about.versionLabel" = "Version %@";

"about.privacy.header" = "Privacy";
"about.privacy.statement" = "Keybo does not collect, transmit, or store any of your typing data. The keyboard runs entirely on-device. We don't use analytics, crash reporting, or any third-party SDKs that could exfiltrate data. Allow Full Access is required only for haptic feedback — it does not enable any data collection.";

"about.legal.header" = "Legal";
"about.legal.privacyPolicyLink" = "Full privacy policy";
"about.legal.sourceCodeLink" = "Source code on GitHub";
"about.legal.copyright" = "© %@ Freedom Martin, s.r.o.";

"general.title" = "Keybo";
```

### 7. Privacy policy HTML

`marketing/privacy-policy.html` (mimo `KeyboResources` — to není app bundle resource):

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Keybo — Privacy Policy</title>
    <style>
        body { font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #222; }
        h1, h2 { color: #111; }
        h1 { font-size: 1.8rem; border-bottom: 2px solid #eee; padding-bottom: .5rem; }
        h2 { font-size: 1.2rem; margin-top: 2rem; }
        p { margin: .75rem 0; }
        .meta { color: #777; font-size: .9rem; }
    </style>
</head>
<body>
    <h1>Keybo — Privacy Policy</h1>
    <p class="meta">Last updated: [DATE]</p>

    <h2>1. What we collect</h2>
    <p>Nothing. Keybo is a custom iOS keyboard that runs entirely on your device. We do not collect, transmit, store, or share any data, including but not limited to:</p>
    <ul>
        <li>Text you type or have typed</li>
        <li>Words, phrases, or any patterns from your input</li>
        <li>Personal information, device identifiers, or usage analytics</li>
        <li>Network requests of any kind — Keybo has no internet access by design</li>
    </ul>

    <h2>2. Why does Keybo ask for "Allow Full Access"?</h2>
    <p>iOS requires custom keyboards to enable "Allow Full Access" in order to use the haptic feedback (vibration) API. This is an iOS sandbox restriction, not a data collection mechanism. Keybo uses Full Access exclusively for the following:</p>
    <ul>
        <li>Haptic feedback on key taps</li>
        <li>Reading/writing keyboard preferences (e.g. "Always show number row") in a shared container between the host app and the keyboard extension</li>
    </ul>
    <p>Keybo does not use Full Access for network access, keychain access, or any other purpose. The source code is open and verifiable.</p>

    <h2>3. Third-party services</h2>
    <p>Keybo uses no third-party services, SDKs, or analytics frameworks.</p>

    <h2>4. Data sharing</h2>
    <p>Keybo does not share any data with any party because there is no data to share.</p>

    <h2>5. Children's privacy</h2>
    <p>Keybo does not collect data from any user, including children under 13.</p>

    <h2>6. Changes to this policy</h2>
    <p>If we ever change Keybo's behavior in a way that affects privacy (e.g., adding optional cloud sync in a future version), this policy will be updated, and the change will be highlighted in the app update changelog.</p>

    <h2>7. Contact</h2>
    <p>For questions about privacy, contact: <a href="mailto:martin.svoboda026@gmail.com">martin.svoboda026@gmail.com</a></p>
</body>
</html>
```

Tento HTML soubor:
- **Není v aplikačním bundle** — nejde o resource pro app, je to artefakt který nahraješ na svůj web.
- **Repo si ho drží** pro version control, aby šlo dohledat změny.
- **První řádek** „Last updated: [DATE]" se ručně edituje při každém update.
- URL na který tento HTML hostuješ → updatuj `Constants.URLs.privacyPolicy`.

### 8. `AboutViewModelMock`

```swift
#if DEBUG
@Observable
@MainActor
public final class AboutViewModelMock: AboutViewModeling {
    public var versionString: String = "1.0 (1)"
    public func openPrivacyPolicy() {}
    public func openSourceCode() {}
}
#endif
```

### 9. Snapshot test

`Features/About/Tests/AboutSnapshots.swift`:

- AboutView default × dark + light = 2 snapshoty

### 10. AppDependency

```swift
extension AppDependency {
    public func aboutVM() -> AboutViewModel {
        AboutViewModel()
    }
}
```

### 11. Wiring v root

Settings sheet `.about` (task 12) ukáže `AboutView(viewModel: dependencies.aboutVM())`. Žádná navigation v rámci About — flat screen.

## Mimo scope

- In-app webview pro privacy policy. Otevřeme v Safari místo. Jednodušší, méně review friction.
- „Acknowledgements" / třetí strany licence. Keybo v v1.0 nemá runtime third-party deps (SwiftyBeaver/BaseKitX/ACKategories jsou v Template scaffoldu ale pro Keybo bychom je mohli vynechat — to je task pro v1.1 cleanup).
- „Rate Keybo" prompt. Future polish.
- Multi-language (en, cs separately). v1.0 jen en.

## Hotovo když

- `Features/About/` framework existuje a buildne.
- `AboutView` zobrazuje app name, version, privacy statement, dva odkazy.
- „Full privacy policy" otevírá URL v Safari.
- „Source code on GitHub" otevírá repo URL v Safari.
- `marketing/privacy-policy.html` v repo, kompletní text.
- 2 snapshot testy green.
- Manuální test v simulátoru.

## Rizika

- **`Constants.URLs.privacyPolicy` placeholder** — pokud zapomeneš updatovat před App Store submission, URL bude nefunkční. Doplnit do release checklist (mimo scope tohoto tasku, ale flag).
- **Privacy statement copy precision** — App Store review může protestovat pokud kopíruje něco nepřesně. „Keybo does not collect any data" musí být doslova pravda — žádný analytics/crash reporting/feature flag SDK ve výsledné aplikaci.

## Reference

- `~/Development/WidgetCoin/Features/About/Sources/AboutView.swift` — vzor pro layout
- `~/Development/WidgetCoin/Features/About/Sources/AboutViewModel.swift` — vzor pro VM
- Apple App Store Review Guidelines, sekce 5.1.1 Privacy — <https://developer.apple.com/app-store/review/guidelines/#privacy>

## Codex review

**Skip** — statický content, žádná logika.
