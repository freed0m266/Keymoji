# 03 — Key rendering UI (KeyboardUI)

**Status:** Done — 2026-05-24

**Priorita:** v1.0 · **Úsilí:** M · **Dopad:** Blokující

## Cíl

Napsat SwiftUI views, které vykreslí klávesnici z `KeyboardLayout` modelu (task 02). Žádný input handling, žádné gestures kromě basic tap visual feedback. Views jsou parametrizované pouze callback closures (`onKey: (Key) -> Void`) — drátování na `textDocumentProxy` je v tasku 04.

Po dokončení tasku 03 jde do SwiftUI preview vložit `KeyboardView(layout: ..., onKey: { _ in })` a uvidět hotovou klávesnici v obou color schemes a se snapshot testy.

## Kontext

- `KeyboardUI` je framework s `APPLICATION_EXTENSION_API_ONLY = YES` (nastaveno v tasku 01). **Žádné `UIApplication.shared`, žádné `openURL`, žádné `UIScreen.main`.** Všechno přes SwiftUI a `GeometryReader`.
- Barvy jsou systémové semantic (rozhodnutí grilling Q10): `Color(.systemBackground)`, `Color(.label)`, `Color(.secondaryLabel)`, `Color(.systemGray4)` (pro letter keys), `Color(.systemGray2)` (pro system keys). Žádný custom Asset Catalog v v1.0.
- Snapshot testy obě varianty (light + dark) od první commitu — viz task 09 snapshot count v `tasks/README.md`.

## Scope

### 1. `KeyStyle` — design tokens

`KeyboardUI/Sources/Style/KeyStyle.swift`:

```swift
struct KeyStyle {
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let foregroundColor: Color
    let font: Font
    let cornerRadius: CGFloat
}

extension KeyStyle {
    static func style(for role: KeyRole, shift: ShiftState? = nil) -> KeyStyle {
        // letter key: systemGray4 bg, label fg, .body font, 5pt corner
        // system key: systemGray2 bg, label fg, .body weight semibold, 5pt corner
    }
}
```

Konkrétně:

- **Letter / character keys**:
  - bg: `Color(.systemGray4)` — světle šedá v light, tmavě šedá v dark
  - pressed bg: `Color(.systemGray3)` o krok jiná (highlight efekt)
  - fg: `Color(.label)`
  - font: `.title2` nebo `.system(size: 22, weight: .regular)` — velikost se možná bude muset ladit po prvním reálném použití
  - corner: 5
- **System keys (shift, delete, return, 123, globe, space, dot)**:
  - bg: `Color(.systemGray2)` — tmavší než letter keys (vizuálně odlišené)
  - pressed bg: `Color(.systemGray)`
  - fg: `Color(.label)`
  - font: `.system(size: 18, weight: .semibold)` pro labely, `.title3` pro SF Symbols
  - corner: 5

Shift v upper / capsLock stavu má **invertovaný kontrast** (bg `.label`, fg `.systemBackground`), aby uživatel viděl aktivní stav. Caps lock má navíc indikátor (např. malou tečku pod ikonkou nebo přesvícený line-under).

### 2. `KeyView` — jedna klávesa

`KeyboardUI/Sources/Views/KeyView.swift`:

```swift
struct KeyView: View {
    let key: Key
    let style: KeyStyle
    let onTap: (Key) -> Void

    @State private var isPressed = false

    var body: some View {
        button content
    }
}
```

Layout:

- Tap area = full bounds (klávesa včetně padding).
- Tap target minimum 44×44 (Apple HIG) — vynutíme přes `.frame(minHeight: 44)`.
- `@State isPressed` přepíná `style.backgroundColor` ↔ `style.pressedBackgroundColor`. Toggle on `DragGesture(minimumDistance: 0)` onChanged → true, onEnded → false. (Standard SwiftUI `Button` má jen půl funkční pressed state, custom gesture je čistší.)
- Při end-of-touch volat `onTap(key)` jen pokud touch skončila *uvnitř* bounds (jinak je to swipe-out cancel).

`KeyContent` rendering:

