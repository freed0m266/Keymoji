# 07 — Long-press popover s diakritikou

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** L · **Dopad:** High

## Cíl

Implementovat long-press popover, který se objeví nad klávesou držením prstu ~450 ms, ukáže `alternates` (diakritiku) jako horizontální řadu kandidátů, dovolí uživateli slide-to-select prstem (bez puštění) a při puštění vloží zvýrazněný alternate. Funguje pro všechna písmena s diakritikou (~14 letters) i pro čísla (long-press symboly z tasku 02). Haptika při entry do popoveru a při změně highlighted kandidáta.

Toto je největší UI task v1.0 a největší příležitost pro nečekané chování. Detailní state machine níže.

## Kontext

- `Key.alternates: [KeyContent]` je v modelu z tasku 02. Letters mají 4–8 alternates, čísla mají 1.
- Apple iOS popover má specifickou shape: bublina nad klávesou s tail (trojúhelník) směřujícím dolů na base klávesu. Pro v1.0 můžeme zjednodušit na rounded rectangle bez tail.
- Popover orientace: defaultně centrovaný nad klávesou. Pokud klávesa je na levém okraji, popover se zarovná zleva. Pokud na pravém, zprava. Detection: `keyMidX < popoverHalfWidth` → align left.
- Slide-to-select: prst zůstává přitisknutý od momentu, kdy popover vyskočí. Highlighted kandidát = ten, nad kterým je prst. Move prst → změň highlight. Pusť → vlož highlighted.
- Pokud `alternates.isEmpty`, long-press se neaktivuje (žádný popover, jen normální tap při puštění).
- Pressed visual feedback z tasku 03 musí coexistovat s long-press gesture.

## Scope

### 1. Gesture model

V SwiftUI je kombinace short-tap + long-press + drag jeden z těžších cases. Pure SwiftUI gestures jsou pro tohle občas křehké (priority, simultaneity, cancelation). Zvážit dva přístupy:

- **(a) Pure SwiftUI**: `LongPressGesture(minimumDuration: 0.45)` ∧ `DragGesture(minimumDistance: 0)`, `SimultaneousGesture`.
- **(b) `UIViewRepresentable` wrapper** s custom `UILongPressGestureRecognizer` + `UIPanGestureRecognizer`.

**Doporučení: (a) pure SwiftUI v prvním pokusu.** Pokud po implementaci vidíme bugy (např. cancel race conditions na rychlém tapu), fallback na (b).

State machine jednoho stisku:

```
idle
  ↓ touchDown
pressed                                  (visual highlight)
  ↓ holding > 450ms                      ↘ touchUp before 450ms → insert primary, idle
popover                                  (zobrazit kandidáty, vibrate)
  ↓ dragging                             ↘ drag out of popover bounds → stay on last highlighted? OR cancel?
hovering (jiný highlighted kandidát)     (vibrate na změnu)
  ↓ touchUp → insert highlighted alternate, dismiss popover, idle
```

Edge case: uživatel drží 800ms ale nepohne se. Highlighted = první kandidát (= obvykle primární písmeno, nebo první alternate). Apple konvence: highlighted = primární písmeno na začátku, prst musí kandidáta najít posunem.

**Naše konvence:** highlighted = první *alternate* (ne primary). Důvod: pokud uživatel chtěl primární, neudělal by long-press — udělal by short tap. Long-press = signál „chci variant".

### 2. `LongPressPopoverView`

`KeyboardUI/Sources/Views/LongPressPopoverView.swift`:

```swift
struct LongPressPopoverView: View {
    let baseKey: Key
    let alternates: [KeyContent]
    let highlightedIndex: Int
    let style: KeyStyle

    var body: some View {
        HStack(spacing: 2) {
            ForEach(alternates.indices, id: \.self) { idx in
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(idx == highlightedIndex ? style.pressedBackgroundColor : Color.clear)
                    keyContentView(alternates[idx])
                        .foregroundStyle(idx == highlightedIndex ? Color(.systemBackground) : Color(.label))
                        .padding(8)
                }
                .frame(width: 40, height: 40)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
        )
    }
}
```

Výška popoveru: ~52pt. Šířka: `alternates.count * 42 + 8`.

### 3. Pozicování popoveru relativně klávesy

V `KeyView` (rozšířit z tasku 03):

```swift
struct KeyView: View {
    // existing fields...
    @State private var isShowingPopover = false
    @State private var highlightedAlternateIndex = 0

    var body: some View {
        baseKeyView
            .overlay(alignment: .top) {
                if isShowingPopover, !key.alternates.isEmpty {
                    LongPressPopoverView(
                        baseKey: key,
                        alternates: key.alternates,
                        highlightedIndex: highlightedAlternateIndex,
                        style: style
                    )
                    .offset(y: -56)            // posun nahoru nad klávesu
                    .fixedSize()               // popover neroztahuje base key bounds
                    .zIndex(1000)
                }
            }
            .simultaneousGesture(combinedGesture)
    }
}
```

