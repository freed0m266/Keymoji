# 09 — Delete repeat-on-hold

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Medium

## Cíl

Když uživatel drží delete klávesu, mazat průběžně char-by-char. Initial delay 400 ms (single delete na tap), pak repeat à 80 ms. Po ~2 s držení **NEzrychluje** ani **NEpřepíná** na word-by-word — to je Future task (`future-delete-word-by-word.md`).

## Kontext

- `KeyView` z tasku 03 má `DragGesture(minimumDistance: 0)` pro pressed state. Long-press z tasku 07 přidává popover pro klávesy s alternates. Delete klávesa **NEMÁ** alternates → long-press popover nevyskočí → můžeme přidat dedicated repeat behavior.
- Repeat se realizuje přes `Timer` nebo `Task` v `KeyView`. Při touch down → start timer s 400 ms initial → po vypršení trigger backspace + start druhý timer s 80 ms repeat. Při touch up → cancel oba.

## Scope

### 1. Delete-specific repeat logic v `KeyView`

`KeyboardUI/Sources/Views/KeyView.swift` (rozšíření z task 03):

```swift
struct KeyView: View {
    // existing fields
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        baseKeyView
            .simultaneousGesture(combinedGesture)
    }

    private var combinedGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed {
                    isPressed = true
                    handleTouchDown()
                }
            }
            .onEnded { value in
                isPressed = false
                handleTouchUp(landed: value.location)
            }
    }

    private func handleTouchDown() {
        if case .backspace = key.action {
            startBackspaceRepeat()
        } else if !key.alternates.isEmpty {
            startLongPressTimer()             // z task 07
        }
    }

    private func handleTouchUp(landed: CGPoint) {
        cancelBackspaceRepeat()
        cancelLongPressTimer()

        if isShowingPopover {
            commitHighlightedAlternate()
        } else {
            onTap(key)                        // normální tap
        }
    }

    private func startBackspaceRepeat() {
        repeatTask = Task {
            // Initial fire (immediate, on touch down? OR after 400 ms?)
            // Apple chování: první backspace na touch down (tap-style), pak pauza 400 ms, pak repeat.
            // Ale tap-style by se spustil v onEnded — to by mazalo na puštění, ne na držení.
            // Lepší: na touch down NEdělej nic; v onEnded krátký tap → 1 backspace; když držíš > 400 ms → repeat fires.

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            while !Task.isCancelled {
                await MainActor.run {
                    onTap(key)                // dispatch backspace
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func cancelBackspaceRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
```

**Pozor na conflict s normální tap behavior:** `onTap(key)` v `handleTouchUp` se volá při krátkém tapu. Při repeat (>400 ms hold) první backspace už proběhl v Task → po puštění se NEvolá `onTap` znovu (protože při pustění bychom dvakrát smazali).

Řešení: track flag, jestli repeat už začal:

```swift
@State private var didStartRepeating = false

private func startBackspaceRepeat() {
    didStartRepeating = false
    repeatTask = Task {
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            didStartRepeating = true
            onTap(key)                        // první repeat fire
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onTap(key)
            }
        }
    }
}

private func handleTouchUp(landed: CGPoint) {
    let wasRepeating = didStartRepeating
    cancelBackspaceRepeat()
    cancelLongPressTimer()

    if isShowingPopover {
        commitHighlightedAlternate()
    } else if !wasRepeating {
        onTap(key)                            // jen krátký tap, ne post-repeat
    }
}
```

### 2. Vizuální feedback během repeat

Při repeat by `KeyView` měl zůstat ve pressed state (uživatel drží prst). To je už zařízené z task 03 (`isPressed` ostává true).

Volitelně: po prvním repeat fire ukázat malou pulsovací animaci nebo trvalý highlight. **Doporučení:** žádná extra animace pro v1.0, basic pressed state dostatečné.

### 3. Unit testy

Repeat behavior je SwiftUI gesture interakce → testovatelné jen integrace, ne pure logic. Nepíšeme unit testy pro `KeyView` repeat.

Místo toho: testujeme, že `KeyboardState`/`InputDispatcher` snese rychlé opakované `.backspace` calls a nepokazí state. To je už pokryté v task 04 testech (kdy `backspaceCount` se inkrementuje per call). Doplnit jeden test:

