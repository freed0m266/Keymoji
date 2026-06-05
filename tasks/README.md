# Roadmapa implementace

> Aktuální status snapshot: [dashboard.html](dashboard.html) (regenerate s `python3 scripts/generate_dashboard.py`).

Tasky pro **Keymoji v1.0** — jednoduchá custom iOS klávesnice nahrazující SwiftKey pro osobní použití, s plánem na App Store release.

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

## v1.1 — Uživatelská přání z původního prompt seznamu

16. [16 — User override pro light/dark mode](16-light-dark-override.md)
17. [17 — Quick emoji key + system emoji picker](17-emoji-key.md)
18. [18 — Favorite emojis editor](18-favorite-emojis.md)
19. [19 — Slack-style emoji typing (`:smile:` → 😄)](19-slack-emoji-typing.md)
20. [20 — Emoji codes reference screen](20-emoji-codes-reference.md)

## v1.1 — Bugfixes & polish odložené z v1.0

21. [21 — Top-row long-press popover clipping](21-popover-top-row-clipping.md)
22. [22 — Cross-process settings observation (Darwin notifications)](22-cross-proc-settings-observation.md)
23. [23 — Trackpad mode (long-press space)](23-trackpad-on-space.md)
24. [24 — Delete word-by-word (long hold)](24-delete-word-by-word.md)
25. [25 — Key preview popup (Apple-style bublina nad prstem)](25-key-preview-popup.md)
26. [26 — Sound feedback toggle (`playInputClick()`)](26-sound-feedback.md)
27. [27 — Auto-switch back to letters after space on symbols](27-auto-switch-to-letters-after-space.md)
29. [29 — Plynulý swipe-down dismiss klávesnice](29-swipe-down-dismiss-jank.md)
30. [30 — Odstranit globe key z bottom row](30-remove-globe-key.md)
31. [31 — Haptic feedback pro každou klávesu](31-haptic-feedback-for-every-key.md)
32. [32 — Favorite emojis: zobrazit shortcode místo druhé kopie emoji](32-favorites-show-shortcodes.md)
34. [34 — Rozšířit `EmojiCatalog` na všechny single-codepoint emoji z Wikipedie](34-full-unicode-single-emoji-catalog.md)
35. [35 — Redesign klávesnice: vizuální parita s nativní iOS klávesnicí](35-keyboard-native-look-redesign.md)
36. [36 — Programovatelná akce na dvojitý tap na space (tečka / dismiss / nic)](36-space-double-tap-action.md)
37. [37 — `KeyContent.number` case + vertikální zarovnání digitů](37-key-content-number-case.md)
38. [38 — Onboarding feature tour: zmínit všechny zásadní funkce](38-onboarding-feature-tour.md)
39. [39 — Emoji search v keyboardu (`.emojiSearch` mode)](39-emoji-search.md)
41. [41 — Click sound: nepřiměřená hlasitost po startu klávesnice](41-click-sound-volume-bug.md)
42. [42 — Kliknutí do mezery mezi klávesami nesmí propadnout](42-inter-key-gap-hit-areas.md)
45. [45 — Přepínání QWERTY / QWERTZ layoutu](45-qwerty-qwertz-switch.md)
49. [49 — Favorites bar: TabView paging místo free-scroll](49-favorites-bar-tabview-paging.md)

## v1.2 — Word suggestions

40. [40 — Word completion suggestions (UILexicon + UITextChecker + personal recents)](40-word-completion-suggestions.md)
48. [48 — Seznam naučených slov se správou (zobrazit + mazat jednotlivě)](48-learned-words-list-management.md)
51. [51 — Suggestion bar: haptika na začátku stisku (parita s klávesami)](51-suggestion-bar-haptic-on-press-down.md)

## Pre-App-Store

28. [28 — Real app icon](28-app-icon.md)
47. [47 — App Store listing & ASO](47-app-store-listing.md)

## Tech debt / Refactoring

33. [33 — Refactor: splitnout Favorites na 2 moduly, rename + sjednotit ViewModel pattern](33-feature-modules-and-vm-refactor.md)

## Mimo scope úplně

- **iPad support.** iPad keyboard má vlastní layout (split, floating, mini), to je celý vlastní projekt. Keymoji zůstává iPhone only minimálně do v1.5.
- **Více jazyků klávesnice.** v1.0 i dohledný Future jsou English only. Diakritika dostupná přes long-press popover, ne přes layout switch. Pozn.: positional **QWERTY/QWERTZ** varianta je v scope (task 45) — není to další jazyk, jen prohození pozic Y/Z; písmena zůstávají English-only.
- **SwiftKey-style next-word prediction (bigram model nad personal corpus).**
  Prefix-match completion z UILexicon + UITextChecker + personal recents je
  v scope (v1.2, task 40). Plnotučná next-word prediction (predikce dalšího
  slova bez prefixu) zůstává out of scope.
- **Autocorrect.** Bar nikdy nenabízí překlepy a nikdy ticho nepřepisuje text
  po space. Selection je vždy explicitní (tap na chip). Out of scope permanentně.
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
