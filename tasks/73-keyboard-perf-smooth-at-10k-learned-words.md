# 73 — Výkon: plynulá klávesnice i při 10 000 learned words

**Status:** Done — 2026-06-22 (všechny fáze 0 → A → B → C + editor v jedné větvi `feature/73-keyboard-perf-smooth-at-10k-learned-words`).

## Výsledky implementace (2026-06-22)

**Benchmarky (iPhone 17 sim, 100-call bloky, `PersonalRecentsStorePerformanceTests`):**

| Op | Baseline (UserDefaults JSON, cap 1000) | Po fázi A (souborový store + bucket index, cap 10000) |
|---|---|---|
| `matches(prefix:)` @plný pool | ~2.5 ms / call | **~0.06 ms / call** (bucket + folded-prefix `hasPrefix` pre-filtr; neroste s velikostí poolu) |
| `learn()` (re-learn) | ~2.5 ms / call | **~0.004 ms / call** (O(1) in-memory; zápis debounced mimo hot-path) |

Splňuje budget `matches < ~0.2 ms`. `learn` na hot-path je čistě in-memory; atomický `NSFileCoordinator` zápis je debounced (750 ms) na utility queue, flush na `viewWillDisappear`.

**Architektura:** `LearnedWordsIndex` (thread-safe, file-backed, bucket podle foldnutého 1. znaku, předpočítaný folded key, amortizovaný batch-trim). `PersonalRecentsStore` zachoval veřejné API + `PersonalRecentsReading`. `@Observable KeyboardViewModel` + hosting controller instalován jednou + `Equatable` `KeyRowView` (`.equatable()`) → key grid se nepřekresluje na stisk neměnící layout; `makeLayout` memoizovaný (1× na stisk). Suggestion compute debounced/cancellable/memoizovaný, mimo synchronní keystroke. Cross-process invalidace přes nový `AppGroupStoreKey.learnedWordsChanged` Darwin kanál + `reload()`. Editor: lazy `List` + `.searchable` filtr + "no results" stav.

**Odchylka od spec (fáze C):** Spec předpokládal, že `UITextChecker` „není main-isolated" → compute na pozadí. V iOS 26 SDK je ale `UITextChecker` deklarovaný `NS_SWIFT_UI_ACTOR` (**je `@MainActor`**), takže dotaz nelze přesunout na pozadí. Compute proto běží **debounced + cancellable + memoizovaný na main actoru**, ale *mimo* synchronní keystroke path (vložení znaku zůstává okamžité) a s coalescingem — rychlé psaní zruší mezilehlé computy, takže drahá pipeline (vč. `UITextChecker`) běží jen v pauzách. To řeší jádro auditního nálezu (#3/#4: „celá pipeline synchronně na každý stisk uvnitř makeRoot"). `matches` (recents) je nově thread-safe a mohl by jít na pozadí, kdyby se přidal background spell-checker.

**Codex review:** 2 nálezy (oba P2), oba aplikovány — (1) memoizace návrhů se invaliduje při změně provider dat (lexicon delivery / recents reload), (2) `reload()` serializován přes write queue, aby in-flight debounced zápis neklobboval host editaci.

**Pozn. — pre-existing fail:** `LayoutBuilderTests.testCzechSet_eKey_orderedByFrequency` selhává (čeká `["é","ě"]`, kód dává `["ě","é"]`) — soubory bit-identické s base commitem, **není to regrese tohoto tasku** (jako paywall flake). Vhodné opravit samostatně.

---

**Status (původní):** Spec — připraveno z analýzy + Q&A session 2026-06-22 (multi-agent perf audit + rozhodnutí níže). Implementace v další session.

