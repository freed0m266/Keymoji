# 51 — Řazení favorites baru podle četnosti používání

**Status:** Waiting

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium

## Cíl

Dnes se favorites bar v [`SuggestionBarView`](KeyboardUI/Sources/Views/SuggestionBarView.swift) zobrazuje
**přesně v ručním pořadí**, které si user nastavil dragem v
[`FavoriteEmojisEditorView`](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift).
Přidat usero­vi v editoru **živý přepínač řazení**:

- **Ruční pořadí** (`.manual`) — dnešní chování, drag-to-reorder. **Zůstává defaultem.**
- **Podle četnosti** (`.frequency`) — bar se řadí dynamicky podle toho, jak často daný emoji používáš
  (sestupně). Pořadí se průběžně „učí“ a mění s používáním.

Klíčová zjištění z průzkumu kódu, která tvarují návrh:

- **Četnost se dnes nikde nesleduje.** Existuje jen `recentEmojis` (řazení podle *recency*, bez počtů,
  capped na 30). Pro řazení podle četnosti musíme **nově začít počítat** každé vložení emoji.
- **Start od nuly** — žádná migrace, počítání nabíhá až po nasazení (viz [Rizika](#rizika)).
- **Počítá se každé vložení emoji kdekoli** (favorites bar, emoji panel, hledání, Slack `:shortcode:`
  substituce) — ne jen tap ve favorites baru.
- Ruční pořadí v `store.favoriteEmojis` **zůstává jediným zdrojem pravdy**. Frekvenční řazení je jen
  **pohled (presentation sort)** nad tímto polem — nic se nepřeukládá, přepnutí zpět na `.manual`
  obnoví původní ruční pořadí beze ztráty.

## Kontext

**Persistence — [`AppGroupStore`](KeymojiCore/Sources/Shared/AppGroupStore.swift):**
- Wrapper umí jen `bool` / `string` / `stringArray`. Dictionary `{emoji: count}` uložíme jako **JSON
  string** — stejný vzor jako `wordCompletionRecentsJSON` ([:152](KeymojiCore/Sources/Shared/AppGroupStore.swift:152)).
- Enum nastavení (`AppearancePreference`, `LetterLayout`) se ukládá jako raw string s fallbackem na
  default — vzor pro `FavoritesSortMode` ([:120-126](KeymojiCore/Sources/Shared/AppGroupStore.swift:120)).
- Klíče: [`AppGroupStoreKey`](KeymojiCore/Sources/Shared/AppGroupStoreKey.swift) enum.

**Cross-process notifikace — [`SettingsChangeNotifier`](KeymojiCore/Sources/Shared/SettingsChangeNotifier.swift):**
- `post(_ key: AppGroupStoreKey)` / `addObserver(for: AppGroupStoreKey)` — **kanál = `AppGroupStoreKey`**.
  Nový klíč `.favoritesSortMode` automaticky dá nový notifikační kanál.

**Počítání vložení — [`KeyboardViewController`](KeyboardExtension/Sources/KeyboardViewController.swift):**
- **Dvě** insertion cesty pro emoji:
  1. Synth `emoji.` key → `recordRecentEmojiIfNeeded(key:)` ([:581-593](KeyboardExtension/Sources/KeyboardViewController.swift:581)).
  2. Slack `:shortcode:` substituce → `applySlackSuggestion(emoji:)` ([:484-512](KeyboardExtension/Sources/KeyboardViewController.swift:484)),
     která bumpuje recents přímo (synth key se nevytváří).
- Obě cesty musí bumpnout i count → vyčlenit jeden helper.

**Stav klávesnice — [`KeyboardState`](KeyboardCore/Sources/Models/KeyboardState.swift):**
- Drží runtime zrcadla store nastavení (`favoriteEmojis`, `recentEmojis`, `letterLayout`…),
  plněná v `refreshFromStore()` ([:163+](KeyboardExtension/Sources/KeyboardViewController.swift:163)).

**Render baru — [`KeyboardRoot`](KeyboardExtension/Sources/KeyboardRoot.swift):**
- Předává `favoriteEmojis: state.favoriteEmojis` do `KeyboardView` ([:32](KeyboardExtension/Sources/KeyboardRoot.swift:32))
  → `SuggestionBarView`. **`SuggestionBarView` zůstává „hloupý“** — jen renderuje pole, které dostane.

**Editor — [`FavoriteEmojisEditorViewModel`](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift)
+ [View](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift)
+ [Mock](Features/FavoriteEmojisEditor/Testing/FavoriteEmojisEditorViewModelMock.swift).**
Host app sdílí stejný App Group store → editor umí číst counts a zobrazit náhled frekvenčního pořadí.

## Scope

### 1. Model řazení — `FavoritesSortMode` (KeymojiCore)

Nový public enum vedle `LetterLayout` / `AppearancePreference`:

```swift
public enum FavoritesSortMode: String, Sendable, CaseIterable {
    /// User's hand-curated drag order (default — preserves today's behavior).
    case manual
    /// Most-used emoji first, by insertion count, descending.
    case frequency
}
```

### 2. Pure ordering helper — `FavoritesOrdering` (KeymojiCore)

Jediné místo s logikou řazení, testovatelné a sdílené mezi extension i editorem:

```swift
public enum FavoritesOrdering {
    /// Returns `favorites` ordered for display. `.manual` → unchanged. `.frequency` → by `counts`
    /// descending; emojis with equal/missing count keep their relative order in `favorites`
    /// (stable tie-break → deterministic, and zero-count favorites stay in manual order day one).
    public static func ordered(
        _ favorites: [String],
        counts: [String: Int],
        mode: FavoritesSortMode
    ) -> [String] {
        guard mode == .frequency else { return favorites }
        return favorites.enumerated().sorted { lhs, rhs in
            let lc = counts[lhs.element] ?? 0
            let rc = counts[rhs.element] ?? 0
            if lc != rc { return lc > rc }
            return lhs.offset < rhs.offset   // stable: preserve manual order on ties
        }.map(\.element)
    }
}
```

> Tie-break na původní index zaručuje, že při startu od nuly (všechny counts 0) vrátí frekvenční
> režim **přesně ruční pořadí** — feature je „tichá“, dokud se nenasbírají data.

### 3. Persistence — `AppGroupStore` + klíče

`AppGroupStoreKey`: přidat `case favoritesSortMode` a `case emojiUsageCounts`.

`AppGroupStore` typed accessory:

```swift
/// Favorites bar ordering. Defaults to `.manual` (today's hand-curated drag order).
var favoritesSortMode: FavoritesSortMode {
    get {
        guard let raw = string(forKey: .favoritesSortMode) else { return .manual }
        return FavoritesSortMode(rawValue: raw) ?? .manual
    }
    set { setString(newValue.rawValue, forKey: .favoritesSortMode) }
}

/// Per-emoji lifetime insertion counts `{ emoji: count }`, stored as JSON. Bumped by the keyboard
/// extension on every emoji insertion; read to drive `.frequency` favorites ordering.
var emojiUsageCounts: [String: Int] {
    get {
        guard let json = string(forKey: .emojiUsageCounts),
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }
    set {
        guard let data = try? JSONEncoder().encode(newValue),
              let json = String(data: data, encoding: .utf8)
        else { return }
        setString(json, forKey: .emojiUsageCounts)
    }
}
```

> Mírně preferuj malý `incrementUsage(of:)` helper na storu (read-modify-write jednoho emoji), ať se
> v controlleru nepíše dekód/enkód celého dictionary na každý tap. Alternativa: bumpovat in-memory
> zrcadlo ve `state` a persistovat (viz krok 5).

### 4. Počítání vložení — `KeyboardViewController`

Vyčlenit helper a volat ho z **obou** insertion cest:

```swift
/// Bumps the lifetime usage count for `emoji` (any insertion path) and persists. Drives
/// `.frequency` favorites ordering. Keep in sync with the two emoji insertion sites.
private func incrementEmojiUsage(_ emoji: String) {
    guard !emoji.isEmpty else { return }
    state.emojiUsageCounts[emoji, default: 0] += 1
    store.emojiUsageCounts = state.emojiUsageCounts   // or store.incrementUsage(of: emoji)
}
```

- Zavolat v `recordRecentEmojiIfNeeded(key:)` (synth `emoji.` key) — hned po extrakci `emoji`.
- Zavolat v `applySlackSuggestion(emoji:)` — vedle stávajícího recents bumpu.

### 5. Stav + render — `KeyboardState`, `refreshFromStore`, `KeyboardRoot`

- `KeyboardState`: přidat `public var favoritesSortMode: FavoritesSortMode` a
  `public var emojiUsageCounts: [String: Int]` (+ init parametry, default `.manual` / `[:]`).
- `refreshFromStore()`: zrcadlit `store.favoritesSortMode` a `store.emojiUsageCounts` do `state`
  (stejný `if changed` vzor jako ostatní pole).
- Observers ([:140-156](KeyboardExtension/Sources/KeyboardViewController.swift:140)): přidat
  `settingsNotifier.addObserver(for: .favoritesSortMode) { self?.refreshFromStore() }`.
- `viewWillAppear` / seed: načíst obě hodnoty stejně jako `favoriteEmojis`.
- **`KeyboardRoot`** ([:32](KeyboardExtension/Sources/KeyboardRoot.swift:32)) — místo `state.favoriteEmojis` předat:

```swift
favoriteEmojis: FavoritesOrdering.ordered(
    state.favoriteEmojis,
    counts: state.emojiUsageCounts,
    mode: state.favoritesSortMode
),
```

> `incrementEmojiUsage` mutuje `state.emojiUsageCounts` → po každém tapu `rebuild()` → bar se
> v `.frequency` přerovná **živě**. `SuggestionBarView` se nemění.

### 6. Editor — ViewModel + View + Mock

**`FavoriteEmojisEditorViewModeling`** rozšířit:

```swift
var sortMode: FavoritesSortMode { get set }
/// Favorites in the order they'll appear in the bar — manual order, or frequency-sorted.
var displayedFavorites: [String] { get }
```

**`FavoriteEmojisEditorViewModel`:**
- `sortMode` čte/zapisuje `store.favoritesSortMode`; setter zavolá `notifier.post(.favoritesSortMode)`
  (živé propsání do klávesnice).
- `displayedFavorites` = `FavoritesOrdering.ordered(favorites, counts: store.emojiUsageCounts, mode: sortMode)`.
- **Remove/move musí operovat nad uloženým ručním polem, ne nad displayed indexy:**
  - View teď iteruje `displayedFavorites`. V `.frequency` se displayed pořadí ≠ stored pořadí, takže
    `remove(at offsets:)` dostane offsety do *displayed* listu. Přemapovat: offset → emoji
    (`displayedFavorites[offset]`) → `favorites.removeAll { $0 == emoji }` → `persist()`.
  - `move` má smysl jen v `.manual` (v `.frequency` je pořadí odvozené) → ve `.frequency` drag skrýt.

**`FavoriteEmojisEditorView`:**
- Nad list/empty state přidat **segmented `Picker`** vázaný na `viewModel.sortMode`
  (`Ruční pořadí` / `Podle četnosti`) — např. v `Section` v listu nebo pod navigation barem.
- `ForEach` iteruje `viewModel.displayedFavorites` (místo `favorites`).
- `.onMove` + `EditButton` zobrazit **jen** pro `sortMode == .manual`. Ve `.frequency` footer změnit
  na text typu „Pořadí se řídí četností používání.“ a skrýt drag handle.
- `.onDelete` ponechat v obou režimech (remap dle ViewModelu výše).

**`FavoriteEmojisEditorViewModelMock`:** přidat `sortMode` (uložené property) + `displayedFavorites`
(lokální `FavoritesOrdering.ordered` nad injektovaným `counts` slovníkem — přidat init param
`counts: [String: Int] = [:]`), aby šly previews/snapshoty obou režimů.

### 7. Lokalizace

`KeymojiResources/Resources/en.lproj/Localizable.strings` — k existujícím `settings.favorites.*`
([:81-89](KeymojiResources/Resources/en.lproj/Localizable.strings:81)):

```strings
"settings.favorites.sort.title" = "Order";
"settings.favorites.sort.manual" = "Manual";
"settings.favorites.sort.frequency" = "Most used";
"settings.favorites.frequencyFooter" = "Favorites are ordered by how often you use them.";
```

- Přegenerovat SwiftGen `L10n` → `L10n.Settings.Favorites.Sort.*` / `.frequencyFooter`.
- Přidat i do dalších `*.lproj`, pokud existují (jinak fallback na en).

### 8. Testy

- **`FavoritesOrdering`** (KeymojiCore tests): `.manual` = passthrough; `.frequency` řadí podle counts
  desc; **prázdné counts → vrátí přesně vstupní pořadí** (start od nuly); tie na count → stabilní
  podle původního indexu; emoji bez záznamu v `counts` se bere jako 0.
- **`AppGroupStore`**: `emojiUsageCounts` JSON round-trip (zápis → čtení); `favoritesSortMode` default
  `.manual` + persistence raw stringu + fallback neznámého rawValue na `.manual`.
- **`FavoriteEmojisEditorViewModelTests`**: set `sortMode` persistuje + postuje notifikaci;
  `displayedFavorites` v obou režimech; `remove(at:)` ve `.frequency` smaže **správný emoji**
  (regrese mapování offset→emoji, ne offset→stored index).
- **`FavoriteEmojisEditorSnapshots`**: nový `..._frequency_dark` (sortMode `.frequency`, mock s counts,
  bez drag handle, frekvenční footer) + **re-record** stávajícího favorites snapshotu (přibyl picker →
  posun layoutu — očekávané, ne bug).
- **Extension**: pokud existují testy `recordRecentEmojiIfNeeded` / dispatcheru, přidat assert, že
  vložení emoji bumpne `emojiUsageCounts` (obě cesty: synth key i Slack substituce).

## Mimo scope

- **Migrace / seedování counts** z `recentEmojis` — vědomě začínáme od nuly (viz Rizika).
- **Vzestupné / časově vážené řazení** (decay, „za posledních 7 dní“) — jen prostý lifetime count.
- **Pruning `emojiUsageCounts`** — dict je malý (řádově desítky–stovky emoji); cap neřešíme.
- **Řazení emoji panelu / recents tabu** podle počtů — týká se jen favorites baru.
- Změna `SuggestionBarView` — zůstává beze změny (dostává hotové pořadí).
- Per-emoji zobrazení počtu v editoru (badge s číslem) — případně samostatný task.

## Hotovo když

- V editoru je přepínač **Ruční pořadí / Podle četnosti**; default je `.manual` (beze změny chování).
- V `.frequency` se favorites bar v klávesnici řadí podle počtů sestupně a **živě** se přerovnává,
  jak emoji používáš; přepnutí zpět na `.manual` obnoví původní ruční pořadí.
- Každé vložení emoji (favorites bar, panel, hledání, Slack substituce) zvýší jeho count o 1 a persistuje se.
- Ruční pořadí v `store.favoriteEmojis` se frekvenčním režimem **nepřepisuje**.
- Editor ve `.frequency` zobrazuje náhled frekvenčního pořadí, skrývá drag a remove maže správný emoji.
- `FavoritesOrdering` při prázdných counts vrací přesně vstup (start od nuly = žádná vizuální změna).
- Sort logika žije **jen** ve `FavoritesOrdering` (extension i editor ji sdílí; mock v sync).
- Lokalizační klíče přidány + `L10n` přegenerován.
- Nové unit/VM testy green; nový + re-recorded snapshot green.

## Rizika

- **Den 1 = žádná data.** Counts startují prázdné → `.frequency` první dny nic nezmění (vrací ruční
  pořadí). To je záměr, ne bug; UX to nesmí prezentovat jako „rozbité“. Footer to vysvětluje.
- **Bar se může přerovnat pod prstem.** Tap na favorita zvýší jeho count → ve `.frequency` se po
  `rebuild()` může emoji posunout. V praxi vložení textu často naplní suggestions a bar se skryje, ale
  ověřit, že to nepůsobí trhaně; případně přerovnat až při dalším otevření baru (mimo scope, jen pozn.).
- **Mapování offset→emoji při remove.** Hlavní past: ve `.frequency` jsou displayed indexy ≠ stored
  indexy. `remove(at offsets:)` musí mazat podle hodnoty emoji, ne podle stored indexu — jinak smaže
  špatný favorit. Pokryto testem.
- **Dvě insertion cesty.** Slack substituce nejde přes synth `emoji.` key — když se count bumpne jen
  v `recordRecentEmojiIfNeeded`, Slack vložení se nezapočítá. Bumpovat v obou (stejný problém jako u
  recents, viz [:498-507](KeyboardExtension/Sources/KeyboardViewController.swift:498)).
- **Dva zdroje pravdy pro counts.** `state.emojiUsageCounts` (live) vs `store.emojiUsageCounts`
  (persist). Držet je v sync po každém bumpu; `refreshFromStore` je nepřepíše živými daty, pokud se
  zrcadlí stejným `if changed` vzorem.
- **Snapshot drift.** Přidaný picker posune layout stávajícího favorites snapshotu → re-record je
  očekávaný. Zkontrolovat diff vizuálně.

## Reference

- [44 — Oblíbené emoji v suggestion baru](44-favorite-emojis-in-suggestion-bar.md) — vznik favorites baru.
- [49 — Favorites bar TabView stránkování](49-favorites-bar-tabview-paging.md) — aktuální render baru.
- [50 — Řazení naučených slov podle četnosti](50-learned-words-sort-by-count.md) — analogický „sort by count“ vzor (sort enum + default + picker + lokalizace + snapshoty).
- [18 — Oblíbené emoji](18-favorite-emojis.md) — původ favorites + editoru.
