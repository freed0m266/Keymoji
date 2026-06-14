# 63 — Monetizace: Keymoji Plus (freemium + jednorázový unlock)

**Status:** TODO

**Priorita:** v1.x (před prvním veřejným releasem) · **Úsilí:** L · **Dopad:** High

## Cíl

Z Keymoji udělat **freemium** appku s jediným jednorázovým in-app nákupem
**„Keymoji Plus"** (non-consumable, ~$3.99 / 99 Kč tier). Klávesnice zůstává
**zdarma navždy** a plně použitelná jako daily driver; Plus odemyká jen
**personalizační vrstvu oblíbených emoji**. Žádný subscription, žádný časový
trial.

> **Zaveď před prvním veřejným releasem.** v1.0 je teď v `PREPARE_FOR_SUBMISSION`,
> appku zatím nikdo nemá → zavedení limitu oblíbených a zamčení frekvenčního
> řazení teď **nikomu nic neodebírá**. Kdyby Plus přišel až po veřejném launchi
> free verze, brali bychom funkce stávajícím uživatelům = přesně ten resentment,
> kterému se vyhýbáme.

## Business & psychologie (zafixovaná rozhodnutí)

Vzešlo z `/marketing-psychology` session. Tohle **není** k re-litigaci v
implementaci — je to zadání.

**Model: čistý freemium + jednorázový unlock.**
- Subscription zamítnut: appka nemá průběžné náklady (nula networking/backend)
  ani průběžně dodávanou hodnotu → měsíční poplatek za klávesnici = resentment →
  1★ recenze → zničená privacy/indie goodwill (jediné reálné aktivum).
- „Free trial pak jednorázová platba" **technicky nejde**: StoreKit free trial /
  introductory offer existuje **jen pro auto-renewable subscriptions**, ne pro
  non-consumable. Trial proto neřešíme — „trial" je samotná free verze (časově
  neomezená, funkčně osekaná).

**Železné pravidlo splitu:** klávesnice má brutálně vysokou adoption energy
(install → Settings → Add Keyboard → enable → Allow Full Access → přepnout se →
*věřit jí všechno, co píšu*). Proto **nesmíme gateovat nic, co je potřeba k
osvojení jako denní klávesnice.** Konvertujeme až potom, co je uživatel závislý
(switching cost přes naučená slova + nastavené oblíbené = endowment/IKEA effect).

| FREE (denní klávesnice — navždy zdarma) | PLUS (jednorázový unlock $3.99) |
|---|---|
| Celé psaní: QWERTY/QWERTZ, number row, symboly, shift/caps | **Neomezený počet oblíbených emoji** |
| Diakritika (long-press akcenty + jazykové sady) | **Více stránek oblíbených** (paging v baru) |
| Word suggestions **+ učení slov** (motor návyku → free naplno) | **Auto-řazení oblíbených podle četnosti** (`.frequency` mód) |
| Správce naučených slov (view/sort/delete) | _(rezerva pro budoucí Plus: témata, zvukové sady)_ |
| Trackpad na space, delete po slovech, haptika+zvuky, light/dark | |
| Žádný autocorrect, plná privacy | |
| Emoji **search podle jména** + procházení **celého katalogu** | |
| Emoji **`:shortcode:`** psaní (Slack styl) | |
| **6 oblíbených** v jedné řadě (ruční pořadí) | |

