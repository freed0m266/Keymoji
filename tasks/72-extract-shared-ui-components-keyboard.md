# 72 — Refactor: pročistit a rozdělit UI klávesnicové extension (KeyboardUI)

**Status:** Spec — připraveno z grill session 2026-06-20 (`/grill-with-docs`). Implementace v další session.

**Priorita:** Tech debt · **Úsilí:** M · **Dopad:** None (čistý refactor, žádná uživatelská změna)

**Souvisí s:** **task 71** (sesterský refactor host-app views → `KeymojiUI`; tenhle task je jeho protějšek pro klávesnici), [33 — Feature module + VM refactor](33-feature-modules-and-vm-refactor.md).

## Souhrn

`KeyboardUI` (UI klávesnicové app-extension) má dvě skoro-duplicitní emoji buňky + dva **byte-identické** `ButtonStyle`y, sdílený „search field" chrome na dvou místech, a dva přerostlé soubory — `KeyView.swift` (635 ř., gesture engine) a `EmojiPanelView.swift` (358 ř.). Task to (a) extrahuje sdílené komponenty/modifiery a (b) rozdělí ty dva soubory do menších podle concernu.

**`KeyboardUI` je extension-only** (`APPLICATION_EXTENSION_API_ONLY`) a **nemůže** importovat host-app design systém `KeymojiUI` — proto je oddělený od tasku 71 a všechna sdílená primitiva žijí **uvnitř `KeyboardUI`**.

**Žádná změna logiky ani UI.** Pouze přesun opakujícího se view kódu + rozdělení souborů + relaxace viditelnosti pro cross-file extensions.

## Železná pravidla (zafixovaná z grill session 2026-06-20)

Stejná jako [task 71](71-extract-shared-ui-components-host-app.md):

1. **Pixel-perfect preservation.** Komponenta reprodukuje každý call site byte-for-byte; rozdíly se stávají **parametry**, vzhled se nikdy nesjednocuje.
2. **Pokud by sdílená komponenta byla skoro jen samé parametry / větvení**, neextrahuje se — viz rozhodnutí o search baru níže (z full `EmojiSearchBar` zbyl jen `searchFieldChrome()` modifier).
3. **Žádná změna logiky / chování / timingu.** Hlavně `KeyView` je hot-path gesture engine (haptika, trackpad, delete-repeat, popover) — split je čistě organizace souborů, **žádný** přesun do helper struct/modelů, který by změnil sémantiku.
4. **Regrese se hlídá existujícím `KeyboardUI` snapshot suite** — žádný nový test target.

## Regresní síť (existující — pokrývá vše, co saháme)

[`KeyboardViewSnapshots`](../KeyboardUI/Tests/KeyboardViewSnapshots.swift) renderuje celou klávesnici přes všechny page stavy, takže **pokrývá i emoji panel a emoji search**, které měníme nejvíc:
- `.emojis` page → `testEmojis_noRecents/withRecents/withFavorites` (pokrývá `EmojiPanelView`, `EmojiCell`, tab bar, grid, search trigger).
- `.emojiSearch` page → `testEmojiSearch_emptyQuery_noRecents/withRecents`, `testEmojiSearch_query_rain` (pokrývá `EmojiSearchView`, `resultCell`, search bar).
- `.letters(_)` / `.symbols(_)` všechny stavy → pokrývá `KeyView` (rendering, content, return label, popover přes [`LongPressPopoverSnapshots`](../KeyboardUI/Tests/LongPressPopoverSnapshots.swift)).
- Plus [`SuggestionBarViewSnapshots`](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift), [`KeyboardUISmokeTests`](../KeyboardUI/Tests/KeyboardUISmokeTests.swift).

**Důkaz nulové UI změny = celá `KeyboardUI` snapshot suite projde beze změny obrázků.**

## Scope

### 1. Sdílený `EmojiCellButtonStyle` (nový `KeyboardUI/Sources/Style/EmojiCellButtonStyle.swift`)

Dnes **dvě 100% identické** definice:
- `EmojiCellButtonStyle` ([EmojiPanelView.swift:319-328](../KeyboardUI/Sources/Views/EmojiPanelView.swift:319))
- `EmojiSearchResultButtonStyle` ([EmojiSearchView.swift:149-157](../KeyboardUI/Sources/Views/EmojiSearchView.swift:149))

