# 67 — Debug menu pro simulaci fresh/free user stavů (DEBUG-only)

**Status:** Done — 2026-06-19 (vše implementováno; Debug+Release build zelený, KeymojiCore 85 + Settings 14 testů zelené)

## ✅ Implementováno (2026-06-19, větev `feature/67-debug-menu-simulate-free-user`)

- **`DebugOverrides` (KeymojiCore, `#if DEBUG`)** — `static var forceFreeTier` přes injektovatelný `UserDefaults` (default `.standard`, host-only; testy si dají izolovaný suite). Persistentní.
- **Maska v `PurchaseService.applyEntitlement`** — `effectiveOwned = owned && !DebugOverrides.forceFreeTier` pod `#if DEBUG`; `#else` větev beze změny. Mirror i observable `isPlus` dostanou masku + notifier `.isPlus` → UI i klávesnice live. Reálný StoreKit entitlement netknutý (toggle off → `refreshEntitlement()` → reálné Plus zpět). Přidán DEBUG test seam `applyEntitlementForTesting(_:)`.
- **`PromoTrialStore.debugWrite(_:)` (`#if DEBUG`)** — přímý zápis celého recordu (mimo `PromoTrialStoring`), volá `private persist` ve stejném souboru. Umožní reset flagů / posun expiry do minulosti, co idempotentní `consume*` cesta neumí.
- **Nový `Debug` feature modul** (`Features/Debug/`, Tuist `Feature(name:"Debug", dependencies:[core], hasTests:false, hasTesting:false)`, celé `#if DEBUG` → v Release prázdný framework). `DebugMenuView` + konkrétní `DebugMenuViewModel` (bez protokolu/mocku) + `debugMenuVM()`.
- **Akce VM:** `toggleForceFreeTier()` (+ `refreshEntitlement()` live), `resetOnboarding()`, `resetGift()` / `resetCheatCode()` (vyčistí consumed flag + celý sdílený `expiresAt` + mirror nil + notify), `expireTrialNow()` (welcomeConsumed=true + expiry/mirror do minulosti + notify). Žádná akce nesahá na favorites/learned words/recents/usage counts. Live readout: effective Plus, paid mirror, force-free, onboardingComplete, welcomeConsumed, cheatCodeConsumed, promo expiry.
- **Settings integrace** — `Settings` dep na `debug`; `#if DEBUG` „🛠 Debug" `NavigationLink` na konci formu (pod snapshot foldem → existující Settings snapshoty beze změny).
- **Testy** — `DebugOverridesTests` (KeymojiCore): force-free maskuje owned entitlement (mirror + observable false) → po vypnutí zpět true; default false.
- **Codex (closing):** 0 nálezů — ověřil Debug+Release build a že DEBUG override logika je v Release vykompilovaná pryč.

**Pozn.:** `#else`/release větev `applyEntitlement` ověřena beze změny (Release build zelený, `Debug.framework` v Release prázdný). Kombinaci „reset onboarding" + force-free neprovádět dokud není hotový [task 68](68-onboarding-rerun-truncates-favorites.md) (viz Rizika níže).

---

**Priorita:** v1.x (testovací nástroj pro [task 64](64-hesoyam-promo-trial.md)) · **Úsilí:** M · **Dopad:** Medium (odemkne manuální QA tasku 64 bez ztráty reálných dat a bez deaktivace StoreKit Plus)

**Závisí na:** [64 — Welcome trial + HESOYAM](64-hesoyam-promo-trial.md) (testuje jeho plochu), [63 — Keymoji Plus](63-monetization-keymoji-plus.md) (entitlement infra).

## Kontext

Vývojář má **reálně aktivní StoreKit Plus**, který nejde jednoduše deaktivovat, a **nechce přijít o data** (learned words, vybrané favorites). Bez nástroje proto nejde manuálně otestovat free / onboarding / gift / HESOYAM / downgrade plochu tasku 64. Tenhle task přidává DEBUG-only nástroj, který tyhle stavy simuluje nedestruktivně.

## Cíl

V **DEBUG** buildech host appky umožnit simulovat stavy fresh/free uživatele:

- nikdy neviděl onboarding (`onboardingComplete == false`),
- nemá aktivované Plus,
- nikdy nenapsal HESOYAM,
- nikdy si nevybral gift (welcome),
- **+ vypršelý trial** (aby šla otestovat i druhá půlka 64 — S4 / loss-aversion / afterTrial).

Samostatný `Debug` feature modul, navigace z `SettingsView`. **Nikdy** nesahá na favorites / learned words / recents / usage counts.

## Rozhodnutí (zafixovaná z grill session 2026-06-19)

