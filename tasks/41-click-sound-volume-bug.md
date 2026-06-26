# 41 — Click sound: nepřiměřená hlasitost po startu klávesnice

**Status:** Done — 2026-05-29

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Medium (otravný daily-use bug, „neovládatelná" klávesnice po prvním stisku)

## Souhrn

Key click sound (task [26](26-sound-feedback.md), `UIKitClickSound` přes `UIDevice.current.playInputClick()`) **funguje** — zvuk se přehrává. Ale **hlasitost je při startu klávesnice často neúměrně nahlas** (subjektivně na max system volume), a po několika vteřinách psaní se sama přepne na očekávanou tichou click hlasitost (tak jak ji emituje nativní Apple klávesnice).

Klasický pattern: otevřu input field, klávesnice se objeví, první 3–10 stisků hraje zhruba na úrovni media volume / hlasitě, pak najednou („cvak“ v audio routě) přepne na kýženou system keyboard-click hlasitost a zbytek session už je v pořádku.

Nativní Apple klávesnice tohle nedělá — od prvního stisku přehrává click na fixed quiet volume podle Sounds & Haptics → Keyboard Clicks. Bug je tedy v našem audio setupu, ne v Apple API.

## Hypotézy (k ověření)

Pořadí od nejpravděpodobnější:

1. **`AVAudioSession` dědíme po host appce.** Keyboard extension neběží v izolovaném audio session contextu — sdílí audio routu s aktivním foreground appem. Pokud uživatel přijde z appky s `AVAudioSession.sharedInstance().category = .playback` (Spotify, YouTube, hra), první volání `playInputClick()` se routuje přes media output (full system volume). Po krátké době iOS audio session zřejmě interně přerouteu/downgraduje, ale prvních pár cvaků projde nahlas.
   - **Co ověřit:** otevřít klávesnici v Notes hned po čerstvém boot phonu (bez prior audio session) vs. po hraní Spotify. Hypotéza je, že čerstvý boot = OK, po Spotify = bug.
   - **Fix kandidát:** v `KeyboardViewController.viewDidLoad` (nebo `viewWillAppear`) explicit `try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])` před prvním `playInputClick()`. `.ambient` je correct pro UI sound effects co nemají soutěžit s media playback. **Pozor:** keyboard extension nesmí přerušit playing music host appky — `.mixWithOthers` je tam musí.

2. **`UIInputViewAudioFeedback` conformance se aktivuje s delayem.** `KeymojiInputView` (subclass `UIInputView`, conformance v [`KeyboardViewController.swift:431`](../KeyboardExtension/Sources/KeyboardViewController.swift)) je installed v `loadView()`. iOS interně cachuje audio feedback eligibility až někdy po view did appear. Před tím první `playInputClick()` calls jdou do fallback path která ignoruje system click volume.
   - **Co ověřit:** logovat `view.window != nil` + `isInputViewVisible` v okamžiku každého z prvních 10 stisků. Pokud první 3 stisky jsou před `viewDidAppear`, hypotéza sedí.
   - **Fix kandidát:** odložit first `play()` call dokud `viewDidAppear` neproběhne — buď v `UIKitClickSound` přes weak ref na controller, nebo gate flag který se flipne v `viewDidAppear`. Cena: první stisk může být tichý (acceptable trade-off vs. „příliš nahlas").

3. **`playInputClick()` se za určitých okolností degraduje na `AudioServicesPlaySystemSound(1104)`** (Tock sound) přes výchozí media volume. iOS dokumentace tvrdí že `playInputClick` honours system keyboard-click setting (fixed quiet level), ale prakticky se objevuje v Stack Overflow / Apple Developer Forums posts (2018–2024) že pokud audio session není ready, fall-backuje na system sound API které jede přes ringer/media volume.
   - **Co ověřit:** vyzkoušet nahradit dočasně `playInputClick()` přímým `AudioServicesPlaySystemSound(1104)` a porovnat hlasitostní profil. Pokud je identický → hypotéza 3 (fall-back path), pokud výrazně jinak → ne ono.

4. **Allow Full Access timing — vyloučeno.** Zvažováno, že `playInputClick()` potřebuje Allow Full Access; na zařízení ověřeno, že **nepotřebuje** (Full Access gateuje jen haptiku, ne zvuk — viz task 87), takže tahle hypotéza neplatí.

## Reprodukce

1. Killnout Keymoji extension (force-quit nějakou appku co ho používá).
2. Otevřít Spotify, spustit playback hudby (libovolnou hlasitostí).
3. Otevřít Notes nebo Messages, focus do input field — klávesnice se objeví.
4. Začít psát rychle (>3 stisky/s).
5. **Bug:** první 3–10 stisků = hlasitě (přibližně na media volume Spotify), pak audio přepne na tichou click úroveň zbytek session.

Kontrolní scénář (bez bug):
1. Po fresh boot phonu (žádné prior audio session).
2. Otevřít Notes, psát.
3. Click sound by měl být tichý / system-level od prvního stisku.

Manuální verifikace dle hypotézy 1 — pokud control scenario je OK a repro scenario je bug, jasný signál že problém je AVAudioSession inheritance.

## Scope

1. **Reprodukce + audio session profiling.**
   - Otestovat na reálném zařízení (simulator neumí keyboard click sound věrohodně).
   - Logovat v `KeyboardViewController.viewDidLoad`:
     - `AVAudioSession.sharedInstance().category` (před našim setupem)
     - `AVAudioSession.sharedInstance().categoryOptions`
     - `AVAudioSession.sharedInstance().mode`
   - Logovat v každém `UIKitClickSound.play()` první ~20 calls per session: `view.window != nil`, `viewIfLoaded?.isHidden`, current audio category.

2. **Fix per dominantní hypotéza.**
   - Pokud hypotéza 1 (AVAudioSession inherit): set `.ambient` + `.mixWithOthers` v `viewDidLoad` _před_ jakýmkoliv `playInputClick()`. Test že hudba Spotify nedostala pause a že click už od prvního stisku je tichý.
   - Pokud hypotéza 2 (UIInputViewAudioFeedback delay): gate flag (`hasAppeared`), odložit `play()` no-op dokud `viewDidAppear` neproběhne. Test že první stisk po appearance je už tichý.
   - Pokud hypotéza 3 (fallback path): kombinovat fix 1 + 2 — explicit session setup zajistí že fallback path nikdy nesáhne na media volume.

3. **Regression check existing path.**
   - Click sound stále hraje (Sounds & Haptics on, Keymoji Settings click toggle on).
   - Click sound stále nehraje když Settings toggle off.
   - Click sound stále nehraje když user vypne Keyboard Clicks v Sounds & Haptics.
   - Host app playback hudby není přerušený nebo paused když začnu psát (kritické — `.mixWithOthers` musí tam být, jinak break music).
   - Haptic feedback (task [31](31-haptic-feedback-for-every-key.md)) není fix-affected.

4. **Žádné nové toggles.**
   - Tohle je čistě bug fix. Žádný „normalize click volume" Setting. Cíl je parita s nativní klávesnicí, ne uživatelská konfigurace.

## Závislosti

- Task [26](26-sound-feedback.md) (click sound impl) — done.
- Task [31](31-haptic-feedback-for-every-key.md) (haptic refactor) — done, but verify haptic path je nedotčený.

## Mimo scope

- Vlastní custom click sound sample (.wav přes `AudioServicesCreateSystemSoundID`). Apple `playInputClick()` je idiomatic Apple-supported cesta; nahrazení by řešilo bug ale rozbilo respekt user system preference („Keyboard Clicks" toggle by přestal fungovat).
- Per-key volume control. Mimo scope.
- Per-app audio session deny-list („v Spotify nevolá playInputClick"). Hyper-edge; fix by měl být general.

## Hotovo když

- [ ] Root cause identified (která hypotéza to byla, zaznamenat v komentáři ve fixed kódu).
- [ ] Reprodukce scénář (Spotify playback → otevři Keymoji → psaní) už nevykazuje hlasitý úvod — od prvního stisku tichý click parita s native keyboard.
- [ ] Control scenario (fresh boot, žádné prior audio) zůstává funkční.
- [ ] Hudba v host appce není přerušená když začnu psát na Keymoji (regression check pro `.mixWithOthers` pokud aplikováno).
- [ ] Settings toggle pro click sound funguje (on/off) beze změny.
- [ ] Side-by-side audio recording s nativní klávesnicí (loud Spotify scenario) — Keymoji click track není slyšitelně hlasitější.
- [ ] Žádná regrese haptik, popover, ani delete-repeat.

## Reference

- [`KeyboardExtension/Sources/UIKitClickSound.swift`](../KeyboardExtension/Sources/UIKitClickSound.swift) — `play()` wrapper kolem `UIDevice.current.playInputClick()`.
- [`KeyboardExtension/Sources/KeyboardViewController.swift`](../KeyboardExtension/Sources/KeyboardViewController.swift) — `loadView` instaluje `KeymojiInputView` (UIInputViewAudioFeedback conformance, line ~431).
- [`KeyboardCore/Sources/Public/KeyClickSounding.swift`](../KeyboardCore/Sources/Public/KeyClickSounding.swift) — protocol + Noop.
- Task [26](26-sound-feedback.md) — původní sound feedback impl.
- Apple — [`UIDevice.playInputClick()`](https://developer.apple.com/documentation/uikit/uidevice/1620025-playinputclick), [`UIInputViewAudioFeedback`](https://developer.apple.com/documentation/uikit/uiinputviewaudiofeedback), [`AVAudioSession` categories](https://developer.apple.com/documentation/avfaudio/avaudiosession/category).
