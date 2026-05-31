# Keybo

Keybo is a private, on-device custom iOS keyboard. It is built as a personal
SwiftKey replacement with a path to App Store release.

Core product constraints:

- No account, sync, analytics, telemetry, crash reporting, ads, or remote SDKs.
- The keyboard extension must not use the network. Keep all typing behavior on-device.
- iPhone only, iOS 26+, Swift 6.0, Tuist-managed project.
- Main typing UX is English US QWERTY with Czech long-press diacritics and explicit
  user-selected suggestions. Autocorrect and next-word prediction are out of scope.

## Important Files

- `README.md` is the best high-level product and architecture overview.
- `tasks/README.md` and numbered `tasks/*.md` are the roadmap and scope source of truth.
- `Project.swift` and `Tuist/ProjectDescriptionHelpers/Targets/**` define generated targets.
- `marketing/privacy-policy.html` is the privacy policy source of truth.
- `KeyboCore/Sources/Shared/KeyboURLs.swift` points to the hosted privacy URL.

## Targets

- `Keybo`: host app. Owns onboarding, settings entry points, app resources, and app group entitlement.
- `KeyboardExtension`: app extension principal target. Hosts SwiftUI in `UIInputViewController`,
  bridges UIKit types into `KeyboardCore`, and wires haptics/click sound/text proxy.
- `KeyboardCore`: pure Swift keyboard logic. No UIKit or SwiftUI. Models, layout, input dispatch,
  shift/caps state, auto-cap, emoji parsing/search, suggestions, and personal recents.
- `KeyboardUI`: SwiftUI keyboard rendering. Extension-safe (`APPLICATION_EXTENSION_API_ONLY = YES`).
  Depends on `KeyboardCore`, `KeyboUI`, `KeyboResources`, and `KeyboCore`.
- `KeyboCore`: shared app utilities such as `AppDependency`, `BaseViewModel`, `AppGroupStore`,
  `SettingsChangeNotifier`, `Logger`, and shared enums/settings.
- `KeyboUI`: host/design-system helpers (`Icon`, view extensions). Do not confuse with `KeyboardUI`.
- `KeyboResources`: localized strings and generated `L10n` alias.
- `KeyboTesting`: snapshot helpers.
- `Features/*`: independent host-app feature frameworks.

Current feature modules include `Onboarding`, `Settings`, `About`, `EmojiCodes`,
`EmojiCatalogPicker`, `FavoriteEmojisEditor`, and the leftover `Example` template.

## Build And Generation

- Regenerate Xcode files after target/resource/package changes:

```bash
tuist generate
```

- Build the app and keyboard extension:

```bash
xcodebuild -workspace Keybo.xcworkspace -scheme Keybo -destination 'generic/platform=iOS Simulator' build
```

- Run focused test schemes when touching a target. Use an installed iPhone simulator for test
  destinations, for example:

```bash
xcodebuild test -project Keybo.xcodeproj -scheme KeyboardCore_Tests -destination 'platform=iOS Simulator,name=<available iPhone>'
xcodebuild test -project Keybo.xcodeproj -scheme KeyboardUI_Tests -destination 'platform=iOS Simulator,name=<available iPhone>'
xcodebuild test -project Keybo.xcodeproj -scheme Settings_Tests -destination 'platform=iOS Simulator,name=<available iPhone>'
```

- SwiftLint runs through the build phase via Mint. Keep code lint-clean instead of bypassing it.

## Architecture Boundaries

- Keep `KeyboardCore` platform-neutral. It should depend on protocols such as
  `TextDocumentProxying`, `KeyboardControlling`, `HapticFeedbackProviding`, and
  `KeyClickSounding`, not on UIKit.
- Keep UIKit adaptation in `KeyboardExtension` (`TextProxyAdapter`, mappings, controller,
  `UIKitHaptics`, `UIKitClickSound`).
- Keep visual keyboard behavior in `KeyboardUI`; avoid putting input/state-machine logic there
  unless it is strictly view interaction glue.
- Shared cross-process settings live in `AppGroupStore` using the app group
  `group.com.freedommartin.keybo`.
