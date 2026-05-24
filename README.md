# Keybo

A simple, private, on-device custom iOS keyboard. Built as a personal replacement for SwiftKey, with an eye on App Store release.

- **No account.** No login, no sync, no analytics, no third-party SDKs.
- **No network.** The keyboard never connects to the internet — everything runs on-device.
- **Built for Czech + English** typing: US QWERTY layout with long-press diacritic popovers (`á č ě š ř ž …`).
- **iPhone only** (portrait + landscape), iOS 26+.

## Status

v1.0 feature-complete. 15 tasks done; usable end-to-end on device. Pre-App-Store polish (real icon, hosted privacy policy URL) tracked in [`tasks/27-app-icon.md`](tasks/27-app-icon.md).

See [`tasks/README.md`](tasks/README.md) for the full roadmap including v1.1 follow-ups (emoji panel, light/dark override, trackpad mode, …).

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) — project generation
- [Mint](https://github.com/yonaskolb/Mint) — SwiftLint via build phase

## Getting Started

```bash
# Install Tuist if you don't have it
curl -Ls https://install.tuist.io | bash

# Install build tools (SwiftLint)
mint bootstrap

# Resolve and generate the Xcode project
tuist install
tuist generate

# Open in Xcode
open Keybo.xcworkspace
```

To use Keybo as your iOS keyboard after building & installing:

1. Settings → General → Keyboard → Keyboards → Add New Keyboard → Keybo
2. Tap Keybo in the list → enable **Allow Full Access** (required by iOS for haptic feedback; Keybo doesn't use it for anything else — see [Privacy](#privacy))
3. In any text field, tap the globe icon and pick Keybo

The host app's onboarding screen walks through these steps with live status detection.

## Project Structure

```
Keybo/
├── Keybo/                          # Host app (onboarding + settings entry point)
│   ├── Sources/
│   │   ├── App/                    # @main + AppDelegate (SwiftyBeaver setup)
│   │   └── Views/                  # RootView, ContentView
│   └── Resources/                  # AppIcon, asset catalog
├── KeyboardExtension/              # The actual keyboard (.appex)
│   └── Sources/
│       ├── KeyboardViewController  # Principal class, hosts SwiftUI via UIHostingController
│       ├── KeyboardRoot            # SwiftUI root that re-builds layout from KeyboardState
│       ├── TextProxyAdapter        # Bridges UITextDocumentProxy → KeyboardCore protocol
│       ├── UIKitHaptics            # Real haptic implementation (needs Full Access)
│       └── *Mapping.swift          # UIKit enum ↔ KeyboardCore enum bridges
├── KeyboardCore/                   # Pure-Swift keyboard logic (no UIKit)
│   ├── Sources/
│   │   ├── Models/                 # Key, KeyboardLayout, KeyboardPage, ShiftState…
│   │   ├── Logic/                  # LayoutBuilder, ShiftStateMachine, AutoCapitalizer, InputDispatcher
│   │   └── Public/                 # Protocols (TextDocumentProxying, HapticFeedbackProviding)
│   └── Tests/                      # ~85 unit tests
├── KeyboardUI/                     # SwiftUI rendering of the keyboard
│   ├── Sources/
│   │   ├── Views/                  # KeyboardView, KeyRowView, KeyView, LongPressPopoverView
│   │   └── Style/                  # KeyStyle (semantic colors)
│   └── Tests/                      # Snapshot tests (light + dark)
├── KeyboCore/                      # Cross-target shared utilities
│   └── Sources/
│       ├── Dependencies/           # AppDependency container
│       ├── Shared/                 # AppGroupStore, BaseViewModel, Logger, KeyboURLs
│       ├── Services/               # NetworkService scaffold (unused; legacy from template)
│       └── Extensions/             # Foundation extensions
├── KeyboUI/                        # Design system for the host app
├── KeyboResources/                 # Localization (L10n alias, en.lproj)
├── KeyboTesting/                   # AssertSnapshot helper
├── Features/                       # Host-app feature frameworks
│   ├── Example/                    # Template leftover (unused)
│   ├── Onboarding/                 # 3-step setup flow with live activation detection
│   ├── Settings/                   # Toggles for number row + haptic feedback
│   └── About/                      # Version, privacy statement, external links
├── marketing/                      # Privacy policy HTML (hosted externally)
├── tasks/                          # Implementation roadmap (Czech)
└── Tuist/
    └── ProjectDescriptionHelpers/  # Target manifests
```

## Architecture

**MVVM** with protocol-first design and constructor-injected dependencies:

```
KeyboardExtension                Host app
        ↓                            ↓
  KeyboardUI    ←————  shares —————  Features/*
        ↓                            ↓
  KeyboardCore  ←————  shares —————  KeyboCore (AppGroupStore, Logger)
```

- Every `ViewModel` is backed by a `*ViewModeling` `@MainActor` protocol; concrete impls inherit `BaseViewModel`.
- Views are generic over their VM protocol: `struct OnboardingView<ViewModel: OnboardingViewModeling>: View`.
- Cross-process state (host ↔ keyboard) lives in an App Group `UserDefaults` via `AppGroupStore`.
- Mocks under `Features/<Name>/Testing/` (wrapped `#if DEBUG`) drive snapshot tests and SwiftUI previews.

Keyboard logic is split:

- **`KeyboardCore`** (pure Swift, no UIKit) — layout model, shift state machine, input dispatcher, auto-cap. Unit-tested in isolation.
- **`KeyboardUI`** (SwiftUI) — view rendering only. Snapshot-tested at 393×260.
- **`KeyboardExtension`** (`.appex`) — wires the two via `UIHostingController` inside `UIInputViewController`. Reads `view.bounds.width` to size the SwiftUI keyboard authoritatively.

## Privacy

Keybo's `marketing/privacy-policy.html` is the source of truth — hosted at the URL in `KeyboCore/Sources/Shared/KeyboURLs.swift`. Summary:

- **Nothing collected.** No typing data, words, phrases, device identifiers, or analytics.
- **No network access.** The extension never makes URL requests.
- **No third-party SDKs that exfiltrate data.** SwiftyBeaver console logging only.
- **"Allow Full Access" is required only for haptic feedback** — iOS sandbox restriction, not a data-collection mechanism.

## Tests

- `KeyboardCore_Tests` — ~85 unit tests covering layout builder, shift state machine, auto-cap, input dispatch.
- `KeyboardUI_Tests` — 16 snapshot tests (light + dark variants).
- `KeyboCore_Tests` — `AppGroupStore` tests with isolated `UserDefaults` suite.
- `Onboarding_Tests`, `Settings_Tests`, `About_Tests` — feature snapshot tests.

Snapshots use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with `#filePath` so references live next to the test source files, not in the simulator sandbox.

## Adding a Feature

Use the feature generator script:

```bash
./scripts/new_feature.sh FeatureName
tuist generate
```

## Workflow

- Work on `main`, incremental commits, gitmoji prefix (`✨` feat, `🐛` fix, `📝` docs, `💄` polish, `📸` snapshots, `🧱` infra, `♻️` refactor).
- `tasks/` holds the roadmap. Each numbered task has Scope / Mimo scope / Hotovo když / Rizika / Reference sections.
- Key tasks (those marked **Codex review: Ano**) get a `codex review --uncommitted` pass before closing commit.

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — console logging only (no remote destinations)
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — visual regression tests
- [BaseKitX](https://github.com/freed0m266/BaseKitX), [ACKategories](https://github.com/AckeeCZ/ACKategories) — linked via template scaffold, not actively imported (candidates for removal in future cleanup)
