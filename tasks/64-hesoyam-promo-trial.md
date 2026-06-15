# 64 — „HESOYAM" promo cheat → 30denní Plus trial

**Status:** TODO

**Priorita:** v1.x (po/se [taskem 63](63-monetization-keymoji-plus.md)) · **Úsilí:** M–L · **Dopad:** Medium (akvizice + konverze)

**Závisí na:** [63 — Keymoji Plus](63-monetization-keymoji-plus.md) (entitlement infra, paywall, downgrade fallback, free favorites limit). Bez 63 nedává smysl.

## ⚠️ Log z 1. pokusu — NEDOKONČENO, vráceno (2026-06-15)

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
   pár trailing znaků), ne striktní suffix. **Scope 4 „context KONČÍ na HESOYAM" je tím
   pádem v praxi špatně — přepsat zadání.**

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

Skrytý promo „cheat": uživatel napíše na klávesnici **`HESOYAM`** (pocta GTA: San
Andreas) → odpálí se efekt a aktivuje se **jednorázový 30denní trial Keymoji
Plus**. Po měsíci graceful downgrade + loss-aversion pobídka ke koupi.

## Business & psychologie (zafixováno přes `/grill-me`)

Není to skutečné tajemství — je to **plošný, jednorázový, časově omezený Plus
trial pro všechny**, zabalený do „cheat code" obálky, který má **působit
exkluzivně** a **šířit se organicky** (word-of-mouth, sociální sítě). Akceptováno,
že je dohledatelný.

**Proč to dává smysl (a není to čistá ztráta revenue):** časově omezený Plus =
učebnicový **loss-aversion konverzní motor**. Měsíc neomezených oblíbených → user
si nastaví 20 oblíbených, zvykne si → měsíc skončí → spadne na 6 → *cítí ztrátu* →
zaplatí $3.99, aby si nechal, co si postavil. Je to ta samá „Plus preview" mechanika
zamítnutá v tasku 63 (option B), ale **opt-in a self-selecting** (aktivuje si ji
ten, koho baví) → lepší než vnucený trial. „Cheat" je jen viralní doručovací obal.

Viralní artefakt = **napsané „HESOYAM" zůstává v textu stát** (nemažeme ho) →
kamarád v chatu to uvidí, zeptá se „co to je?" → organické šíření.

## Rozhodnutí (zafixovaná, neřešit znovu)

| Téma | Rozhodnutí |
|---|---|
| Co odemyká | **Reálný Plus** (ne kosmetiku), na **30 dní**, **jednou** |
| Kde se zadává | **Kdekoliv** uživatel píše (libovolné textové pole přes klávesnici) |
| Match | **Case-insensitive** (`hesoyam` = `HESOYAM` = `Hesoyam`) |
| Napsaný text | **Nechat stát** (nemazat) — je to viralní artefakt |
| Secure fields | **Nikdy nefíruje** v password/secure polích |
| Re-fire po expiraci | Toast **„Promo already used 🔒"**, žádný efekt, žádný nový měsíc |
| Persistence | **Keychain, best-effort** (přežije reinstal, ne factory reset), **žádný backend** |
| Anti-abuse | Per-device jeden měsíc; leak vědomě akceptován (kdo reinstaluje pro 2. měsíc, stejně by nezaplatil) |
| Notifikace expirace | **Žádné** (žádný permission prompt) — discovery-driven |
| Efekt | Lightweight emoji-rain/confetti + banner + původní chime; **finální feel se ladí naživo** |
| Knihovny | **KeychainAccess** (kishikawakatsumi), **ConfettiSwiftUI** (simibac) |

## Architektura

**Efektivní entitlement** = `zaplaceno (task 63 isPlus) OR (promoExpiresAt != nil && now < promoExpiresAt)`.
- `isPlus` (task 63) = **jen placené**, zůstává čistý StoreKit zdroj pravdy.
- Promo žije vedle: nový stav `promoPlusExpiresAt: Date?`.

**Zdroje pravdy (dva, záměrně):**
- **Keychain (sdílený access-group)** = trvalý anti-abuse + expiry záznam:
  `{ consumed: Bool, expiresAt: Date }`. Přežije reinstal. Čte se **jen při
  aktivaci a při startu host appky** (ne na hot path).
