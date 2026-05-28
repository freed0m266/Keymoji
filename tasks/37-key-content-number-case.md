# 37 — `KeyContent.number` case + vertikální zarovnání digitů

**Status:** Todo

**Priorita:** v1.1 (visual polish) · **Úsilí:** S · **Dopad:** Medium (vizuální parita kláves)

## Cíl

Rozšířit `KeyContent` o nový case `number(String)` pro digity v number row. V `KeyView` se pak text bude renderovat s `.offset(y: -2)` (mírně vzhůru, aby písmena vypadala opticky vycentrovaná na kapce klávesy), zatímco digity v `.number` se vykreslí **bez** offsetu — opticky sedí na střed i tak, protože SF font má pro číslice vyšší x-height než pro lowercase písmena. Cíl je vizuální parita s Apple stock klávesnicí, kde se letters a digits zjevně renderují s mírně jiným baseline.

## Kontext

- `KeyContent` enum v [KeyboardCore/Sources/Models/Key.swift:30](KeyboardCore/Sources/Models/Key.swift:30) má dnes 2 case: `.text(String)` a `.symbol(SystemSymbol)`.
- Digity 0–9 tečou z [KeyboardCore/Sources/Logic/LayoutBuilder.swift:51](KeyboardCore/Sources/Logic/LayoutBuilder.swift:51) (`makeNumberRow`) jako `primary: .text(entry.digit)`. Jejich long-press alternates (`!`, `@`, `#`, …) jsou symboly, nikoli digity — zůstávají `.text`.
- `KeyView.content` v [KeyboardUI/Sources/Views/KeyView.swift:441](KeyboardUI/Sources/Views/KeyView.swift:441) je `@ViewBuilder` switch nad `effectiveContent`. Tady přibyde nový case + `.offset(y: -2)` aplikovaný **pouze** na `.text`.
- Druhé renderovací místo: `LongPressPopoverView.contentView(for:)` v [KeyboardUI/Sources/Views/LongPressPopoverView.swift:39](KeyboardUI/Sources/Views/LongPressPopoverView.swift:39). Switch nad `KeyContent` taky musí pokrýt `.number`. Popover alternates jsou ale pořád `.text`, takže `.number` v praxi v popoveru nepoužijeme — case existuje jen pro vyčerpávající switch.
- `KeyView.commitAlternate` ([KeyView.swift:419](KeyboardUI/Sources/Views/KeyView.swift:419)) má `guard case .text(let altText) = altContent` — alternates pořád zůstávají `.text`, takže žádná změna. Nicméně vyplatí se to ošetřit obecně (viz scope 3).

### Co se NEmění

- **Toggle key `"123"`** v bottom row a v symbol row C (`#+=` ↔ `123`) zůstává `.text("123")`. Není to digit-input, je to systémový label/page-switcher.
- **Long-press alternates digitů** (`"!"`, `"@"`, …) zůstávají `.text` — jsou to symboly, ne čísla.
- **Punktuace** v bottom rowu (`.`, `,`, `?`, `!`, `'`) — `.text`.

Hraniční rozhodnutí: `.number` zavádíme **jen pro skutečné single-digit input keys**, tj. number row primaries. Žádné multi-character číselné labely a žádné symboly. Tím je rozhodnutí stabilní (jen 10 míst v `LayoutBuilder` se mění) a `.offset(y: -2)` rule je jasný — letters & symbols up, digits flat.

## Scope

### 1. Rozšířit `KeyContent` enum

[KeyboardCore/Sources/Models/Key.swift:30](KeyboardCore/Sources/Models/Key.swift:30):

```swift
public enum KeyContent: Sendable, Equatable {
    case text(String)
    /// Single digit (`"0"`–`"9"`) rendered in the number row. Distinct from `.text` so
    /// `KeyView` can skip the optical letter-offset (digits sit visually centered without it).
    case number(String)
    case symbol(SystemSymbol)
}
```

Krátký doc comment vysvětluje **proč** — bez něj se za rok ztratí důvod, proč jsou digity v separátním case.

### 2. `LayoutBuilder.makeNumberRow` přepnout primary na `.number`

[KeyboardCore/Sources/Logic/LayoutBuilder.swift:51](KeyboardCore/Sources/Logic/LayoutBuilder.swift:51):

```swift
private static func makeNumberRow() -> KeyboardRow {
    let keys = numberRowMapping.map { entry in
        Key(
            id: "number.\(entry.digit)",
            primary: .number(entry.digit),       // ← změněno z .text(entry.digit)
            alternates: [.text(entry.alternate)],
            action: .insertText(entry.digit),
            visualWeight: .standard,
            role: .character
        )
    }
    return KeyboardRow(id: "numberRow", keys: keys)
}
```

Alternates zůstávají `.text` — viz Kontext.

### 3. `KeyView` content rendering + offset

