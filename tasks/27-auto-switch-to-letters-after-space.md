# 27 — Auto-switch back to letters after space on symbols

**Status:** Done — 2026-05-25

**Priorita:** v1.1 · **Úsilí:** XS · **Dopad:** Medium (daily typing flow)

## Cíl

Když je klávesnice na některé symbol stránce (`.symbols(.primary)` nebo `.symbols(.alternate)`) a uživatel ťukne na space, po vložení mezery se klávesnice automaticky přepne zpět na `.letters(.lower)`. Mimikuje SwiftKey/Apple chování: po mezeře typicky následuje nové slovo, takže další tap by měl být písmeno bez extra `[ABC]` tap.

## Kontext

- Aktuální chování: tap na space na symbol stránce vloží mezeru a klávesnice zůstává na symbolech. Uživatel musí ručně tapnout `[ABC]` (bottom row toggle) aby se dostal zpět na písmena.
- SwiftKey + Apple stock klávesnice tohle dělají automaticky — UX zlepšení.
- Logika patří do `InputDispatcher.dispatch` v případě `.space`. Auto-switch musí proběhnout *po* vložení mezery a *po* update space-tracking flagů (kvůli double-tap-space → `". "` substituci, viz scope níže).
- Existující flow:
  - `case .space:` → `handleSpace(state:proxy:now:)` vloží mezeru nebo nahradí předchozí mezerou na `". "` při double-tapu.
  - `state.lastInsertWasSpace`/`lastSpaceInsertedAt` se mění uvnitř `handleSpace`.
- Auto-cap interakce: `KeyboardViewController.textDidChange` zavolá `refreshAutoCapitalization` po každé textové změně. Pokud po space je sentence-start (např. po `". "`), auto-cap promote `.letters(.lower) → .letters(.upper)`. Náš nový switch musí tento flow respektovat.

## Scope

### 1. Auto-switch v `InputDispatcher`

`KeyboardCore/Sources/Logic/InputDispatcher.swift`, case `.space`:

```swift
case .space:
    handleSpace(state: &state, proxy: proxy, now: now())
    // After a space on either symbol page, hop back to letters. The user is presumably
    // starting a new word; SwiftKey/Apple stock behave the same way. Auto-cap (in the
    // controller's `textDidChange`) will then promote to `.upper` if appropriate.
    if case .symbols = state.page {
        state.page = .letters(.lower)
    }
```

Switch musí být **po** `handleSpace` (aby double-tap-space → `". "` proběhlo s page=.symbols pokud uživatel tapl space podruhé rychle), ale **před** návratem z `dispatch`. Auto-cap se postará v `refreshAutoCapitalization` voláné z `textDidChange`.

### 2. Pozor na double-tap-space chování

Edge case: uživatel je na `.symbols(.primary)`, tapne space, page se přepne na `.letters(.lower)`. Tapne space znovu během 500ms okna. Co se stane?

- První space: handleSpace insert " ", `lastInsertWasSpace=true`, `lastSpaceInsertedAt=t0`. Page switch na `.letters(.lower)`.
- Druhý space (page už je letters): handleSpace, `isDoubleTap=true` (kvůli `lastInsertWasSpace` + window), substituce `". "`. Page je už letters, no switch needed.

Test musí ověřit, že double-tap přes page switch funguje (timestamp tracking se nesmí rozbít).

### 3. Žádný auto-switch po `.return` (zatím)

Apple stock přepne i po return. Ale tohle není explicitně zmíněno v task pretextu. **Mimo scope** tohoto tasku — pokud chceš později, samostatný small task. Důvod: return má jinou sémantiku (často odeslat zprávu), behavior se může lišit per-app.

### 4. Unit testy

`KeyboardCore/Tests/InputDispatcherTests.swift`:

- `testSpace_onSymbolsPrimary_autoSwitchesToLetters()` — page začíná `.symbols(.primary)`, dispatch `.space`, expect page=.letters(.lower) + inserted=[" "].
- `testSpace_onSymbolsAlternate_autoSwitchesToLetters()` — totéž pro `.alternate`.
- `testSpace_onLetters_doesNotChangePage()` — kontrola že na letters page space pageu nemění (existující chování zachováno).
- `testDoubleSpace_onSymbolsPrimary_substitutesAndSwitches()` — první space na symbols → letters + " " vloženo. Druhý space within window → `". "` substituce na letters page.

### 5. Žádná snapshot regrese

KeyboardView rendering se nemění (pouze state.page transition). Snapshot testy nepotřebují refresh.

## Mimo scope

- Auto-switch po `.return` — viz scope 3.
- Auto-switch po jiných text-vkládajících klíčích (tečka, čárka, atd.). Apple to nedělá, my taky ne.
- Settings toggle „Auto-switch off symbols after space". Pokud někomu vadí, samostatný Future task.

## Hotovo když

- Tap na space na primary nebo alternate symbol page přepne klávesnici na `.letters(.lower)`.
- Tap na space na letters page chování nemění.
- Double-tap-space substituce stále funguje (i přes page switch mezi tapy).
- Auto-cap po `". "` nadále kicks in (page → .upper po terminator+space).
- 4 nové unit testy v `InputDispatcherTests` green.
- Existující 85 KeyboardCore testů + 16 KeyboardUI snapshot testů green.
- Manuální verify v simulátoru: napsat "Hello!" na letters, tap `[123]` (jdeš na symbols), napsat "$5", space → automaticky letters. Pokračovat psát "world." → ✓

## Rizika

- **Double-tap space interakce** — pokud auto-switch změní state.page mezi prvním a druhým space tapem, ověřit že `handleSpace` druhého tapu stále detekuje double-tap (přes `lastInsertWasSpace` + `lastSpaceInsertedAt`). Test 4 výše chrání.
- **Auto-cap po `". "` substituci** — `refreshAutoCapitalization` v controlleru se volá po `textDidChange`. Po `". "` substituci na letters page, kontext končí `". "` → shouldCap=true → page=.upper. Auto-switch nezasahuje (page už je letters). ✓
- **User intent na pokračování v symbolech** — jeden trade-off: pokud uživatel chce psát `$5 $10` (dvě cena), musí po prvním space znovu tapnout `[123]`. Apple/SwiftKey ten trade-off berou. Stejně tak my.

## Reference

- `KeyboardCore/Sources/Logic/InputDispatcher.swift` — `case .space:` blok
- `KeyboardCore/Tests/InputDispatcherTests.swift` — existující space testy jako vzor
- SwiftKey / Apple stock behavior — vzor
