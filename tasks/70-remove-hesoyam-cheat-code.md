# 70 — Odstranit HESOYAM / cheat code (a mrtvou stacking matiku)

**Status:** Todo

**Priorita:** v1.x (před App Store releasem, [task 47](47-app-store-listing.md)) · **Úsilí:** S–M · **Dopad:** Medium (méně kódu, méně rizik; **odstraní jediné existenční App Review 2.3.1 riziko** — skrytou funkci)

**Závisí na:** nic (čistý removal). **Ruší půlku [tasku 64](64-hesoyam-promo-trial.md)** (HESOYAM vertikálu) — Welcome vertikála z 64 **zůstává plně funkční**.

**Souvisí:** [63 — Keymoji Plus](63-monetization-keymoji-plus.md) (entitlement infra, nedotčená) · [67 — Debug menu](67-debug-menu-simulate-free-user.md) (ubude cheat akce) · [ADR 0001](../docs/adr/0001-opt-in-welcome-plus-trial.md) (amend) · [CONTEXT.md](../CONTEXT.md) (termíny).

## Kontext / proč

HESOYAM (napsání `hesoyam` na klávesnici → +60 dní Plus, konfety) **na zařízení nikdy spolehlivě nefungoval**. `textDidChange` v keyboard extension neslučuje 1:1 se znaky (coalescing přes návrhy), takže detekce reálné aktivace míjela — viz revert log v [tasku 64](64-hesoyam-promo-trial.md) (1. pokus vrácen) i to, že device-tuning HESOYAM efektu zůstal v 64 nedokončený a **efekt nebyl nikdy ověřen funkční**.

