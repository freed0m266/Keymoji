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
76. [76 — „What's New" content version: založení baseline](76-whats-new-content-version-baseline.md) — pouze infrastruktura (Int verze v `AppGroupStore` + seed-on-absence na startu); What's New UI je budoucí task. Seed **teď, před prvním obsahem**, ať budoucí oznámení míří správně.

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
50. [60 — Favorites editor: název emoji místo shortcode + odvozené názvy vlajek](60-favorites-show-emoji-name.md)
62. [62 — Onboarding: výběr oblíbených emoji (s garantovaným ne-prázdným fallbackem)](62-onboarding-pick-favorites.md)
69. [69 — Beta feedback round 1: popover bez base + downward-cancel + trackpad 2D scrubbing](69-beta-feedback-popover-trackpad.md) — round 1 beta UX fix dvou každodenních gest v `KeyView`.

## v1.2 — Word suggestions

40. [40 — Word completion suggestions (UILexicon + UITextChecker + personal recents)](40-word-completion-suggestions.md)
48. [48 — Seznam naučených slov se správou (zobrazit + mazat jednotlivě)](48-learned-words-list-management.md)
51. [51 — Favorites bar: řazení podle četnosti používání](51-favorites-bar-sort-by-frequency.md)
54. [54 — Skrýt number row v landscape orientaci](54-hide-number-row-in-landscape.md)
56. [56 — SuggestionBar: zobrazovat i na symbol page (jen ne emoji / emoji-search)](56-suggestion-bar-always-except-emoji.md)

## v1.2 — Sizing & layout

52. [52 — Refaktor výšky/šířky kláves: model „zdola nahoru" + jedna konstanta](52-key-sizing-bottom-up-refactor.md)
53. [53 — Probliknutí klávesnice na max výšku při přepnutí](53-keyboard-switch-height-flash.md)
55. [55 — Shodné hrany a cluster mezi řádkem 3 a řádkem C](55-row3-rowc-edge-key-parity.md)
59. [59 — Auto numberpad pro číselná pole (numberPad / decimalPad)](59-auto-numberpad-for-numeric-fields.md)
61. [61 — Konstantní výška klávesnice + generalizovaný `topRegion`](61-constant-height-top-region.md)

## v1.x — Typing & diakritika

58. [58 — Jazykové sady letterAlternates + popup vždy se základním písmenem](58-letter-alternates-language-sets.md)
65. [65 — Accent-aware doplňování, caps lock z prázdného pole & limity](65-accent-aware-completions-capslock-limits.md)
66. [66 — Číslice nejdou napsat při vypnutém number row → nativní rozložení symbolů](66-number-row-off-digits-native-symbol-layout.md)
73. [73 — Výkon: plynulá klávesnice i při 10 000 learned words](73-keyboard-perf-smooth-at-10k-learned-words.md) — fázovaný (storage→file+index, `@Observable` scoped invalidace, async suggestion pipeline); řeší všechny critical/high/medium nálezy perf auditu, beze změny chování/UI.
74. [74 — Kvalita učení a návrhů: anti-překlep, čísla & nicky, e-mail quick-pick](74-learning-quality-numbers-emails.md) — navazuje na 73; práh `count ≥ 2` proti zobrazování naučených překlepů, učení čísel/telefonů/nicků (sjednocení completion na letters+symbols), proaktivní e-mail quick-pick.
77. [77 — Learned words: uniformní suggest práh (skrýt 1×, zrušit e-mail výjimku)](77-learned-words-uniform-suggest-threshold.md) — editor skryje podprahová slova, `minSuggestCount` se stává jediným zdrojem pravdy pro prose i adresy i viditelnost; **supersedes e-mail výjimku z tasku 74 (Fáze C)**.
78. [78 — Jazyk doplnění dle Accent setu (accent → systém → EN)](78-completion-language-from-accent-set.md) — jednojazyčný fallback řetězec místo natvrdo anglické base; **supersedes aditivní model z tasku 65** ([ADR 0002](../docs/adr/0002-single-completion-language-from-accent-set.md)).

## Monetizace

63. [63 — Keymoji Plus (freemium + jednorázový unlock $3.99)](63-monetization-keymoji-plus.md) — zavést **před** prvním veřejným releasem.
64. [64 — „HESOYAM" promo cheat → 30denní Plus trial](64-hesoyam-promo-trial.md) — viralní easter egg + loss-aversion konverze (závisí na 63). **(HESOYAM půlka zrušena [taskem 70](70-remove-hesoyam-cheat-code.md).)**
67. [67 — Debug menu pro simulaci fresh/free user stavů (DEBUG-only)](67-debug-menu-simulate-free-user.md) — QA nástroj pro promo/trial obrazovky, kompiluje se jen v DEBUG (závisí na 63, 64).
68. [68 — Re-run onboardingu ořezává favorites na free cap (data loss)](68-onboarding-rerun-truncates-favorites.md) — drží invariant z 64 „favorites se po downgradu nemažou" (závisí na 64).
70. [70 — Odstranit HESOYAM / cheat code (a mrtvou stacking matiku)](70-remove-hesoyam-cheat-code.md) — čistý removal nefunkční cheat vrstvy; ruší HESOYAM půlku tasku 64, Welcome trial zůstává beze změny (odstraní jediné App Review 2.3.1 riziko).

## Pre-App-Store

28. [28 — Real app icon](28-app-icon.md)
47. [47 — App Store listing & ASO](47-app-store-listing.md)

## Tech debt / Refactoring

33. [33 — Refactor: splitnout Favorites na 2 moduly, rename + sjednotit ViewModel pattern](33-feature-modules-and-vm-refactor.md)
71. [71 — Refactor: extrahovat sdílené UI komponenty z host-app views do KeymojiUI](71-extract-shared-ui-components-host-app.md) — pixel-perfect, žádná změna UI; host-app půlka.
72. [72 — Refactor: pročistit a rozdělit UI klávesnicové extension (KeyboardUI)](72-extract-shared-ui-components-keyboard.md) — sesterský refactor, extension-only (nemůže importovat KeymojiUI).

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
