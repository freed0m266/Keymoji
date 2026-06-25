# 85 — Auto-capitalization: oprava bugu s tečkou + master toggle

**Status:** Todo — připraveno z grill session 2026-06-25.

**Priorita:** v1.x (bug — velké písmeno po tečce **nikdy** nenaskočí) · **Úsilí:** M (root-cause v pipeline + cross-process toggle + integrační test) · **Dopad:** Medium (každodenní psaní + nový uživatelský toggle).

**Souvisí s:** [06 — auto-capitalization](06-auto-capitalization.md), [27 — auto-switch to letters after space](27-auto-switch-to-letters-after-space.md). Glosář **Auto-capitalization** v [`CONTEXT.md`](../CONTEXT.md). Dotýká se [`AutoCapitalizer`](../KeyboardCore/Sources/Logic/AutoCapitalizer.swift), [`KeyboardViewController.refreshAutoCapitalization`](../KeyboardExtension/Sources/KeyboardViewController.swift), [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift) + [`AppGroupStoreKey`](../KeymojiCore/Sources/Shared/AppGroupStoreKey.swift), [`KeyboardState`](../KeyboardCore/Sources/Models/KeyboardState.swift), [`SettingsView`](../Features/Settings/Sources/SettingsView.swift) + [`SettingsViewModel`](../Features/Settings/Sources/SettingsViewModel.swift).

## Část A — bug: tečka nikdy nekapitalizuje

**Symptom (ověřeno uživatelem):** po `". "` se další písmeno **nezvětší**; po `"? "` a `"! "` ano.

**Co víme:** `AutoCapitalizer` čistá logika je správná pro všechny tři — `hasSuffix(". ")` i unit test s `"Hello. "` + `.sentences` prochází ([AutoCapitalizer.swift:33](../KeyboardCore/Sources/Logic/AutoCapitalizer.swift), [`AutoCapitalizerTests`](../KeyboardCore/Tests/AutoCapitalizerTests.swift)). Takže **bug je v pipeline**, ne v `AutoCapitalizer`.

**Leading hypotéza (potvrdit při běhu):** post-dispatch re-run `refreshAutoCapitalization` se spouští **jen při změně stránky** ([KeyboardViewController.swift:910-916](../KeyboardExtension/Sources/KeyboardViewController.swift)). `?`/`!` jsou jen na symbolové stránce → mezerník přepne symboly→písmena → re-run se spustí → kapitalizuje. Tečka jde i přes dedikovanou spodní `dot` klávesu na **písmenkové** stránce ([LayoutBuilder.swift:547,566](../KeyboardCore/Sources/Logic/LayoutBuilder.swift)) → mezerník stránku **nemění** → re-run se nespustí → auto-cap visí jen na `textDidChange` vyvolaném *během* `insertText(" ")`, který může číst ještě nezaktualizovaný `documentContextBeforeInput` → mine to.

**Fix:** re-run `refreshAutoCapitalization` po dispatchi i pro textové akce (`.space`, `.insertText`, `.insertRawText`) **bez ohledu na změnu stránky** (idempotentní). Zachovat výjimku pro `.shift` (re-run by přepsal ruční lowercase override na začátku věty — komentář [:903](../KeyboardExtension/Sources/KeyboardViewController.swift)). Root-cause finálně ověřit reprodukcí (tečka přes `dot` klávesu i přes symboly).

## Část B — master toggle

| Téma | Rozhodnutí |
|---|---|
| **Default** | **Zapnuto.** Standardní očekávané chování; toggle je hlavně vypínač. |
| **Sémantika** | Master on/off. Zapnuto = stávající chování (po opravě i tečka), pořád **ctí trait pole**. Vypnuto = klávesnice nikdy nepromuje na velké. |
| **Co NEdělá** | Žádný override-ON: pole s `.none` (username/heslo) zůstane bez velkého i při zapnutém toggle. |
| **Trigger set** | Beze změny: `. ? !` + start pole + `\n\n`. **Čárka NE** (uprostřed věty). |
| **Úložiště** | Nový `AppGroupStore` Bool `autoCapitalizationEnabled` (cross-process — extension čte), pattern jako `hapticFeedbackEnabled`. |

## Scope

- [`AppGroupStoreKey`](../KeymojiCore/Sources/Shared/AppGroupStoreKey.swift): `case autoCapitalizationEnabled`. [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift): typovaný accessor (default `true`).
- [`KeyboardState`](../KeyboardCore/Sources/Models/KeyboardState.swift): `autoCapitalizationEnabled` mirror, refresh ve `viewWillAppear` jako `spaceDoubleTapAction` ([KeyboardViewController.swift:241](../KeyboardExtension/Sources/KeyboardViewController.swift)).
- Gate: preferovaně přidat `enabled: Bool` param do `AutoCapitalizer.shouldCapitalize` (AutoCapitalizer zůstane čistá pure-funkce) — když `false` → vždy `false`. Volající `refreshAutoCapitalization` předá `state.autoCapitalizationEnabled`.
- Pipeline fix z Části A (re-run po textových akcích).
- [`SettingsView`](../Features/Settings/Sources/SettingsView.swift) `keyboardSection`: `Toggle` + footer. [`SettingsViewModel`](../Features/Settings/Sources/SettingsViewModel.swift): bindable `autoCapitalizationEnabled` (čte/zapisuje store). `L10n.Settings.Keyboard`: title + footer string.
- Mock: `SettingsViewModelMock` doplnit property.

## Non-goals

- Override-ON v `.none` polích.
- Čárka jako trigger.
- Změna trigger setu (`. ? !` + start + `\n\n` beze změny).
- Změna `ShiftStateMachine` (jen `KeyboardState.page` flip přes existující cestu).

## Akceptační kritéria

- Po `". "` (přes `dot` klávesu **i** přes symboly), `"? "`, `"! "` → další písmeno velké (toggle ON).
- Toggle OFF → nikdy velké (ani na začátku pole).
- Pole `.none` (username/heslo) → nikdy velké i při ON.
- Default po čisté instalaci = ON.
- **Integrační test přes dispatcher** (ne jen `AutoCapitalizer`): `.`/`?`/`!` + mezera přes obě cesty → `letters(.upper)`; OFF → zůstává `.lower`.

## Regresní síť

**Existující — musí projít:** [`AutoCapitalizerTests`](../KeyboardCore/Tests/AutoCapitalizerTests.swift) (případně rozšířit o `enabled` param), [`ShiftStateMachineTests`](../KeyboardCore/Tests/ShiftStateMachineTests.swift), auto-switch po space (task 27).

**Nové:** `enabled == false` → `shouldCapitalize` vždy `false`; integrační test tečka-přes-dot-klávesu kapitalizuje; cross-process toggle čtení v extension.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, iPhone 17 / iOS 26.2.
- **Nejdřív reprodukovat bug** (tečka přes `dot` klávesu, pak space) → potvrdit hypotézu → fix → ověřit, že `?`/`!` dál fungují.
- Manuálně: vypnout toggle → ověřit, že nic nekapitalizuje; username pole → bez velkého.
- Bez nových `.swift` souborů → `tuist generate` netřeba.
