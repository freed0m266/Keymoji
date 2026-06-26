# Keymoji

The iPhone keyboard for people who live in emoji — personalized emoji one tap away, on top of a fast, native-feeling QWERTY. Built as a personal replacement for SwiftKey, now heading to the App Store.

- **Emoji-first.** Pin favorites in your own order, reach them from an emoji row above the keys, and search any emoji by name or `:shortcode:`.
- **Feels native.** Designed to match the iOS keyboard, with the conveniences you'd expect from SwiftKey — minus the bloat.
- **Private by default.** The keyboard makes no network calls at all — what you type never leaves the device. The app sends only anonymous, opt-out usage stats (which settings get used, never content). No ads, no tracking, no accounts.
- **English layout**, US QWERTY (optional QWERTZ), with long-press diacritics for Czech, Slovak, German, Polish, French, Spanish (`á č ě š ř ž …`).
- **iPhone only** (portrait + landscape), iOS 26+.

## Status

**Beta-bound.** Feature-complete for the first release — 58 of 62 tasks done. Next step is a TestFlight beta, then a final polish pass and App Store submission.

The 4 remaining tasks are post-beta polish, not blockers: top-row popover clipping ([21](tasks/21-popover-top-row-clipping.md)), Apple-style key preview bubble ([25](tasks/25-key-preview-popup.md)), keyboard-switch height flash ([53](tasks/53-keyboard-switch-height-flash.md)), and auto numberpad for numeric fields ([59](tasks/59-auto-numberpad-for-numeric-fields.md)).

App Store readiness is in place: real app icon ([28](tasks/28-app-icon.md)), and English listing copy + submission checklist in [`marketing/app-store/`](marketing/app-store/) ([47](tasks/47-app-store-listing.md)). Screenshots and the App Store Connect upload remain manual.

See [`tasks/README.md`](tasks/README.md) for the full roadmap and [`tasks/dashboard.html`](tasks/dashboard.html) for a live Kanban snapshot (`python3 scripts/generate_dashboard.py`).

## Features

**Emoji**
- Favorites bar above the keys — your top emoji in your own order, with TabView paging and an optional most-used-first sort.
- Favorites editor in the host app: pick emoji, reorder, and see each one's name (flag names derived automatically).
- Dedicated emoji page with the full single-codepoint Unicode catalog plus recents.
- In-keyboard emoji search — type a name and pick from a results bar; falls back to recents when empty.
- Slack-style shortcodes: type `:smile:` and get 😄.
- Emoji codes reference screen in the host app (tap to copy a shortcode).

**Typing**
- Smart word suggestions that learn the words you actually use — personal recents → `UILexicon` → `UITextChecker`, on-device only, with a managed learned-words list (sort, swipe-to-delete, bulk clear).
- Long-press any key for accents/diacritics; selectable language alternate sets (CZ / SK / DE / PL / FR / ES / All).
- Shift state machine with caps lock, and auto-capitalization at sentence starts.
- QWERTY ↔ QWERTZ positional toggle.
- Always-on number row (auto-hidden in landscape to save vertical space).
- Two symbol pages at parity with the native keyboard.

**Feel & gestures**
- Native look: three-tier key shading, spacing, and typography tuned for parity with iOS.
- Haptic feedback and key click sounds (distinct space/delete sounds), fully toggleable.
- Trackpad cursor — long-press the space bar to move the caret precisely.
- Delete word-by-word on a long hold; delete repeat-on-hold.
- Configurable double-tap-space action (period / dismiss / nothing).
- Light/Dark appearance override, independent of the system.
- Constant keyboard height across letters, symbols, emoji, and search pages.