Obě: `ZStack { RoundedRectangle(cornerRadius: 5).fill(configuration.isPressed ? Color(.systemGray3) : Color.clear); configuration.label }`.

- Vyčlenit jednu `internal struct EmojiCellButtonStyle: ButtonStyle` do Style souboru.
- Smazat `EmojiSearchResultButtonStyle`; oba call sites → `.buttonStyle(EmojiCellButtonStyle())`.

### 2. Sdílený `EmojiCell` (nový `KeyboardUI/Sources/Views/EmojiCell.swift`)

Dnes panel má `private struct EmojiCell` ([EmojiPanelView.swift:292-317](../KeyboardUI/Sources/Views/EmojiPanelView.swift:292)); search má metodu `resultCell(for:)` ([EmojiSearchView.swift:130-146](../KeyboardUI/Sources/Views/EmojiSearchView.swift:130)). Jádro (emoji glyph button + press highlight) je sdílené; liší se **sizing** a **long-press**.

Zobecnit existující `EmojiCell` struct (přesunout do vlastního souboru, `internal`):

```swift
struct EmojiCell: View {
    let emoji: String
    let glyphSize: CGFloat
    /// `nil` → roztáhnout na `maxWidth: .infinity` (grid panel). Jinak fixní šířka (search bar).
    let width: CGFloat?
    let height: CGFloat
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            glyph
                .contentShape(Rectangle())
        }
        .buttonStyle(EmojiCellButtonStyle())
        .applyingLongPress(onLongPress)        // attach .onLongPressGesture jen když != nil
        .accessibilityElement()
        .accessibilityLabel(emoji)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    @ViewBuilder private var glyph: some View {
        let base = Text(emoji)
            .font(.system(size: glyphSize))
            .minimumScaleFactor(0.8)
            .lineLimit(1)
        if let width {
            base.frame(width: width, height: height)
        } else {
            base.frame(maxWidth: .infinity).frame(height: height)
        }
    }
}
```

- **`width: nil` větev** reprodukuje panel (`.frame(maxWidth: .infinity).frame(height:)`), **`width: 42` větev** reprodukuje search (`.frame(width:, height:)`).
- Pořadí `minimumScaleFactor` / `lineLimit` se mezi dnešními call sites liší (panel: scale→limit, search: limit→scale) — render identický; sjednotit na jedno pořadí a **ověřit emoji + search snapshoty**.
- `onLongPress == nil` → **nepřipojovat** `.onLongPressGesture` (search dnes long-press nemá). Helper `applyingLongPress(_:)` (privátní `@ViewBuilder` extension nebo `if let` ve body).
- ⚠️ Drobnost: panel cell má `.accessibilityElement()`, search `resultCell` ne. Sjednoceno na **včetně** `.accessibilityElement()` — pro leaf button s jediným labelem je to behaviorálně no-op (snapshoty a11y stejně neměří). Pokud paranoidní, ověřit VoiceOverem na search cell.

Call sites:
- **`EmojiPanelView.grid`** ([:254](../KeyboardUI/Sources/Views/EmojiPanelView.swift:254)) — už `EmojiCell` používá; doplnit `width: nil`, `onLongPress: { … }` (beze změny chování).
- **`EmojiSearchView.resultCell`** → nahradit:
  ```swift
  EmojiCell(
      emoji: emoji, glyphSize: Self.glyphSize, width: Self.cellWidth, height: Self.cellHeight,
      onTap: { onKeyTapHaptic(); onKeyClick(); onSelectEmoji(emoji) },
      onLongPress: nil
  )
  ```

### 3. `searchFieldChrome()` modifier (nový `KeyboardUI/Sources/Style/View+SearchFieldChrome.swift` nebo rozšířit existující style extension)

