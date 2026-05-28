# 36 — Programovatelná akce na dvojitý tap na space

**Status:** Done — 2026-05-28

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Medium (daily typing flow)

## Cíl

Uživatel si v host appce zvolí, co má dělat dvojitý tap na space:

1. **Napsat tečku** (`". "` substituce — current behavior, default)
2. **Schovat klávesnici** (dismiss)
3. **Nedělat nic** (druhý space se vloží jako normální mezera)

Preference žije v `AppGroupStore`, čte se v `viewWillAppear` jako ostatní settings, `InputDispatcher.handleSpace` ji respektuje.

## Kontext

- Dnes je dvojitý tap na space hardcoded na `". "` substituci v `KeyboardCore/Sources/Logic/InputDispatcher.swift` v `handleSpace(state:proxy:now:)`. Window 500 ms (`doubleSpaceWindow`).
- Některým uživatelům `". "` chování vadí (chybné triggery při rychlém psaní, jiné jazykové návyky). Apple stock klávesnice nabízí v Settings → General → Keyboards toggle „." Shortcut" (zap/vyp). My jdeme o krok dál — třetí volba „dismiss" je oblíbená feature ze SwiftKey.
- Settings screen je v [Features/Settings/Sources/SettingsView.swift](Features/Settings/Sources/SettingsView.swift) — přidáme nový Picker do `keyboardSection`.
- `AppGroupStore` má vzor pro string-enum preferenci: viz `appearance: AppearancePreference` v [KeyboCore/Sources/Shared/AppGroupStore.swift:99](KeyboCore/Sources/Shared/AppGroupStore.swift:99). Stejný pattern použijeme.
- `KeyboardControlling.dismissKeyboard()` už existuje ([KeyboardCore/Sources/Public/KeyboardControlling.swift](KeyboardCore/Sources/Public/KeyboardControlling.swift)) — `InputDispatcher.dispatch` ho dostává v parametru, takže `handleSpace` k němu může dosáhnout.

## Scope

### 1. `SpaceDoubleTapAction` enum

Nový soubor `KeyboardCore/Sources/Models/SpaceDoubleTapAction.swift`:

```swift
import Foundation

/// What the keyboard does when the user double-taps space within `InputDispatcher.doubleSpaceWindow`.
/// Persisted as a string in `AppGroupStore` under `spaceDoubleTapAction`.
public enum SpaceDoubleTapAction: String, Sendable, CaseIterable {
    /// Replace the previous space with ". " (Apple-stock behavior). Default.
    case insertPeriod
    /// Hide the keyboard. First space stays inserted; second tap dismisses without inserting.
    case dismissKeyboard
    /// No special handling — the second space is inserted as a regular space.
    case none
}
```

Důvod, proč v `KeyboardCore` (a ne v `KeyboCore`): hodnota se čte uvnitř `InputDispatcher`, který je v `KeyboardCore`. `AppGroupStore` (v `KeyboCore`) referencuje tento enum přes import — `KeyboCore` už importuje `KeyboardCore`? Pokud ne, zvolíme opačnou polohu (enum v `KeyboCore`, `InputDispatcher` ho importuje). **Zkontrolovat dependency graph před implementací** — `AppearancePreference` žije v `KeyboCore`, takže nejspíš dáme i `SpaceDoubleTapAction` do `KeyboCore/Sources/Shared/` pro konzistenci a `KeyboardCore` ho bude importovat. Důležité je, ať enum sdílí host app i extension přes jeden import bez kruhové závislosti.

### 2. `AppGroupStoreKey` + typed accessor

V [KeyboCore/Sources/Shared/AppGroupStoreKey.swift](KeyboCore/Sources/Shared/AppGroupStoreKey.swift) přidat case:

```swift
case spaceDoubleTapAction
```

V [KeyboCore/Sources/Shared/AppGroupStore.swift](KeyboCore/Sources/Shared/AppGroupStore.swift) (vedle `appearance`):

```swift
var spaceDoubleTapAction: SpaceDoubleTapAction {
    get {
        guard let raw = string(forKey: .spaceDoubleTapAction) else { return .insertPeriod }
        return SpaceDoubleTapAction(rawValue: raw) ?? .insertPeriod
    }
    set { setString(newValue.rawValue, forKey: .spaceDoubleTapAction) }
}
```

Default `.insertPeriod` — jak chce zadání. Unknown raw value fallback také `.insertPeriod` (defensive proti migracím / corrupted defaults).

### 3. `KeyboardState` nové pole

V [KeyboardCore/Sources/Models/KeyboardState.swift](KeyboardCore/Sources/Models/KeyboardState.swift):

```swift
public var spaceDoubleTapAction: SpaceDoubleTapAction
```