- **`AppGroupStore.promoPlusExpiresAt`** = levné zrcadlo pro klávesnici (čte ho na
  každém renderu při výpočtu efektivního entitlementu, stejně jako `isPlus`).
- Host app při startu **rekonsiliuje**: pokud Keychain má záznam a App Group ne
  (post-reinstal), obnoví `promoPlusExpiresAt` z Keychainu (→ zbytek trialu po
  reinstalu zůstane, a re-aktivace je zablokovaná).

**Detekce** = reuse existujícího `documentContextBeforeInput` skenování (stejná
kategorie jako [`SlackEmojiSuggester`](KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift)
a word completion — **žádná nová privacy kategorie**, vše lokální).

**Aktivace žije v keyboard extension** (tam se píše), ale Keychain čte přes sdílený
access-group (KeychainAccess do **obou** targetů).

## Scope

### 1. Knihovny (SPM přes Tuist)
- **KeychainAccess** → host app **i** keyboard extension target.
- **ConfettiSwiftUI** → keyboard extension (kde se renderuje efekt) — viz Rizika
  (paměť).

### 2. Keychain wrapper — `PromoTrialStore` (KeymojiCore)
Protocol-first (`PromoTrialStoring` + impl), sdílený host app ↔ extension:
- `var record: PromoTrialRecord?` (`{ consumed: Bool, expiresAt: Date }`,
  serializace přes KeychainAccess, **`accessGroup`** = keychain group pro App Group).
- `func consume(expiresAt: Date)` — zapíše `consumed: true` + expiry (idempotentní,
  nepřepíše existující consumed).
- `var isPromoActive: Bool` (`record?.consumed == true && now < expiresAt`) — pozn.
  `now` je system clock; clock-manipulaci ignorujeme (rounding error).
- `var hasBeenConsumed: Bool`.

