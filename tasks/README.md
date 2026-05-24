# Roadmapa implementace

Tasky pro **Keybo v1.0** — jednoduchá custom iOS klávesnice nahrazující SwiftKey pro osobní použití, s plánem na App Store release.

Procházet shora dolů; pořadí respektuje dependency. Plnohodnotně funkční klávesnice je po dokončení tasku 09. Tasky 10–13 dotahují host appku a App Store readiness.

Diskutovaná architektura, design rozhodnutí a non-goals jsou zafixované v jednotlivých task dokumentech — pokud něco není v Scope, je to záměr.

## v1.0 — Core keyboard

1. [01 — Scaffolding (Tuist targety, entitlements, Info.plist)](01-scaffolding.md)
2. [02 — Layout model (KeyboardCore)](02-layout-model.md)
3. [03 — Key rendering UI (KeyboardUI)](03-key-rendering.md)
4. [04 — Input handling + adaptive return + double-tap space](04-input-handling.md)
5. [05 — Shift state machine + caps lock](05-shift-and-capslock.md)
6. [06 — Auto-capitalization](06-auto-capitalization.md)
7. [07 — Long-press popover s diakritikou](07-long-press-popover.md)
8. [08 — Haptika + key click sound](08-haptics-and-sound.md)
9. [09 — Delete repeat-on-hold](09-delete-repeat.md)

## v1.0 — Host app & persistence

10. [10 — `AppGroupStore` + cross-process settings](10-app-group-store.md)
11. [11 — Host app onboarding (3-step flow)](11-host-app-onboarding.md)
12. [12 — Host app Settings screen](12-host-app-settings.md)
13. [13 — About screen + privacy policy HTML](13-about-and-privacy.md)

## v1.0 — Visual polish

14. [14 — Stejná šířka kláves v ASDF řádku](14-equal-letter-key-widths.md)
15. [15 — Symbol page parity se SwiftKey (dvě stránky, stejná výška)](15-symbol-page-parity.md)

## Future (po v1.0)

Stuby, plně se vypíší až přijde čas.

- [future — User override pro light/dark mode](future-light-dark-override.md)
- [future — Cross-process settings observation (Darwin notifications)](future-cross-proc-settings-observation.md)
- [future — Trackpad mode (long-press space)](future-trackpad-on-space.md)
- [future — Quick emoji key + system emoji picker](future-emoji-key.md)
- [future — Favorite emojis editor](future-favorite-emojis.md)
- [future — Slack-style emoji typing (`:smile:` → 😄)](future-slack-emoji-typing.md)
- [future — Emoji codes reference screen](future-emoji-codes-reference.md)
- [future — Real app icon (před App Store releasem)](future-app-icon.md)
- [future — Delete word-by-word (long hold)](future-delete-word-by-word.md)
- [future — Key preview popup (Apple-style bublina nad prstem)](future-key-preview-popup.md)
- [future — Sound feedback toggle (`playInputClick()`)](future-sound-feedback.md)
- [future — Top-row long-press popover clipping](future-popover-top-row-clipping.md)

## Mimo scope úplně

- **iPad support.** iPad keyboard má vlastní layout (split, floating, mini), to je celý vlastní projekt. Keybo zůstává iPhone only minimálně do v1.5.
- **Více jazyků klávesnice.** v1.0 i dohledný Future jsou English QWERTY only. Diakritika dostupná přes long-press popover, ne přes layout switch.
- **Word prediction / autocorrect.** SwiftKey-style ML prediction je full project. Mimo Keybo scope.
- **Voice typing, swipe typing, GIF picker, sticker picker.** Vše out.
- **Reklamy, analytics, telemetry, crash reporting.** Záměrná absence — privacy claim je „nesbíráme nic" a držíme to.

## Workflow

- Práce na `main`, incremental commits, gitmoji prefix (`✨`, `🐛`, `📝`, `💄`, `📸`, `👷`, `🧹`, `🚧`).
- Každý task se commituje jedním nebo více commity. Velký task (např. 02, 07) klidně 3–5 commitů.
- Po dokončení **klíčových tasků** (02, 04, 05, 06, 07, 10, 11) spustit `codex review --uncommitted` před closing commitem a reagovat na smysluplné připomínky.
- Testy se píšou *uvnitř* příslušného tasku, ne v samostatném „Tests" tasku.

## Reference

- WidgetCoin task style: `~/Development/WidgetCoin/tasks/`
- WidgetCoin `AppGroupStore` pattern: `~/Development/WidgetCoin/WidgetCoinCore/Sources/Shared/AppGroupStore.swift`
- WidgetCoin extension target setup: `~/Development/WidgetCoin/Tuist/ProjectDescriptionHelpers/Targets/Widget.swift`
- Apple Custom Keyboard Programming Guide: <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Keyboard.html>