**Priorita:** v1.x (kvalita psaní — core hodnota produktu; přímý beta-feedback „klávesnice není smooth") · **Úsilí:** L (velký, fázovaný — 3 vrstvy) · **Dopad:** High (latence na každý stisk; cítí se při každém psaní)

**Souvisí s:** [65 — accent-aware completions](65-accent-aware-completions-capslock-limits.md), [56 — suggestion bar](56-suggestion-bar-always-except-emoji.md), [40 — completion model](40-word-completion.md) (pokud existuje), [LearnedWordsEditor feature](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift), [CONTEXT.md](../CONTEXT.md) (termín *Learned word*). Dotýká se [`PersonalRecentsStore`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift), [`KeyboardViewController`](../KeyboardExtension/Sources/KeyboardViewController.swift), [`KeyboardRoot`](../KeyboardExtension/Sources/KeyboardRoot.swift), [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift), [`SettingsChangeNotifier`](../KeymojiCore/Sources/Shared/SettingsChangeNotifier.swift).

## Kontext / proč

Produkční build je při psaní cítit jako laggy / ne-smooth. Multi-agent audit hot-path (40 nálezů, 31 potvrzeno adversariální verifikací) ukázal, že **na každý stisk** běží synchronně na hlavním vlákně příliš mnoho práce a část z toho **roste lineárně s počtem naučených slov**. Uživatel má 700+ learned words; cíl je, aby klávesnice zůstala plynulá **i při 10 000**.

Dvě nezávislé příčiny, které se sčítají v jednom snímku (8 ms na 120 Hz):

1. **Roste s počtem slov.** [`PersonalRecentsStore.matches(prefix:)`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:90) na každý stisk udělá plný `JSONDecoder().decode` celé mapy a lineárně projde všechna slova s per-znak diakritickým `fold()` (alokace). `learn()` na každou mezeru/tečku/čárku dekóduje **obě** JSON mapy, **obě** znovu zakóduje a synchronně zapíše do App Group UserDefaults.
2. **Fixní náklad nezávislý na slovech.** Každý stisk nahradí **celý** SwiftUI root view (`rebuild()` → `hostingController.rootView = makeRoot()`), žádný `@Observable` ani scoped invalidace → re-diff ~30–40 kláves. Celá suggestion pipeline (včetně `UITextChecker`) běží synchronně uvnitř `makeRoot()`, bez debounce / async / memoizace. `makeLayout()` se staví 2× na stisk. `rebuild()` se na přechodech (auto-cap) spustí 2×.

Tento task řeší **všechny kritické, vysoké i střední** nálezy auditu.

## Cíl

Klávesnice je plynulá při souvislém psaní i s **10 000** learned words na 120 Hz zařízení, **bez jakékoliv změny chování návrhů ani UI** (důkaz: snapshot suite projde beze změny obrázků). Storage learned words přejde z UserDefaults JSON blobu na souborový store v App Group containeru s in-memory prefix indexem. Rendering přejde na `@Observable` scoped invalidaci. Suggestion compute jde mimo hlavní vlákno.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Storage backend** | Souborový store v App Group containeru (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`), atomický zápis + `NSFileCoordinator`. **Žádná nová závislost** (ne SQLite/GRDB). |
| **In-memory index** | Pool načten jednou do paměti (~stovky KB i při 10k) + prefix index (bucket podle foldnutého 1.–2. znaku). Folded key **předpočítaný při `learn()`**, ne per-keystroke. |
| **Kapacita** | `capacity` **1000 → 10000**. |
| **Eviction** | Pryč od per-`learn()` `O(n)` `keys.min`. Amortizovaný batch-trim: pool roste do `cap + slack`, ořez na `cap` proběhne občas v rámci odloženého background zápisu (off hot-path). |
| **`learn()` na hot-path** | `O(1)` in-memory mutace + **debounced atomický zápis** souboru. Žádný synchronní decode/encode/zápis per mezeru. |
| **Host-app editor** | `LearnedWordsEditor` přepnut na lazy list + search, ať uveze 10k řádků. Součást tohoto tasku. |
| **Členění** | **Jeden fázovaný task** (fáze 0 → A → B → C + cross-cutting editor), mergováno po fázích. |
| **`KeyboardState`** | Zůstává čistý value `struct` (InputDispatcher `inout` + KeyboardCore testy se **nemění**). `@Observable` je nová tenká vrstva v extension, ne v `KeyboardCore`. |
| **Async staleness** | Suggestion compute na background váže na snapshot `(prefix + kontext)`; výsledek zastaralý vůči aktuálnímu caretu se **zahodí**. Vložení znaku zůstává synchronně na mainu. |
| **Migrace** | **Žádná** — pre-release, žádní uživatelé (ani beta). Build, co přepne storage, startuje z prázdna; pool se přirozeně doučí psaním (platí i pro dev zařízení — vlastní test data se resetují, bereme). Staré UserDefaults klíče rovnou smazat. |
| **Cross-process invalidace** | Host edituje (remove/clear) → Darwin notifikace přes [`SettingsChangeNotifier`](../KeymojiCore/Sources/Shared/SettingsChangeNotifier.swift) → extension reload indexu. Baseline reload na `viewWillAppear`. |
| **Veřejné API store** | `matches / learn / remove / clear / allLearnedWords / count` + protokol `PersonalRecentsReading` **zachováno** → `WordCompletionProvider`, `LearnedWordsEditorViewModel` i existující testy beze změny chování. |
| **Profiling** | Signposty jsou **dev-only** (`#if DEBUG` / profiling build), do release se nedostane žádná nová instrumentace. Drží privacy claim „nesbíráme nic". |
| **Chování / scoring návrhů** | **Beze změny.** Tohle je čistě výkon; výstup identický. |

## Scope (fázovaně)

### Fáze 0 — Instrumentace & baseline (měřitelný před/po)

- Dev-only `os_signpost` (`#if DEBUG`) kolem `handle()`, `currentSuggestions()`, `matches()`, `learn()`, `rebuild()`. Neshipuje se.
- XCTest performance benchmarky v `KeyboardCore/Tests/Suggestions/` se syntetickým poolem 10k slov: `matches(prefix:)` a `learn()`. Zaznamenat **baseline čísla** do tasku (před → po).
- Zafixovat perf budget (viz Akceptační kritéria).

### Fáze A — Storage + lookup *(řeší kritický #1, vysoký #5, cap, eviction)*

- Nový souborový store v App Group containeru: drží `[word: (count, lastUsed)]`, atomický zápis (`Data.write(.atomic)` v `NSFileCoordinator` koordinaci). Nahrazuje UserDefaults JSON blob jako truth source.
- In-memory cache + prefix index (bucket podle foldnutého 1.–2. znaku) + předpočítaný folded key per slovo. `matches()` = `O(1 hash + k)` (`k` = velikost bucketu), **žádný** per-keystroke JSON decode, **žádné** per-keystroke folding alokace.
  - Bucket-mapa, **ne** seřazené pole + binary search — důvod: insert na `learn()` je `O(1)` append do bucketu vs. `O(n)` shift do seřazeného pole.
  - Bucket key = foldnutý **první** znak slova (1 znak jako baseline; 2 znaky jen pokud benchmark ukáže příliš velké buckety). Foldnutý prefix určí jeden bucket.
  - **Uvnitř bucketu pořád běží dnešní [`directionalPrefixMatch`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:75)** — bucket jen zúží kandidáty, **nemění výsledek**. Směrová diakritická sémantika (`c`→`c`/`č`, `č`→jen `č`) zůstává beze změny. To je invariant: výstup `matches()` je bit-identický s dnešním, jen rychlejší.
- Thread-safe přístup k indexu (actor nebo neměnný snapshot předaný compute tasku ve fázi C) — `matches()` poběží z background tasku.
- `learn()`: `O(1)` in-memory + debounced background atomický zápis. Eviction = amortizovaný batch-trim (ne per-learn `O(n)`).
- `capacity` 1000 → 10000.
- Žádná migrace dat (pre-release, žádní uživatelé) — store startuje z prázdna; pool se přirozeně doučí psaním. Staré UserDefaults klíče `wordCompletionRecents` / `…LastUsed` rovnou smazat (legacy, už se nečtou).
- Cross-process invalidace: host `remove`/`clear` → Darwin post; extension subscribe → reload index; `viewWillAppear` reload jako baseline.
- **Zachovat veřejné API + `PersonalRecentsReading`.** Store init injektovatelný adresářem/URL (jako `AppGroupStore(suiteName:)`) kvůli testovatelnosti.

### Fáze B — Rendering: `@Observable` scoped invalidace *(řeší kritický #2, střední makeLayout 2×)*

- Nová `@Observable` model vrstva v extension drží **granulární** publikované vlastnosti (layout-affecting state, `suggestions`, `favoriteEmojis`, …). `UIHostingController` se instaluje **jednou**; mutace in-place místo `rootView = makeRoot()`.
- Granularita: key grid závisí jen na layout-affecting vstupech (page/shift/layout/numberRow/returnKeyType/alternateSet) → na běžné písmeno se **nepřekresluje**; suggestion bar a favorites se aktualizují nezávisle.
- Stabilní closury (uložené reference, ne realokované v `makeRoot()`) + `Equatable` view vstupy → SwiftUI může short-circuitovat řádky/klávesy.
- `makeLayout()` **1×** (memoizovaný na layout-affecting vstupech), sdílený mezi view body a height výpočtem (`KeyboardRoot.body` + `desiredKeyboardHeight()` přestanou stavět dvakrát).
- Drobnost zdarma: cache `Set(UITextChecker.availableLanguages)` v `resolveLanguage`.
- `KeyboardState` zůstává value struct — pure logika a KeyboardCore testy netknuté.

### Fáze C — Suggestion pipeline: async + dedup *(řeší vysoké #3, #4)*

- Vložení znaku synchronně na mainu (instant press-feel). Suggestion compute → background (debounced, **cancellable** `Task`), výsledek aplikován na main do `@Observable` modelu. Staleness: snapshot `(prefix, kontext, page, jazyky, eligibility)`; zastaralé vůči aktuálnímu caretu zahodit.
- Coalescing rebuildů: `needsRebuild` flag / jeden flush per runloop turn. `refresh*` metody nevolají `rebuild()` opakovaně ve stejném stisku.
- Memoizace suggestions na `(prefix, page, jazyky, eligibility)` — opakovaný identický výpočet v jednom stisku zdarma.
- `UITextChecker` dotaz na background (není main-isolated; instance confinovaná per task).

### Cross-cutting — host-app editor lazy

- `LearnedWordsEditor` na lazy render (`List` / `LazyVStack`) + search/filter, ať uveze 10k řádků. `LearnedWordsEditorViewModel` sort přes 10k jen jednorázově na zobrazení (ne hot-path); ověřit, že načtení 10k a sort nezamrzne UI (případně async načtení do listu).

## Regresní síť

**Existující (musí projít beze změny chování):**
- [`PersonalRecentsStoreTests`](../KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift) — learn/match/evict/remove/clear, diacritic folding.
- [`WordCompletionProviderTests`](../KeyboardCore/Tests/Suggestions/WordCompletionProviderTests.swift), [`InputDispatcherSuggestionTests`](../KeyboardCore/Tests/Suggestions/InputDispatcherSuggestionTests.swift), [`SuggestionCoordinatorTests`](../KeyboardCore/Tests/Suggestions/SuggestionCoordinatorTests.swift).
- [`LearnedWordsEditorViewModelTests`](../Features/LearnedWordsEditor/Tests/LearnedWordsEditorViewModelTests.swift).
- **KeyboardUI snapshot suite** ([`KeyboardViewSnapshots`](../KeyboardUI/Tests/KeyboardViewSnapshots.swift), [`SuggestionBarViewSnapshots`](../KeyboardUI/Tests/SuggestionBarViewSnapshots.swift)) — **důkaz nulové UI změny = projde beze změny obrázků.**

**Nové (uvnitř tohoto tasku):**
- Perf benchmarky (fáze 0): `matches()` a `learn()` @10k, baseline → po.
- Cross-process invalidace: host `remove`/`clear` → extension reload (Darwin).
- Eviction @ cap 10k: batch-trim správnost (drží nejlepší podle count/lastUsed, deterministicky).
- Async staleness/cancellation: rychlá sekvence stisků → zobrazí se jen výsledek pro aktuální prefix, staré se zahodí.

## Akceptační kritéria (perf budget)

- **Žádný** per-keystroke JSON decode/encode ani UserDefaults zápis na hot-path.
- `matches(prefix:)` @10k: bez plného scanu, bez per-keystroke folding alokací; cíl řádově **< ~0.2 ms** na baseline zařízení (přesné číslo zafixovat z fáze 0).
- `learn()` na mezeru: `O(1)` in-memory + odložený zápis (synchronní část < ~0.1 ms).
- Key grid se **nepřekresluje** na stisk, který nemění layout (ověřit `_printChanges` / view-body counts v debug nebo signposty).
- Suggestion compute běží **mimo** hlavní vlákno; synchronní per-stisk práce = vložení znaku + state + naplánování.
- **Smooth at 10k:** na 120 Hz zařízení žádné dropnuté snímky při souvislém psaní s plným 10k poolem (manuální verifikace + Instruments / signposty).
- Privacy: žádná nová instrumentace/telemetrie v release buildu.

## Non-goals

- Next-word prediction / autocorrect — trvale out (viz [tasks/README.md](README.md) → Mimo scope).
- SQLite/GRDB nebo jakákoliv nová závislost — rozhodnuto pro souborový store.
- Změna chování/pořadí/scoringu návrhů nebo UI klávesnice — tohle je čistě výkon; výstup identický.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`** (ne `.xcodeproj`), simulátor iPhone 17 / iOS 26.2 (viz memory *keymoji-build-uses-workspace*).
- Perf budget se ověřuje na **fyzickém 120 Hz zařízení** s plným 10k poolem — simulátor nereprezentuje frame timing.
- Pozn.: `testPaywall_loadingPrice_dark` flakuje na tomto stroji nezávisle na změně (memory *keymoji-paywall-snapshot-flaky*) — není to regrese tohoto tasku.