- `.text(let s)` → `Text(s)`
- `.symbol(let sym)` → `Image(systemName: sym.systemName)`, kde `SystemSymbol` enum má `.systemName` computed property (`.shift → "shift"`, `.delete → "delete.left"`, `.return → "return"`, `.globe → "globe"`).

### 3. `KeyRowView` — řádek

`KeyboardUI/Sources/Views/KeyRowView.swift`:

```swift
struct KeyRowView: View {
    let row: KeyboardRow
    let totalWidth: CGFloat                 // z GeometryReader
    let onKey: (Key) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(row.keys) { key in
                KeyView(...)
                    .frame(width: keyWidth(for: key, totalRowWeight: ...))
            }
        }
    }

    private func keyWidth(...) -> CGFloat { ... }
}
```

Width algoritmus: sečíst všechny `key.visualWeight.value` v řádku → totalWeight. Klávesa dostane `(key.visualWeight.value / totalWeight) * (totalWidth - totalSpacing)` šířky. Spacing mezi klávesami: 4pt. Margin na okrajích: 3pt na každé straně řádku (vně HStacku).

### 4. `KeyboardView` — kompletní klávesnice

`KeyboardUI/Sources/Views/KeyboardView.swift`:

```swift
public struct KeyboardView: View {
    public let layout: KeyboardLayout
    public let onKey: (Key) -> Void

    public init(layout: KeyboardLayout, onKey: @escaping (Key) -> Void) {
        self.layout = layout
        self.onKey = onKey
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 6) {
                ForEach(layout.rows) { row in
                    KeyRowView(row: row, totalWidth: proxy.size.width - 6, onKey: onKey)
                        .frame(height: rowHeight(for: row, in: proxy.size))
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
        }
        .frame(height: keyboardHeight)
    }
}
```

Výška klávesnice:

- iPhone portrait: 216pt klasicky pro klávesnici **bez** number row, +44pt pro number row → 260pt.
- iPhone landscape: 162pt **bez** number row, +40pt pro number row → 202pt.
- Detekce orientace přes `proxy.size.height > proxy.size.width` (rough; lepší přes UIDevice ale to extension nemá).

Pro v1.0 zafixovat: 260pt portrait s number row, 216pt bez, 202pt landscape s number row, 162pt bez. Reálně se to bude muset doladit po prvním reálném zkoušce.

Výška řádku: `(totalHeight - 5*6 padding-spacing) / rowCount` — uniformně. Number row může být *menší* (každý řádek dostane proporční share), ale to optimalizujeme až po reálném testu.

### 5. Return key label

Return key v `KeyboardLayout` má `KeyContent.symbol(.return)` jako default. Ve view (`KeyView` nebo dedicated `ReturnKeyView`) ale přepíšeme label podle `layout.returnKeyType`:

```swift
private var returnKeyLabel: KeyContent {
    switch layout.returnKeyType {
    case .default:       return .symbol(.return)
    case .go:            return .text("Go")
    case .search, .google, .yahoo:  return .text("Search")
    case .send:          return .text("Send")
    case .done:          return .text("Done")
    case .next:          return .text("Next")
    case .join:          return .text("Join")
    case .continue:      return .text("Continue")
    case .route:         return .text("Route")
    case .emergencyCall: return .text("Call")
    }
}
```

Toto je čistě view layer logika — `KeyboardCore` model už ReturnKeyType propaguje (task 02 zařídí), `KeyboardUI` jen překlopí enum na label.

### 6. Snapshot testy

`KeyboardUI/Tests/KeyboardViewSnapshots.swift`:

```swift
final class KeyboardViewSnapshots: XCTestCase {
    func testLettersLower_withNumberRow_dark() { ... }
    func testLettersLower_withNumberRow_light() { ... }
    func testLettersUpper_withNumberRow_dark() { ... }
    func testLettersUpper_withNumberRow_light() { ... }
    func testLettersCapsLock_withNumberRow_dark() { ... }
    func testLettersCapsLock_withNumberRow_light() { ... }
    func testSymbols_withNumberRow_dark() { ... }
    func testSymbols_withNumberRow_light() { ... }
    func testLettersLower_withoutNumberRow_dark() { ... }
    func testLettersLower_withoutNumberRow_light() { ... }
    func testReturnLabel_search_dark() { ... }
    func testReturnLabel_done_dark() { ... }
    func testReturnLabel_go_dark() { ... }
    func testReturnLabel_send_dark() { ... }
}
```

