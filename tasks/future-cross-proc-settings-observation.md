# Future — Cross-process settings observation (Darwin notifications)

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** S · **Dopad:** Low (UX polish)

## Souhrn

Když user změní toggle v host appce, klávesnice si toho v v1.0 všimne až při dalším `viewWillAppear` (re-read z `AppGroupStore`). To znamená, že pokud uživatel má klávesnici aktivně otevřenou a změní toggle v Settings, změna se neprojeví okamžitě.

Upgrade: Darwin notifications (`CFNotificationCenterPostNotification` přes Darwin center) umožňují cross-process eventing. Host appka zapíše → pošle notifikaci → extension odebere → re-rendruje.

## Scope (až přijde čas)

- `SettingsChangeNotifier` v `KeyboCore` — wrapper nad Darwin notifications.
- Host příklad: `SettingsViewModel.didSet showNumberRow` → `notifier.notifyShowNumberRowChanged()`.
- Extension: `KeyboardViewController` v `viewDidLoad` zaregistruje observer; v `deinit` deregistruje.
- Pozor na `@Sendable` v notification callback (Swift 6 concurrency).
- Test: dva procesy nejde easily testovat, manuální verify.

## Závislosti

Task 10 hotový.

## Proč ne v v1.0

Toggling je rare action. „Re-open klávesnice" po toggle UX kompromis je akceptovatelný v v1.0.