A přidat do `init(...)` s default `.insertPeriod`. Pole má stejnou roli jako `showNumberRow` — runtime kopie nastavení, kterou `KeyboardViewController` plní z `AppGroupStore` v `viewWillAppear` (viz scope 5).

### 4. `InputDispatcher.handleSpace` respektuje volbu

V [KeyboardCore/Sources/Logic/InputDispatcher.swift](KeyboardCore/Sources/Logic/InputDispatcher.swift), `case .space:` blok a `handleSpace`:

```swift
case .space:
    handleSpace(state: &state, proxy: proxy, controller: controller, now: now())
    if case .symbols = state.page {
        state.page = .letters(.lower)
    }
```

```swift
private static func handleSpace(
    state: inout KeyboardState,
    proxy: any TextDocumentProxying,
    controller: any KeyboardControlling,
    now: Date
) {
    let withinWindow = state.lastSpaceInsertedAt.map { now.timeIntervalSince($0) < doubleSpaceWindow } ?? false
    let isDoubleTap = state.lastInsertWasSpace && withinWindow

    guard isDoubleTap else {
        proxy.insertText(" ")
        state.lastInsertWasSpace = true
        state.lastSpaceInsertedAt = now
        return
    }

    switch state.spaceDoubleTapAction {
    case .insertPeriod:
        proxy.deleteBackward()
        proxy.insertText(". ")
        state.lastInsertWasSpace = true
        state.lastSpaceInsertedAt = nil       // prevents triple-tap chaining
    case .dismissKeyboard:
        // First space is already in the document; second tap just dismisses without inserting.
        controller.dismissKeyboard()
        state.lastInsertWasSpace = true        // trailing char in document is still " "
        state.lastSpaceInsertedAt = nil
    case .none:
        // No special handling — fall through to a regular space insert.
        proxy.insertText(" ")
        state.lastInsertWasSpace = true
        state.lastSpaceInsertedAt = now        // keep timestamp so the *next* tap can still double-tap, if user remaps later? See note.
    }
}
```

**Pozn. k `.none` a timestamp:** s `.none` se efektivně double-tap feature vypíná, takže timestamp reset nebo refresh nehraje roli pro samotnou klávesnici. Necháme `now`, ať se chování přiblíží stavu „žádný double-tap se nikdy nestal" — tři rychlé spaces vedou ke třem mezerám bez jakékoli substituce.

**Pozn. k `.dismissKeyboard` a auto-switch zpět na letters:** scope 1 v [tasks/27-auto-switch-to-letters-after-space.md](tasks/27-auto-switch-to-letters-after-space.md) přepíná page na `.letters(.lower)` po každém space. Když uživatel dismissne přes double-tap na symbol page, page se přepne na letters (uvnitř `dispatch`, *po* `handleSpace`). Klávesnice se sice zavřela, ale při příštím otevření bude na letters — což je obvykle žádoucí (next-word default). Žádný speciální handling není potřeba.

### 5. `KeyboardViewController` čte preferenci

V `KeyboardExtension/Sources/KeyboardViewController.swift` (vedle existujícího `showNumberRow` re-read v `viewWillAppear`):

```swift
public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    state.showNumberRow = AppGroupStore.shared.showNumberRow
    state.spaceDoubleTapAction = AppGroupStore.shared.spaceDoubleTapAction
    // …existing reads…
    rebuild()
}
```

Stejně jako u ostatních settings: změna v host appce se projeví **při dalším otevření klávesnice**, ne live. Live cross-process observation je vlastní task (22 — Darwin notifications).

### 6. Settings UI — Picker

V [Features/Settings/Sources/SettingsView.swift](Features/Settings/Sources/SettingsView.swift), uvnitř `keyboardSection` (nebo nová sub-sekce — viz UX poznámka):

```swift
Section {
    Picker(Texts.Keyboard.spaceDoubleTapAction, selection: $viewModel.spaceDoubleTapAction) {
        ForEach(SpaceDoubleTapAction.allCases, id: \.self) { action in
            Text(label(for: action)).tag(action)
        }
    }
    .pickerStyle(.menu)
} footer: {
    Text(Texts.Keyboard.spaceDoubleTapFooter)
}

private func label(for action: SpaceDoubleTapAction) -> String {
    switch action {
    case .insertPeriod:    return Texts.Keyboard.SpaceDoubleTap.insertPeriod
    case .dismissKeyboard: return Texts.Keyboard.SpaceDoubleTap.dismissKeyboard
    case .none:            return Texts.Keyboard.SpaceDoubleTap.none
    }
}
```

