# 16 — User override pro light/dark mode

**Status:** Done — 2026-05-25

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium

## Souhrn

Picker v Settings „System / Light / Dark" který přepíše systémový color scheme klávesnice. Klávesnice se v v1.0 řídí systémem (přesněji: konzumující appkou), což pokrývá ~95 % uživatelské potřeby; user override je polish pro tu menšinu.

## Scope (až přijde čas)

- `AppearancePreference` enum v `KeymojiCore` (system / light / dark).
- Persistence v `AppGroupStore` přes `AppGroupStoreKey.appearance`.
- Settings picker (segmented control) v `SettingsView`.
- V `KeyboardView` aplikovat `.preferredColorScheme(...)` (nebo equivalent pro keyboard extension) podle preference.
- Snapshot testy obě varianty pro každý case.
- **Pozor**: keyboard extension trait collection je řízený konzumující appkou, ne app preferencí. Možná bude potřeba override přes UIInputView trait. Vyžaduje výzkum.

## Závislosti

Task 10 (`AppGroupStore`) hotový — tady přidáme nový klíč.

## Reference

- `~/Development/WidgetCoin/tasks/23-light-mode-and-appearance-switch.md` — analogická story