- When adding a setting that affects the keyboard, add a typed `AppGroupStore` accessor,
  update `AppGroupStoreKey`, and post/observe through `SettingsChangeNotifier` if the extension
  must react while visible.
- Preserve the privacy model. Do not add networking, analytics, remote logging, cloud sync, or
  third-party services to the keyboard without explicit user approval.

## Feature Pattern

Host-app feature modules follow MVVM with protocol-first view models:

- `@MainActor public protocol <Name>ViewModeling: Observable, AnyObject`
- Concrete view models use `@Observable`, inherit `BaseViewModel`, and are `internal` unless
  a public surface is required.
- Views are generic over the protocol, for example
  `struct SettingsView<ViewModel: SettingsViewModeling>: View`.
- Observable view models are held with `@Bindable` when the view needs bindings; use existing
  feature style as the local precedent.
- Factory functions are public and main-actor isolated, for example
  `public func settingsVM() -> some SettingsViewModeling`.
- Mocks live in `Features/<Name>/Testing/`, wrapped in `#if DEBUG`, and power previews/snapshots.

Preferred feature layout:

```text
Features/<Name>/
  Sources/
    <Name>View.swift
    <Name>ViewModel.swift
    <Name>Dependencies.swift   # only when the feature has real dependencies
  Testing/
    <Name>ViewModelMock.swift
  Tests/
    <Name>Snapshots.swift
```

Use `./scripts/new_feature.sh FeatureName` for new host-app feature scaffolding, then run
`tuist generate`.

## Swift Style

- Follow the existing tab-indented Swift style and `// MARK: -` organization.
- Prefer small, explicit types over broad abstractions. Add protocols where the architecture
  needs testability or module boundaries, not as decoration.
- Public APIs are for cross-target use. Keep implementations `internal` by default.
- Mark view-model protocols and implementations `@MainActor`.
- Use `execute(...)` for UseCase entry points when adding a UseCase layer.
- Prefer localized strings through `L10n` for user-facing host-app text.
- Keep comments concise and useful. Explain tricky keyboard behavior, state-machine invariants,
  extension constraints, or privacy-sensitive choices.

## Keyboard-Specific Rules

- `InputDispatcher` is the central routing point for key actions and state mutation. Add tests
  for new actions or edge cases.
- `ShiftStateMachine`, `AutoCapitalizer`, `LayoutBuilder`, suggestions, emoji search, and parser
  logic should stay unit-testable without a simulator UI.
- Haptics and click sounds are press feedback, not text-dispatch side effects. Follow existing
  comments before moving them.
- `KeyboardUI` snapshots render fixed keyboard sizes, commonly `393x260`, in light and dark.
- Remember custom keyboard extension constraints: no `UIApplication.shared` in extension-safe
  frameworks, no assumptions that document context is available, and no data collection.

## Tests And Snapshots

- For pure logic changes, add or update `KeyboardCore/Tests/**`.
- For keyboard rendering changes, update `KeyboardUI/Tests/**` snapshots intentionally.
- For host feature UI changes, add/update the matching `Features/<Name>/Tests/*Snapshots.swift`.
- `KeyboTesting/AssertSnapshot` is the generic snapshot helper; `KeyboardUI/Tests/SnapshotHelpers.swift`
  is specialized for keyboard renders.
- Snapshot tests use `#filePath` in local helpers so references stay next to tests. Keep that pattern.
- Do not silently accept snapshot churn. Verify the visual change matches the task before recording.

## Task Workflow

- Numbered task files define scope, non-goals, done criteria, risks, and references. Treat them as
  binding when implementing a task.
- If a task says something is out of scope, do not implement it opportunistically.
- Update the task status only when the requested work and relevant verification are complete.
- Some key tasks request `codex review --uncommitted`; run it when the task workflow asks for it
  and triage findings instead of blindly applying them.

## Git Hygiene

- The worktree may contain user changes. Never revert unrelated edits.
- Keep commits grouped by intent. The project prefers short gitmoji-prefixed subjects.
- Do not commit unless the user explicitly asks.
