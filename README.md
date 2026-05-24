# Keybo

iOS app keybo with a modular SwiftUI architecture, managed with Tuist.

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) (for project generation)
- [Mint](https://github.com/yonaskolb/Mint) (for SwiftLint via build phase)

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

## Project Structure

```
Keybo/
├── Keybo/                       # Main app target (entry point + ContentView)
│   ├── Sources/
│   │   ├── App/                    # @main + AppDelegate (logger setup)
│   │   └── Views/                  # ContentView (top-level screen)
│   └── Resources/                  # Asset catalog
├── KeyboCore/                   # Shared framework (DI, models, services)
│   └── Sources/
│       ├── Dependencies/           # AppDependency container
│       ├── Extensions/             # Foundation extensions
│       ├── Services/               # NetworkService and friends
│       └── Shared/                 # BaseViewModel, Logger
├── KeyboUI/                     # Design system (View+Extensions, Icon)
├── KeyboResources/              # Localization (L10n alias)
├── KeyboTesting/                # AssertSnapshot helper
├── Features/                       # Independent feature frameworks
│   └── Example/
│       ├── Sources/                # View, ViewModel, Dependencies
│       ├── Testing/                # Mock ViewModel (DEBUG)
│       └── Tests/                  # Snapshot tests
└── Tuist/                          # Build system configuration
    └── ProjectDescriptionHelpers/
```

## Architecture

The keybo follows **MVVM** with **UseCases** and a **Repository** layer:

```
View → ViewModel → UseCase → Repository → Service (API)
```

- Every ViewModel, UseCase, Repository, and Service is backed by a protocol
- Dependencies are injected via a global `AppDependency` container
- Each feature defines its own `*Dependencies` struct + `AppDependency` extension
- Views are generic over their ViewModel protocols

## Adding a Feature

Use the feature generator script:

```bash
./new_feature.sh FeatureName
```

Then regenerate the project:

```bash
tuist generate
```

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — Logging
- [BaseKitX](https://github.com/freed0m266/BaseKitX) — Foundation utilities
- [ACKategories](https://github.com/AckeeCZ/ACKategories) — Common helpers
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — Snapshot tests
