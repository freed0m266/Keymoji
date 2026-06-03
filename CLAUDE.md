# Keymoji

iOS app keymoji with a modular SwiftUI architecture, managed with Tuist.

## Targets

- **Keymoji** — Main app entry point (placeholder ContentView)
- **KeymojiCore** — Shared framework (DI, Services, BaseViewModel, Logger)
- **KeymojiUI** — Design system (View extensions, Icon wrapper, reusable components)
- **KeymojiResources** — Localization strings and `L10n` alias
- **KeymojiTesting** — Snapshot testing utilities (`AssertSnapshot` helper)
- **Feature modules** (`Features/`) — Independent feature frameworks: `Example`

## Build

- Build system: Tuist (`tuist generate` to regenerate Xcode project)
- Swift 6.0, iOS 26+

## Architecture

- MVVM with UseCases and Repository layers
- Protocol-first design: every ViewModel, UseCase, Repository, and Service has a protocol
- ViewModels use `@Observable` macro, inherit from `BaseViewModel`
- Views are generic over ViewModel protocols: `struct ExampleView<ViewModel: ExampleViewModeling>: View`
- Constructor-based DI via global `AppDependency` singleton (`nonisolated(unsafe) let dependencies`)
- Each feature has a `*Dependencies` struct + `AppDependency` extension providing its deps
- ViewModel factory functions: `exampleVM()`
- Mocks in `Testing/` directories, wrapped in `#if DEBUG`, used for SwiftUI previews

## Feature Module Structure

```
Features/{Name}/
├── Sources/
│   ├── {Name}View.swift
│   ├── {Name}ViewModel.swift
│   └── {Name}Dependencies.swift
├── Testing/
│   └── {Name}ViewModelMock.swift
└── Tests/
    └── {Name}Snapshots.swift
```

## Code Style

- `@State private var viewModel` in views for observable state
- `@MainActor` on ViewModel protocols and implementations
- UseCase entry point is always `execute(...)` method
- Shared framework types are `public`, implementations are `internal`
- Protocol naming: `<Name>...ing` (e.g. `ExampleViewModeling`)
- Snapshot tests use `AssertSnapshot()` helper with `XCTestCase`