### 3. Entitlement plumbing — rozšířit task 63
- `AppGroupStoreKey`: přidat `case promoPlusExpiresAt` (Date jako ISO/epoch string).
- `AppGroupStore`: typed accessor `var promoPlusExpiresAt: Date?`.
- **Efektivní Plus helper** (čistá funkce, sdílená, testovatelná):
  `effectiveIsPlus(paid: Bool, promoExpiresAt: Date?, now: Date) -> Bool`.
  Použít všude, kde task 63 čte `isPlus` pro gating (editor limit, frequency,
  keyboard clamp, paywall „už máš Plus").
- `SettingsChangeNotifier`: nový kanál `.promoPlusExpiresAt` → po aktivaci se běžící
  klávesnice **živě** odemkne (stejně jako `.isPlus`).

### 4. Detekce cheatu — `CheatCodeDetector` (KeyboardCore, pure)
- `static func matches(context: String?) -> Bool` — vrátí true, když
  `context` (= `documentContextBeforeInput`) **končí** na `HESOYAM`
  **case-insensitive**. Žádné slovní hranice nutné (HESOYAM nekoliduje s reálným
  slovem). Plně unit-testovatelné.
- Volat z [`KeyboardViewController`](KeyboardExtension/Sources/KeyboardViewController.swift)
  po vložení znaku (tam, kde se už počítá Slack/word-completion kontext).
- **Guard `state.isSecureTextEntry`** ([:282](KeyboardExtension/Sources/KeyboardViewController.swift:282))
  → v secure poli nikdy nefíruje.
- **Text NEMAZAT** (žádný `deleteBackward`).

### 5. Aktivační flow (keyboard extension)
Při `CheatCodeDetector.matches`:
1. `effectiveIsPlus` už true kvůli **placenému** Plus → odpal efekt + toast
   „You already have Plus ✨", **nespotřebuj** Keychain (edge #1).
2. `promoTrialStore.hasBeenConsumed` → toast „Promo already used 🔒", **žádný efekt,
   žádný grant** (edge #3 / re-fire).
3. Jinak (čerstvé) → `promoTrialStore.consume(expiresAt: now + 30d)`,
   `store.promoPlusExpiresAt = expiresAt`, `notifier.post(.promoPlusExpiresAt)`,
   **odpal efekt** + banner „🎉 Plus unlocked — 30 days". Klávesnice se odemkne živě.
- `KeyboardState`: zrcadlit `promoPlusExpiresAt`; `refreshFromStore` + observer
  `.promoPlusExpiresAt`. Keyboard clamp (task 63 Scope 6) použít `effectiveIsPlus`.

### 6. Efekt — izolovaná komponenta (KeyboardUI)
- Samostatná SwiftUI overlay komponenta nad klávesnicí (`CheatEffectOverlay`):
  **ConfettiSwiftUI s nízkým stropem konfet** + banner toast + krátký **původní**
  chime.
- Chime gated na existující `keyClickSoundEnabled` (zvuky vypnuté → tichý) a
  **izolovaný k snadnému smazání** (jeden řádek). Zvuk vyžaduje Full Access (jako
  key clicks) — bez něj jen vizuál.
- **Finální choreografii (hustota, délka, zvuk) NELADIT v kódu předem** — ladí se
  ručně po prvním buildu na zařízení.
- ⚠️ **Žádné Rockstar assety** — žádná GTA znělka, font, zelený cheat-text styl,
  loga. Pouze **původní homage**. Trigger string „HESOYAM" OK (vstupní řetězec, ne
  branding), ale **nemarketovat s GTA trademarky/obrázky**.

### 7. Expirace + downgrade + konverzní pobídka (loss-aversion payoff)
- **Žádné notifikace** (žádný permission prompt). Discovery-driven.
- Downgrade = **reuse task 63 safe fallback**: `favoriteEmojis` se **nemažou**, jen
  se nezobrazují nad `freeFavoritesLimit`; frequency mód spadne na `.manual`.
- **Loss-aversion ve Favorites editoru** (host app): když promo vypršelo &&
  `favoriteEmojis.count > limit` && !placeno → banner *„Your Plus trial ended —
  your N extra favorites are saved. Bring them back for {price}."* → paywall
  (task 63). Endowment + loss aversion v místě bolesti.
- **Countdown v Settings** (ne v klávesnici): když promo běží → „Plus (trial) — 23
  days left". Tikající hodiny = mírná urgence (Zeigarnik) + poctivost.
- **Paywall headline po expiraci** (task 63 Scope 8): kontextová varianta
  *„You loved Plus. Get it back."*

### 8. App Store review
- **Přiznat v App Review notes** (povinné, snižuje 2.3.1 riziko skryté funkce):
  *„The app includes a promotional easter-egg: typing 'hesoyam' on the keyboard
  grants a one-time 30-day trial of Keymoji Plus. To test: install, type hesoyam in
  any text field, observe the unlock."*
- **NENÍ to obcházení IAP** — rozdáváš vlastní funkci zdarma, žádné peníze mimo
  Apple. Riziko je čistě „hidden feature" 2.3.1, kryté disclosure.
- **Fallback, kdyby Apple i tak zamítl** (popsat, neimplementovat dopředu):
  - (a) přesunout vstup do **„Have a promo code?" pole v Settings** (review-safe,
    nudné) — cheat se pak nezadává přes klávesnici, jen v host appce; nebo
  - (b) nechat cheat odemykat **jen kosmetický efekt/téma**, ne Plus → 2.3.1 obava
    o IAP úplně mizí.

### 9. Lokalizace
- Klíče `promo.*` (banner unlocked / already-used / already-have-plus / trial-ended
  / countdown). Přegenerovat `L10n`. Ceny ze StoreKitu (nehardcodovat).

### 10. Testy
- **`CheatCodeDetector`**: match na konci bufferu, case-insensitive, ne-match
  uprostřed/jinde, prázdný kontext.
- **`PromoTrialStore`**: consume zapíše consumed+expiry; idempotence (druhý consume
  nepřepíše); `isPromoActive` přepíná podle `now` vs `expiresAt`; round-trip přes
  Keychain (test s mock/in-memory keychain nebo `SKKeychain` test suite).
- **`effectiveIsPlus`**: paid=true → true; promo aktivní → true; promo vypršelé →
  false; obojí false → false.