**Host app**
- 4-step onboarding with live activation detection, a favorites picker, and a feature tour.
- Settings: number row, haptics, sound, suggestions, double-tap action, layout (QWERTY/QWERTZ), accent set, appearance.
- About screen with version, privacy statement, and external links.

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
open Keymoji.xcworkspace
```

To use Keymoji as your iOS keyboard after building & installing:

1. Settings → General → Keyboard → Keyboards → Add New Keyboard → Keymoji
2. Tap Keymoji in the list → enable **Allow Full Access** (required by iOS for haptic feedback; Keymoji doesn't use it for anything else — see [Privacy](#privacy))
3. In any text field, tap the globe icon and pick Keymoji

The host app's onboarding screen walks through these steps with live status detection.

## Project Structure

```
Keymoji/
├── Keymoji/                          # Host app (onboarding + settings entry point)
│   ├── Sources/
│   │   ├── App/                    # @main + AppDelegate (SwiftyBeaver setup)
│   │   └── Views/                  # RootView, ContentView
│   └── Resources/                  # AppIcon, asset catalog
├── KeyboardExtension/              # The actual keyboard (.appex)
│   └── Sources/
│       ├── KeyboardViewController  # Principal class, hosts SwiftUI via UIHostingController
│       ├── KeyboardRoot            # SwiftUI root that re-builds layout from KeyboardState
│       ├── TextProxyAdapter        # Bridges UITextDocumentProxy → KeyboardCore protocol
│       ├── SuggestionProviderAdapters  # Wires UILexicon/UITextChecker into the core
│       ├── UIKitHaptics            # Real haptic implementation (needs Full Access)
│       ├── UIKitClickSound         # Key click / space / delete sounds
│       └── *Mapping.swift          # UIKit enum ↔ KeyboardCore enum bridges
├── KeyboardCore/                   # Pure-Swift keyboard logic (no UIKit)
│   ├── Sources/
│   │   ├── Models/                 # Key, KeyboardLayout, KeyboardPage, KeyboardState, Emoji…
│   │   ├── Logic/                  # LayoutBuilder, ShiftStateMachine, AutoCapitalizer, InputDispatcher,
│   │   │   │                       #   KeyboardMetrics, EmojiSearchIndex, SlackEmoji*
│   │   │   └── Suggestions/        # SuggestionCoordinator, WordCompletionProvider, eligibility…
│   │   ├── Storage/                # PersonalRecentsStore (learned words)
│   │   └── Public/                 # Protocols (TextDocumentProxying, HapticFeedbackProviding…)
│   └── Tests/                      # ~340 unit tests
├── KeyboardUI/                     # SwiftUI rendering of the keyboard
│   ├── Sources/
│   │   ├── Views/                  # KeyboardView, KeyRowView, KeyView, SuggestionBarView,
│   │   │                           #   LongPressPopoverView, emoji panels
│   │   └── Style/                  # KeyStyle (semantic colors)
│   └── Tests/                      # Snapshot tests (light + dark)
├── KeymojiCore/                      # Cross-target shared utilities
│   └── Sources/
│       ├── Dependencies/           # AppDependency container
│       ├── Shared/                 # AppGroupStore, settings keys, FavoritesOrdering,
│       │                           #   LetterAlternateSet, SpaceDoubleTapAction, Logger, KeymojiURLs
│       ├── Services/               # NetworkService scaffold (unused; legacy from template)
│       └── Extensions/             # Foundation extensions
├── KeymojiUI/                        # Design system for the host app
├── KeymojiResources/                 # Localization (L10n alias, en.lproj)
├── KeymojiTesting/                   # AssertSnapshot helper
├── Analytics/                        # Host-app-only TelemetryDeck wrapper (never linked into the extension)
├── Features/                       # Host-app feature frameworks
│   ├── Onboarding/                 # 4-step setup: activation, favorites picker, feature tour
│   ├── Settings/                   # Toggles for number row, haptics, sound, layout, accents, appearance
│   ├── FavoriteEmojisEditor/       # Pick + reorder favorite emoji
│   ├── EmojiCatalogPicker/         # Full Unicode emoji catalog browser
│   ├── EmojiCodes/                 # Slack shortcode reference (tap to copy)
│   ├── LearnedWordsEditor/         # View / sort / delete learned words
│   ├── About/                      # Version, privacy statement, external links
│   └── Example/                    # Template leftover (unused)
├── marketing/                      # Privacy policy HTML + App Store listing copy
├── tasks/                          # Implementation roadmap (Czech) + status dashboard
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
  KeyboardCore  ←————  shares —————  KeymojiCore (AppGroupStore, Logger)
