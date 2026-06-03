# 26 — Sound feedback toggle (`playInputClick()`)

**Status:** Done — 2026-05-25

**Priorita:** v1.1 · **Úsilí:** XS · **Dopad:** Low

## Souhrn

V1.0 task 08 záměrně vynechává klikací zvuk klávesnice (`UIDevice.current.playInputClick()`). Defaultně iOS klávesnice click sound poskytuje jen pokud uživatel má „Keyboard Clicks" zapnuté v Settings → Sounds & Haptics. Pro Keymoji je to ~10 řádků kódu.

## Scope (až přijde čas)

- `KeyClickSounding` protocol v `KeyboardCore`.
- `UIKitClickSound` adapter v `KeyboardExtension`, používá `UIDevice.current.playInputClick()`.
- `KeyboardViewController` adoptuje `UIInputViewAudioFeedback` (task 08 už toto deklaroval).
- `InputDispatcher.dispatch` volá `clickSound.play()` v insertText / space / return / backspace.
- Toggle v Settings „Keyboard click sound" (default OFF — Apple default je taky off).

## Závislosti

Task 04, 08, 12 hotové.

## Proč ne v v1.0

Drobnost s nízkým ROI — uživatelé sound feedback většinou nepoužívají (silenced ringer). Skipujeme v v1.0 abychom nezvyšovali test povrch.