[KeyboardUI/Sources/Views/KeyView.swift:441](KeyboardUI/Sources/Views/KeyView.swift:441):

```swift
@ViewBuilder
private var content: some View {
    switch effectiveContent {
    case .text(let text):
        Text(text).offset(y: -2)
    case .number(let digit):
        Text(digit)
    case .symbol(let symbol):
        Image(systemName: symbol.systemName)
    }
}
```

Dále `contentFont` v [KeyView.swift:455](KeyboardUI/Sources/Views/KeyView.swift:455) — `.number` použije stejný font jako `.text` (je to taky textový glyph z hlediska font sizing):

```swift
private var contentFont: Font? {
    switch effectiveContent {
    case .symbol:           return .system(size: 20, weight: .regular)
    case .text, .number:    return style.font
    }
}
```

`commitAlternate` v [KeyView.swift:419](KeyboardUI/Sources/Views/KeyView.swift:419) — `guard case .text(let altText)` ponechat tak, jak je. Alternates zůstávají `.text` (viz scope 2). Pokud by někdy v budoucnu vznikla potřeba `.number` alternates, je to vědomé rozšíření a vrátíme se sem.

`hasTextAlternates` v [KeyView.swift:437](KeyboardUI/Sources/Views/KeyView.swift:437) — beze změny. Kontroluje jen `.text` v alternates; popover digitů má `.text("!")`, `.text("@")`, … → vrátí `true` jako doteď.

`accessibilityLabel` ([KeyView.swift:486](KeyboardUI/Sources/Views/KeyView.swift:486)) — beze změny. Label se odvíjí od `key.action` (`.insertText("1")` → `"1"`), ne od KeyContent.

### 4. `LongPressPopoverView` — vyčerpávající switch

[KeyboardUI/Sources/Views/LongPressPopoverView.swift:39](KeyboardUI/Sources/Views/LongPressPopoverView.swift:39):

```swift
@ViewBuilder
private func contentView(for content: KeyContent) -> some View {
    switch content {
    case .text(let text):
        Text(text)
    case .number(let digit):
        Text(digit)
    case .symbol(let symbol):
        Image(systemName: symbol.systemName)
    }
}
```

Bez offsetu — popover má vlastní cellovou geometrii a digity tam stejně v praxi nepřistanou. Cílem je jen pokrýt switch, ať se nelámou buildy / future case-changes.

### 5. Unit test (KeyboardCore)

Přidat do `KeyboardCore/Tests/LayoutBuilderTests.swift` (nebo jeho ekvivalentu — pokud testovací soubor pro number row neexistuje, založit `NumberRowTests.swift`):

```swift
func testNumberRow_primariesAreNumberContent() {
    let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
    let numberRow = layout.rows.first { $0.id == "numberRow" }
    XCTAssertNotNil(numberRow)
    for key in numberRow!.keys {
        guard case .number = key.primary else {
            XCTFail("Number row key \(key.id) primary should be .number, got \(key.primary)")
            return
        }
    }
}

func testNumberRow_alternatesStayText() {
    let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
    let numberRow = layout.rows.first { $0.id == "numberRow" }!
    for key in numberRow.keys {
        XCTAssertEqual(key.alternates.count, 1)
        if case .text = key.alternates[0] {
            // OK — alternates are punctuation symbols, stay .text
        } else {
            XCTFail("Number row alternate should be .text, got \(key.alternates[0])")
        }
    }
}
```

### 6. Snapshot testy (KeyboardUI)

Visuální regrese:

- `KeyView` previews/snapshots digitové klávesy (pokud existují) refreshnout — number row keys se posunou o ~2pt dolů relativně k dnešku, letters/symbols vypadají optimisticky stejně (ale formálně se taky posunou o `.offset(y: -2)` — dnes neměly žádný offset).
- Plné keyboard snapshoty (letters + number row, symbols + number row) refreshnout. Diff bude jednotný posun textu o 2pt vzhůru s výjimkou digitů.

Postup standardní (analogie [tasks/14-equal-letter-key-widths.md:107](tasks/14-equal-letter-key-widths.md:107)):

1. Implementovat scope 1–4.
2. `record: true` v `SnapshotHelpers`, run KeyboardUI testy.
3. Vizuálně překontrolovat každý refresh — letters a symbols nahoru o 2pt, digity 0–9 v původní pozici.
4. `record: false`, re-run, verify green.
5. Commit nových reference PNG.

### 7. Manuální verify

1. Build & run host app, otevřít klávesnici v jakémkoli text fieldu.
2. Letters page s number row zapnutým: digity 0–9 a písmena vedle sebe — porovnat vertikální zarovnání s Apple stock klávesnicí (otevřít vedle v Notes přes globe key). Měly by sedět stejně.
3. Long-press na digit (`1`) → popover zobrazí `!` — verify, že popover labely (`!`) sedí v cell uprostřed (popover offset zatím neřeším, jen kontrola, že se nic nerozbilo).
4. Symbols page (žádné digity v hlavní mřížce, jen `"123"` toggle vlevo dole a `"#+="` / `"123"` toggle v row C) — toggle labely vypadají jako dřív (jsou `.text`, dostávají `-2pt` offset stejně jako letters/symbols).
5. Letters bez number row — verify, že písmena vypadají posunutá nahoru o 2pt vůči předchozí verzi (visual diff oproti master snapshotu).

