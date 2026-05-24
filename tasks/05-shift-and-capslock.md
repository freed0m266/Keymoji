# 05 — Shift state machine + caps lock

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Nahradit zjednodušený 1-tap shift toggle z tasku 04 plnohodnotnou state machine: `lower → upper (1× tap) → lower (po vložení písmene)`, `lower → upper → capsLock (double-tap)`, `capsLock → lower (tap)`. Vizuální feedback shift klávesy v každém stavu. Žádný auto-cap — ten je task 06.

## Kontext

- V tasku 04 je shift čistě toggle `lower ↔ upper`, žádný caps lock. `KeyboardState.page = .letters(.upper)` se po vložení písmene snižuje na `.letters(.lower)` (downshift). To je dobrý základ.
- `KeyAction.capsLockToggle` už v modelu existuje (task 02), v dispatch je stubnutý.
- Detekce double-tap se v iOS typicky řeší přes time window (400–500 ms). Apple double-tap na shift je ~300 ms threshold reálně.
- Caps lock je `KeyboardPage.letters(.capsLock)`, tap na shift v capsLock stavu → `lower`. Caps lock se *nesnižuje* po písmenech.

## Scope

### 1. `ShiftStateMachine` v `KeyboardCore`

`KeyboardCore/Sources/Logic/ShiftStateMachine.swift`:

```swift
public enum ShiftStateMachine {
    public struct State: Sendable, Equatable {
        public var page: KeyboardPage
        public var lastShiftTapAt: Date?

        public init(page: KeyboardPage = .letters(.lower), lastShiftTapAt: Date? = nil) {
            self.page = page
            self.lastShiftTapAt = lastShiftTapAt
        }
    }

    public enum Event: Sendable, Equatable {
        case shiftTapped(at: Date)
        case characterInserted
        case pageSwitched(to: KeyboardPage)
    }

    public static func reduce(_ state: State, _ event: Event) -> State {
        var s = state
        switch event {
        case .shiftTapped(let now):
            s.page = nextPageAfterShiftTap(s.page, lastTapAt: s.lastShiftTapAt, now: now)
            s.lastShiftTapAt = now

        case .characterInserted:
            // Downshift jen z upper, ne z capsLock
            if case .letters(.upper) = s.page {
                s.page = .letters(.lower)
            }

        case .pageSwitched(let target):
            s.page = target
            s.lastShiftTapAt = nil
        }
        return s
    }

    private static func nextPageAfterShiftTap(
        _ page: KeyboardPage,
        lastTapAt: Date?,
        now: Date,
        doubleTapWindow: TimeInterval = 0.4
    ) -> KeyboardPage {
        guard case .letters(let shift) = page else { return page }

        let isDoubleTap: Bool = lastTapAt.map { now.timeIntervalSince($0) < doubleTapWindow } ?? false

        switch shift {
        case .lower:
            return .letters(.upper)
        case .upper:
            return isDoubleTap ? .letters(.capsLock) : .letters(.lower)
        case .capsLock:
            return .letters(.lower)
        }
    }
}
```

### 2. Integrace do `InputDispatcher`

Refaktor `InputDispatcher.dispatch` z tasku 04:

```swift
case .shift:
    state = applyShiftTap(state: state)

case .insertText(let text):
    proxy.insertText(textWithShiftApplied(text, state: state))
    state = ShiftStateMachine.reduce(state, .characterInserted)
    updateSpaceTracking(...)

case .switchPage(let page):
    state = ShiftStateMachine.reduce(state, .pageSwitched(to: page))
```

Pomocná funkce:

```swift
private static func applyShiftTap(state: KeyboardState) -> KeyboardState {
    let now = Date()
    let smState = ShiftStateMachine.State(page: state.page, lastShiftTapAt: state.lastShiftTapAt)
    let newSm = ShiftStateMachine.reduce(smState, .shiftTapped(at: now))
    var s = state
    s.page = newSm.page
    s.lastShiftTapAt = newSm.lastShiftTapAt
    return s
}
```

Pole `lastShiftTapAt: Date?` přidat do `KeyboardState` (task 04 ho zatím nemá).

### 3. `KeyAction.capsLockToggle` — odebrat

Vzhledem k tomu, že caps lock se v této verzi triggerne double-tapem (vyřízeno ve state machine), `KeyAction.capsLockToggle` jako separátní action **není potřeba**. Smazat z `KeyAction` enum (task 02). Pokud něco už na něj odkazuje, opravit.

Důvod čištění: jednoduší API. Klávesa shift má jeden `.shift` action, state machine řeší zbytek.

### 4. Vizuální feedback v `KeyView`

`KeyboardUI/Sources/Style/KeyStyle.swift` — rozšířit `KeyStyle.style(for:shift:)`:

