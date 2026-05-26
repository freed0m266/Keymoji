# 31 — Haptic feedback pro každou klávesu

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** XS · **Dopad:** Medium (daily UX, taktilní konzistence)

## Souhrn

Aktuálně haptic feedback (light impact) fire jen klávesy, které mutují dokument: `insertText`, `insertRawText`, `backspace`, `deleteWord`, `space`, `return`. System controls — **shift**, **page switch** (123 / ABC / emoji switcher), **dismiss keyboard**, a **trackpad cursorOffset** — žádný haptic neemitují. Logika je v `firesKeyTapFeedback` ([KeyboardUI/Sources/Views/KeyView.swift:183](KeyboardUI/Sources/Views/KeyView.swift:183)).

Komentář v kódu říká „mirrors Apple's convention of feedback-on-character-key but silent system controls" — což je verný popis stock iOS, ale preferenčně chci, aby **každá** klávesa vibrovala. Subjektivně je to víc satisfying a líp odlišuje úspěšný tap (zejména u shiftu, kde uživatel potřebuje potvrzení, že se stav skutečně přepnul).

## Scope

1. **`KeyView.firesKeyTapFeedback`** ([KeyboardUI/Sources/Views/KeyView.swift:183-190](KeyboardUI/Sources/Views/KeyView.swift:183))
   - Buď celou property smazat a fire `onKeyTapHaptic()` + `onKeyClick()` v `handleTouchDown` unconditionally,
   - nebo nechat property a vrátit `true` pro všechny case kromě `cursorOffset` (viz níže).
   - Druhá varianta je čistější — guard pro `cursorOffset` zůstává explicitní.

2. **`cursorOffset` — keep silent.**
   - Trackpad-mode emituje `cursorOffset` **kontinuálně** během dragu (každý pohyb prstu nad threshold). Fire haptic 60×/s by byl katastrofa.
   - Vstup do trackpad módu už má vlastní `trackpadModeEntered()` haptic (heavier "thunk") přes `HapticFeedbackProviding`, což je správně.
   - Closing: keep `cursorOffset` mimo `firesKeyTapFeedback`.

3. **Key-click sound** ([KeyView.swift:169](KeyboardUI/Sources/Views/KeyView.swift:169))
   - Sound je vázaný na stejnou condition jako haptic. **Rozhodnout:** budeme i sound emitovat pro system klávesy?
   - Návrh: ano, ze stejných důvodů — konzistence. iOS `playInputClick()` je jediný oficiální sound API a stock klávesnice ho hraje i na shift/page switch.
   - Pokud by zvuk u shift/page switch byl iritující, snadno se rozdělí na dva flagy (`firesKeyTapHaptic` vs. `firesKeyClick`) — initial verze jednoho flagu.

4. **Komentář** (řádky 164-166 v `KeyView`)
   - Přepsat tak, aby reflektoval novou logiku: „Fire on every key except continuous trackpad scrubbing."

5. **Manuální test**
   - Na zařízení s Full Access + zapnutým haptic toggle: tap shift, tap 123/ABC, tap emoji switcher, dismiss (pokud někde existuje), space. Každé z těchto musí cinknout.
   - Trackpad-mode (long-press space + drag): jediný haptic na vstupu, žádné průběžné během dragu.
   - Long-press popover: existující `popoverEntry` + `popoverHighlightChanged` se nesmí změnit (orthogonal logika v `HapticFeedbackProviding`, kterou tento task netouchuje).

## Mimo scope

- **Diferenciace intensity podle key typu** (např. „shift = soft, character = light"). Pokud se ukáže, že stejný light impact pro všechno je moc monotónní, řeším separátně. v1 stačí uniformita.
- **Změna haptic settings UI v host appu.** Toggle „Haptic feedback" v Settings už řídí *všechno* přes `isEnabled` v `UIKitHaptics` ([KeyboardExtension/Sources/UIKitHaptics.swift:18-29](KeyboardExtension/Sources/UIKitHaptics.swift:18)) — nic dalšího nepřibývá.
- **Haptic na emoji panelu** ([EmojiPanelView.swift](KeyboardUI/Sources/Views/EmojiPanelView.swift)). Category tabs, emoji cells, corner delete, toggle-favorite — všechny už fire `onKeyTapHaptic()`. Nic k řešení.
- **Haptic na onboarding obrazovkách v host appu.** Mimo keyboard extension scope.

## Závislosti

- **Task 30** (remove globe key) — ortogonal, ale pokud task 30 padne před tímto, jednou méně `case .nextKeyboard` v switch. Drobnost.

## Hotovo když

- Tap na shift, 123/ABC toggle, emoji switcher → cítit ten samý light impact jako u písmene.
- Trackpad-mode drag: žádné průběžné haptics, vstup pořád emituje vlastní "thunk".
- Bez Full Access: silent fallback funguje (žádný crash, žádný warning).
- Manuální regression: normální typing pořád feels right, popover diakritiky pořád funguje stejně.

## Reference

- [KeyboardUI/Sources/Views/KeyView.swift:155-190](KeyboardUI/Sources/Views/KeyView.swift:155) — `handleTouchDown` + `firesKeyTapFeedback`
- [KeyboardCore/Sources/Public/HapticFeedbackProviding.swift](KeyboardCore/Sources/Public/HapticFeedbackProviding.swift) — protocol
- [KeyboardExtension/Sources/UIKitHaptics.swift](KeyboardExtension/Sources/UIKitHaptics.swift) — concrete impl + `isEnabled` gate