- **Aktivační flow**: čerstvý → grant + notifikace; už consumed → „already used",
  žádný grant; paid → efekt, žádný consume. (testovatelné nad protokoly bez UI.)
- **Editor**: po expiraci s favorites > limit ukáže loss-aversion banner; placený
  ne.

## Mimo scope

- **Garantovaná „jednou za život"** — iOS to bez serveru neumí; best-effort per-device.
- **Backend / DeviceCheck / iCloud KVS** — vědomě zamítnuto (server / brand violation).
- **Více cheat kódů / recurring** — možný pozdější easter egg, ne teď.
- **Prodlužování / stackování trialu** — jednou, bez prodloužení; clock-manipulace ignorována.
- **Notifikace o expiraci** — discovery-driven, žádný permission prompt.
- **GTA assety jakéhokoliv druhu** — pouze původní homage.

## Hotovo když

- Napsání `hesoyam` (case-insensitive) kdekoliv (mimo secure pole) **poprvé** →
  efekt + 30denní Plus aktivní **živě** bez restartu klávesnice; napsaný text zůstane stát.
- Stav přežije **reinstal** appky (Keychain); factory reset / nové zařízení = nový měsíc (akceptováno).
- Druhé napsání po expiraci → „Promo already used", žádný nový měsíc.
- Zaplacený user → efekt + „already have Plus", bez spotřeby tokenu; placené přebíjí promo.
- Po expiraci: lišta spadne na 6 (data zachována), Favorites editor ukáže
  loss-aversion banner → paywall; Settings během trialu ukazuje zbývající dny.
- Efekt je izolovaná komponenta laditelná/smazatelná bez šťourání do input pipeline; chime na sound toggle.
- Žádné Rockstar assety; cheat přiznán v review notes; fallback popsán.
- Unit testy (detector, store, effectiveIsPlus, flow) green.

## Rizika

- **App Review 2.3.1 (skrytá funkce).** Hlavní existenční riziko. Krýt disclosure
  v review notes; mít fallback (Scope 8) připravený v hlavě.
- **Paměť v extension (ConfettiSwiftUI).** ~48–70 MB jetsam strop. Strop konfet
  nízko, **změřit v extension** (Instruments). Spike u stropu → fallback minimální
  vlastní emoji-rain.
- **Keychain není garantovaný.** Apple přežití po uninstallu oficiálně negarantuje
  (historicky kolísalo). Best-effort, akceptováno. Sdílený access-group entitlement
  musí sedět host app i extension, jinak klávesnice nepřečte „už použito".
- **Re-fire / dvojí grant.** Detekce po každém znaku → ošetřit, aby aktivace
  proběhla jednou (po consume je `hasBeenConsumed` true). Hlídat, ať efekt
  nefíruje opakovaně, dokud `HESOYAM` zůstává na konci bufferu (debounce na
  „už zpracováno pro tenhle výskyt").
- **Trapnost efektu.** Zvuk/vizuál může vystřelit v cizím/pracovním chatu. User si
  to napsal schválně → akceptováno; chime jde vypnout sound togglem.
- **Listing claim „source code public on GitHub".** Repo je dnes **private**, takže
  cheat ve zdrojáku není odhalený — ALE App Store popis veřejný zdroj slibuje. Když
  repo někdy zveřejníš kvůli privacy claimu, `HESOYAM` v něm bude. Nesouvisí přímo
  s touto funkcí, ale drž v patrnosti (viz task 63 Scope 11 / [[keymoji-app-store-connect]]).

## Reference

- [63 — Keymoji Plus](63-monetization-keymoji-plus.md) — entitlement infra, paywall, downgrade fallback, free limit (tahle funkce na něm staví).
- [`SlackEmojiSuggester`](KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) — vzor lokálního skenování `documentContextBeforeInput`.
- [10 — AppGroupStore](10-app-group-store.md) / [22 — Cross-proc settings](22-cross-proc-settings-observation.md) — store + Darwin notifikace vzor.
- KeychainAccess: <https://github.com/kishikawakatsumi/KeychainAccess>
- ConfettiSwiftUI: <https://github.com/simibac/ConfettiSwiftUI>