## Mimo scope

- Per-page font tuning (jiný weight/size pro digity vs. letters). Pokud bude potřeba, samostatný task.
- Audit dalších kláves, které by mohly mít „number" charakter — `"123"` page toggle zůstává `.text`, viz Kontext.
- `.number` jako alternate (long-press na něco vyvolá digit). Žádný use-case, neřešíme.
- Změna magic number `-2`. Pokud se po visual verify ukáže, že `-1` nebo `-3` sedí lépe, doladit v rámci tohoto tasku — ale ne vytvářet z toho settings/config.
- Popover offset polish — `LongPressPopoverView` cell text sedí jak sedí; visual finetuning popoveru je separátní visual debt.

## Hotovo když

- `KeyContent` má 3 case: `.text`, `.number`, `.symbol`.
- `LayoutBuilder.makeNumberRow` produkuje primary `.number(...)`, alternates `.text(...)`.
- `KeyView` renderuje `.text` s `.offset(y: -2)`, `.number` bez offsetu, `.symbol` jako image (beze změny).
- `LongPressPopoverView` pokrývá vyčerpávajícím switchem všechny 3 case.
- 2 nové unit testy v `KeyboardCore` green (`testNumberRow_primariesAreNumberContent`, `testNumberRow_alternatesStayText`).
- Refreshnuté snapshot testy KeyboardUI green a vizuálně verifikované.
- Manuální verify potvrzuje, že digity v simulátoru sedí na střed kapky a písmena/symboly jsou posunuté nahoru o 2pt (parita s Apple stock).
- Žádné `@unknown default` warningy ani build errory; všechny switch nad `KeyContent` v repu pokrývají `.number` (ověřit `grep -rn "case .text" --include="*.swift"` v `KeyboardCore` + `KeyboardUI`).

## Rizika

- **Magic number `-2`.** Bez visual research může být `−1` nebo `−3` lepší. Riziko nízké — vizuální verify v simulátoru proti Apple stock klávesnici během implementace ho odhalí; case to nechá doladit bez API změny.
- **Dynamic Type / Accessibility text sizes.** Při větších font sizes (`accessibilityExtraLarge`) může 2pt offset přestat působit přirozeně, protože glyfy jsou výrazně vyšší. Klávesnice ale font scaling nepodporuje out-of-the-box (`style.font` je fixed size), takže prakticky se to neprojeví. Pokud někdy zavedeme Dynamic Type, vrátit se sem.
- **Symboly v row C (`. , ? ! '`) jako `.text`.** Dostanou `.offset(y: -2)`. Tečka a čárka jsou nízko na baseline — posun o 2pt vzhůru je může opticky odlepit od kapky. Visual verify v simulátoru během implementace (krok 4 v manuálním verify) to musí potvrdit/odhalit. Pokud vypadají špatně, zvážit `.symbol(...)` nebo třetí case (např. `.lowGlyph`) — ale to už by byl scope creep, vrátit se vlastním taskem.
- **Backwards compat snapshotů.** Refresh ~všech KeyboardUI snapshotů (letters, symbols × 2 page, emojis page nemá number row tak ji vyloučit). Žádná logická regrese, jen binary diff. Commit udělat samostatně od logiky, ať PR diff je čitelný.

## Reference

- [KeyboardCore/Sources/Models/Key.swift:30](KeyboardCore/Sources/Models/Key.swift:30) — `KeyContent` enum
- [KeyboardCore/Sources/Logic/LayoutBuilder.swift:51](KeyboardCore/Sources/Logic/LayoutBuilder.swift:51) — `makeNumberRow`
- [KeyboardUI/Sources/Views/KeyView.swift:441](KeyboardUI/Sources/Views/KeyView.swift:441) — `content` ViewBuilder + `contentFont`
- [KeyboardUI/Sources/Views/LongPressPopoverView.swift:39](KeyboardUI/Sources/Views/LongPressPopoverView.swift:39) — popover `contentView`
- [tasks/14-equal-letter-key-widths.md](tasks/14-equal-letter-key-widths.md) — vzor pro KeyboardCore/UI změnu se snapshot refreshem
- [tasks/35-keyboard-native-look-redesign.md](tasks/35-keyboard-native-look-redesign.md) — širší visual-parity kontext (pokud je tento task podmnožinou redesign sprintu, zvážit merge)

## Codex review

**Skip** — triviální enum extension + 1 view modifier. Visual verify pokryje vše, žádná state machine ani concurrency surface.
