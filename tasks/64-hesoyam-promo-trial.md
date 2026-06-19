# 64 — Welcome Plus trial (opt-in) + HESOYAM promo bonus

**Status:** Done — 2026-06-19 (vše implementováno + build/testy zelené; **device tuning HESOYAM efektu + on-device ověření přes [debug menu task 67](67-debug-menu-simulate-free-user.md) zbývá**)

## ✅ Fáze 3 — HESOYAM půlka (Scope 9, 10, 11, 13, 14 + privacy, 2026-06-19)

Poslední (device-dependentní) půlka. Build app+extension zelený (ConfettiSwiftUI linkuje pod `APPLICATION_EXTENSION_API_ONLY`, ověřeno extension-safe — žádné UIScreen/UIApplication); KeymojiCore 82 + KeyboardCore 374 testů.

- **Scope 9 — `CheatCodeDetector`** (KeyboardCore, pure): **window match** v posledních `code.count+10` znacích (NE strict suffix — revert log #1) + 10 testů. Flow v `KeyboardViewController.detectCheatCode()` v `textDidChange`: secure-field guard, **debounce** (`cheatCodeHandled`, fírne 1× per occurrence, re-arm po opuštění okna), **text nemaže** (viralní artefakt).
- **Scope 10 — `HesoyamActivating`** (KeymojiCore, bez PurchaseServicing — paid čte z `AppGroupStore.isPlus` mirroru): `.granted(wasExtension:)` / `.alreadyHavePaidPlus` (efekt, no consume) / `.alreadyUsed` (no efekt) + 6 testů.
- **Scope 11 — `CheatEffectOverlay` + `CheatEffectController`** (KeyboardUI, ConfettiSwiftUI): reference-type controller přežije root rebuildy; confetti + banner (granted/alreadyHavePlus) vs. tichý toast (alreadyUsed); `.allowsHitTesting(false)`. Haptika+chime gated v controlleru (`playCheatCelebration`, isolated, device-tune). **Žádné Rockstar assety.**
- **Scope 13** — review notes (`fastlane/.../notes.txt`) rozšířeny o HESOYAM + welcome disclosure. **Scope 14** — `promo.hesoyam.*` lokalizace.
- **Privacy** — `marketing/privacy-policy.html` opraveno: přiznán on-device Keychain promo záznam (řešilo fázi-1 Codex nález); odstraněn už nepravdivý „no network requests" claim (StoreKit IAP).
- **Bit-exact mirror fix:** `AppGroupStore.promoPlusExpiresAt` přešel z `timeIntervalSince1970` na `timeIntervalSinceReferenceDate` — round-trip `Date` teď přesný (velký konstantní offset jinak shazoval low bits → flaky equality).

**Codex (closing):** 1 nález (P2) — `ConfettiCannon(hapticFeedback:)` defaultně `true`, obcházel by `hapticFeedbackEnabled` + dubloval controller haptiku → **applied** `hapticFeedback: false`.

**Co ještě reálně chybí (mimo kód):** doladit choreografii confetti/chime na zařízení (Scope 11 záměrně neladěno v kódu) a projet celé QA přes debug menu (task 67). HESOYAM efekt (cesta „already have Plus") jde ověřit na zařízení i s reálným Plus hned teď.

### 🔤 Codename neutralizace (2026-06-19)

Aby šlo tajné slovo měnit na jednom místě (a kód nebyl pojmenovaný po konkrétním slově), přejmenováno kódové jméno `Hesoyam*` → **`CheatCode*`** (case-sensitive: `CheatCodeActivating`/`Activator`/`Outcome`, `cheatCodeConsumed`, `consumeCheatCode`, `cheatCodeGrantDays`, `promo.cheatCode.*`, soubory `CheatCodeActivating.swift`/`CheatCodeActivatorTests.swift`). Komentáře zneutralizované, testy detektoru odvozují fixtures z `CheatCodeDetector.code`. **Jediný výskyt literálu „hesoyam" ve Swift kódu = `CheatCodeDetector.code`** (single source of truth; změna keywordu = 1 edit). Reálné slovo dál žije v review notes (Apple ho potřebuje) a historických doc (task/ADR/CONTEXT — marketing/domain term „HESOYAM promo bonus" záměrně ponechán). Build + KeymojiCore/KeyboardCore/Settings/FavoriteEmojisEditor testy zelené po renamu.

### 🔑 Keychain access group — bez hardcoded team ID (2026-06-19)
Team ID už není v žádném zdrojáku: entitlement používá `$(AppIdentifierPrefix)com.freedommartin.keymoji.shared` (codesign team-prefixne při podpisu); `KeychainPromoBacking` zjišťuje team prefix **za běhu** z keychainu (probe item → `kSecAttrAccessGroup`). Team ID žije jen v `Project.swift` `DEVELOPMENT_TEAM` + `fastlane/Appfile`. Ověřeno: app se instaluje+spouští na simu s `$(AppIdentifierPrefix)` entitlementem.

### 🔍 Externí code review (2026-06-19)
3 nálezy, adversariálně ověřeno workflow (3 agenti):
- **#1 Onboarding truncation (P1)** — potvrzeno reálné = **[task 68](68-onboarding-rerun-truncates-favorites.md)**. Vědomě **ponecháno jako samostatný task** (ne v této větvi).
- **#3 Keychain durability (P2) — OPRAVENO.** `PromoTrialKeychainBacking.set` → `throws`; `consume*` → `Date?` (nil když durable zápis selže); aktivátory publikují grant + mirror + notify **jen po úspěšném zápisu** (`CheatCodeOutcome.couldNotPersist` nový case → klávesnice tiše neoslaví). 5 in-memory backingů + testy aktualizované; přidán failure-path test. Premise-independent.
- **#2 Full Access consume (P2) — ODLOŽENO na device-verify.** Premisa (klávesnice bez Full Access má App Group read-only → keyboard-side zápisy tiše no-opnou) je **device-only ověřitelná** a agent ji nepotvrdil na iOS 26 (aktuální Apple doc nenačtena). **Pokud platí, je to app-wide problém** (recents/favorites/usage/word-learning + privacy-policy claim), ne jen HESOYAM. Reconciliace na host-launchi HESOYAM částečně self-healuje. **Akce: na zařízení ověřit, jestli keyboard App Group zápisy přežijou s Full Access OFF** (instalace bez Full Access → psát → zkontrolovat recents/favorites). Ten jeden test rozhodne #2 i app-wide otázku. Pak teprve řešit (gate na `hasFullAccess` / oprava / úprava privacy policy). Zvážit samostatný task.

## ✅ Fáze 2d — picker selectionLimit + loss-aversion (Scope 7 + 12 + 8-editor, 2026-06-19)

Tímto je **host-app Welcome trial vertikála kompletní** (vše simulátor-ověřeno).

- **Scope 7 — `EmojiCatalogPickerView.selectionLimit: Int? = nil`** (additive): cap → unselected cells `.opacity(0.35)` + `.disabled`. Onboarding „Browse all emoji" tlačítko pod gridem → sheet s pickerem (`selectionLimit: viewModel.favoritesLimit`). Settings editor sheet zůstává bez capu (paywall přes onToggle). Onboarding feature dostal dep na `emojiCatalogPicker`.
- **Scope 12 — loss-aversion banner** v editoru: `showLossAversionBanner` (!effectiveIsPlus && hasConsumedAnyTrial && favorites > cap) → banner „Your Plus trial ended — your N extra favorites are saved" (plurál stringsdict) → paywall `.afterTrial`. Potlačí generický upsell row. `FavoriteEmojisEditorViewModel` dostal `promoStore`.
- **Scope 8 (editor) — `.afterTrial` routing:** `toggle()` past cap → `.afterTrial` když `hasConsumedAnyTrial`, jinak `.favoritesLimit`.
- **Testy:** FavoriteEmojisEditor 24 (3 nové loss-aversion VM + 1 nový snapshot, vizuálně ověřený) · Onboarding 21 (browse-all v 5 re-recorded snapshotech).

### Stav celé host-app welcome půlky (vše zelené, simulátor-ověřeno)
Scope 4 (gating 5 sites) · 5 (onboarding banner) · 6 (Settings PlusRowState S1–S4 + confirm + toast) · 7 (picker) · 8 (.afterTrial + editor) · 10 (WelcomeTrialActivating) · 12 (loss-aversion) · launch reconciliace · lokalizace (welcome/trial/loss-aversion + plurály). Testy: KeymojiCore 77 · KeyboardCore 366 · Onboarding 21 · Settings 14 · Paywall 18 · FavoriteEmojisEditor 24.

**Zbývá (device-only HESOYAM půlka):** Scope 9 `CheatCodeDetector` (window match) + flow v `KeyboardViewController` (secure guard, debounce, text nemazat) · `HesoyamActivating` (extension, bez PurchaseServicing) · Scope 11 `CheatEffectOverlay` (ConfettiSwiftUI dep → KeyboardUI) · Scope 13 review notes · privacy-policy.html keychain update.

## ✅ Fáze 2c — onboarding welcome banner (Scope 5, 2026-06-19)

Banner nad gridem v pick-favorites kroku. Zelený build + **Onboarding 21 testů** (11 snapshot vč. 2 nových welcome stavů + 10 VM vč. nového activate testu). Banner snapshoty vizuálně ověřeny (offer button + „Plus active until {date}" success card s 8 vybranými = odemčený cap).

- **`OnboardingPreferencesProviding`** rozšířeno: `canShowWelcomeOffer` (!paid && !welcomeConsumed && !trialActive), `welcomeTrialActiveUntil`, `@MainActor activateWelcomeTrial()` (konstruuje `WelcomeTrialActivator` se sdíleným promoStore inline → bez stored @MainActor existential).
- **`OnboardingViewModel`:** `favoritesLimit` z `let` → observable `private(set) var` + `canShowWelcomeOffer`/`welcomeTrialActiveUntil` observable; `refreshEntitlement()` (init + po activate) → grid se odemkne **in place** (cap 6 → `.max`); `activateWelcomeTrial()` deleguje + refresh.
- **`OnboardingView`:** `welcomeBanner` v pickFavoritesStep — paid/expired-consumed → skrytý; trial aktivní → read-only „🎁 Plus active until {date}"; welcome dostupný → tlačítko „🎁 Activate your gift…" (`withAnimation` → grid un-dim + banner morph).
- **Lokalizace:** `welcome.onboarding.cta`, `welcome.onboarding.activeUntil`.
- Mocky + spy (`FavoritesPreferencesSpy` modeluje effective isPlus) aktualizované.

**Device test (onboarding):** Settings → Setup instructions (nebo fresh install) → pick-favorites krok → „🎁 Activate your gift" → grid se odemkne (>6 výběr) + banner „Plus active until {date}".

**Zbývá:** Scope 7 picker `selectionLimit` + onboarding „Browse all" sheet · Scope 12 loss-aversion downgrade banner v editoru · pak device-only HESOYAM (Scope 9, 11, HesoyamActivating, confetti).



## ✅ Fáze 2b — Settings welcome řádek (Scope 6, 2026-06-19)

První **tap-testovatelný surface**. Zelený build + Settings 14 testů (8 nových state-machine + 6 snapshot).

- **`PlusRowState`** (S1 `.paid` / S2 `.welcomeAvailable` / S3 `.trialActive(daysLeft:)` / S4 `.afterTrial`) v `SettingsViewModel`. Precedence: paid > active trial > welcomeConsumed?afterTrial:welcomeAvailable. HESOYAM-only expired (welcome netknutý) → stále S2 (welcome se nabízí dál).
- **VM reaktivita:** observable mirrors `promoExpiresAt`/`welcomeConsumed`, seed v initu + observer `.promoPlusExpiresAt` (HESOYAM grant z klávesnice za běhu) → row live. `activateWelcomeTrial()` deleguje na `WelcomeTrialActivating` + recompute. `trialActiveUntil` pro toast.
- **View:** 4-stavový řádek; S2 → **confirm alert** („Activate a free month of Plus? … aktivovat jde jen jednou") → activate → S3 + **toast** „Plus active until {date}" (3s); S4 → paywall `.afterTrial`.
- **Lokalizace:** `welcome.settings.*` + `settings.plus.trialDaysLeft` s **plurály přes `Localizable.stringsdict`** (Tuist accessor ze `.strings`, runtime plural ze stringsdict; ověřeno `tr()` přes `Bundle.module.localizedString`).
- **8 unit testů** state machine (real VM + in-memory backing + PurchaseServiceMock): welcomeAvailable/paid/activate→trialActive(30)/idempotence/paid no-op/expiredWelcome→afterTrial/activeHesoyam→trialActive/expiredHesoyam→welcomeAvailable.

**Device test (Settings welcome):** Settings → „🎁 Activate a free month of Plus" → confirm → řádek „Keymoji Plus trial — 30 days left" + toast → klávesnice odemkne neomezené favorites live (notifier).

**Zbývá:** Scope 5 onboarding welcome banner + „Procházet všechny" · Scope 7 picker `selectionLimit` · Scope 12 loss-aversion downgrade banner v editoru · onboarding welcome lokalizace + snapshoty · pak device-only HESOYAM (Scope 9, 11, HesoyamActivating, confetti).



## ✅ Fáze 2a — gating core + use case + reconciliace (2026-06-19)

Sdílené jádro, na kterém staví všechny surfaces. **Bezpečná no-op migrace** (promo expiry je nil dokud
nevznikne grant), plně ověřeno: zelený build app+extension + KeymojiCore 77 · KeyboardCore 366 ·
FavoriteEmojisEditor 20 · Settings 6 · Paywall 18 testů; app se instaluje + spouští na simu.

- **Scope 4 — gating migrace na `effectiveIsPlus` (všech 5 sites):** FavoriteEmojisEditorVM (`isPlus` + sortMode fallback) · OnboardingPreferences.isPlus · SettingsVM.isPlus · PaywallVM.isPlus (+ inject `store`) · KeyboardState (`promoPlusExpiresAt` mirror + `effectiveIsPlus` computed; clamp + favorite-add gate; `KeyboardViewController` čte mirror v `refreshFromStore` + observuje `.promoPlusExpiresAt`). `PurchaseService.isPlus` + `AppGroupStore.isPlus` zůstávají **paid-only**.
- **Scope 8 — `.afterTrial`** PaywallContext + headline „You loved Plus. Get it back." (`paywall.headlineAfterTrial`).
- **Scope 10 — `WelcomeTrialActivating`** use case ([WelcomeTrialActivating.swift](../KeymojiCore/Sources/Shared/WelcomeTrialActivating.swift)): paid guard → idempotent welcomeConsumed guard → consume → App Group mirror → notify. + `makeShared()` factory + 4 testy. (HesoyamActivating = fáze HESOYAM.)
- **Launch reconciliace** ([PromoTrialReconciliation.swift](../KeymojiCore/Sources/Shared/PromoTrialReconciliation.swift)): App Group ← Keychain master při startu (přežije reinstal); tolerant compare (1s) proti float driftu epoch-string round-tripu; wired v `KeymojiApp` `didFinishLaunching`.

**Pozn. reaktivita:** host VM počítají effective z `store.promoPlusExpiresAt` on-read (ne `@Observable`-tracked) → grant během otevřené obrazovky se projeví až na next appear. Klávesnice je výjimka — má skutečný mirror + notifier observer (live unlock). Surfaces (onboarding/Settings), kde aktivace probíhá v daném VM, si recompute řeší samy (fáze 2b).

**Zbývá:** Scope 5 welcome onboarding banner · Scope 6 Settings PlusRowState (S1–S4) + confirm alert + toast · Scope 7 picker `selectionLimit` · Scope 12 loss-aversion downgrade banner · Scope 14 welcome/trial lokalizace (plurály) + snapshoty · pak device-only HESOYAM (Scope 9, 11, HesoyamActivating, confetti).

---



## ✅ Fáze 1 — foundation (2026-06-19, větev `feature/64-hesoyam-promo-trial`)

Postaveno **verifikovatelné jádro** (zelený build app+extension + 73 KeymojiCore testů), checkpoint
před UI surfaces dle dohody (foundation-first):

- **`effectiveIsPlus(paid:promoExpiresAt:now:)`** — čistá funkce ([EffectiveEntitlement.swift](../KeymojiCore/Sources/Shared/EffectiveEntitlement.swift)) + 5 testů. **Zatím nikým nevoláno** — migrace ~5 gating sites (Scope 4) je fáze 2.
- **`PromoTrialStore`** (Keychain) — `PromoTrialRecord` + `PromoTrialStoring` + `nextExpiry` stacking math + idempotentní `consumeWelcome`/`consumeHesoyam` + injektovatelný backing (testy bez entitlements) + `KeychainPromoBacking` (KeychainAccess) + 12 testů. ([PromoTrialStore.swift](../KeymojiCore/Sources/Shared/PromoTrialStore.swift))
- **`AppGroupStore.promoPlusExpiresAt: Date?`** (epoch-string serial.) + `case promoPlusExpiresAt` v `AppGroupStoreKey` (→ `.promoPlusExpiresAt` notifier kanál zdarma) + 3 testy.
- **SPM:** KeychainAccess → KeymojiCore. **ConfettiSwiftUI vědomě odloženo** na fázi efektu (nepřidávat nepoužitý dep do extension-only KeyboardUI buildu předem).
- **Entitlements:** `keychain-access-groups` na host i extension přes **`$(AppIdentifierPrefix)com.freedommartin.keymoji.shared`** (codesign team-prefixne při podpisu — žádný hardcoded team ID). Group name `com.freedommartin.keymoji.shared` v `Constants.swift` ↔ `promoKeychainGroupName` v KeymojiCore; team prefix `KeychainPromoBacking` **zjišťuje za běhu** z keychainu (probe), takže team ID není v žádném zdrojáku (jen v `Project.swift` `DEVELOPMENT_TEAM`).

**Zbývá (fáze 2+):** Scope 4 gating migrace · Scope 5–6 welcome onboarding+Settings · Scope 7 picker `selectionLimit` · Scope 8 `.afterTrial` paywall · Scope 9–11 HESOYAM detekce+flow+confetti overlay · Scope 10 use cases · Scope 12 loss-aversion downgrade · host-app launch reconciliace App Group ↔ Keychain · Scope 13 review notes · Scope 14 lokalizace · zbylé testy + snapshoty.

**Codex (fáze 1):** 2 nálezy (P2). (1) „gates ještě nečtou effectiveIsPlus" — **fáze 2 dle plánu, ne bug.** (2) **`marketing/privacy-policy.html:344`** tvrdí „does not use Full Access for … keychain access" — s promo Keychainem to bude nepřesné; runtime nepřesné teprve až přibude aktivační surface. **Vyřešit ve fázi completion** (vedle Scope 13 review notes) — vyžaduje produktové/právní rozhodnutí o formulaci.

---

**Priorita:** v1.x (po/se [taskem 63](63-monetization-keymoji-plus.md)) · **Úsilí:** L–XL · **Dopad:** High (akvizice + konverze + discoverability)

**Závisí na:** [63 — Keymoji Plus](63-monetization-keymoji-plus.md) (entitlement infra, paywall, downgrade fallback, free favorites limit). Bez 63 nedává smysl.

**Související rozhodnutí:** [ADR 0001 — Opt-in Welcome Plus trial](../docs/adr/0001-opt-in-welcome-plus-trial.md) — vědomě otáčí 63/64 zamítnutí forced/app-implemented trialu.

## ⚠️ Log z 1. pokusu — NEDOKONČENO, vráceno (2026-06-15)

> Pozn.: 1. pokus pokrýval **jen HESOYAM** (welcome trial v původním zadání neexistoval). Poučení
> z revertu níže ale platí i pro tuhle rozšířenou verzi — zejména detekce HESOYAM a styl práce.

Zkusili jsme celý task naimplementovat (detekce, Keychain perzistence, `effectiveIsPlus`
plumbing, ConfettiSwiftUI efekt, loss-aversion banner, countdown v Settings, paywall
headline, lokalizace, testy). **Všechno se zbuildilo a všechny unit testy prošly, ALE na
zařízení to nefungovalo** — napsání „hesoyam" neudělalo vůbec nic. Změny jsme vrátili
(`git reset --hard`, větev smazána). Zjištění, ať jsme příště rychlejší:

1. **Root cause: `textDidChange` v extension neslučuje 1:1 se znaky.** Při psaní (a hlavně
   při vkládání přes návrhy) buffer skočí v jednom callbacku třeba z „heso" rovnou na
   „hesoyam h" — klávesnice tedy skoro nikdy nevidí buffer končící **přesně** na „hesoyam".
   Detekce přes `hasSuffix("hesoyam")` proto reálné aktivace míjela. (Ověřeno on-device:
   po ~18 napsaných znacích jen ~4 volání detekce; kontext byl „hesoyam h", `match=false`.)
   → Detekovat přes **okno na konci bufferu** (`contains` v posledních ~17 znacích, snese
   pár trailing znaků), ne striktní suffix. **Tahle verze už to má v Rozhodnutí + Scope 9.**

2. **`documentContextBeforeInput` funguje** — v debug proužku jsme „hesoyam" reálně viděli.
   Dostupnost kontextu NENÍ problém (obava v Rizicích je lichá).

3. **Efekt (ConfettiSwiftUI overlay + banner) jsme NIKDY neviděli** — protože detekce
   nefírovala, overlay se nespustil. Jestli konfety/banner reálně fungují, je **pořád
   neznámé**. Příště ověřit efekt samostatně a brzy (ne ho stavět naslepo).

4. **Jak debugovat extension:** Xcode konzole NEukazuje logy z extension, když pustíš
   host-app scheme (debugger visí na appce, ne na extension). Co fungovalo a použít hned
   příště: **vykreslit debug stav přímo na klávesnici** (dočasný proužek se živým
   `documentContextBeforeInput` + match stavem). Tahle technika dovedla k root cause.

5. **Meta-lekce (nejdůležitější):** zelené unit testy ≠ funguje na zařízení, u klávesnice
   obzvlášť. Stavět **inkrementálně a ověřovat běh na telefonu po každém kroku**. Nejdřív
   rozchodit jádro (detekce → efekt) na zařízení, teprve pak Keychain / paywall / zbytek.
   Tady se postavila celá featura proti zeleným testům a ověřovalo se až nakonec = chyba.

6. **Co bylo OK k převzetí:** `effectiveIsPlus` (paid OR aktivní promo) protažený přes
   editor/settings/onboarding/keyboard clamp; Keychain shared-access-group + ConfettiSwiftUI
   (ověřeno extension-safe: žádné `UIApplication`/`UIScreen`) + KeychainAccess wiring se
   zbuildilo. Persistence přes reinstal neověřena.

7. **Drobnosti:** chime byl jen tipnutý placeholder (system sound `1025`), nikdy neslyšený ·
   build pouštět přes `xcodebuild -workspace`, NE `-project` (Tuist dává externí SPM do
   workspace, jinak „Unable to find module dependency") · simulátory tu jsou iPhone 17 /
   iOS 26.2 · `Paywall_Tests/testPaywall_loadingPrice_dark` padá i na čistém `main`
   (animovaný spinner snapshot, env-citlivý — nesouvisí s tímhle taskem).

## Cíl

Dvě komplementární cesty, jak userovi dát Plus zadarmo bez vnucení — obě konzumovatelné per-device,
**stackující do jednoho `promoPlusExpiresAt`**, obě s graceful downgrade po expiraci:

1. **Welcome Plus trial** — **opt-in** 30denní Plus, nabízený jako *dárek* v onboardingu (krok
   pick-favorites) a v Settings (řádek S2 dokud nespotřebovaný). Aktivace je explicitní stisk
   tlačítka (onboarding) nebo confirm alert (Settings).
2. **HESOYAM promo bonus** — skrytý cheat (napsání `hesoyam` na klávesnici, kdekoli mimo secure
   pole) → **+60 dní** Plus, stackující na stejný expiry. Pocta GTA: San Andreas, viralní artefakt.

Po expiraci graceful downgrade (favorites zachované, schované nad cap; loss-aversion banner v editoru;
Settings se vrátí k paywallu). Žádné push notifikace (drží duch 64 — discovery-driven, žádný permission
prompt).

## Business & psychologie

### Welcome Plus trial (opt-in)

Vědomé otočení původního zafixovaného „žádný forced/app-implemented trial" pravidla z 63/64. Viz
[ADR 0001](../docs/adr/0001-opt-in-welcome-plus-trial.md) pro plné odůvodnění; tady jen TL;DR:

- **Opt-in zachovává self-selection** — totéž, co dělalo HESOYAM přijatelným v původním 64.
  Forced-trial fear (plošný drop → resentment → 1★) nepřichází ke slovu: drop zažije jen ten, kdo
  si dárek aktivně vzal.
- **Discoverability** — HESOYAM sám stojí na word-of-mouth a tom, že je cheat dohledatelný.
  Netechničtí useři se k němu nikdy nedostanou. Welcome dává **každému** trvale viditelný vstupní
  bod (Settings S2 dokud nespotřebovaný).
- **Endowment** — uvítací měsíc s odemčeným gridem v onboardingu = user si nastaví víc oblíbených,
  zvykne si → po expiraci spadne na 6 → cítí ztrátu → paywall (`.afterTrial` headline „You loved
  Plus. Get it back."). Učebnicová loss-aversion v opt-in obálce.
- **Framing = dárek, ne free trial.** UI **nikdy** neříká „free trial" (asociace „pak budeš platit
  / dali ti kreditku?"); říká „🎁 měsíc Plus zdarma". Aktivace je explicit consent, ne dark pattern.

### HESOYAM promo bonus

Není to skutečné tajemství — je to **plošný, jednorázový, časově omezený Plus bonus pro všechny**,
zabalený do „cheat code" obálky, který má **působit exkluzivně** a **šířit se organicky**
(word-of-mouth, sociální sítě). Akceptováno, že je dohledatelný.

**Proč to dává smysl i vedle welcome trialu:**

- **Stacking** = HESOYAM nikdy nevyjde naprázdno. Aktivoval sis welcome? HESOYAM přidá další dva
  měsíce navrch. Nikdy nevyužil welcome? HESOYAM ti začne dva měsíce od teď. Vždy hodnotný.
- **Viralní artefakt** = napsané „HESOYAM" zůstává v textu stát (nemažeme ho) → kamarád v chatu to
  uvidí, zeptá se „co to je?" → organické šíření. Welcome se virálně nešíří, HESOYAM ano.
- **Doplňková konverze cesta** pro lidi, co welcome v onboardingu přeskočili a do Settings se
  nedostanou.

## Rozhodnutí (zafixovaná, neřešit znovu)

| Téma | Rozhodnutí |
|---|---|
| Welcome typ | **Opt-in** dárek (viz [ADR 0001](../docs/adr/0001-opt-in-welcome-plus-trial.md)) — žádný forced trial |
| Welcome délka | **+30 dní** od aktivace, jednou per-device |
| Welcome surfaces | Onboarding (pick-favorites banner) + Settings S2 řádek **dokud nespotřebováno** |
| Welcome onboarding UX | Tlačítko **„🎁 Aktivovat dárek"** v banneru nad gridem; žádný confirm (kontext je explicitní). Po stisku banner přemorfuje na success state, grid se odemkne |
| Welcome Settings UX | Řádek S2 „🎁 Aktivovat měsíc Plus zdarma" → tap → **confirm alert** („Aktivovat? Jednou."). Po stisku řádek S3 + krátký toast |
| Welcome efekt | **Tichý** — žádné konfety. Payoff = vizuální odemčení gridu / row přepnutí |
| HESOYAM délka | **+60 dní**, jednou per-device |
| HESOYAM detekce | **Window match** v posledních ~17 znacích `documentContextBeforeInput` (case-insensitive `contains`), **NE strict suffix** (viz revert log #1) |
| HESOYAM efekt | Konfety + banner; text reflektuje stacking: „Plus extended — now until {date}" nebo „Plus unlocked — 60 days" |
| HESOYAM text v poli | **Nechat stát** (nemazat) — viralní artefakt |
| Sčítací matika | `expiry = max(now, currentExpiry ?? now) + grantDays`. Jeden vzorec pro oba granty |
| Persistence | **Keychain** sdílený access-group: `{ welcomeConsumed: Bool, hesoyamConsumed: Bool, expiresAt: Date? }`. App Group zrcadlí `promoPlusExpiresAt` pro hot path |
| Effective Plus | `effectiveIsPlus(paid, promoExpiresAt, now)` — `paid` zůstává `AppGroupStore.isPlus` (StoreKit truth source), promo žije vedle |
| Secure fields | HESOYAM **nikdy nefíruje** v password/secure polích |
| Re-fire po consume | Toast „Already used 🔒", žádný efekt, žádný grant |
| Notifikace expirace | **Žádné** (žádný permission prompt) — discovery-driven |
| Anti-abuse | Per-device, leak vědomě akceptován |
| Knihovny | **KeychainAccess** (kishikawakatsumi), **ConfettiSwiftUI** (simibac) — jen pro HESOYAM |

## Architektura

**Effective Plus** — čistá funkce, sdílená, testovatelná, **jediný správný gating call**:

```swift
public func effectiveIsPlus(paid: Bool, promoExpiresAt: Date?, now: Date) -> Bool {
    if paid { return true }
    if let expiry = promoExpiresAt, now < expiry { return true }
    return false
}
```

Použít všude, kde dnes čte `AppGroupStore.isPlus` pro **gating** (viz Scope 4 — 5 sites).
`AppGroupStore.isPlus` **zůstává paid-only** (čistý StoreKit truth source, nikdy přepsaný promo).

**Zdroje pravdy (tři, záměrně):**

- **`AppGroupStore.isPlus`** = jen placené (dnešní semantika, nezahrabaný StoreKit zdroj). Nedotýkat se.
- **`AppGroupStore.promoPlusExpiresAt: Date?`** = levné zrcadlo pro klávesnici a UI (čte se v gating
  hot path, stejně jako `isPlus`).
- **Keychain (sdílený access-group)** = trvalý anti-abuse + master expiry: `{ welcomeConsumed,
  hesoyamConsumed, expiresAt: Date? }`. Přežije reinstal. Čte se **jen při aktivaci a startu host
  appky** (ne na hot path).

**Host app při startu rekonsiliuje** App Group ↔ Keychain — pokud Keychain má expiry a App Group
ne (post-reinstal), obnoví `promoPlusExpiresAt` z Keychainu (→ zbytek trialu po reinstalu zůstane,
re-aktivace consumed grantu zablokovaná).

**Aktivační surfaces (sdílí jeden use case):**

- **Welcome onboarding** (host app) → `WelcomeTrialActivating.activate()`
- **Welcome Settings S2** (host app) → tentýž use case, po confirm alertu
- **HESOYAM keyboard extension** → `CheatCodeDetector.matches(context:)` → `HesoyamActivating.activate()`

Use case vrstva drží: Keychain consume → App Group zápis → `SettingsChangeNotifier.post(.promoPlusExpiresAt)`
(klávesnice se živě odemkne, stejný vzor jako dnešní `.isPlus`).

**Detekce HESOYAM** = reuse existujícího `documentContextBeforeInput` skenování (stejná kategorie
jako [`SlackEmojiSuggester`](KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) a word completion
— **žádná nová privacy kategorie**, vše lokální). Window match (viz revert log).

## Scope

### 1. Knihovny (SPM přes Tuist)
- **KeychainAccess** → host app **i** keyboard extension target (oba čtou Keychain).
- **ConfettiSwiftUI** → **jen** keyboard extension (welcome je tichý, žádné konfety) — sledovat
  paměť (viz Rizika).

### 2. Keychain wrapper — `PromoTrialStore` (KeymojiCore)
Protocol-first (`PromoTrialStoring` + impl), sdílený host app ↔ extension:

```swift
public struct PromoTrialRecord: Codable, Sendable, Equatable {
    public var welcomeConsumed: Bool
    public var hesoyamConsumed: Bool
    public var expiresAt: Date?
}

public protocol PromoTrialStoring: Sendable {
    var record: PromoTrialRecord { get }  // default-construct prázdný, ne optional
    var isPromoActive: Bool { get }       // expiresAt != nil && now < expiresAt
    @discardableResult func consumeWelcome(now: Date) -> Date  // returns new expiry; idempotent
    @discardableResult func consumeHesoyam(now: Date) -> Date  // idempotent
}
```

- Serializace přes KeychainAccess (`accessGroup` = keychain group pro App Group).
- Společná interní logika: `nextExpiry(currentExpiry: Date?, now: Date, addDays: Int) -> Date`
  = `max(now, currentExpiry ?? now) + addDays.days`.
- Idempotence: druhý `consumeWelcome`/`consumeHesoyam` nepřepíše flag, vrátí existující expiry.
- `now` je system clock; clock-manipulace ignorována (rounding error).

### 3. AppGroupStore + notifier
- `AppGroupStoreKey`: přidat `case promoPlusExpiresAt`.
- `AppGroupStore`: typed accessor `var promoPlusExpiresAt: Date?` (ISO/epoch string serialized).
- `SettingsChangeNotifier`: nový kanál `.promoPlusExpiresAt` — po aktivaci se běžící klávesnice
  živě odemkne (stejně jako dnešní `.isPlus`).

### 4. `effectiveIsPlus` plumbing — migrace ~5 gating sites

Najít a přepnout všechny dnešní `isPlus` reads, které slouží **gating logice** (NE StoreKit truth):

| Site | File | Dnešní | Po migraci |
|---|---|---|---|
| Favorites editor cap + frequency lock | [FavoriteEmojisEditorViewModel.swift:55](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift) | `purchaseService.isPlus` | `effectiveIsPlus(paid: purchaseService.isPlus, promoExpiresAt: store.promoPlusExpiresAt, now: Date())` |
| Onboarding favorites cap | [OnboardingPreferences.isPlus:42](../Features/Onboarding/Sources/OnboardingDependencies.swift) | `store.isPlus` | `effectiveIsPlus(paid: store.isPlus, ...)` |
| Settings Plus row stav | [SettingsViewModel.swift:99](../Features/Settings/Sources/SettingsViewModel.swift) | `purchaseService.isPlus` | nahradí `var plusRowState: PlusRowState` (viz Scope 6) |
| Paywall "already Plus" check | [PaywallViewModel.swift:62](../Features/Paywall/Sources/PaywallViewModel.swift) | `service.isPlus` | `effectiveIsPlus(...)` |
| Keyboard clamp + favorite add gate | [KeyboardState.swift:79](../KeyboardCore/Sources/Models/KeyboardState.swift) + uses in [KeyboardViewController.swift:558,737](../KeyboardExtension/Sources/KeyboardViewController.swift) | `state.isPlus` | runtime mirror `state.effectiveIsPlus` (derived z `isPlus` + `promoExpiresAt` mirrors) |

**Pozor:** `PurchaseService.isPlus` (KeymojiCore) zůstává placeno-only — je to StoreKit observer,
ne gating. Migrace se týká **konzumentů**, ne tohoto zdroje.

### 5. Welcome trial — onboarding banner (Features/Onboarding)

V `pickFavoritesStep` ([OnboardingView.swift](../Features/Onboarding/Sources/OnboardingView.swift))
nad gridem přidat banner. State derived z `viewModel`:

| Stav (effectiveIsPlus + welcomeConsumed) | Banner |
|---|---|
| Paid | Skrytý |
| Trial aktivní (welcome právě aktivován nebo HESOYAM) | Read-only success: „🎁 Plus aktivní do {date}" (no CTA) |
| Welcome dostupný (!paid && !welcomeConsumed && !trialActive) | **Tlačítko „🎁 Aktivovat dárek — měsíc Plus zdarma"** |
| Welcome spotřebovaný + trial vypršel | Skrytý (žádný banner; konverze přes loss-aversion v editoru / Settings) |

Po stisku „Aktivovat dárek":
1. `viewModel.activateWelcomeTrial()` → preferences provider → `WelcomeTrialActivating.activate()`
2. Keychain consume + App Group zápis + notify
3. Banner přepne na success state
4. `viewModel.favoritesLimit` přepočítá na `effectiveIsPlus` → grid live odemkne dimované buňky

**Tlačítko „Procházet všechny emoji"** (z grilling Q3): pod gridem, otevírá sheet s
`EmojiCatalogPickerView` — s correct cap (viz Scope 7).

**`OnboardingViewModel` rozšíření:**
- `var canShowWelcomeOffer: Bool` (= !paid && !welcomeConsumed && !trialActive)
- `var welcomeTrialActiveUntil: Date?` (= store.promoPlusExpiresAt pokud isPromoActive)
- `func activateWelcomeTrial()`
- `var favoritesLimit: Int` — recompute reactive na effectiveIsPlus (nepřežehlit hodnotu v init)

**`OnboardingPreferencesProviding` rozšíření:**
- `var canShowWelcomeOffer: Bool { get }`
- `var welcomeTrialActiveUntil: Date? { get }`
- `func activateWelcomeTrial()` (delegace na `WelcomeTrialActivating`)

### 6. Welcome trial — Settings row state machine (Features/Settings)

Nahradit dnešní 2-stavový `if isPlus` ([SettingsView.swift:65-91](../Features/Settings/Sources/SettingsView.swift))
explicitním 4-stavovým enumem ve VM:

```swift
public enum PlusRowState: Equatable, Sendable {
    case paid                           // S1
    case welcomeAvailable               // S2
    case trialActive(daysLeft: Int)     // S3
    case afterTrial                     // S4
}
```

| Stav | Řádek | Tap |
|---|---|---|
| S1 paid | „Keymoji Plus — Unlocked ✓" | nic (skrytý Restore pro jistotu) |
| S2 welcomeAvailable | **„🎁 Aktivovat měsíc Plus zdarma"** + chevron | **Confirm alert** → activate |
| S3 trialActive | „Plus (zkušební) — zbývá {N} dní" | nic (info only — žádný CTA během trialu, drží 63 „nenaguj") |
| S4 afterTrial | „✨ Unlock Keymoji Plus" → paywall (dnešní chování) | paywall (`.settings` context) |

**Confirm alert v S2** (v `SettingsView`):
- Title: „Aktivovat měsíc Plus zdarma?"
- Message: „Můžeš si ho vzít teď, nebo si počkat — ale aktivovat jde jen jednou."
- Actions: **„Aktivovat"** (default) / **„Zrušit"** (cancel)

Po úspěšné aktivaci: nativní toast / inline banner v Settings „Plus aktivní do {date}" (krátký, 3s).

`SettingsViewModel` rozšíření:
- `var plusRowState: PlusRowState` (derived z `effectiveIsPlus`, `purchaseService.isPlus`, store)
- `func activateWelcomeTrial()` → delegace na `WelcomeTrialActivating`

### 7. EmojiCatalogPickerView — `selectionLimit` param (Features/EmojiCatalogPicker)

Additive API change pro shared component:

```swift
public init(
    selectedEmojis: Set<String>,
    onToggle: @escaping (String) -> Void,
    onDone: @escaping () -> Void,
    selectionLimit: Int? = nil    // ← nový, optional, default nil
)
```

- Když `selectionLimit != nil && selectedEmojis.count >= selectionLimit && !cellIsSelected`:
  `.opacity(0.35)` + `.disabled(true)` (vzor z onboarding gridu
  [OnboardingView.swift:235-238](../Features/Onboarding/Sources/OnboardingView.swift)).
- Onboarding „Procházet všechny" sheet pass `selectionLimit: viewModel.favoritesLimit`
  (= 6 free, `.max` po welcome/paid → efektivně bez capu).
- Settings editor sheet **neuvádí** `selectionLimit` (chová se jako dnes — tap přes cap → paywall
  přes `onToggle` callback).

### 8. PaywallContext `.afterTrial`

V `PaywallContext` enum
([PurchaseServicing.swift:7](../KeymojiCore/Sources/Shared/PurchaseServicing.swift)) přidat:

```swift
case afterTrial   // user měl trial, ten vypršel, teď loss-aversion paywall
```

V `PaywallView` headline ([:24-33](../Features/Paywall/Sources/PaywallView.swift)):
```swift
case .afterTrial: Texts.headlineAfterTrial   // "You loved Plus. Get it back."
```

V `FavoriteEmojisEditorViewModel.toggle()` ([:99](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift)):
když `!paid && hasConsumedAnyTrial && !trialActive && favorites.count > limit` →
`requestPaywall(.afterTrial)` místo `.favoritesLimit`.

### 9. HESOYAM detekce + flow (keyboard extension)

**`CheatCodeDetector` (KeyboardCore, pure):**
```swift
public enum CheatCodeDetector {
    /// Match `hesoyam` (case-insensitive) anywhere in the last ~17 characters of `context`.
    /// Window > suffix because textDidChange in extensions doesn't tick 1:1 with characters
    /// (revert log #1) — strict hasSuffix would miss most real activations.
    public static func matches(context: String?) -> Bool { … }
}
```
- Plně unit-testovatelné.
- Velikost okna ~17 (= `"hesoyam".count + 10` slack pro trailing space/punctuation/atd.) — kalibrovat
  na zařízení proti reálným `textDidChange` skokům.
- Volat z [`KeyboardViewController`](../KeyboardExtension/Sources/KeyboardViewController.swift) po
  vložení znaku (tam, kde se už počítá Slack/word-completion kontext).
- **Guard `state.isSecureTextEntry`**
  ([:282](../KeyboardExtension/Sources/KeyboardViewController.swift)) → v secure poli nikdy nefíruje.
- **Text NEMAZAT** (žádný `deleteBackward`).
- **Debounce „už zpracováno":** match → dokud HESOYAM zůstává v okně, znovu nefírovat (jinak by
  každý další znak retriggeroval „already used" toast).

**Aktivační flow při `matches == true`:**
1. `effectiveIsPlus` true kvůli **placenému** Plus → konfety + toast „You already have Plus ✨",
   **nespotřebovat** Keychain token (edge #1, drží z původního 64).
2. `promoTrialStore.record.hesoyamConsumed` → toast „Promo already used 🔒", **žádný efekt,
   žádný grant** (edge #3).
3. Jinak (čerstvý) → `promoTrialStore.consumeHesoyam(now: Date())` → new expiry → set App Group →
   notify → **odpal efekt** + banner:
   - Pokud `record.expiresAt` byl `> now` před consume (welcome běží / dříve HESOYAM): banner
     **„🎉 Plus extended — now until {date}"**
   - Jinak: banner **„🎉 Plus unlocked — 60 days"**

**Debug:** vykreslit dočasný proužek se živým `documentContextBeforeInput` + match stavem na
klávesnici (revert log #4) — používat během vývoje, smazat před closing commitem.

### 10. Společný use case `WelcomeTrialActivating` (KeymojiCore, host app only)

```swift
@MainActor
public protocol WelcomeTrialActivating {
    /// Returns the new expiry on success, nil if already consumed or paid Plus is active.
    @discardableResult func activate() -> Date?
}
```

Impl drží `PromoTrialStoring` + `AppGroupStore` + `SettingsChangeNotifier` + `PurchaseServicing`
(pro paid guard). Vyhne se duplikaci logiky onboarding ↔ Settings.

Analogicky `HesoyamActivating` v keyboard extension (lehčí — bez `PurchaseServicing`; paid info
čte z App Group zrcadla).

### 11. Efekt — `CheatEffectOverlay` (KeyboardUI)

Beze změny vůči původnímu 64:
- Samostatná SwiftUI overlay nad klávesnicí: **ConfettiSwiftUI s nízkým stropem konfet** + banner
  toast + krátký **původní** chime.
- Chime gated na existující `keyClickSoundEnabled` (zvuky vypnuté → tichý) a izolovaný k snadnému
  smazání. Zvuk vyžaduje Full Access.
- **Finální choreografii (hustota, délka, zvuk) NELADIT v kódu předem** — ladí se ručně po prvním
  buildu na zařízení.
- Banner text předaný jako parametr (HESOYAM cold vs extended — viz Scope 9).
- **Welcome nepoužívá** tuhle overlay (welcome je tichý → menší expozice ConfettiSwiftUI v paměti
  extension, viz Rizika).
- ⚠️ **Žádné Rockstar assety** — žádná GTA znělka, font, zelený cheat-text styl, loga. Pouze
  původní homage. Trigger string „HESOYAM" OK (vstupní řetězec, ne branding).

### 12. Expirace + downgrade + konverzní pobídka (loss-aversion payoff)

- **Žádné notifikace** (žádný permission prompt). Discovery-driven (drží 64).
- Downgrade = **reuse 63 safe fallback**: `favoriteEmojis` se **nemažou**, jen se nezobrazují nad
  `freeFavoritesLimit`; frequency mód spadne na `.manual`.
- **Loss-aversion ve Favorites editoru** (host app): když promo vypršelo && `favoriteEmojis.count > limit`
  && !placeno → banner *„Your Plus trial ended — your N extra favorites are saved. Bring them back for
  {price}."* → paywall (`.afterTrial` context, Scope 8). Endowment + loss aversion v místě bolesti.
- **Countdown v Settings** = S3 stav (Scope 6).
- **Paywall headline `.afterTrial`** = „You loved Plus. Get it back."

### 13. App Store review
- **Welcome trial je veřejně viditelný** v onboardingu i Settings → **NENÍ** „hidden feature" 2.3.1.
- **HESOYAM ANO** → review notes (rozšířit z původního 64):
  *„The app includes a promotional easter-egg: typing 'hesoyam' on the keyboard grants a one-time
  60-day Keymoji Plus bonus that stacks onto the user's existing Plus trial. To test: install, type
  hesoyam in any text field, observe the unlock. The app also offers an explicit opt-in 30-day Plus
  trial in onboarding and Settings — both gifts together can extend Plus to ~90 days; the user pays
  zero. Neither bypasses IAP — Plus is also available via standard in-app purchase."*
- Welcome trial v review notes uvést jen jako kontext (viz výše).
- Žádné peníze mimo Apple, žádné obcházení IAP.
- **Fallback, kdyby Apple HESOYAM zamítl** (popsat, neimplementovat dopředu, drží z 64):
  - (a) přesunout cheat input do „Have a promo code?" pole v Settings (review-safe, nudné), nebo
  - (b) nechat cheat odemykat jen kosmetický efekt/téma, ne Plus.
  - Welcome trial zamítnutím HESOYAM netrpí — funguje samostatně.

### 14. Lokalizace
- **Welcome:** klíče `welcome.onboarding.cta`, `welcome.onboarding.activeUntil`,
  `welcome.settings.cta`, `welcome.settings.confirm.title`, `welcome.settings.confirm.message`,
  `welcome.settings.confirm.activate`, `welcome.settings.confirm.cancel`,
  `welcome.settings.toast`.
- **Trial countdown:** `settings.plus.trial.daysLeft` (s plural variants).
- **HESOYAM banner:** `promo.hesoyam.unlocked` (cold), `promo.hesoyam.extended` (stacking),
  `promo.hesoyam.alreadyUsed`, `promo.hesoyam.alreadyHavePlus`.
- **Paywall:** `paywall.headline.afterTrial` = „You loved Plus. Get it back."
- **Loss-aversion editor banner:** `favorites.lossAversion.title`, `…body`.
- Přegenerovat `L10n`. Ceny ze StoreKitu (nehardcodovat).

### 15. Testy

**`effectiveIsPlus` (KeymojiCore Tests):**
- paid=true, expiry=nil, now=any → true
- paid=false, expiry=future, now=before → true
- paid=false, expiry=past, now=now → false
- paid=false, expiry=nil → false

**`PromoTrialStore.nextExpiry` sčítací matika (KeymojiCore Tests):**
- První welcome: currentExpiry=nil, now=T → return T+30d
- HESOYAM po expired welcome: currentExpiry=T-1d, now=T → return T+60d
- HESOYAM během běžícího welcome (day 10 of 30): currentExpiry=T+20d, now=T → return T+80d (přičti
  60 k expiry)
- HESOYAM po dříve aktivovaném HESOYAM (consumed=true) → idempotent, vrátí existující expiry,
  nezmění
- Welcome idempotence: druhý consumeWelcome → vrátí stejný expiry, `welcomeConsumed` zůstane true

**`PromoTrialStore` Keychain round-trip:**
- Mock keychain nebo `SKKeychain` test suite — write record, read record, ověř flag + expiry round-trip.
- Reconciliace: smazat App Group, ponechat Keychain → host app restart → App Group má expiry zpět.

**Welcome activation flow (host app Tests):**
- Čerstvý → `WelcomeTrialActivating.activate()` vrátí new expiry, Keychain consumed=true, App Group
  set, notifier post.
- Druhý activate → vrátí nil, žádný side-effect.
- Paid Plus aktivní → activate vrátí nil, žádný consume (paid přebíjí).

**HESOYAM activation flow (extension Tests, mock protokoly):**
- Čerstvý → grant + nový expiry, notify.
- Consumed → no-op, „already used" toast trigger.
- Paid → „already have Plus" toast, žádný consume.
- Stacking text variant: pokud current expiry > now → extended banner; jinak unlocked banner.

**`CheatCodeDetector` window match:**
- Match: „hesoyam" na konci, „HESOYAM x" s trailing znakem (do window), „heso hesoyam" v okně,
  case mix.
- Ne-match: „hesoyam" mimo okno (víc než ~17 trailing chars), buffer končící uprostřed slova
  („heso"), prázdný kontext.

**Editor & VM:**
- `FavoriteEmojisEditorViewModel`: gating přes `effectiveIsPlus` — paid → unlimited; promo aktivní
  → unlimited; oboje false → cap 6 + paywall.
- Po expiraci s favorites > limit → `requestPaywall(.afterTrial)` (ne `.favoritesLimit`).

**Onboarding banner state machine:**
- `canShowWelcomeOffer` pro každý effective state (paid / trial active / welcome consumed-expired
  / dostupný).
- Po `activateWelcomeTrial()` → banner přepne state, `favoritesLimit` se zvedne.

**Settings PlusRowState transitions:**
- Pro každý ze 4 stavů ověř string + tap chování (confirm alert v S2, paywall v S4, no-op v S1/S3).

**Snapshot testy:**
- Onboarding pick-favorites banner: welcome available, trial active, paid (3 variants).
- Settings Plus row: všechny 4 stavy (S1-S4).
- Paywall headline `.afterTrial` (dark + light).
- EmojiCatalogPicker se `selectionLimit: 6` a 6 vybranými (cells nad cap ztlumené).

## Mimo scope

- **Forced / app-implemented trial bez opt-in** — explicitně zamítnuto, viz
  [ADR 0001](../docs/adr/0001-opt-in-welcome-plus-trial.md).
- **Garantovaná „jednou za život"** — iOS to bez serveru neumí; best-effort per-device.
- **Backend / DeviceCheck / iCloud KVS** — vědomě zamítnuto (server / brand violation).
- **Více cheat kódů / recurring trial** — možný pozdější easter egg, ne teď.
- **Prodlužování / stackování nad rámec welcome + HESOYAM** — jen tyhle dva granty, dál nestackuje.
- **Notifikace o expiraci** — discovery-driven, žádný permission prompt.
- **GTA assety jakéhokoliv druhu** — pouze původní homage.
- **Welcome v jiném contextu než onboarding + Settings** (např. push z keyboardu, deep link, atd.) — out.

## Hotovo když

- V onboardingu pick-favorites kroku banner „🎁 Aktivovat dárek" → stisk → grid se odemkne, banner
  přepne na „🎁 Plus aktivní do {date}", expiry zapsaný v Keychainu + App Group + notify (klávesnice
  živě odemčená bez restartu).
- „Procházet všechny emoji" v onboardingu otevře `EmojiCatalogPickerView` s correct cap
  (6 pre-welcome ztlumené, ∞ po welcome / paid).
- Settings Plus řádek prochází stavy S1–S4 dle `effectiveIsPlus` + `welcomeConsumed`.
- S2 tap → confirm alert → aktivace → S3 stav + toast.
- S3 (trial běží) ukazuje „zbývá N dní", **bez CTA**.
- S4 (po expiraci) → paywall (dnešní chování).
- Napsání `hesoyam` (case-insensitive) kdekoliv mimo secure pole **poprvé** → konfety + +60 dní
  k current expiry, žije bez restartu klávesnice; napsaný text zůstane stát.
- HESOYAM během aktivního trialu → banner text **„Plus extended — now until {date}"**.
- HESOYAM cold (žádný trial) → banner **„Plus unlocked — 60 days"**.
- Stav přežije **reinstal** appky (Keychain); factory reset = nový grant (akceptováno).
- Druhé HESOYAM po consume → „Promo already used", žádný grant.
- Placený user → welcome banner skrytý (onboarding i Settings); HESOYAM ukáže „You already have
  Plus", bez consume.
- Po expiraci: lišta spadne na 6 (data zachována), Favorites editor ukáže `.afterTrial` paywall
  banner; Settings spadne do S4.
- `effectiveIsPlus` aplikovaný na všech 5 gating sites (Scope 4); `PurchaseService.isPlus` zůstává
  paid-only.
- `EmojiCatalogPickerView` má volitelný `selectionLimit` param a respektuje ho ztlumením cells.
- Žádné Rockstar assety; HESOYAM přiznán v review notes; welcome v review notes jako kontext;
  fallback popsán.
- Unit testy (effectiveIsPlus, sčítací matika, oba activate flows, detector, store, banner state
  machines) + snapshoty green.

## Rizika

- **App Review 2.3.1 (HESOYAM jako skrytá funkce).** Welcome trial je veřejný, takže tuhle obavu
  *nezvyšuje* — HESOYAM zůstává single existenční riziko reviewu, kryté disclosure v notes (Scope
  13). Mít fallback (Scope 13a/b) připravený v hlavě.
- **Migrace ~5 sites na `effectiveIsPlus`.** Pokud zapomeneme některý site, gating zůstane na
  `isPlus` (paid-only) a trial tam nebude fungovat (silent UX bug — user má Plus, ale jedno místo
  v UI ho ignoruje). Mitigace: **grep checklist** všech dnešních `isPlus` reads + integration test
  pro každý site v promo-active stavu.
- **Paměť v extension (ConfettiSwiftUI).** ~48–70 MB jetsam strop. Strop konfet nízko, **změřit
  v extension** (Instruments). Spike u stropu → fallback minimální vlastní emoji-rain. Welcome
  ConfettiSwiftUI nepoužívá → expozice jen u HESOYAM.
- **Keychain není garantovaný.** Apple přežití po uninstallu oficiálně negarantuje (historicky
  kolísalo). Best-effort, akceptováno. Sdílený access-group entitlement musí sedět host app i
  extension, jinak klávesnice nepřečte „už použito".
- **Re-fire / dvojí grant.** Detekce po každém znaku (HESOYAM) → debounce + `hesoyamConsumed` flag
  v Keychain chrání. Welcome je explicit-tap, méně rizikové — `welcomeConsumed` flag pokrývá
  rapid-fire scénář (Settings tap dvakrát rychle).
- **Trapnost efektu (HESOYAM).** Zvuk/vizuál může vystřelit v cizím/pracovním chatu. User si to
  napsal schválně → akceptováno; chime jde vypnout sound togglem. Welcome je tichý → tahle obava
  se welcome netýká.
- **Listing claim „source code public on GitHub".** Repo je dnes private, takže cheat ve zdrojáku
  není odhalený — ALE App Store popis veřejný zdroj slibuje. Když repo zveřejníš kvůli privacy
  claimu, `HESOYAM` v něm bude. Nesouvisí přímo s touto funkcí, ale drž v patrnosti (viz task 63
  Scope 11 / [[keymoji-app-store-connect]]).
- **Welcome consume race** mezi onboardingem a Settings: user otevře Settings během onboarding
  back-stacku, aktivuje v Settings → vrátí se do onboardingu → banner už ukáže success state
  (notifier provede refresh). Drží se z toho, že `WelcomeTrialActivating` jde přes jeden
  `PromoTrialStoring` + jeden App Group + jeden notifier.

## Reference

- [63 — Keymoji Plus](63-monetization-keymoji-plus.md) — entitlement infra, paywall, downgrade
  fallback, free limit (tahle funkce na něm staví).
- [ADR 0001 — Opt-in Welcome Plus trial](../docs/adr/0001-opt-in-welcome-plus-trial.md) — proč
  opt-in trial otáčí původní 63/64 zamítnutí forced trialu.
- [62 — Onboarding pick favorites](62-onboarding-pick-favorites.md) — kam vstupuje welcome banner
  + „Procházet všechny" tlačítko.
- [`SlackEmojiSuggester`](../KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) — vzor lokálního
  skenování `documentContextBeforeInput`.
- [10 — AppGroupStore](10-app-group-store.md) / [22 — Cross-proc settings](22-cross-proc-settings-observation.md)
  — store + Darwin notifikace vzor.
- [`EmojiCatalogPickerView`](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift)
  — shared component, rozšíření o `selectionLimit`.
- [`CONTEXT.md`](../CONTEXT.md) — Monetization terms (Welcome Plus trial, HESOYAM promo bonus,
  Plus trial expiry, Effective Plus).
- KeychainAccess: <https://github.com/kishikawakatsumi/KeychainAccess>
- ConfettiSwiftUI: <https://github.com/simibac/ConfettiSwiftUI>

## Codex review

**Ano** — task se dotýká:
- Entitlement gating contract change (`isPlus` → `effectiveIsPlus`) napříč ~5 sites.
- Nová persistence vrstva (Keychain anti-abuse záznam + App Group zrcadlo).
- Cross-process notifikace (`.promoPlusExpiresAt` Darwin channel) — keyboard live unlock.
- State machine Settings rowu (4 stavy) + onboarding banner state machine.
- Modifikace shared component (`EmojiCatalogPickerView` API rozšíření).
- Finish flow onboardingu s novým consumable side-effectem (welcome aktivace).
- Keyboard extension consume cesta (HESOYAM) s anti-abuse hlídáním.

To je přesně typ změny, kde druhé Codex oko vyplatí — víc než task 62, kde Codex review byl
explicitně doporučen. Spustit přes `codex exec --full-auto` (nebo `/codex-review`) na celý diff
před closing commitem.