> **Rozhodnutí z grill session:** plný sdílený `EmojiSearchBar` se **nedělá** — dva bary jsou strukturálně odlišné (panel = read-only **Button** trigger, statický „Search Emoji" + `Spacer`, **bez** clear buttonu, navíc `.padding(.top,6).bottom,4)`; search = **ne**-button, live query/placeholder `ZStack` **s** `xmark` clear buttonem). Plná komponenta by byla skoro jen mode-větvení (porušuje pravidlo 2). Sdílí se **jen field chrome** (pozadí + sizing).

```swift
extension View {
    func searchFieldChrome() -> some View {
        self
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemGray3).opacity(0.45))
            )
    }
}
```

Call sites (každý si drží svůj obsah + vlastní vnější padding/Button):
- **`EmojiPanelView.searchBarTrigger`** ([:136-141](../KeyboardUI/Sources/Views/EmojiPanelView.swift:136)) — `HStack{…}.foregroundStyle(.secondary)` pak `.searchFieldChrome()` pak **ponechat** vnější `.padding(.horizontal,10).padding(.top,6).padding(.bottom,4).contentShape(Rectangle())` a obalující `Button` + accessibility.
- **`EmojiSearchView.searchBar`** ([:89-94](../KeyboardUI/Sources/Views/EmojiSearchView.swift:89)) — `HStack{…}` pak `.searchFieldChrome()` pak **ponechat** vnější `.padding(.horizontal,10)`.
- ⚠️ Chrome **nezahrnuje** `.foregroundStyle` — panel ho má na HStacku, search per-element. Hranice modifieru = přesně `padding(.horizontal,10) + frame(height:32) + background(...)`.

### 4. Split `KeyView.swift` (635 → ~180) do extension souborů

Stejný `struct KeyView` (je `internal`), roztažený přes víc souborů podle už existujících `// MARK:` seamů. **View strom byte-identický.** Jediná mechanická změna: `@State private var`, `private static let` konstanty a `private` helpery, na které sahá extension v jiném souboru, se uvolní z `private` na **`internal`** (file-scope `private`/`fileprivate` přes soubory nejde). `KeyView` je internal struct → členy zůstávají module-scoped, **žádná změna public API**, žádná změna chování.

| Soubor | Obsah (dnešní řádky) |
|---|---|
| `KeyView.swift` | struct decl, stored props + `@State` + static konstanty, `init`, `body`, `combinedGesture`, `isSpaceKey` (1-180) |
| `KeyView+Gestures.swift` | `handleTouchDown`, `firesKeyTapFeedback`, `clickSoundKind`, `keyBackgroundColor`, `handleTouchUp` (182-269) |
| `KeyView+Trackpad.swift` | `startTrackpadArmTimer`, `handleSpaceDrag`, `emitCursorOffset` (271-326) |
| `KeyView+Backspace.swift` | `startBackspaceRepeat`, `fireBackspaceRepeat`, `fireWordDeleteRepeat` (328-396) |
| `KeyView+LongPress.swift` | `startLongPressTimer`, `updateHighlight`, `popoverOriginX`, `popoverOverlayAlignment`, `commitAlternate`, `hasTextAlternates` (398-478) |
| `KeyView+Content.swift` | `content`, `contentFont`, `effectiveContent`, `returnKeyLabel`, `accessibilityLabel`, `isLowercaseLetter` (480-544) |

- `#if DEBUG` previews (547-635) → buď zůstanou v `KeyView.swift`, nebo `KeyView+Previews.swift`.
- **Žádné** přesouvání gesture logiky do nového typu — jen `extension KeyView { … }` v každém souboru.

### 5. Split `EmojiPanelView.swift` (358 → ~150) do extension souborů

`EmojiPanelView` je `public struct`; uvolnit `private` → **`internal`** na cross-file členech (NE na `public` — public API beze změny). `EmojiCell` a `EmojiCellButtonStyle` z tohoto souboru odchází (scope §1, §2).

| Soubor | Obsah (dnešní řádky) |
|---|---|
| `EmojiPanelView.swift` | struct, props, `init`, konstanty, `visibleCategories`/`currentEmojis`/`columns`, `body`, `.onChange` (1-116) |
| `EmojiPanelView+SearchBar.swift` | `searchBarTrigger` (118-150) |
| `EmojiPanelView+Tabs.swift` | `categoryTabs`, `categoryTab`, `categoryTabIcon`, `cornerButton` (152-242) |
| `EmojiPanelView+Grid.swift` | `grid`, `emptyState` (244-285) |

### 6. README

Už doplněno: task 72 je v [tasks/README.md](README.md) → Tech debt / Refactoring (vedle 33, 71).

## Hotovo když

**Komponenty / dedup:**
- Nové: `KeyboardUI/Sources/Style/EmojiCellButtonStyle.swift`, `KeyboardUI/Sources/Views/EmojiCell.swift`, `searchFieldChrome()` modifier.
- `grep -rn "EmojiSearchResultButtonStyle\|func resultCell" KeyboardUI/` → prázdno (sloučeno).
- Oba search bary volají `.searchFieldChrome()`; oba emoji buňky používají sdílený `EmojiCell` + `EmojiCellButtonStyle`.

**Split:**
- `KeyView.swift` ~180 ř.; existují `KeyView+Gestures/Trackpad/Backspace/LongPress/Content.swift`. `grep -rn "private static let\|@State private" KeyView*.swift` → cross-file členy už `internal` (ne `private`).
- `EmojiPanelView.swift` ~150 ř.; existují `EmojiPanelView+SearchBar/Tabs/Grid.swift`.
- Žádný `EmojiPanelView`/`KeyView` člen nezveřejněn nad rámec dnešního (žádný omylem `public`).

**Důkaz nulové UI/behavior změny:**
- **Celá `KeyboardUI` snapshot suite projde beze změny obrázků** (`KeyboardViewSnapshots` vč. `.emojis`/`.emojiSearch`, `LongPressPopoverSnapshots`, `SuggestionBarViewSnapshots`, `KeyboardUISmokeTests`). Žádný re-record.
- `KeyboardCore` testy zelené (logika netknutá).
- `tuist generate` bez warningu, build zelený.
- **Reálné ověření na zařízení/simulátoru** (gesture engine se nesnapshotuje): long-press popover s diakritikou, delete-on-hold → word delete eskalace, **trackpad scrubbing na space**, emoji panel tap/long-press-favorite, emoji search. iPhone 17 / iOS 26.2 sim ([keymoji-build-uses-workspace memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keymoji-build-uses-workspace.md)).

## Mimo scope

- **Host-app views / `KeymojiUI`** — to je [task 71](71-extract-shared-ui-components-host-app.md).
- **Centralizace konstant / typografie / barev** (`KeyboardMetrics`/`Typography`/`Colors` enumy) — záměrně **ne**: velký churn v hot path + riziko tichého přepsání hodnoty = změna UI. Nízká hodnota / vysoké riziko.
- **`HapticButton` wrapper** — záměrně **ne**: měnil by strukturu/pořadí haptic+click+action volání na ~7 místech (behavior-adjacent).
- **Plný sdílený `EmojiSearchBar`** — jen `searchFieldChrome()` (viz §3).
- **Split / refaktor `SuggestionBarView`** (251 ř., tři módy) — drží jako celek, ne teď.
- **`KeyboardView.swift`** (387 ř.) — zůstává; je to koordinátor s čitelnými computed properties, split není potřeba.
- **Logika `KeyView` gest** (timing, eskalace, trackpad matematika), `InputDispatcher`, `LayoutBuilder` — beze změny.
- **`CONTEXT.md`** — žádná aktualizace (implementační detail, ne doménový slovník).

## Codex review

**Ano** — `KeyView` je hot-path gesture engine (haptika, trackpad scrubbing, delete-repeat eskalace, popover highlight). Split do extensions + uvolnění `private`→`internal` je mechanické, ale na kritickém kódu, který se **nesnapshotuje** — regresi by chytlo jen reálné ověření + druhý pár očí. Hlídat hlavně: že se žádný `@State`/konstanta omylem nezduplikovala při přesunu, a že `EmojiCell` `width: nil` vs fixed větev sedí pixel na pixel.

## Reference

- [task 71](71-extract-shared-ui-components-host-app.md) — sesterský host-app refactor, stejná pravidla.
- [KeyboardUI/Sources/Views/KeyView.swift](../KeyboardUI/Sources/Views/KeyView.swift) — gesture engine k rozdělení (MARK seamy už existují).
- [KeyboardUI/Sources/Views/EmojiPanelView.swift](../KeyboardUI/Sources/Views/EmojiPanelView.swift) / [EmojiSearchView.swift](../KeyboardUI/Sources/Views/EmojiSearchView.swift) — emoji buňky, ButtonStyle, search chrome.
- [KeyboardUI/Tests/KeyboardViewSnapshots.swift](../KeyboardUI/Tests/KeyboardViewSnapshots.swift) — regresní síť (pokrývá emoji panel + search).
- [KeyboardUI/Sources/Style/KeyStyle.swift](../KeyboardUI/Sources/Style/KeyStyle.swift) — vzor Style souboru v KeyboardUI.