```swift
func testMultipleBackspaces_inRapidSuccession() {
    var state = KeyboardState(...)
    let proxy = MockTextProxy()

    for _ in 0..<10 {
        InputDispatcher.dispatch(
            key: backspaceKey,
            state: &state,
            proxy: proxy,
            controller: MockController(),
            haptics: MockHaptics()
        )
    }
    XCTAssertEqual(proxy.backspaceCount, 10)
}
```

### 4. Manuální test

V Notes.app:

- Napsat „aaaaaaaaaa" (10 písmen).
- Touch down na delete, držet 2 sekundy.
- Očekávat: jedno smazání ihned nepřijde; po 400 ms se začne mazat ~12 chars/s.
- Pustit po 2 s → maze přestane.
- Po pustení napsat dvojklik backspace (rychlý tap-tap) → 2 charaktery smazané, žádný repeat.

### 5. Conflict s long-press popover na ostatních klávesách

Long-press popover (task 07) pro letter keys aktivuje po 450 ms. Delete repeat aktivuje po 400 ms. Pokud uživatel drží letter klávesu **a** zároveň by mohl mít delete charakter, je tu race? Ne, repeat-on-hold se nevolá pro letter keys (jen pro `.backspace` action). Detekce v `handleTouchDown` přes `if case .backspace = key.action`.

### 6. Pre-warming feedback

Není potřeba `UIImpactFeedbackGenerator.prepare()` per backspace repeat — `UIKitHaptics` to už dělá v init (task 08).

`haptics.keyTap()` se volá v `InputDispatcher.dispatch` při `.backspace`. To znamená, že **každý** repeat backspace vibruje. Při 12 backspaces/s to je dost vibrací → potenciálně otravné.

**Doporučení:** v `InputDispatcher` při `.backspace` rozlišit „first backspace" vs „repeat":

- Single backspace (tap nebo first repeat fire) → haptic.
- Subsequent repeats → NO haptic.

Implementačně: `KeyboardState` track `backspaceRepeatActive: Bool` — set true při `repeat` mode entry, false při released. `InputDispatcher` při `.backspace` kontroluje a skipuje haptic pokud `backspaceRepeatActive == true && nejedná se o první fire`.

Alternativně jednodušší: vždy haptic na backspace, ale `UIImpactFeedbackGenerator` při rychlé sequence se sám rate-limituje internally (Apple impl). Praktický rozdíl nebude velký. **Pro v1.0:** vždy haptic, žádné rate-limiting.

Pokud po reálném testu zjistíme, že je to otravné, je to rate-limit v `UIKitHaptics.keyTap` (last fire timestamp + minimum interval).

## Mimo scope

- Word-by-word delete po ~2 s držení — Future task.
- Acceleration (postupné zrychlování repeat rate) — Future polish.
- Custom delete animations (swoosh, particles) — wontfix.
- Swipe-to-delete (drag delete vlevo by smazalo whole word) — wontfix / Future consideration.

## Hotovo když

- Krátký tap na delete maže 1 znak.
- Hold delete > 400 ms začne mazat průběžně à 80 ms.
- Po puštění mazání přestane.
- Žádný extra znak nesmazán „omylem" po release (testováno: smaže přesně počet, který user držel).
- 1 přidaný unit test (rapid backspace dispatch).
- Manuální test na zařízení potvrdí očekávanou rychlost.

## Rizika

- **`Task.sleep(for:)` accuracy** — async sleep v SwiftUI gesture handler se může zpozdit pod heavy CPU load. Repeat rate může v reálu být 60–80 ms místo 80, nebo i pomalejší. Subjektivně velmi malý rozdíl, žádný blocker.
- **Touch up nezacancluje repeat na čas** — pokud Task už spal a probudil se po user release, je tu race window kde se vystrelil jeden zbytečný backspace. `Task.isCancelled` check po každém sleep ale tohle eliminuje.

## Reference

- `KeyboardUI/Sources/Views/KeyView.swift` (task 03 + task 07 modifikace)
- `KeyboardCore/Sources/Logic/InputDispatcher.swift` (task 04)
- Apple HIG: Custom keyboard — nedokumentuje repeat behavior

## Codex review

**Skip** — mechanická `Task.sleep` smyčka, malé scope, dobře identifikovatelná manuálně.