**Picker style:** `.menu` (dropdown), ne `.segmented` — 3 labely typu „Insert period" / „Hide keyboard" / „Do nothing" jsou na segmented control moc dlouhé. Menu picker je standardní iOS Settings UX (viz Apple Settings → Keyboards screen).

**Sekce:** vlastní `Section` (ne v existujícím `keyboardSection` se 3 toggly), aby footer s vysvětlením seděl jen k téhle volbě. Header lze sdílet pod „Keyboard" nebo dát „Double-tap space" — finální detail nech na cit při psaní.

### 7. `SettingsViewModel` + protocol

V `Features/Settings/Sources/SettingsViewModel.swift`:

```swift
public var spaceDoubleTapAction: SpaceDoubleTapAction {
    didSet { store.spaceDoubleTapAction = spaceDoubleTapAction }
}
```

A v initu načíst z `store.spaceDoubleTapAction`. V `SettingsViewModeling` protokolu přidat:

```swift
var spaceDoubleTapAction: SpaceDoubleTapAction { get set }
```

V `Features/Settings/Testing/SettingsViewModelMock.swift` přidat default `.insertPeriod`.

### 8. Lokalizace

`KeyboResources/Resources/en.lproj/Localizable.strings`:

```strings
"settings.keyboard.spaceDoubleTapAction" = "Double-tap space";
"settings.keyboard.spaceDoubleTapFooter" = "Choose what happens when you tap the space bar twice in quick succession.";
"settings.keyboard.spaceDoubleTap.insertPeriod" = "Insert “. ”";
"settings.keyboard.spaceDoubleTap.dismissKeyboard" = "Hide keyboard";
"settings.keyboard.spaceDoubleTap.none" = "Do nothing";
```

(+ `cs.lproj` pokud existuje. Zkontrolovat v repu.)

V `KeyboResources` `L10n` aliasy doplnit pod `L10n.Settings.Keyboard.SpaceDoubleTap.*` (pattern `L10n.Settings.Keyboard.Appearance.*` jako vzor).

### 9. Unit testy

V `KeyboardCore/Tests/InputDispatcherTests.swift` (rozšířit existující space testy):

- `testDoubleSpace_insertPeriodMode_substitutes()` — state.spaceDoubleTapAction = `.insertPeriod`, dvě space taps do 500 ms → inserted=`[" ", ". "]`, backspaceCount=1. (Regression — current behavior.)
- `testDoubleSpace_dismissKeyboardMode_dismissesWithoutInsertingSecond()` — `.dismissKeyboard`, dvě space taps → inserted=`[" "]`, `mockController.dismissCalls == 1`, žádný backspace.
- `testDoubleSpace_noneMode_insertsTwoSpaces()` — `.none`, dvě space taps → inserted=`[" ", " "]`, žádný backspace, žádný dismiss.
- `testDoubleSpace_dismissKeyboardMode_outsideWindow_doesNotDismiss()` — `.dismissKeyboard`, dvě space taps s `now()` posunutým o 600 ms → inserted=`[" ", " "]`, dismissCalls=0.
- `testDoubleSpace_dismissKeyboardMode_onSymbols_dismissesAndSwitchesToLetters()` — page=`.symbols(.primary)`, `.dismissKeyboard`, dvě space taps → dismissCalls=1, page=`.letters(.lower)` (kontrola, že auto-switch z tasku 27 stále běží).
- `testTripleSpace_insertPeriodMode_doesNotChain()` — tři rychlé space taps → druhý nahradí na `". "`, třetí nesubstituuje znovu (timestamp reset). Existing test, jen ověřit, že refactor nerozbil.

`MockController` musí mít `var dismissCalls = 0` a inkrementovat v `dismissKeyboard()`.

### 10. Snapshot test pro Settings

`Features/Settings/Tests/SettingsSnapshots.swift` — Picker se vykreslí v existujícím snapshotu Settings screenu automaticky. Refresh existujících snapshotů (1× light, 1× dark) — diff = jeden nový řádek s Pickerem. Žádný nový dedicated snapshot.

### 11. Manuální verify

1. Otevřít host appku → Settings.
2. Vidět novou volbu „Double-tap space" s defaultem „Insert ». «".
3. V Notes.app napsat „hello  " (rychlé dvě mezery) → vidět „hello. ". (Regression: default behavior.)
4. Vrátit se do Settings, vybrat „Hide keyboard". Otevřít Notes, otevřít klávesnici, dvě rychlé mezery → klávesnice se zavře. V Notes je trailing „ " (jedna mezera).
5. Vrátit se do Settings, vybrat „Do nothing". V Notes dvě rychlé mezery → „  " (dvě mezery), žádná substituce.
6. Quit a re-open host appku → volba persistuje.