| Téma | Rozhodnutí |
|---|---|
| **Model** | Hybrid: **override** jen pro Plus (StoreKit entitlement nejde z appky resetnout), **reset** (reálné přepsání app-owned stavu) pro onboarding / HESOYAM / gift — chceme ty flow reálně projít znovu |
| **No-Plus** | `DebugOverrides.forceFreeTier` v **KeymojiCore** (`#if DEBUG`, host-only `UserDefaults.standard`); maska v jediném writeru `PurchaseService.applyEntitlement` → `owned && !forceFreeTier`. **Persistent** (přežije relaunch), **live** (toggle → `refreshEntitlement()` → mirror + notifier → UI i klávesnice hned) |
| **Reset onboarding** | `store.onboardingComplete = false`; projeví se **až po restartu** appky (`RootView` čte flag jen při `@State` initu) — UI to explicitně řekne |
| **Reset gift / Reset HESOYAM** | dvě samostatná tlačítka; každé vyčistí svůj consumed flag **+ celý sdílený `expiresAt`** v Keychainu + `promoPlusExpiresAt` mirror + post `.promoPlusExpiresAt`. Sdílený expiry nejde rozplést → reset kteréhokoli grantu = promo hodiny na nulu (vědomě) |
| **Expire trial now** | `welcomeConsumed=true` + `expiresAt` do minulosti + mirror do minulosti → odemkne S4 / loss-aversion / afterTrial (funguje s force-free ON + >6 favorites) |
| **Umístění** | **samostatný `Debug` feature modul**; `Settings` dostane dep na `debug`; `#if DEBUG` `NavigationLink` z `SettingsView` |
| **VM** | pragmaticky **konkrétní `DebugMenuViewModel` bez protokolu/mocku** (DEBUG-only, mimo shipnutou plochu) |
| **Live readout** | sekce nahoře se současným stavem (effective Plus, reálný paid, force-free, onboardingComplete, welcomeConsumed, hesoyamConsumed, promo expiry) |
| **Data** | žádná debug akce **nikdy** nemění favorites / learned words / recents / usage counts |

## Scope

### 1. `DebugOverrides` (KeymojiCore, `#if DEBUG`)
- `public enum DebugOverrides` s `static var forceFreeTier: Bool { get/set }` přes `UserDefaults.standard` (host-only). Override patří do entitlement domény (vedle `PurchaseService` / `effectiveIsPlus`), proto KeymojiCore.

### 2. Maska v `PurchaseService.applyEntitlement` (KeymojiCore)
```swift
#if DEBUG
let effectiveOwned = owned && !DebugOverrides.forceFreeTier
#else
let effectiveOwned = owned
#endif
```
- `store.isPlus` mirror i observable `isPlus` dostanou `effectiveOwned`; notifier `.isPlus` post jako dnes → klávesnice + VM live.
- Reálný StoreKit entitlement se **nedotkne**; vypnutí flagu → `refreshEntitlement()` zapíše reálné `true` → Plus zpět.
- **Release větev (`#else`) musí zůstat beze změny** (žádný debug leak do produkce).

### 3. Nový `Debug` feature modul (`Features/Debug/`)
- Tuist `Feature(name: "Debug", dependencies: [core], hasTests: false, hasTesting: false)`.
- `DebugMenuView` + `DebugMenuViewModel`, celé `#if DEBUG` → v Release prázdný framework.

### 4. `DebugMenuViewModel` (konkrétní, `#if DEBUG`)
Akce (každá nedestruktivní vůči favorites/learned words):
- `toggleForceFreeTier()` → přepne `DebugOverrides.forceFreeTier` + zavolá `PurchaseService.shared.refreshEntitlement()` (live).
- `resetOnboarding()` → `store.onboardingComplete = false`.
- `resetGift()` / `resetHesoyam()` → vyčisti příslušný consumed flag + `expiresAt` v `PromoTrialStore` + `store.promoPlusExpiresAt = nil` + notifier.
- `expireTrialNow()` → nastav `welcomeConsumed=true` + `expiresAt`/mirror do minulosti + notifier.
- Live readout (computed): effective Plus, reálný paid (`PurchaseService.isPlus` před maskou — nebo poznámka že maska je aktivní), `forceFreeTier`, `onboardingComplete`, `welcomeConsumed`, `hesoyamConsumed`, promo expiry.
- Pozn.: `PromoTrialStore` nemá dnes API pro přímý zápis flagů — přidat DEBUG-only helper (např. `func debugSet(_ record:)` / cílené settery) nebo to řešit přes nový method na `PromoTrialStoring`. Drž to čisté (žádné veřejné mutace mimo `#if DEBUG`).

### 5. Settings integrace
- `Settings` feature: dep na `debug`.
- `SettingsView`: na konci formu `#if DEBUG` sekce s `NavigationLink` „🛠 Debug" → `DebugMenuView`.

### 6. Testy
- KeymojiCore: test že `forceFreeTier == true` maskuje entitlement (owned=true → `store.isPlus == false` && `isPlus == false`; po vypnutí → true).

## Hotovo když

- DEBUG build: `Settings → 🛠 Debug` otevře debug screen; v Release řádek ani logika neexistuje.
- **Force-free toggle** → effective Plus false všude (favorites cap, Settings řádek, paywall, klávesnice live) bez ztráty reálného Plus; vypnutí → reálné Plus zpět.
- **Reset onboarding** → po restartu naběhne onboarding; favorites/learned words zachované.
- **Reset gift / HESOYAM** → consumed flag false + promo hodiny na nule; klávesnice HESOYAM zase nafíruje.
- **Expire trial now** (+ force-free, >6 favorites) → Settings S4, loss-aversion banner v editoru, `.afterTrial` paywall.
- Live readout ukazuje aktuální stav.
- Žádná debug akce nezmění favorites / learned words / recents / usage counts.

## Rizika / pozn.

- ⚠️ **Dokud není opravený [task 68](68-onboarding-rerun-truncates-favorites.md)**, kombinace „reset onboarding" + force-free + dokončení pick-favorites kroku ořeže favorites na 6. Do té doby tuhle kombinaci neprovádět (nebo udělat 68 první).
- „Expire trial now" ukáže afterTrial jen s force-free ON (jinak reálné Plus maskuje promo).
- `forceFreeTier` je host-only; klávesnice vidí jen zamaskovaný mirror → konzistentní cross-process bez sdílení flagu.

## Codex review

**Ano** — task se dotýká `PurchaseService.applyEntitlement` (entitlement writer). I když je maska `#if DEBUG`, ověřit, že `#else`/release větev je beze změny a že debug logika nemůže prosáknout do produkce.