Použít `AssertSnapshot()` helper z `KeymojiTesting`. Reference image se vytvoří při prvním běhu (`record: true`), pak commitne.

Snapshoty rendrovat na 393×260 (iPhone 15 šířka, klávesnice s number row v portrait). `inPreview(colorScheme: .light/.dark)` helper z `KeymojiUI` (rozšíření za WidgetCoin vzor).

### 7. SwiftUI Previews

`KeyboardUI/Sources/Views/KeyboardView.swift` na konci:

```swift
#if DEBUG
#Preview("Letters Lower / Dark") {
    KeyboardView(
        layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default),
        onKey: { _ in }
    )
    .inPreview(colorScheme: .dark)
}

#Preview("Letters Upper / Light") { ... }
#Preview("Symbols / Dark") { ... }
#Preview("Without Number Row / Dark") { ... }
#endif
```

Slouží k vizuální iteraci během vývoje. Nedoplňujeme na ně testy — od toho jsou snapshoty.

### 8. Accessibility

Každý `KeyView` dostane:

- `.accessibilityLabel(...)` — pro letter key text labelu, pro system key user-readable name („Shift", „Delete", „Return", „Switch to symbols", „Next keyboard", „Space", „Period").
- `.accessibilityHint(...)` — pro system keys popis akce („Toggles uppercase", „Deletes previous character"). Skipnu pro letter keys, label stačí.
- `.accessibilityAddTraits(.isKeyboardKey)` — explicitní trait pro VoiceOver.

### 9. Locale assertion

V `KeyboardView.init` přidat `assert(...)` nebo logger note: „Keymoji v1.0 supports US English layout only". Nejde o crash, jen safety check pro budoucí refaktor.

## Mimo scope

- Input handling (`textDocumentProxy`) — task 04.
- Long-press popover — task 07. V tomto tasku gesture jen detekuje krátký tap.
- Pressed visual feedback je v scope; key preview popup (bublina nad prstem) je Future.
- Haptika — task 08.
- Themes / user override pro light-dark — Future.
- Žádný animovaný switch mezi pages (letters ↔ symbols) — v1.0 instant cut. Animace je polish v Future.

## Hotovo když

- `KeyboardUI/Sources/Views/` obsahuje `KeyView`, `KeyRowView`, `KeyboardView`.
- `KeyboardUI/Sources/Style/KeyStyle.swift` definuje barvy a fonty.
- `KeyboardView` je `public`, použitelná z extension targetu (task 04).
- ~14 snapshot testů (light + dark) green.
- SwiftUI Previews fungují v Xcode preview canvas pro všechny kombinace.
- Žádný hardcoded `Color.black`/`Color.white` mimo systémové semantic API.
- `APPLICATION_EXTENSION_API_ONLY` build warning žádný.

## Rizika

- **Výška klávesnice** je hádaná. Po prvním reálném testu na zařízení se může ukázat, že 260pt portrait + number row je moc/málo. Číslo je v jednom místě, refaktor triviální.
- **Pressed state s `DragGesture(minimumDistance: 0)`** může konfliktovat s long-press gesture v tasku 07. Plánuj, že task 07 přepíše `KeyView` na `SimultaneousGesture` nebo na custom `UIViewRepresentable` pokud SwiftUI gesture API nestačí.
- **Snapshot stability**: SF Symbols rendering se může drobně lišit mezi iOS verzemi. Pokud snapshot testy padají kvůli sub-pixel render, dovolit `precision: 0.98` v `AssertSnapshot()` configu.

## Reference

- `KeymojiUI/Sources/Extensions/View+Extensions.swift` — `inPreview()` helper
- `KeymojiTesting/Sources/AssertSnapshot.swift` — snapshot helper
- `~/Development/WidgetCoin/Features/Settings/Tests/SettingsSnapshots.swift` — vzor snapshot test
- Apple HIG: Keyboards → Layout — <https://developer.apple.com/design/human-interface-guidelines/keyboards>
- SF Symbols: shift, delete.left, return, globe — <https://developer.apple.com/sf-symbols/>