```swift
extension KeyStyle {
    static func style(for role: KeyRole, page: KeyboardPage? = nil, isShiftKey: Bool = false) -> KeyStyle {
        if isShiftKey, case .letters(let shift) = page {
            switch shift {
            case .lower:
                // normální system key style — bg systemGray2
                return systemKey()
            case .upper:
                // invertovaný kontrast — bg label, fg systemBackground
                return shiftActive()
            case .capsLock:
                // jako upper, ale s indikátorem (line under nebo dot)
                return shiftCapsLock()
            }
        }
        return baseStyle(for: role)
    }
}
```

V `KeyView` rendering shift klávesy:

- `.lower`: standardní `Image(systemName: "shift")`
- `.upper`: `Image(systemName: "shift.fill")`, invertovaný kontrast
- `.capsLock`: `Image(systemName: "capslock.fill")` (Apple SF Symbol existuje), invertovaný kontrast, NEBO `Image(systemName: "shift.fill")` + custom underline `Rectangle()` overlay

**Preferovaná varianta:** `Image(systemName: "capslock.fill")` — sémanticky správnější, žádný custom overlay, accessibility label automaticky správný.

### 5. Detekce že klávesa je shift v `KeyView`

`KeyView` parametr `isShiftKey: Bool` určujeme tak, že volající (`KeyRowView`) ví, že key má `KeyAction.shift`. Alternativně může `KeyView` derive sám z `key.action`. Druhá varianta čistší — zapouzdřuje styling rozhodnutí.

### 6. Unit testy

`KeyboardCore/Tests/ShiftStateMachineTests.swift`:

- `lower → shiftTap → upper`.
- `upper → characterInserted → lower` (downshift).
- `upper → shiftTap (>400ms) → lower` (single tap to deactivate).
- `upper → shiftTap (<400ms) → capsLock` (double-tap).
- `capsLock → shiftTap → lower` (deactivate caps).
- `capsLock → characterInserted → capsLock` (NO downshift in caps).
- `capsLock → shiftTap (<400ms, double) → lower` (double-tap z capsLock taky deaktivuje — jen jednoduché tap stačí, druhý tap ho zbytečně testuje; ale ověřit že to nezahodí caps).
- `lower → pageSwitched(.symbols) → symbols`.
- `lower → pageSwitched(.letters(.lower)) → letters(.lower)`.
- `upper → pageSwitched(.symbols) → symbols, lastShiftTapAt == nil` (page switch resetuje shift tap history).
- `lower → shiftTap → pageSwitched(.symbols) → shiftTap(@.symbols) → no change` (shift tap na symbols page žádný efekt — `nextPageAfterShiftTap` early-returnuje).

~10 testů. Použít fixed `Date()` instances jako vstup, ne `Date()` v testu (deterministicky).

### 7. Snapshot testy update

Snapshot testy v `KeyboardUI/Tests/KeyboardViewSnapshots.swift` z tasku 03 už pokrývají `letters(.lower)`, `letters(.upper)`, `letters(.capsLock)`. **Verifikovat**, že capsLock snapshot renderuje s `capslock.fill` ikonkou + invertovaným kontrastem. Pokud snapshoty z task 03 byly z doby, kdy `KeyView` ještě nepřebíral shift style, **re-record** ty tři.

## Mimo scope

- Auto-capitalization (task 06).
- `lastShiftTapAt` se NEpersistuje (in-memory state v extension procesu). Pokud uživatel zavře klávesnici a po 5 minutách otevře, double-tap window se vyresetuje. Žádný big deal.
- Custom double-tap window v Settings — Future polish.

## Hotovo když

- Shift z lower → upper, vložené písmeno upper, pak zpět na lower.
- Double-tap shift z lower → upper → capsLock. Klávesa shift má distinct visual (capslock.fill ikonka).
- V capsLock vložená písmena jsou upper a klávesnice zůstává v capsLock.
- Tap na shift v capsLock → lower.
- Switch na symbols a zpět resetuje shift double-tap window.
- ~10 unit testů `ShiftStateMachineTests` green.
- Capslock snapshot (v KeyboardUI/Tests) vizuálně rozdílný od upper.
- Manuální test v Notes.app: napsat „HELLO World." s caps lock + jednotlivé shifty správně.

## Rizika

- **Double-tap window 400 ms** může na pomalejších palcích triggernout false-positive (uživatel chtěl tap-tap dva normální upper-shifty). Apple má 300 ms. Pokud user feedback naznačuje false positives, snížit.
- **`KeyAction.capsLockToggle` odebrání** — pokud je něco už z tasku 04 odkazuje, build selže. Quick fix.

## Reference

- `KeyboardCore/Sources/Logic/InputDispatcher.swift` (z tasku 04)
- Apple SF Symbols: `shift`, `shift.fill`, `capslock.fill`

## Codex review

**Ano** — state machine s time windows je klasická past na off-by-one. Stojí za druhé oko.
