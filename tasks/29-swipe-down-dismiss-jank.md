# 29 — Plynulý swipe-down dismiss klávesnice

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium (daily UX, viditelný regress oproti konkurenci)

## Souhrn

V appkách se scrollovacím chatem (typicky iMessage, ale i Mail, Messages-like apps obecně) iOS nabízí gesto „swipe down z chat area" pro schování klávesnice. U Keybo se animace skrývání **sekne / trhá** — klávesnice nesleduje prst plynule a finální dismiss vypadá choppy. Nativní Apple klávesnice i SwiftKey to samé gesto odbavují plynule.

Vnímáme to jako bug, ne jako missing feature: iOS gesto zvládá driveni interactive dismiss `UIInputViewController` zdánlivě out-of-the-box (žádný explicitní opt-in není potřeba). Něco v našem rendering/hosting setupu zjevně blokuje main thread nebo brání systému plynule animovat `inputView.frame.origin.y`.

## Hypotézy (k ověření)

Pořadí od nejpravděpodobnější:

1. **SwiftUI re-render na každý frame během gesta.** `UIHostingController<KeyboardRoot>` reaguje na změny `KeyboardState` (`@Observable`); pokud iOS během dismiss gesta opakovaně volá `viewDidLayoutSubviews` s měnícím se `view.bounds.width` (nebo height), náš `viewDidLayoutSubviews` v `KeyboardViewController.swift:46-56` rebuilduje SwiftUI strom přes `rebuild()`. To je drahé na každý frame.
   - **Co ověřit:** logovat `viewDidLayoutSubviews` během swipe-down v iMessage. Pokud se volá 60×/s s měnícím se bounds, je to ono.
   - **Fix kandidát:** během interactive dismissu šířka klávesnice se nemění — měnit by se měla jen origin.y. Pokud `state.keyboardWidth` zůstává konstantní, `rebuild()` se nezavolá. Ověřit, že tomu tak skutečně je, a pokud ne, přidat ochranu (např. ignorovat layout změny během tracked gesture).

2. **`UIHostingController` re-layoutuje SwiftUI strom při změně frame parentu.** Auto Layout constraints v `installHostingController` (`KeyboardViewController.swift:130-135`) jsou `equalTo: view.leading/trailing/top/bottom`. Když systém animuje `view.frame.origin.y`, host SwiftUI dostane layout pass každý frame.
   - **Co ověriť:** zapnout `CA_DEBUG_TRANSACTIONS=1` nebo Instruments → SwiftUI / Time Profiler během dismissu. Hledat top-frame v `KeyboardView.body`.
   - **Fix kandidát:** rasterizovat snapshot klávesnice před dismissem? Nebo `host.view.layer.shouldRasterize = true` během gesture? Risk: vizuální regrese, nutno testovat.

3. **`KeyboInputView` (`inputViewStyle: .keyboard`) interaguje špatně s system dismiss.** Náš custom `UIInputView` subclass je tam jen kvůli `UIInputViewAudioFeedback`. Pokud sám o sobě nedělá nic divného (a v `KeyboardViewController.swift:265+` vypadá minimalisticky), tato hypotéza je low-probability — ale stojí za izolaci: nahradit dočasně default `inputView` a sledovat, jestli dismiss zplyne.

4. **`KeyboardRoot` má drahý `body` při zmenšujícím se frame.** Pokud `GeometryReader` uvnitř `KeyboardView` propočítává layout celé klávesnice (40+ kláves) na každý frame, gesto se sekne. Náš guard v `viewDidLayoutSubviews` brání `rebuild()`, ale ne SwiftUI internímu layout passu.
   - **Co ověřit:** Instruments → SwiftUI → kolik bodies/s. Pokud `KeyRowView.body` se reevaluje 60×/s během dismissu, je to ono.

## Scope (až přijde čas)

1. **Reprodukce + profiling.**
   - Zařízení > simulátor — gesto se na simulátoru nedá udělat dobře a perf na simu lže.
   - Reprodukovat v iMessage, Mail compose, Notes. Ne v Safari (Safari má vlastní hide gesture).
   - Instruments: Time Profiler na keyboard extension process (Settings → Developer → ?) nebo SwiftUI template. Záznam ~3s pokrývajících gesto od start do dismiss completion.
   - Heap & main thread hangs během gesta.

2. **Targeted fixes podle profilingu.**
   - Pokud hypotéza 1: guard ve `viewDidLayoutSubviews` proti rebuilds during gesture (možná detekovat přes `view.window?.gestureRecognizers`?).
   - Pokud hypotéza 2/4: vyzkoušet rasterizaci host view layer během dismissu (`UIView.beginAnimations`?), nebo `drawsAsynchronously = true` na CALayer.
   - Pokud hypotéza 3: vrátit `inputView = nil` (default) a vyřešit audio feedback jinak (např. delegating wrapper).

3. **Manuální validation.**
   - Pre-fix: nahrát video gesta v iMessage (60fps screen recording).
   - Post-fix: stejný flow, sleng by-side comparison s nativní klávesnicí. Plynulost by měla být subjektivně identická.
   - Otestovat na min. dvou zařízeních (starší a novější iPhone) — perf gap může být patrnější na slabším HW.

4. **Žádné funkční změny.**
   - Toto je čistě perf/rendering fix. Žádné nové features, žádné toggles.

## Závislosti

Žádné — orthogonal vůči ostatním v1.1 taskům. Lze řešit kdykoli.

## Mimo scope

- Custom dismiss gesture inicializovaný *z klávesnice* (např. swipe-down na space). To je separate feature, ne tento bug.
- Změna z `UIInputViewController` na něco jiného (není kam jít — to je jediná Apple-supported cesta).
- Optimalizace celého `KeyboardView` rendering layeru. Pokud profiler ukáže obecnou perf issue, otevřít na to samostatný task.

## Hotovo když

- Swipe-down dismiss klávesnice v iMessage je subjektivně plynulý a nelze od nativní klávesnice odlišit (slow-mo screen recording side-by-side).
- Stejný fix funguje v dalších test scenario apps (Mail compose, Notes).
- Root cause je identifikovaný a zaznamenaný v komentáři ve fixed kódu (proč to skákalo).
- Žádná regrese v normal typing / page switching / popover rendering.

## Proč ne v v1.0

Bug objevený až po dokončení core funkčnosti. Není to blocker (klávesnice se dá zavřít i tapnutím do textu mimo input, případně globe-tap-hold dismiss), ale stojí to za úsilí v polish fázi v1.1.

## Reference

- `KeyboardExtension/Sources/KeyboardViewController.swift` — hosting controller, `viewDidLayoutSubviews`, `KeyboInputView`
- `KeyboardExtension/Sources/KeyboardRoot.swift` — SwiftUI root
- Apple Custom Keyboard Programming Guide: <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Keyboard.html>
