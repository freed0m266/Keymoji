# 76 — „What's New" content version: založení baseline

**Status:** Todo — připraveno z grill session 2026-06-24. Pouze *infrastruktura* (uložená hodnota + seed); samotná What's New obrazovka je budoucí task.

**Priorita:** v1.x (musí jít ven **dřív** než první What's New obsah — viz „proč teď") · **Úsilí:** S (jeden klíč v `AppGroupStore` + konstanta + seed na startu) · **Dopad:** Medium (samo o sobě neviditelné; je to nutná podmínka, aby budoucí What's New mířil správně).

**Souvisí s:** [10 — AppGroupStore](10-app-group-store.md) (sem klíč patří), [11 — onboarding](11-host-app-onboarding.md) (sousední „jednorázový stav" `onboardingComplete`). Glosář: termín **What's New version** v [`CONTEXT.md`](../CONTEXT.md). Dotýká se [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift), [`AppGroupStoreKey`](../KeymojiCore/Sources/Shared/AppGroupStoreKey.swift), [`KeymojiApp`/`AppDelegate`](../Keymoji/Sources/App/KeymojiApp.swift).

## Kontext / proč

Chceme do budoucna „What's New" obrazovku po updatu. Aby uměla správně rozhodnout „má se tomuhle zařízení něco ukázat?", potřebuje **baseline** — poslední content verzi, kterou zařízení vidělo. Pointa je založit ten baseline **teď, ještě před prvním What's New obsahem**:

> Kdyby se baseline zakládal až v tom samém updatu, který přináší první What's New (řekněme content verze 2), pak by čerstvá instalace dostala „klíč chybí → seedni na 2 → nikdy neukázat" — a What's New 2 by nikdo neuviděl. Tím, že seedneme **teď na verzi 1** (bez obsahu, bez UI), je baseline na světě dřív, než vznikne první obsah.

**Zjednodušení:** aplikace je pre-launch, **stávající uživatelé neexistují**. Takže neřešíme migraci ani „uživatel přeskočil seedovací build" — tenhle build je baseline a každý budoucí uživatel startuje čistě na content verzi 1. Mechanismus seed-on-absence ale zůstává, protože ošetří *budoucí* čerstvé instalace (viz tabulka).

### Co jsme zvážili a zamítli

- **Vázat na app/marketingovou verzi (`CFBundleShortVersionString`) nebo build number** — zamítnuto. Kadence What's New ≠ kadence releasů: bugfix release může jít ven bez What's New, nebo můžeš chtít dvě oznámení v jednom releasu. Navíc string verze vyžaduje sémantické porovnávání. **Vyhrazený monotónní Int** je triviální `stored < current` a obě kadence odpojuje.
- **Neseedovať a brát `absent == 0`** — zamítnuto. Vedlo by to k zobrazení „What's New" čerstvému uživateli verze, na kterou se právě nainstaloval (právě prošel onboardingem, nemá vůči čemu). Seed-on-absence to potlačí.

## Cíl

1. Ve sdíleném storage existuje monotónní Int **What's New content version**, založený na startu appky na aktuální hodnotu, pokud chybí.
2. Tahle session **nic nezobrazuje** — žádné What's New UI, žádné porovnání, žádný obsah. Jen baseline.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Model verze** | **Vyhrazený monotónní `Int`**, ručně zvedaný při psaní nového What's New obsahu; odpojený od app/marketingové verze. Konstanta v kódu, např. `currentWhatsNewVersion`. |
| **Počáteční hodnota** | `currentWhatsNewVersion = 1` (baseline; tahle session žádný obsah nemá). |
| **Úložiště** | `AppGroupStore` — konzistentní s `onboardingComplete` a jediným úložným vzorem. (Klávesnice ho nečte, to nevadí.) Uloženo jako `Int`. |
| **Seedovací sémantika** | **Seed-on-absence** dle tabulky níže. |
| **Kde se seeduje** | Na startu hostitelské appky — `AppDelegate.didFinishLaunchingWithOptions`, vedle `PromoTrialReconciliation.reconcileShared()`. |
| **Scope této session** | Pouze uložená hodnota + seed (+ minimální read accessor pro budoucí porovnání). **Žádné** UI, porovnání, obsah. |

### Seedovací tabulka (chování na startu)

| Stav uloženého klíče | Akce | Kdy nastává |
|---|---|---|
| **chybí** | zapiš `currentWhatsNewVersion`, **nic nezobrazuj** | první spuštění seedovacího buildu / každá budoucí čerstvá instalace |
| `stored < current` | zobraz What's New, pak zapiš `current` | **budoucí session** (až bude obsah) |
| `stored >= current` | nic | běžné spuštění |

## Scope

- Nový case v [`AppGroupStoreKey`](../KeymojiCore/Sources/Shared/AppGroupStoreKey.swift), např. `whatsNewVersion`.
- Typovaný accessor na [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift): `var whatsNewVersion: Int { get set }` (uloženo jako `Int`; default při čtení `0`, takže „chybí" je detekovatelné — viz pozn. níže).
- Konstanta `currentWhatsNewVersion = 1` (umístění: malý namespace/enum, např. `WhatsNew.currentVersion`, v KeymojiCore nebo v host appce — řeší next session při implementaci).
- Seed helper volaný z `AppDelegate.didFinishLaunchingWithOptions`: pokud klíč **chybí**, zapiš `currentWhatsNewVersion`. Rozlišení „chybí vs 0" — buď přes `object(forKey:) == nil` na podkladovém `UserDefaults`, nebo přes separátní bool/`hasSeededWhatsNew`. (Vybrat při implementaci; preferovat čistou „je klíč přítomen?" detekci, ať nemícháme „0" jako sentinel.)

## Non-goals

- What's New obrazovka / UI / obsah (budoucí task).
- Porovnávací a prezentační logika (`stored < current` → zobraz). Tahle session jen seeduje.
- Jakákoli vazba na marketingovou verzi.
- Migrace stávajících uživatelů (neexistují).

## Akceptační kritéria

- Po prvním spuštění je v `AppGroupStore` uložena `whatsNewVersion == currentWhatsNewVersion` (=1).
- Druhé a další spuštění hodnotu nepřepisují směrem dolů ani nic nezobrazují.
- Nic se uživateli nezobrazí (žádné UI v této session).
- Žádná telemetrie; hodnota žije jen v app-group containeru.

## Regresní síť

**Nové:**
- Seed-on-absence: čistý stav → po startu `whatsNewVersion == 1`.
- Idempotence: opakovaný start nemění hodnotu.
- (Příprava na budoucnost) detekce „klíč chybí" funguje i pro legitimní budoucí hodnotu `0`, pokud bychom ji někdy chtěli — proto neopírat „chybí" čistě o `== 0` bez ujištění (viz Scope).

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Smazat app / app-group data → spustit → ověřit uloženou `whatsNewVersion == 1`.
- Nové `.swift` soubory: spustit `tuist generate` **před** `xcodebuild test`, jinak je test tiše přeskočí (memory *keymoji-tuist-new-files-silent-skip*).
