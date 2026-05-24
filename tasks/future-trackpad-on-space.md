# Future — Trackpad mode (long-press space)

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** M · **Dopad:** Medium

## Souhrn

Apple stock klávesnice umí: long-press na space → klávesnice se „zmrazí" a slouží jako trackpad pro pohyb kurzoru v textu. Velmi user-loved feature. V Keybo v1.0 vynecháno kvůli scope.

## Scope (až přijde čas)

- `TrackpadModeState` v `KeyboardExtension` — entry/exit detection na long-press space (~300 ms hold + minimum drag).
- Vizuální change: keyboard fades to indicate trackpad mode (přes overlay s nižším opacity).
- `UITextDocumentProxy.adjustTextPosition(byCharacterOffset:)` — Apple poskytuje pro keyboard extensions.
- Drag delta → character offset mapping. Stage 1: jen horizontální. Stage 2: i vertikální (s line-detection — komplikovanější).
- Haptic při entry do trackpad mode.

## Závislosti

Tasky 04, 07, 08 hotové (long-press infra, haptika).

## Proč ne v v1.0

Komplexní gesture state machine, byť jednorozměrný trackpad lze napsat za den. Polish, ne core funkce.