Edge alignment: pomocí `GeometryReader` zjistit, kde klávesa leží v parent souřadnicích. Pokud klávesa je v levém ~30% šířky klávesnice, popover `.alignment` = `.topLeading` s manuálním `offset(x:)` doprava. Symetricky pro pravý okraj.

Konkretní pravidlo:

```swift
private var popoverHorizontalAlignment: HorizontalAlignment {
    // computed v KeyRowView, předané do KeyView jako parametr
    // index klávesy v řádku < 2 → .leading
    // index klávesy > rowKeyCount - 3 → .trailing
    // else → .center
}
```

### 4. Combined gesture

```swift
private var combinedGesture: some Gesture {
    DragGesture(minimumDistance: 0)
        .onChanged { value in
            if !isPressed {
                isPressed = true
                startLongPressTimer()
            }
            if isShowingPopover {
                updateHighlightedAlternate(from: value.location)
            }
        }
        .onEnded { value in
            isPressed = false
            cancelLongPressTimer()
            if isShowingPopover {
                commitHighlightedAlternate()
                isShowingPopover = false
            } else {
                onTap(key)                   // normální short tap
            }
        }
}

private func startLongPressTimer() {
    longPressTask = Task {
        try? await Task.sleep(for: .milliseconds(450))
        if !Task.isCancelled, !key.alternates.isEmpty {
            await MainActor.run {
                isShowingPopover = true
                highlightedAlternateIndex = 0
                onPopoverEntry()             // haptic callback
            }
        }
    }
}
```

### 5. Highlighted alternate from finger position

```swift
private func updateHighlightedAlternate(from location: CGPoint) {
    // location je v souřadnicích KeyView (parent)
    // popover je posunutý o y: -56, šířka = alternates.count * 42 + 8
    // mapovat location.x na alternate index
    let popoverOriginX = popoverHorizontalOriginX
    let alternateWidth: CGFloat = 42
    let relX = location.x - popoverOriginX
    let newIndex = max(0, min(key.alternates.count - 1, Int(relX / alternateWidth)))
    if newIndex != highlightedAlternateIndex {
        highlightedAlternateIndex = newIndex
        onHighlightChanged()                 // haptic callback
    }
}
```

`popoverHorizontalOriginX` je computed z popover alignment (leading/center/trailing).

### 6. Commit / dismiss

```swift
private func commitHighlightedAlternate() {
    let alternate = key.alternates[highlightedAlternateIndex]
    let synthesizedKey = Key(
        id: key.id + ".alt." + String(highlightedAlternateIndex),
        primary: alternate,
        alternates: [],
        action: .insertText(textValue(alternate)),
        visualWeight: key.visualWeight,
        role: .character
    )
    onTap(synthesizedKey)                    // přes existing onKey callback z tasku 04
}
```

`InputDispatcher.dispatch` v tasku 04 dostane `synthesizedKey` s `.insertText(text)` a vloží `text` přes `textWithShiftApplied`. Shift apply funguje — pokud je page upper, alternate `á` se vloží jako `Á`. (Předpokládá, že `alternates` v `KeyboardCore` byly definované jako lower-case a uppercase mapování z task 02 `LayoutBuilder` už uppercased verze nepřidává explicitně — TBD: ve task 02 to existuje jako separate page state. Ověřit konzistenci.)

**Konzistence task 02 + 07:** `LayoutBuilder` v upper/capsLock page už upper-cases primary i alternates. Tj. když je page upper a key=`A`, `alternates=[Á, À, Â, ...]`. `commitHighlightedAlternate` insertuje raw `alternate.text` bez dalšího shift apply. To je správně — page určuje case už ve fázi build.

**Korekce v InputDispatcher (task 04):** `textWithShiftApplied` aplikuje upper jen na `key.action.insertText`. Pro alternate ze long-press popoveru, který je už ve správném case z layoutu, by se aplikoval dvojí upper (no-op pro ascii ale problematické pro non-ASCII). **Řešení:** synthesizedKey má action `.insertText(rawText)` a `InputDispatcher` při handle alternate detekuje, že jde o alternate (přes `key.role`?), a neaplikuje shift. Cleaner: udělej action `.insertRaw(text)` který nikdy neshifty.

`KeyAction.insertRawText(String)` — přidat. `InputDispatcher.dispatch`:

```swift
case .insertText(let text):
    proxy.insertText(textWithShiftApplied(text, state: state))
    ...

case .insertRawText(let text):
    proxy.insertText(text)
    state = ShiftStateMachine.reduce(state, .characterInserted)
    updateSpaceTracking(insertedText: text, state: &state)
```

`commitHighlightedAlternate` použije `.insertRawText`.

### 7. Haptika hooks (placeholder do tasku 08)

V `KeyView` callbacky:

```swift
let onPopoverEntry: () -> Void
let onHighlightChanged: () -> Void
```