**Proč zrovna tahle čára (nech v kódu jako záměr):**
- Emoji je *hero* marketingu („for people who live in emoji") → celý ho zamknout
  nejde (App Store slib by byl lež → 1★). Search + katalog + ochutnávka 6
  oblíbených je proto free.
- **Limit oblíbených = nejčistší možný paywall.** 7. oblíbený = přirozený strop u
  věci, kterou už user miluje. Ask zní „víc toho, co už používáš", ne „odemkni
  zmrzačenou funkci" (Zeigarnik + goal-gradient + endowment, bez resentmentu).
- Suggestions/učení **schválně zdarma** — motor návyku a switching cost; závislost
  vyrábíme na free vrstvě, peníze bereme na personalizační.
- Plus je záměrně **úzký a generózní** (Reciprocity-first): „dal jsi mi skvělou
  free klávesnici bez tracků → chci ti to vrátit." Gating infra ať je obecná, aby
  šly budoucí Plus features přidat bez re-architektury.

**Cena:** non-consumable, App Store **Tier $3.99 / 99 Kč**. V UI **nikdy
nehardcoduj** — zobrazuj `product.displayPrice` (lokalizovaná cena ze StoreKitu).

**Free limit oblíbených:** `freeFavoritesLimit = 6` (pojmenovaná konstanta, jedna
stránka baru, snadno laditelná).

## Kontext (co už existuje a na co se napojit)

**App Group store — zdroj pravdy sdílený host app ↔ extension:**
- [`AppGroupStore`](KeymojiCore/Sources/Shared/AppGroupStore.swift) — wrapper umí
  `bool` / `string` / `stringArray`; enum se ukládá jako raw string s fallbackem
  na default (vzor: `favoritesSortMode` [:113-119]). `isPlus` bude prostý `bool`.
- [`AppGroupStoreKey`](KeymojiCore/Sources/Shared/AppGroupStoreKey.swift) — typed
  enum klíčů; přidat `case isPlus`.
- [`SettingsChangeNotifier`](KeymojiCore/Sources/Shared/SettingsChangeNotifier.swift)
  — cross-process Darwin notifikace, **kanál = `AppGroupStoreKey`**. Nový klíč
  `.isPlus` automaticky dá nový kanál → po nákupu v host appce se běžící
  klávesnice **živě** odemkne.

**Oblíbené — dnešní stav (task 18/44/49/51):**
- Zdroj pravdy = `store.favoriteEmojis: [String]` (ruční pořadí). **Dnes bez
  capu** — limit zavádíme nově.
- [`FavoritesSortMode`](KeymojiCore/Sources/Shared/FavoritesSortMode.swift) `.manual`
  / `.frequency`; [`FavoritesOrdering.ordered(_:counts:mode:)`](KeymojiCore/Sources/Shared/FavoritesOrdering.swift)
  — čistý sort helper. **`.frequency` je dnes zdarma → tímto taskem se stává
  Plus-only.**
- Editor: [`FavoriteEmojisEditorViewModel`](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift)
  + [View](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift)
  + [Mock](Features/FavoriteEmojisEditor/Testing/FavoriteEmojisEditorViewModelMock.swift)
  (host app — sdílí App Group store).
- Bar v klávesnici: [`SuggestionBarView`](KeyboardUI/Sources/Views/SuggestionBarView.swift)
  (TabView paging, task 49) → renderuje hotové pole z
  [`KeyboardRoot`](KeyboardExtension/Sources/KeyboardRoot.swift) [:32].
- Onboarding pick favorites: [task 62](62-onboarding-pick-favorites.md) — výběr
  oblíbených při prvním spuštění (musí respektovat free limit, viz Scope 7).

**Keyboard runtime stav:** [`KeyboardState`](KeyboardCore/Sources/Models/KeyboardState.swift)
zrcadlí store nastavení, plněno v `refreshFromStore()`
([`KeyboardViewController`](KeyboardExtension/Sources/KeyboardViewController.swift) [:163+]).

**Architektura nákupu (klíčové omezení):** keyboard extension **neumí spustit
StoreKit purchase UI** (sandbox). Proto:
- Paywall i `product.purchase()` žijí **jen v host appce**.
- Extension pouze **čte** `isPlus` z `AppGroupStore`. Žádný StoreKit kód v
  extension targetu.

**Bundle:** base `com.freedommartin.keymoji` → produkt **`com.freedommartin.keymoji.plus`**.
App ID v ASC: **6776134522** (viz [[keymoji-app-store-connect]]).

## Scope

### 1. Entitlement = zdroj pravdy (`AppGroupStore.isPlus`)
- `AppGroupStoreKey`: přidat `case isPlus`.
- `AppGroupStore`: typed accessor `var isPlus: Bool` (get/set přes `bool(forKey:)`
  / `setBool(_:forKey:)`, default `false`).
- Po každé změně entitlementu (Scope 2) zapsat `store.isPlus` + `notifier.post(.isPlus)`.

### 2. `PurchaseService` (StoreKit 2) — **jen host app / KeymojiCore, nikdy extension**
Nový protocol-first service v `KeymojiCore` (`PurchaseServicing` + impl), `@MainActor`,
`@Observable`:
- `func loadProducts() async` → `Product.products(for: ["com.freedommartin.keymoji.plus"])`,
  drží `plusProduct: Product?` a `displayPrice: String`.
- `var isPlus: Bool` (zrcadlo entitlementu, řídí paywall UI).
- `func purchase() async throws -> Bool` → `plusProduct.purchase()`, ověřit
  `VerificationResult` (`.verified`), `transaction.finish()`, pak `refreshEntitlement()`.
- `func restore() async` → `AppStore.sync()` + `refreshEntitlement()` (Apple **vyžaduje**
  restore pro non-consumable).
- `func refreshEntitlement() async` → projet `Transaction.currentEntitlements`,
  set `isPlus`, **zapsat do `AppGroupStore` + post `.isPlus`** (Scope 1).
- **`Transaction.updates` listener** spuštěný při startu host appky (handle nákupů
  z jiného zařízení / Ask-to-Buy) → `refreshEntitlement()`.
- Ověření je **on-device** (`VerificationResult.verified`). Žádný receipt server —
  appka nemá backend a nemá ho mít. Anti-piracy neřešíme (trust brand; App Store
  kupující drtivě prostě zaplatí).

### 3. StoreKit konfigurace + ASC produkt
- **Local `.storekit` config file** (`Keymoji/Resources/Keymoji.storekit` nebo
  dle konvence) s produktem `com.freedommartin.keymoji.plus`, type Non-Consumable,
  cena Tier 4 ($3.99) — pro test v simulátoru bez ASC. Nastavit ve scheme.
- **App Store Connect:** vytvořit In-App Purchase `com.freedommartin.keymoji.plus`
  (Non-Consumable, reference name „Keymoji Plus", $3.99 tier, lokalizovaný
  display name + description). _Manuální krok mimo kód — zapsat do
  [[keymoji-app-store-connect]] memory + `marketing/app-store/SUBMISSION.md`._
- Tuist: ověřit, že App target má StoreKit capability / `.storekit` v resources;
  **extension target StoreKit NEMÁ**.

### 4. Free limit oblíbených — gate v editoru (host app)
- Konstanta `freeFavoritesLimit = 6` (v `KeymojiCore`, např. vedle favorites
  modelu — sdílená s keyboard clampem v Scope 6).
- `FavoriteEmojisEditorViewModel`: při pokusu o přidání oblíbeného nad limit, když
  `!isPlus` → **nepřidat, vyvolat paywall** (Scope 8) místo zápisu. Free user může
  mít max 6; stávajících 6 jde libovolně přeskládat/měnit.
- Vizuálně: u limitu ukázat řádek typu „6/6 — Unlock unlimited with Plus" jako
  tappable upsell (vede na paywall). Žádný hard error, žádný shaming.
- `isPlus` čte ViewModel z injektnutého `PurchaseServicing` (host app DI), ne
  přímo ze StoreKitu.

### 5. Gate frekvenčního řazení (Plus only)
- `.frequency` mód ve `FavoriteEmojisEditorView` picker: když `!isPlus`, volba
  „Most used" je **zamčená** (🔒) → tap vyvolá paywall, mód se nepřepne.
- Keyboard runtime navíc force `.manual` když `!isPlus` (Scope 6) — defense in depth.
- `emojiUsageCounts` se **počítá pořád** (i pro free) — ať Plus po koupi hned
  funguje na nasbíraných datech (žádný „začni od nuly po koupi" útes).

### 6. Keyboard extension — číst `isPlus`, clampovat, observovat
- `KeyboardState`: přidat `public var isPlus: Bool` (default `false`).
- `refreshFromStore()`: zrcadlit `store.isPlus` do `state` (stejný `if changed` vzor).
- Observers: `settingsNotifier.addObserver(for: .isPlus) { self?.refreshFromStore() }`
  → po koupi v host appce se běžící klávesnice **živě** odemkne.
- `KeyboardRoot` [:32] — odvodit zobrazené oblíbené s ohledem na entitlement:
  ```swift
  let limit = state.isPlus ? Int.max : freeFavoritesLimit
  let mode  = state.isPlus ? state.favoritesSortMode : .manual
  let favs  = FavoritesOrdering.ordered(
      Array(state.favoriteEmojis.prefix(limit)),
      counts: state.emojiUsageCounts,
      mode: mode
  )
  ```
  + když `!isPlus`, vynutit **single page** baru (žádný paging) — favs ≤ 6 stejně
  vyjde na jednu stránku, ale clamp drž explicitně pro jistotu.
- **Žádný StoreKit, žádné purchase UI v extension.** Max decentní afordance je už
  pokrytá tím, že free user nemá jak nad limit přidat (gate je v host editoru).

### 7. Onboarding (task 62) — respektovat free limit
- Výběr oblíbených v onboardingu nesmí free uživateli nechat uložit > `freeFavoritesLimit`
  (jinak by keyboard hned clampoval = matoucí). Cap výběr na 6.
- **Žádný upsell uprostřed onboardingu** — neotravovat při prvním spuštění (peak-end:
  první dojem ať je čistě „funguje"). Plus se nabízí až když user organicky narazí
  na strop nebo si o něj řekne v Settings.

### 8. Paywall UI (host app) — `PaywallView` + ViewModel
Protocol-first (`PaywallViewModeling`), `@MainActor`, prezentovaný jako sheet.
Reachable z: (a) limit oblíbených, (b) zamčený frequency picker, (c) Settings řádek.

**Obsah (copy anglicky — app je English-only):**
- Headline dle kontextu: limit → „You've filled your 6 free favorites." /
  frequency → „Auto-sort is a Keymoji Plus feature." / settings → „Keymoji Plus".
- 3 benefit bullety: *Unlimited favorites* · *Multiple favorite pages* ·
  *Auto-sort by most-used*.
- Jeden CTA button: **„Unlock for {displayPrice} — one time"** (lokalizovaná cena).
- Pod tím: **„Restore purchase"** (povinné), malý text **„No subscription. No
  tracking. Pay once, yours forever."** (Contrast vs subscription + Loss aversion).
- Reciprocity/Unity řádek: „Built by one developer. Your purchase keeps Keymoji
  independent, ad-free, and private."
- **Success state** (peak-end): po koupi delightful potvrzení — „You're Plus! 🎉
  Unlimited favorites unlocked." → dismiss, odemčené funkce hned živé.
- Stavy: loading produktu, purchasing (spinner), error (purchase failed / cancelled
  → graceful, žádný děsivý alert), already-Plus (skrýt CTA, ukázat „You have Plus").

### 9. Settings — Plus řádek + Restore
- Do host app Settings ([task 12](12-host-app-settings.md)) přidat sekci/řádek
  **„Keymoji Plus"**:
  - když `!isPlus`: „Unlock Keymoji Plus" → paywall.
  - když `isPlus`: „Keymoji Plus — Unlocked ✓" (+ schovaný „Restore" pro jistotu).
- **Nenaguj.** Jeden tichý vstupní bod, vždy dostupný, nikdy nevyskakuje sám.

### 10. Lokalizace
- `KeymojiResources/.../Localizable.strings`: klíče `paywall.*`, `settings.plus.*`,
  `favorites.limit.*`. Přegenerovat SwiftGen `L10n`. Ceny **nelokalizovat ručně** —
  jdou ze StoreKitu.

### 11. Privacy / App Store listing reconciliation ⚠️
StoreKit **kontaktuje Apple** při nákupu/restore/ověření → koliduje s absolutním
claimem v [listing-en.md](../marketing/app-store/listing-en.md):
„makes **no network requests at all** — there is literally no networking code".
- **Upravit copy poctivě** (Pratfall effect — přiznání nuance = víc důvěry, ne míň):
  zachovat „no analytics, no tracking, no accounts, no third-party SDKs, nothing
  you type ever leaves your phone", ale claim o nule networkingu změnit na něco
  jako: „The only network activity is Apple's own purchase check when you buy or
  restore Plus — and even then, nothing you type is ever involved."
- **App Privacy label v ASC**: zkontrolovat, zda StoreKit/IAP nemění „Data Not
  Collected" pozici (purchase je Apple, ne my; obvykle zůstává, ale ověřit a
  případně deklarovat „Purchases" jako not linked / not tracking).
- Promo text v listingu zmiňuje „zero tracking" — to drží, neměnit.
- Synchronizovat `marketing/app-store/listing-en.md` → `fastlane/metadata/en-GB/`
  → `check-lengths.sh` (viz [[keymoji-app-store-connect]]).
- _Listing copy je samostatný drobný follow-up; tady jen flag + úprava zdroje pravdy._

### 12. Testy
- **`PurchaseService`**: s `.storekit` test configem (StoreKitTest / `SKTestSession`)
  — load produktu, purchase → `isPlus == true` + zápis do `AppGroupStore` + post
  `.isPlus`; restore obnoví entitlement; failed/cancelled purchase nechá `isPlus == false`.
- **`AppGroupStore`**: `isPlus` round-trip + default `false`.
- **`FavoriteEmojisEditorViewModel`**: free user nepřidá 7. oblíbený (zůstane 6 +
  vyvolá paywall trigger); Plus user přidá nad limit; frequency volba zamčená pro
  free; mock dostane injektnutelný `isPlus`.
- **Keyboard clamp** (KeyboardCore/extension): `!isPlus` → max 6 favs + force
  `.manual`; `isPlus` → plný počet + zvolený mód. Čistá funkce ať je testovatelná
  bez StoreKitu (vstup `isPlus: Bool`).
- **Snapshoty**: `PaywallView` (loading / purchasable / purchased / error stavy),
  editor s limitem „6/6" upsell řádkem (free) vs. bez (Plus), zamčený frequency
  picker. Re-record editoru pokud přibyl upsell řádek.

## Mimo scope

- **Subscription, auto-renew, časový free trial** — viz Business sekce, permanentně out.
- **Receipt server / vlastní backend validace** — on-device StoreKit 2 verification
  stačí; appka nemá a nebude mít backend.
- **Anti-piracy / obfuskace** (appka je open-source na GitHubu; App Store kupující
  zaplatí; neřešíme).
- **Promo kódy / offer codes / launch sleva** — možný pozdější marketing krok, ne
  v tomto tasku (jeden SKU, jedna cena, paradox-of-choice minimalizován).
- **Další Plus features** (témata, zvukové sady, víc layoutů) — gating infra ať je
  obecná, ale samotné features jsou budoucí tasky.
- **„14denní Plus preview"** (app-implementovaný trial) — vědomě zamítnut pro v1;
  případný pozdější A/B experiment, ne teď.
- **iPad / další jazyky** — pořád out (viz README „Mimo scope úplně").

## Hotovo když

- Existuje jeden non-consumable produkt `com.freedommartin.keymoji.plus`; lze ho
  koupit v host appce a **Restore** funguje.
- Po koupi se `AppGroupStore.isPlus` nastaví na `true`, pošle se `.isPlus`
  notifikace a **běžící klávesnice se odemkne živě** bez restartu.
- Free user: max **6** oblíbených v jedné řadě, jen ruční pořadí; 7. oblíbený /
  frequency mód vyvolá paywall. Plus user: neomezené oblíbené, víc stránek,
  auto-řazení dle četnosti.
- Veškerá personalizace mimo oblíbené (psaní, diakritika, suggestions+učení,
  správce slov, search, shortcody, trackpad, haptika…) je **zdarma** a nedotčená.
- Cena se v UI zobrazuje ze StoreKitu (`displayPrice`), nikde není hardcoded.
- V extension targetu **není žádný StoreKit kód**; purchase UI žije jen v host appce.
- Onboarding nenechá free usera uložit > 6 oblíbených a neupselluje uprostřed.
- App Store listing privacy claim je upravený tak, aby byl pravdivý i s IAP
  (zdroj pravdy `listing-en.md`); App Privacy label ověřen.
- Unit/VM/clamp testy green; paywall + editor snapshoty green.
- ASC produkt + manuální kroky zapsané do [[keymoji-app-store-connect]] memory.

## Rizika

- **Privacy claim regrese.** Nezapomenout na Scope 11 — pustit IAP a nechat v
  listingu „no network requests at all" = nepravda a riziko App Review/ztráty
  důvěry. Musí jít ruku v ruce.
- **Extension a StoreKit.** Pokud by se StoreKit omylem zalinkoval do extension
  targetu nebo se purchase volalo z klávesnice → nefunguje/rejection. Hlídat
  target membership: purchase jen host app, extension jen čte `isPlus`.
- **Živá synchronizace po koupi.** Bez `.isPlus` Darwin notifikace by se odemčení
  projevilo až po restartu klávesnice. Ověřit cross-process refresh (stejný vzor
  jako `favoritesSortMode`, task 22/51).
- **Clamp vs. existující data.** Kdyby Plus user vrátil zařízení / reinstall a
  `isPlus` se chvíli načítá `false`, keyboard zobrazí jen 6 + `.manual` (bezpečný
  fallback, data v `favoriteEmojis` se neztratí). Po `refreshEntitlement()` se
  obnoví. Nemazat `favoriteEmojis` při downgradu — jen je nezobrazovat nad limit.
- **Frequency byl free.** `.frequency` dnes shipuje jako free (task 51); tímto se
  zamyká. OK jen proto, že v1.0 ještě veřejně nevyšla — kdyby už byla venku,
  neodebírat (viz Cíl).
- **„6/6" jako frustrace, ne pozvánka.** Copy a vizuál upsellu musí znít jako „víc
  toho dobrého", ne jako zeď. Žádné shaming, žádné modální vyskakování při psaní.
- **App Review IAP gotchas.** Restore button povinný; metadata produktu vyplněná;
  paywall nesmí být klamavý; cena z StoreKitu. Otestovat v sandboxu před submitem.

## Reference

- [10 — `AppGroupStore` + cross-process settings](10-app-group-store.md) — vzor store + klíče.
- [12 — Host app Settings screen](12-host-app-settings.md) — kam přijde Plus řádek.
- [22 — Cross-process settings observation](22-cross-proc-settings-observation.md) — Darwin notifikace vzor.
- [49 — Favorites bar TabView paging](49-favorites-bar-tabview-paging.md) — paging baru (Plus odemyká víc stránek).
- [51 — Favorites bar sort by frequency](51-favorites-bar-sort-by-frequency.md) — `FavoritesSortMode` / `FavoritesOrdering` / `emojiUsageCounts` (frequency = Plus only).
- [62 — Onboarding pick favorites](62-onboarding-pick-favorites.md) — musí respektovat free limit.
- [[keymoji-app-store-connect]] — ASC App ID, en-GB locale, fastlane lane (přidat IAP produkt + privacy update).
- Apple StoreKit 2: <https://developer.apple.com/documentation/storekit/in-app_purchase>
- WidgetCoin reference (task style + `AppGroupStore` pattern): `~/Development/WidgetCoin/`.