```

- Every `ViewModel` is backed by a `*ViewModeling` `@MainActor` protocol; concrete impls inherit `BaseViewModel`.
- Views are generic over their VM protocol: `struct OnboardingView<ViewModel: OnboardingViewModeling>: View`.
- Cross-process state (host ↔ keyboard) lives in an App Group `UserDefaults` via `AppGroupStore`, with change observation across processes (Darwin notifications).
- Mocks under `Features/<Name>/Testing/` (wrapped `#if DEBUG`) drive snapshot tests and SwiftUI previews.

Keyboard logic is split:

- **`KeyboardCore`** (pure Swift, no UIKit) — layout model, shift state machine, input dispatcher, auto-cap, sizing metrics, emoji search, and the suggestions pipeline. Unit-tested in isolation.
- **`KeyboardUI`** (SwiftUI) — view rendering only. Snapshot-tested in light + dark.
- **`KeyboardExtension`** (`.appex`) — wires the two via `UIHostingController` inside `UIInputViewController`, and supplies the UIKit-backed haptics, sounds, and suggestion providers. Reads `view.bounds.width` to size the SwiftUI keyboard authoritatively.

## Privacy

Keymoji's `marketing/privacy-policy.html` is the source of truth — hosted at the URL in [`KeymojiCore/Sources/Shared/KeymojiURLs.swift`](KeymojiCore/Sources/Shared/KeymojiURLs.swift). Summary:

- **No content ever leaves the device.** No typing data, words, phrases, learned words, favourites, searches, or device identifiers.
- **Keyboard makes no network calls.** The extension contains no networking code and makes no URL requests — telemetry is host-app-only (boundary 1, [ADR 0004](docs/adr/0004-anonymous-host-app-analytics.md)).
- **Anonymous, opt-out usage stats.** The host app reports which settings get used and app/feature lifecycle events via TelemetryDeck — anonymised on-device, never content, no IDFA, no cross-app tracking. Off in Settings → Privacy stops it entirely.
- **Learned words stay local.** Words used to speed up typing live in a private App Group container only Keymoji can read — never uploaded, not even to Apple.
- **No ad/attribution SDKs.** TelemetryDeck (host-app analytics) and SwiftyBeaver (console logging) only.
- **"Allow Full Access" is required only for haptic feedback** — an iOS sandbox restriction, not a data-collection mechanism. Leave it off and the rest of the keyboard works the same.

## Tests

- `KeyboardCore_Tests` — ~340 unit tests covering layout builder, shift state machine, auto-cap, input dispatch, sizing metrics, emoji search/catalog, and the suggestions pipeline.
- `KeyboardUI_Tests` — snapshot tests for the keyboard, suggestion bar, and long-press popover (light + dark variants).
- `KeymojiCore_Tests` — `AppGroupStore` and shared-state tests with isolated `UserDefaults` suites.
- `Onboarding_Tests`, `Settings_Tests`, `About_Tests`, `EmojiCatalogPicker_Tests`, `EmojiCodes_Tests`, … — feature snapshot tests.

Snapshots use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with `#filePath` so references live next to the test source files, not in the simulator sandbox.

## Adding a Feature

Use the feature generator script:

```bash
./scripts/new_feature.sh FeatureName
tuist generate
```

## Workflow

- Work on `main`, incremental commits, gitmoji prefix (`✨` feat, `🐛` fix, `📝` docs, `💄` polish, `📸` snapshots, `🧱` infra, `♻️` refactor).
- `tasks/` holds the roadmap. Each numbered task has Scope / Mimo scope / Hotovo když / Rizika / Reference sections and a `**Status:**` line; `python3 scripts/generate_dashboard.py` regenerates [`tasks/dashboard.html`](tasks/dashboard.html).
- Key tasks (those marked **Codex review: Ano**) get a `codex review --uncommitted` pass before closing commit.

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — console logging only (no remote destinations)
- [TelemetryDeck](https://github.com/TelemetryDeck/SwiftSDK) — anonymous host-app usage analytics; linked **only** into the app target, never the keyboard extension (boundary 1, [ADR 0004](docs/adr/0004-anonymous-host-app-analytics.md))
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — visual regression tests
- [BaseKitX](https://github.com/freed0m266/BaseKitX), [ACKategories](https://github.com/AckeeCZ/ACKategories) — linked via template scaffold, not actively imported (candidates for removal in future cleanup)