Akviziční roli mezitím plně pokrývá **Welcome Plus trial** (opt-in „🎁 měsíc Plus zdarma" v onboardingu + Settings) — ten funguje skvěle a **zůstává beze změny**. HESOYAM tím ztratil důvod existence a nese jen náklady: nefunkční device cesta, `ConfettiSwiftUI` v paměťově citlivém extension, a App Review 2.3.1 riziko (skrytá funkce). Tenhle task ho **chirurgicky vyřízne** a páteř promo-trialu nechá žít pro Welcome.

**Appka ještě není veřejně venku** → žádní reální uživatelé s aktivním HESOYAM grantem → **žádná migrace, žádné claw-back**. `PromoTrialRecord` je `Codable`: starý záznam s klíčem `cheatCodeConsumed` se po smazání pole tiše dekóduje dál (neznámé klíče se ignorují).

## Rozhodnutí (zafixovaná z grill session 2026-06-20)

| Téma | Rozhodnutí |
|---|---|
| Rozsah | Odstranit **jen** HESOYAM / `CheatCode*` vrstvu. „Cheat codes obecně" = ten jediný cheat (slovo žije na 1 místě v `CheatCodeDetector.code`). Žádné jiné cheaty neexistují |
| Welcome | **Zůstává 100%** — onboarding banner, Settings `PlusRowState`, loss-aversion, `.afterTrial` paywall, gating, reconciliace, Keychain záznam, App Group zrcadlo, notifier |
| Migrace | **Žádná** — pre-release, nikdo app nemá. `Codable` toleruje zmizelé pole. Žádné honorování starých grantů |
| Sdílená páteř | `PromoTrialStore` (typ), `promoPlusExpiresAt`, Keychain, reconciliace **nepřejmenovávat, nesahat na perzistenci** |
| Mrtvá stacking matika | **Zploštit** (důkladný úklid): `nextExpiry(max(now, currentExpiry)+days)` → inline `now + welcomeGrantDays` v `consumeWelcome` (Welcome je jednorázový, `expiresAt` je při consume vždy `nil` → chování identické). Smazat `nextExpiry` helper + stacking testy |
| State machine | `SettingsViewModel.PlusRowState` precedence **nechat** (je korektní/defenzivní). Padají jen **testovací scénáře**, co fabrikovaly stav „expiry aktivní + `welcomeConsumed=false`" (uměl jen HESOYAM) |
| ConfettiSwiftUI | **Odstranit** SPM dep (jen HESOYAM ji používal; Welcome je tichý) |
| Outward docs | `notes.txt`: pryč HESOYAM věta, Welcome nechat. `privacy-policy.html`: **beze změny** (Keychain promo záznam platí dál pro Welcome) |
| Doménová dokumentace | `CONTEXT.md`: smazat termín „HESOYAM promo bonus", přepsat „Plus trial expiry". `ADR 0001`: datovaná „Superseded" sekce (ne nový ADR) |

## Scope

### 1. Smazat soubory (cheat-only)
- `KeyboardCore/Sources/Logic/CheatCodeDetector.swift`
- `KeyboardCore/Tests/CheatCodeDetectorTests.swift`
- `KeymojiCore/Sources/Shared/CheatCodeActivating.swift` (`CheatCodeOutcome`, `CheatCodeActivating`, `CheatCodeActivator`)
- `KeymojiCore/Tests/CheatCodeActivatorTests.swift`
- `KeyboardUI/Sources/Views/CheatEffectOverlay.swift` (`CheatEffectController` + `CheatEffectOverlay`)

### 2. Keyboard extension
**`KeyboardExtension/Sources/KeyboardViewController.swift`:**
- Smazat: `cheatEffect` property, `cheatCodeActivator`, `cheatCodeHandled` (props ~58–66), volání `detectCheatCode()` v `textDidChange` (~309), celou sekci `// MARK: - cheat code` (`detectCheatCode()`, `handleCheatCode()`, `playCheatCelebration()`, ~312–363), a `cheatEffect:` argument v `makeRoot(...)` (~589).
- Komentář ~203 „A Welcome/cheat code grant …" → „A Welcome grant …". `.promoPlusExpiresAt` observer **nechat** (Welcome live unlock).
- ⚠️ Ověřit, jestli `import AudioToolbox` / `AudioServicesPlaySystemSound` nepoužívá ještě key-click zvuk; pokud ano, import **nechat**.

**`KeyboardExtension/Sources/KeyboardRoot.swift`:**
- Smazat `cheatEffect` property (~21), `.overlay { CheatEffectOverlay(controller: cheatEffect) }` (~60) a odpovídající init parametr.

### 3. `PromoTrialStore` (`KeymojiCore/Sources/Shared/PromoTrialStore.swift`)
- `PromoTrialRecord`: smazat pole `cheatCodeConsumed` + jeho init parametr; přepsat doc komentář („both free-Plus grants" → „the Welcome trial").
- `PromoTrialStoring`: smazat `consumeCheatCode(now:)` z protokolu i z `PromoTrialStore`.
- Smazat `static var cheatCodeGrantDays`.
- **Zploštit matiku:** smazat `public static func nextExpiry(...)` a generický `private func consume(...)`; `consumeWelcome` přepsat na přímý body: idempotence guard na `welcomeConsumed` → jinak `expiry = now + welcomeGrantDays.days`, `welcomeConsumed = true`, `persist` (zachovat „nil když durable write selže" — review finding #3).
- **Nechat:** `welcomeGrantDays`, `record`, `isPromoActive`, `KeychainPromoBacking`, `promoKeychainGroupName`, runtime team-prefix, `makeShared()`, `debugWrite` (DEBUG).

### 4. Sdílené VM — reálná logická změna (1 řádek)
- `Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift:76` (`hasConsumedAnyTrial`): `record.welcomeConsumed || record.cheatCodeConsumed` → `record.welcomeConsumed`.

### 5. Debug menu (`Features/Debug/`)
**`DebugMenuViewModel.swift`:** smazat published `cheatCodeConsumed` (~47), `resetCheatCode()` (~110–115), readout `cheatCodeConsumed` v `refresh()` (~150). Přepsat komentář `resetGift()` (~98–100) i class-doc (~21) z „dva granty se stackují / cheat code" na jeden Welcome grant.
**`DebugMenuView.swift`:** smazat řádek `row("Cheat code consumed", …)` (~42) a `Button("Reset cheat code", …)` (~75). Nechat `Reset gift (Welcome)`, `forceFreeTier`, `expireTrialNow`.

### 6. Komentáře (jen wording, význam zůstává — vyhodit „/cheat code")
- `Features/Onboarding/Sources/OnboardingDependencies.swift` (~55, 63)
- `Features/Settings/Sources/SettingsViewModel.swift` (~22, 125, 143, 187)
- `Features/Onboarding/Sources/OnboardingView.swift` (~233)
- `Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift` (~60, 62)
- `KeyboardCore/Sources/Models/KeyboardState.swift` (~82)

### 7. Lokalizace
- `KeymojiResources/Resources/en.lproj/Localizable.strings`: smazat `promo.cheatCode.unlocked` / `.extended` / `.alreadyUsed` / `.alreadyHavePlus` (~140–143). Přegenerovat `L10n` (`L10n.Promo.CheatCode.*` zmizí — ověřit, že nikde nezůstal referenc).

### 8. SPM / Tuist (ConfettiSwiftUI pryč)
- `Tuist/Package.swift`: smazat `ConfettiSwiftUI` package entry (~24).
- `Tuist/ProjectDescriptionHelpers/Targets/KeyboardUI.swift:16`: smazat `.external(name: "ConfettiSwiftUI")`.
- `tuist generate` → regenerovat projekt.

### 9. Testy (smazat cheat/stacking scénáře)
- `KeymojiCore/Tests/PromoTrialStoreTests.swift`: smazat `cheatCodeConsumed` asserty, `nextExpiry_*` (3 testy ~43–59), `consumeCheatCode_*` (~84–97), stacking testy (~101–120). Welcome testy nechat (idempotence + „fresh → now+30").
- `Features/Settings/Tests/SettingsViewModelTests.swift`: smazat `testActiveCheatCode_welcomeNeverTaken_…` (~110) a `testExpiredCheatCode_welcomeNeverTaken_…` (~120) — fabrikovaly stav, co po removalu nevznikne.

### 10. Outward-facing docs
- `fastlane/metadata/review_information/notes.txt`: vyříznout HESOYAM větu (~5), větu o veřejném opt-in Welcome trialu **nechat**.
- `marketing/privacy-policy.html`: **beze změny** (záměrně — Keychain promo záznam platí dál pro Welcome).

### 11. Doménová dokumentace
- `CONTEXT.md`: smazat termín **„HESOYAM promo bonus"**; přepsat **„Plus trial expiry"** („shared by Welcome + HESOYAM, both extend via `max` rule" → „jediný `Date?`, nastavený Welcome Plus trialem na `now + 30d`"). „Effective Plus" a „Welcome Plus trial" **nechat** (definice jsou source-agnostické).
- `docs/adr/0001-opt-in-welcome-plus-trial.md`: přidat datovanou **„Superseded / Update (2026-06-20)"** sekci — HESOYAM odstraněn, důvod (nešel spolehlivě odpálit on-device — `textDidChange` coalescing, revert log; nikdy ověřen funkční; Welcome pokrývá akvizici sám), „stacking retired".
- `tasks/README.md`: přidat řádek `70` pod „Monetizace"; u řádku `64` poznamenat „(HESOYAM půlka zrušena taskem 70)". Přegenerovat dashboard (`python3 scripts/generate_dashboard.py`).

## Co MUSÍ zůstat (deletion guardrail)

Welcome Plus trial jezdí po stejné páteři — **nesmazat omylem**:

- `effectiveIsPlus(...)` ([EffectiveEntitlement.swift](../KeymojiCore/Sources/Shared/EffectiveEntitlement.swift)) + všech 5 gating sites.
- `PromoTrialStore` / `PromoTrialStoring` / `PromoTrialRecord` (zúžený) / Keychain backing / `promoKeychainGroupName` / runtime team-prefix.
- `WelcomeTrialActivating` / `WelcomeTrialActivator`.
- `AppGroupStore.promoPlusExpiresAt` + `case promoPlusExpiresAt` v `AppGroupStoreKey` + `.promoPlusExpiresAt` notifier kanál.
- `PromoTrialReconciliation` (launch Keychain ↔ App Group).
- Settings `PlusRowState` (S1–S4) + onboarding welcome banner + loss-aversion editor banner + `.afterTrial` paywall + `paywall.headline.afterTrial` + `welcome.*` lokalizace.
- Debug: `forceFreeTier`, `resetGift()`, `expireTrialNow()`.

## Hotovo když

- Žádný `CheatCode*` symbol, `hesoyam` literál (mimo historické doc — task 64/CONTEXT/ADR/notes-historie), ani `ConfettiSwiftUI` reference nezůstaly ve zdrojácích (`grep -ri "cheat\|hesoyam\|confetti" --include=*.swift` čistý mimo `SlackEmojiTable` `confetti_ball` shortcode).
- Napsání `hesoyam` na klávesnici **nedělá nic** (žádná detekce, žádný efekt, text se chová jako jakýkoli jiný).
- **Welcome dál funguje:** onboarding „🎁 Aktivovat dárek" → grid se odemkne; Settings S2→S3→S4; expirace → loss-aversion + `.afterTrial`; klávesnice live unlock přes notifier.
- `PromoTrialRecord` nemá `cheatCodeConsumed`; `consumeWelcome` dává `now + 30d`; `nextExpiry`/stacking pryč.
- ConfettiSwiftUI není v `Package.swift` ani v target dependencies; `tuist generate` projde.
- Build **app + extension zelený**; testy zelené (KeymojiCore / KeyboardCore / Settings / FavoriteEmojisEditor / Onboarding / Paywall) — cheat/stacking testy odebrané, zbytek prochází.
- `notes.txt` bez HESOYAM; `CONTEXT.md` bez termínu HESOYAM + přepsaný „Plus trial expiry"; `ADR 0001` má Superseded sekci; README + dashboard aktualizované.

## Rizika

- **Omylem useknout Welcome.** Hlavní riziko removalu — páteř je sdílená. Mitigace: „Co MUSÍ zůstat" checklist výše + po removalu projet Welcome flow (onboarding/Settings/expirace) přes [debug menu (67)](67-debug-menu-simulate-free-user.md).
- **Zapomenutý referenc na `L10n.Promo.CheatCode.*`** → build error. Mitigace: smazat stringy a `grep` před přegenerováním L10n.
- **`AudioToolbox` import** v `KeyboardViewController` — pokud ho `playCheatCelebration` měl jen pro sebe, smazat; jestli ho používá key-click sound, nechat. Ověřit, ne slepě mazat.
- **`tuist generate` po vyhození ConfettiSwiftUI** — extension target nesmí zůstat viset na chybějícím modulu. Build celého workspace (`xcodebuild -workspace`, NE `-project`) potvrdí.

## Codex review

**Ano (lehký)** — removal se dotýká sdílené entitlement páteře (`PromoTrialStore`, `effectiveIsPlus` konzumenti) a cross-process notifieru. Codex má ověřit hlavně **že Welcome cesta zůstala kompletní** (žádný gating site neosiřel, notifier kanál + reconciliace netknuté) a že nezůstal mrtvý referenc. Spustit `codex exec --full-auto` / `/codex-review` na diff před closing commitem.