## Mimo scope

- Live cross-process observation změny preference — task 22.
- Settings pro samotné window 500 ms (uživatelská konfigurace rychlosti double-tap). Apple-default je dost dobrý, žádný request.
- Dodatečné akce (např. „insert čárka", „insert custom string"). Pokud někdo bude chtít, samostatný Future task.
- Per-app override (jiné chování v Mail vs. Notes). Out of scope, v1.x ne.
- Long-press space — to je trackpad mode (task 23), jiná gesture, nepleteme.

## Hotovo když

- `SpaceDoubleTapAction` enum existuje, default `.insertPeriod`.
- `AppGroupStore.spaceDoubleTapAction` getter/setter persistuje volbu, default `.insertPeriod`, fallback na default při neznámém raw value.
- `KeyboardState` má `spaceDoubleTapAction` pole, `KeyboardViewController` ho re-loaduje v `viewWillAppear`.
- `InputDispatcher.handleSpace` se větví podle `state.spaceDoubleTapAction`:
  - `.insertPeriod` → současné chování (`". "` substituce).
  - `.dismissKeyboard` → druhý tap volá `controller.dismissKeyboard()`, žádný insert na druhém tapu.
  - `.none` → druhý tap je normální space.
- Settings screen má Picker (menu style) v sekci „Keyboard" s footerem.
- Lokalizace `en` (+ `cs` pokud existuje) má všechny stringy.
- 6 nových / rozšířených unit testů v `InputDispatcherTests` green.
- Snapshot testy Settings screenu refreshovány.
- Existující testy KeyboardCore i KeyboardUI green.
- Manuální verify v simulátoru pokrývá všechny 3 módy + persistence.

## Rizika

- **`dismissKeyboard()` UX trailing space.** Po dismissu zůstane v dokumentu jedna mezera z prvního tapu. To je správně (uživatel ji tam vědomě vložil), ale někteří mohou očekávat „čistý" dismiss bez stop. Hold rule: respektovat to, co uživatel zapsal — nemazat jeho input. Pokud feedback ukáže opak, budoucí toggle „Strip trailing space on dismiss" jako samostatný task.
- **Interakce s auto-switch (task 27).** Když dismissujeme ze symbol page, scope 4 dělá `handleSpace` *před* page switchem na letters. Pořadí je: handleSpace → dismiss → return z handleSpace → if-symbols → page = letters. Page state je updated i přes dismiss; není problém — klávesnice je jen schovaná, ne destroyed. Test 5 ve scope 9 to ověří.
- **Window 500 ms a `.dismissKeyboard`.** Uživatel může chtít dvě mezery za sebou a omylem triggernout dismiss. Mitigace: 500 ms je dost krátké, že náhodný double-tap je vzácný; pokud někoho rozčiluje, může přepnout na `.none`. Žádný runtime fix.
- **`SpaceDoubleTapAction` umístění (KeyboCore vs. KeyboardCore).** Před implementací zkontrolovat dependency graph v `Tuist/`. `AppearancePreference` je v `KeyboCore` a používá ji jak `AppGroupStore` (`KeyboCore`), tak Settings (`Features/Settings`). `SpaceDoubleTapAction` potřebuje navíc i `KeyboardCore` (`InputDispatcher`). Pokud `KeyboardCore` neimportuje `KeyboCore`, dáme enum sem; jinak `KeyboCore` jako `AppearancePreference`. **Tuist dep graph je single source of truth — neimplementovat naslepo.**

## Reference

- [tasks/27-auto-switch-to-letters-after-space.md](tasks/27-auto-switch-to-letters-after-space.md) — vzor pro space-related InputDispatcher změny + page switch interakce.
- [tasks/16-light-dark-override.md](tasks/16-light-dark-override.md) — vzor pro string-enum preferenci v `AppGroupStore` + Settings Picker.
- [KeyboCore/Sources/Shared/AppearancePreference.swift](KeyboCore/Sources/Shared/AppearancePreference.swift) — vzor enum.
- [KeyboCore/Sources/Shared/AppGroupStore.swift:99](KeyboCore/Sources/Shared/AppGroupStore.swift:99) — vzor accessor.
- [Features/Settings/Sources/SettingsView.swift:62](Features/Settings/Sources/SettingsView.swift:62) — vzor Picker integration.
- [KeyboardCore/Sources/Logic/InputDispatcher.swift:99](KeyboardCore/Sources/Logic/InputDispatcher.swift:99) — `handleSpace` k úpravě.

## Codex review

**Ano** — `handleSpace` je hot path s netriviální state machine (double-tap window, page interakce, dismiss side-effect). Branching podle nové preference zvětšuje surface bug risk. Stojí za review.
