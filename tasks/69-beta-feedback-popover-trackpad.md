# 69 — Beta feedback round 1: popover bez base + downward-cancel + trackpad 2D scrubbing

**Status:** Spec — připraveno z grill session 2026-06-20 (`/grill-with-docs`). Implementace v další session.

**Priorita:** v1.1 (přímý beta-feedback fix) · **Úsilí:** M · **Dopad:** High (dva každodenní gesta — long-press a space-hold scrubbing — uživatelé to používají při každém psaní s diakritikou a při opravách)

**Závisí na:** ničem (čistá UX iterace existujících gest v [`KeyView.swift`](../KeyboardUI/Sources/Views/KeyView.swift) + [`LayoutBuilder.swift`](../KeyboardCore/Sources/Logic/LayoutBuilder.swift)).

## Kontext

Beta-testeři nahlásili dvě UX bolesti:

1. **Trackpad-on-space (cursor scrubbing).** Citlivost je malá (10 pt/znak) → uživatel musí dělat velké tahy pro malý posun. Hlavně: pohyb jde **pouze horizontálně** (`KeyView.swift:305` doslova *„Stage 1: horizontal only"*). Když má uživatel text přes několik řádků a chce o řádek nahoru, musí scrubovat doleva přes celý řádek — desítky znaků.
2. **Long-press alternates popover.** Popover dnes obsahuje **base písmeno** + akcenty (`LayoutBuilder.swift:278-280`: `[.text(displayed)] + accents`), highlight startuje na base. Při hold+release bez tahu se napíše base → popover je vlastně jen vizuální šum. Druhý problém: jakmile se popover otevře, **není cesta zpět** — kamkoliv pustíš, něco napíšeš. iOS native umí zrušit dlouhý-tap sjetím prstu dolů z bunky.

Bonus zjištění z grill session: pre-iOS-26 ani iOS 26 ani iOS 27 nepřidaly žádné nové API pro keyboard extensions pro 2D cursor positioning. Potvrzeno research workflow proti Apple docs + community + SDK diff (viz [keyboard-extension-cursor-api memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keyboard-extension-cursor-api.md)). Jediný cursor primitiv zůstává `UITextDocumentProxy.adjustTextPosition(byCharacterOffset:)` — všechno musíme emulovat přes char offsets a newline-walking v `documentContextBeforeInput` / `documentContextAfterInput`.

## Cíl

Tři změny v dotykovém chování klávesnice, sjednocené do jednoho commitu / jedné PR (sdílí soubor `KeyView.swift`, sdílí původ = beta-feedback):

1. **Popover obsahuje jen alternativy** (bez base písmena), první alt je highlighted od frame 0.
2. **Cancel popoveru sjetím prstu dolů** z popover-bboxu o vzdálenost ≥ výška buňky.
3. **Trackpad scrubbing v 2D** (newline-walk pro vertikál, fallthrough na horizontál když `\n` chybí), citlivější horizontál.

Plus drobnost: úplně **zrušit alternativy na číslicích** (`!@#$%^&*()` přes long-press number row → zmizí — nikdo by je tam neměl tak rychle hledat a po novém popover designu by to bylo matoucí UX).

## Rozhodnutí (zafixovaná z grill session 2026-06-20)

### Popover

| Téma | Rozhodnutí |
|---|---|
| **Obsah popoveru** | Pouze `alternates` (bez base písmena). `LayoutBuilder.makeLetterKey` přestane prependovat base. |
| **`alternates.count == 0`** | Žádný popover; hold+release = base (zachováno). |
| **`alternates.count == 1`** (např. Czech `r` → `[ř]`) | **Popover s jednou buňkou** se zobrazí. Hold+release = `ř`. Dnešní `count == 1` auto-commit branch v `KeyView` se ruší (byl tam jen kvůli číslicím). |
| **`alternates.count ≥ 2`** | Popover s buňkami akcentů. `highlightedAlternateIndex = 0` od momentu otevření (vizuální highlight = první alt vybraný). Hold+release = první alt. Sliding mění highlight. |
| **Číslice (number row + 123 page)** | `numberRowMapping` se ruší celé. `makeDigitKeys()` vrací keys s `alternates: []`. Kill na top number rowu **i** primary symbol page (sdílí `makeDigitKeys()`). |

### Cancel popoveru

| Téma | Rozhodnutí |
|---|---|
| **Směr** | Pouze **dolů** (jako iOS native). Vlevo/vpravo/nahoru jen mění highlight nebo zůstává na krajní buňce. |
| **Threshold** | Celá výška buňky popoveru = **44 pt** pod bottom edge popover-bboxu. |
| **Stickiness** | Jednou cancel-armed = sticky až do release. Návrat prstu zpět nahoru nic nedělá. |
| **Vizuální feedback při armed** | **Popover zmizí úplně** (`isShowingPopover = false`). |
| **Haptic** | Žádný haptic na cancel-arm. |
| **Co se napíše při release** | **Nic.** Žádný base, žádný alt. |

### Trackpad 2D scrubbing

| Téma | Rozhodnutí |
|---|---|
| **Horizontální citlivost** | `trackpadPointsPerCharacter`: **10 → 6 pt/znak** (1.67× rychlejší). |
| **Vertikální citlivost** | Nový `trackpadPointsPerLine` = **22 pt/řádek**. |
| **Dominantní osa** | Per-frame větší absolutní (`abs(dx)` vs `abs(dy)`) rozhodne, co se v tom framu emituje. Anchor obě osy nezávisle. |
| **Vertikál + `\n` v daném směru existuje** | **Skok o řádek** přes newline-walking v `documentContextBeforeInput` (pro up) / `documentContextAfterInput` (pro down). |
| **Cílový sloupec** | Aktuální sloupec = znaky od posledního `\n` (před kurzorem) k pozici kurzoru. Po skoku clampnuto na délku cílového řádku. |
| **Column intent persistence** | Žádná. Per-jump sloupec se počítá znovu. (Native iOS má persistent intent column, ale pro naše jednorázové swipe-gesto je to over-engineering.) |
| **Vertikál + `\n` neexistuje** | Tichý **fallthrough** na horizontál: dy se použije se stejným poměrem jako dx (6 pt = 1 znak, signum: up → záporné, down → kladné). Bez haptic, bez vizuálního flickerování. |
| **Iniciální haptic** | Existující „thunk" haptic na entry zůstává. Žádné nové haptics. |

## Scope

### 1. `LayoutBuilder.swift` — odstranit base z alts + smazat číslicové alts

- `makeLetterKey(_:shift:alternateSet:)`: změnit
  ```swift
  let alternates: [KeyContent] = accents.isEmpty
      ? []
      : [.text(displayed)] + accents.map { ... }
  ```
  na
  ```swift
  let alternates: [KeyContent] = accents.map { .text(shouldUppercase(shift) ? $0.posixUppercased() : $0) }
  ```
  (prázdné `accents` přirozeně dají prázdné `alternates` díky `map` — žádný early-return není potřeba.)
- Aktualizovat dokumentační komentář nad metodou (řádky `KeyboardCore/Sources/Logic/LayoutBuilder.swift:273-277`) — vysvětlení o „cell 0 je base" už neplatí.
- `makeDigitKeys()` (řádek `:91-102`): odstranit `alternates: [.text(entry.alternate)]` → `alternates: []`. Smazat konstantu `numberRowMapping` (`:76-79`) — bude dead code.
- Aktualizovat komentář u `makeDigitKeys()` (`:81-90`) a u CONTEXT.md položky **Number row** (zmínit, že po této změně nemá long-press shortcut).

### 2. `KeyView.swift` — popover behavior

- Smazat `count == 1` auto-commit branch v `startLongPressTimer()` (`:404-408`) — všechny `≥ 1 alternative` keys teď ukazují popover.
- Komentář kolem `hasTextAlternates` (`:476-478`) zůstává platný (filtruje `.text`-only alts, což stále chceme — symbol alternates by nedávaly smysl v insert akci).
- Přidat `@State private var isCancelArmed = false` ke gesture state.
- V `combinedGesture.onChanged`: pokud `isShowingPopover && !isCancelArmed`, zkontrolovat cancel:
  ```swift
  // Popover sits at y offset -cellHeight-12 → bottom edge = -12 in KeyView coords.
  let popoverBottomY = -12.0
  let cancelThreshold = popoverBottomY + Self.popoverCellSize.height  // = -12 + 44 = 32
  if value.location.y > cancelThreshold {
      isCancelArmed = true
      isShowingPopover = false
  }
  ```
- `handleTouchUp`: pokud `isCancelArmed`, **nepsat nic** (žádný `commitAlternate`, žádný `onTap(key)`):
  ```swift
  if isCancelArmed {
      // sticky cancel — silently consume the gesture
  } else if isShowingPopover {
      commitAlternate(at: highlightedAlternateIndex)
      isShowingPopover = false
  } else if didCommitAlternate || didRepeatBackspace || wasTrackpadActive {
      ...
  } else {
      onTap(key)
  }
  ```
- Reset `isCancelArmed = false` v `handleTouchDown` a v `handleTouchUp` (na konci).
- Žádná změna v `updateHighlight` (clamp na kraj zůstává — horizontální swipe za okraj jen zůstává highlighted na krajní buňce).

### 3. `KeyView.swift` + `InputDispatcher.swift` + `Key.swift` — trackpad 2D

- `Key.swift`: přidat novou akci
  ```swift
  case cursorLineOffset(_ lines: Int)  // positive = down, negative = up
  ```
  + aktualizovat všechny `switch`y nad `Key.Action` (`InputDispatcher`, `KeyView.firesKeyTapFeedback`, `accessibilityLabel`).
- `KeyView.swift`:
  - Změnit `trackpadPointsPerCharacter: 10 → 6`.
  - Přidat `static let trackpadPointsPerLine: CGFloat = 22`.
  - Přidat `@State private var trackpadAnchorY: CGFloat = 0`. Resetnout v `handleTouchDown` (společně s `anchorX`).
  - Přepsat `handleSpaceDrag(at:)`:
    1. Dokud trackpad není armed/active, beze změny.
    2. Po aktivaci: per-frame `dx = location.x - anchorX`, `dy = location.y - anchorY`.
    3. Dominantní osa: `abs(dx) > abs(dy)` → horizontál; jinak → vertikál.
    4. Horizontál: jako dnes (chars = `dx / 6`, advance anchorX). Anchor Y se v tom framu **netýká**.
    5. Vertikál: `lines = dy / 22`. Emit `.cursorLineOffset(lines)`. Advance anchorY o `lines * 22`. Anchor X se netýká.
  - Aktivační dead-zone (`trackpadActivationDistance`) musí brát ohled na obě osy: dnes `abs(drag) >= 6` na X. Změnit na `hypot(dx, dy) >= 6` (radius, ne osa-only) a anchorovat dle dominantní osy přechodu.
- `InputDispatcher.swift`: nový case
  ```swift
  case .cursorLineOffset(let lines):
      guard lines != 0 else { break }
      let offset = computeLineJumpOffset(
          lines: lines,
          before: proxy.documentContextBeforeInput ?? "",
          after: proxy.documentContextAfterInput ?? ""
      )
      if offset != 0 {
          proxy.adjustTextPosition(byCharacterOffset: offset)
      } else {
          // Fallthrough: no \n in target direction → behave as if it were a horizontal drag of
          // equivalent magnitude. lines * pointsPerLine / pointsPerChar = lines * 22 / 6 ≈ 3.67×.
          // Simpler: emit `lines * 3` chars in same sign. Tuning detail — see "Otevřená rozhodnutí".
          let fallthroughChars = lines * 4
          proxy.adjustTextPosition(byCharacterOffset: fallthroughChars)
      }
      state.lastInsertWasSpace = false
      state.lastSpaceInsertedAt = nil
  ```
- Nová helper funkce (v `InputDispatcher` nebo nový soubor `KeyboardCore/Sources/Logic/CursorLineWalker.swift`):
  ```swift
  /// Returns the character offset to move the cursor `lines` away (positive = down, negative = up),
  /// preserving the current column (clamped to target line length). Returns 0 if there are not enough
  /// `\n` characters in the required direction within the document context window.
  static func computeLineJumpOffset(lines: Int, before: String, after: String) -> Int { ... }
  ```
  Logic sketch:
  - Aktuální sloupec = počet znaků v `before` po posledním `\n` (nebo celé `before.count` když žádné `\n`).
  - Up (lines < 0): najdi |lines| `\n` od konce `before`. Pokud jich tolik není → return 0. Spočítej start cílového řádku a jeho délku (do dalšího `\n` nebo do konce řádku). Target = start + min(column, lineLength). Offset = -(currentPos - target) = -(before.count - target).
  - Down (lines > 0): symetricky v `after`, kde `\n` ukončuje aktuální řádek a další `\n` end-of-target-line.
- Unit testy (`KeyboardCore/Tests/CursorLineWalkerTests.swift` nebo rozšířit `InputDispatcherTests`):
  - Up s `\n` před kurzorem, target řádek delší než column → column preserved.
  - Up s target řádkem kratším → clamp na end-of-target-line.
  - Up s nedostatkem `\n` → return 0.
  - Symetrie pro down.
  - Edge: prázdný `before` / `after`.
  - Edge: kurzor přímo za `\n` (column = 0).

### 4. Snapshot testy

- `LongPressPopoverSnapshots` — regenerovat. Stávající snapshoty mají base+akcenty; nové budou jen akcenty. Po prvním běhu zkontrolovat manuálně, že zobrazení dává smysl.
- `KeyboardViewSnapshots` — měla by být nedotčena (popover se v idle stavu nezobrazuje).

## Hotovo když

### Popover
- Hold na `e` (Czech) → popover ukazuje `é ě`, první (`é`) highlighted. Release bez tahu → vloží `é`. Slide na `ě` → highlight se přepne, release → `ě`.
- Hold na `r` (Czech) → popover ukazuje jednu buňku `ř`. Release → `ř`.
- Hold na `w` (Czech) → žádný popover. Release → `w`.
- Hold na `1` (number row nebo 123 page) → žádný popover, jen release → `1`. (`!` už není přístupný přes long-press digit.)
- Long-press na `e`, slide prstem dolů ≥ 44 pt pod popover → popover zmizí. Release → nic se nenapíše. Návrat prstem nahoru po cancel-arm → nic se nestane (sticky).
- Long-press na `e`, slide doleva za popover → zůstává highlighted na první buňce (`é`). Release → `é`. (Cancel jen down, ne stranou.)

### Trackpad
- Krátký horizontální swipe (1 cm ≈ 38 pt) na space → kurzor se posune cca o 6 znaků (dnes ~4).
- V multi-line textu (chat, Notes) swipe nahoru ≥ 22 pt → kurzor skočí o řádek nahoru, sloupec zachován / clampnut. Swipe dolů → symetricky dolů.
- V single-paragraph textu bez `\n` swipe nahoru → kurzor se posune doleva (fallthrough), žádný flicker, žádný visual cue.
- Diagonální swipe → osa s větší absolutní deltou v daném framu vyhrává.
- Existující haptic „thunk" na entry zůstává.

### Obecně
- Žádné nové permission prompts. Žádné nové dependencies.
- `KeymojiCore` testy + `Settings` testy + `KeyboardUI` snapshot suite zelené (po regeneraci popover snapshotů).
- Reálné ověření na iPhone 17 / iOS 26.2 sim ([keymoji-build-uses-workspace memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keymoji-build-uses-workspace.md)).

## Otevřená rozhodnutí (řešit při implementaci, malá záležitost)

- **Fallthrough magnitude.** Když vertikál nemá `\n` → kolik znaků za jeden „nominální řádek" (22 pt) emitovat? Návrh: `lines * 4`. Důvod: 22 pt / 6 pt-per-char ≈ 3.67, zaokrouhleno na 4. Při implementaci to zkus a v reálu uvidíš, jestli sedí.
- **Newline-walking helper umístění.** Buď v `InputDispatcher.swift` jako private static, nebo nový soubor `CursorLineWalker.swift` v `KeyboardCore/Sources/Logic/`. Druhé preferuji (testovatelnost, separation), ale je to malá funkce — záleží na velikosti finálního kódu.
- **Cancel-armed mid-trackpad?** Trackpad-mode-active stav cancel ignoruje (popover tam stejně není). Žádná akce potřeba, jen ověřit, že se `isCancelArmed` nezapne během trackpad mode (gestures jsou exkluzivní — popover-related state vs trackpad-related state — ale stojí za check v `handleTouchDown` resetu).

## Rizika / poznámky

- ⚠️ **`documentContextBeforeInput` / `documentContextAfterInput` jsou capnuty** (typicky ~1024 znaků, ne dokumentováno). Pro line jumping v dlouhých dokumentech to znamená: pokud uživatel je hluboko v dokumentu a `\n` je dál než cap, helper vrátí 0 → fallthrough. To je akceptovatelné, ne bug — ale dobré vědět.
- ⚠️ **Hidden contexts (password fields).** Stejně jako backspace word-delete escalation (`KeyView.swift:355-367`, `canEscalateBackspace`), v hidden contextu jsou contexts prázdné → vždy fallthrough. Konzistentní s existujícím chováním backspace, nepotřebuje speciální handling.
- ⚠️ **Snapshot regenerace.** První běh popover snapshotů selže (počet buněk se změnil). Po regeneraci manuálně zkontrolovat, že nové snapshoty vypadají rozumně.
- Po této PR má `Key.Action` 11 case (přidaný `.cursorLineOffset`) — zkontrolovat všechny `switch`y kompilátorovou exhaustivity (žádné `default`y v existujících switchech, takže warning okamžitý).

## Codex review

**Ano** — task se dotýká dvou kritických gest (long-press + space-hold) v `KeyView.swift` a přidává nový `Key.Action` case s newline-walking heuristikou. Failure modes (off-by-one v sloupcovém indexu, neresetování `isCancelArmed` mezi gesty, dominant-axis flicker při „diagonál ~45°") jsou drobné, ale na klávesnici v hot path. Stojí za druhý pár očí.