V `KeyboardView` (rodič) tyto callbacks propaguje výš až do `KeyboardRoot` → `KeyboardViewController`, kde se v tasku 08 implementuje `UIImpactFeedbackGenerator` triggers. V v1.0 tasku 07 jsou to no-op closures.

### 8. Cancel popover na touch up out of bounds

Pokud uživatel slidne mimo popover bounds (např. zpět nad base key bez puštění) a pustí, máme commit nebo cancel?

- **Cancel** (vrátit se na primary tap) — Apple-like ale matoucí, popover už vyskočil.
- **Commit highlighted** kdykoliv končíme s popoverem — předvídatelné.

**Doporučení: commit highlighted** (varianta b). Důvod: uživatel viděl popover, viděl highlight, čekal commit. Cancel by byl surprise.

Edge: pokud se slide out of bounds, highlighted ostane na poslední valid index. Pokud uživatel slidne hodně daleko (mimo všech kandidátů), `updateHighlightedAlternate` zacapne `max(0, min(count-1, ...))` — efektivně lock na okraj.

### 9. Snapshot testy

`KeyboardUI/Tests/LongPressPopoverSnapshots.swift`:

- Popover pro `e` (8 alternates) — light + dark = 2 snapshoty.
- Popover pro `c` (4 alternates) — light + dark = 2 snapshoty.
- Popover s highlighted alternate (3. position) — 1 snapshot.

Snapshot rendering: vykreslit jen `LongPressPopoverView` standalone, ne celou keyboardu. Snapshot na 200×60 pt area.

### 10. Manuální testování

Long-press popover **nelze efektivně otestovat unit testem** (UI interakce s gesture timing). Test plan:

- Manuál v Notes.app: long-press na `e` → popover se ukáže s `é ě è ê ë ē ė ę`. Slide na druhý → `ě` highlighted. Pust → vloží `ě`.
- Pravý okraj: long-press na `p` → popover se zarovná zprava.
- Levý okraj: long-press na `q` → popover zleva.
- Klávesa bez alternates: long-press na `[shift]` → žádný popover (alternates prázdné).
- Čísla: long-press na `1` → popover s `!` (jeden alternate). Slide nutný? Při single alternate by se popover ani neměl ukazovat — rovnou by se měl vložit alternate. **Edge case decision:** pokud `alternates.count == 1`, long-press = okamžitě vloží alternate bez popoveru. UX win.

### 11. Speciální handling pro single-alternate

V scope bod 4 (`startLongPressTimer`), pokud `key.alternates.count == 1`, **přeskoč popover**, rovnou commit jediného alternate na timer fire. Žádný visual feedback (kromě pressed state z tasku 03), jen haptic + insert. Toto je common pattern pro číselné long-presses (`1 → !`).

## Mimo scope

- Slide-to-select se „zapomenutím" — pokud user pustí prst zpátky na základní klávesu (ne nad popoverem), commit primary místo alternate. Apple to dělá; my **commitujeme highlighted** vždycky (viz scope 8).
- Animace popover slide-in / fade. V v1.0 instant show/hide.
- Custom popover tail (trojúhelník). Plain rounded rectangle.
- Multi-row popover pro keys s víc než 8 alternates. Žádná naše key nemá >8.

## Hotovo když

- Long-press na písmena s alternates ukáže popover.
- Slide highlight funguje.
- Pust vloží highlighted (s respektem na case dle page).
- Levý / pravý / středový alignment popoveru funguje na okrajích.
- Single-alternate long-press (čísla → symboly) přeskočí popover, rovnou vloží.
- Long-press na klávesy bez alternates (shift, space, ...) NEukáže popover.
- Tap (krátký, <450ms) funguje jako předtím — vloží primary.
- 5 snapshot testů pro popover variants green.
- Manuální verifikace na simulátoru + reálném zařízení.

## Rizika

- **Gesture race conditions** — short tap vs. long press vs. drag se v SwiftUI občas hádá. Pokud se objeví bugy „tap ignorován po long-press", fallback na `UIViewRepresentable` (scope 1).
- **Performance při swipe přes alternates** — `updateHighlightedAlternate` se volá per pixel of drag. Pokud `rebuild` na hosting controller spustí (nemělo by — popover je čistě KeyView local state), bude jank. Drž popover state v `@State` v `KeyView`, **NE** v `KeyboardState` v extension VC.
- **Touch coordinates v různých orientacích** (portrait vs landscape) — popover origin calculations musí počítat se skutečnou šířkou klávesy.

## Reference

- `KeyboardCore/Sources/Models/Key.swift` (Key.alternates)
- `KeyboardCore/Sources/Logic/InputDispatcher.swift` (insertRawText action)
- Apple HIG: Custom Keyboard — žádný oficiální guidance na popover behavior, Apple to nedokumentuje.

## Codex review

**Ano** — komplexní gesture state machine, hodně edge cases, klíčový pro UX. Review je zde výrazně cennější než jinde.
