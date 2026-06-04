# 48 — Seznam naučených slov se správou (zobrazit + mazat jednotlivě)

**Status:** Done — 2026-06-03

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium

## Cíl

Dnes Settings ukazuje jen **počet** naučených slov (`learnedWordCount`) a umí smazat **všechna**
najednou. Uživatel chce vidět, *jaká* slova to jsou, a mazat je **jednotlivě**.

Po dokončení: ze Settings (sekce Suggestions) vede `NavigationLink` na samostatnou obrazovku
**Learned words**, kde uživatel:

- vidí seznam všech naučených slov (každý řádek = slovo + kolikrát ho appka viděla),
- defaultně řazený **od naposledy použitého po nejstarší**,
- má **switch na abecední řazení**,
- maže slova **jednotlivě** (swipe-to-delete + EditButton),
- má i tlačítko **„Smazat vše"** (přesunuté sem ze Settings).

Settings dál ukazuje počet naučených slov, ale řádek se z „statického počtu + destruktivní tlačítko"
mění na **navigaci s počtem v trailing pozici**.

## Rozhodnutí (odsouhlaseno s uživatelem)

1. **Obsah řádku:** slovo + počet napsání (`count`). Žádné datum — působilo by creepy u PII slov.
2. **„Smazat vše":** přesunout ze Settings na novou obrazovku. Settings zůstane čistý — jen počet
   + navigace dál. (Žádná duplicita.)
3. **„Nejnovější":** = **naposledy použité** (řadíme podle `lastUsed`, který už máme). **Bez** změny
   schématu úložiště — nepřidáváme `firstLearned` timestamp.

## Kontext

- Data žijí v `PersonalRecentsStore`
  ([`PersonalRecentsStore.swift`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift)): dvě JSON
  mapy v `AppGroupStore` — `{slovo: count}` (`wordCompletionRecentsJSON`) a `{slovo: lastUsed}`
  (`wordCompletionRecentsLastUsedJSON`).
- Store dnes umí `count`, `matches(prefix:)`, `learn(_:fromContextType:)`, `clear()`. **Neumí** vypsat
  všechna slova ani smazat jedno konkrétní — to přidáme (Scope 1).
- **PII-adjacent** (viz docstring [`PersonalRecentsStore.swift:13-17`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:13)):
  pool může obsahovat jména, slang i celé e-mailové adresy. Nic neopouští zařízení; nové UI to nesmí
  nikam logovat ani posílat.
- Settings dnes:
  - VM `SettingsViewModel` drží `private(set) var learnedWordCount`, `refreshLearnedWordCount()`,
    `clearLearnedWords()` ([`SettingsViewModel.swift:90-125`](Features/Settings/Sources/SettingsViewModel.swift:90)).
    VM už má `recentsStore: PersonalRecentsStore` ([`SettingsViewModel.swift:94`](Features/Settings/Sources/SettingsViewModel.swift:94)).
  - View má `suggestionsSection` s počtem + destruktivní „Clear" tlačítko + alert
    ([`SettingsView.swift:128-145`](Features/Settings/Sources/SettingsView.swift:128)).
- **Vzor nové obrazovky:** `FavoriteEmojisEditor` — feature modul dosažený přes `NavigationLink`
  ze `SettingsView` ([`SettingsView.swift:171-181`](Features/Settings/Sources/SettingsView.swift:171)),
  s `List` + `.onDelete` + `EditButton` + `ContentUnavailableView` empty state
  ([`FavoriteEmojisEditorView.swift`](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift)),
  VM protokol + factory + `@Observable` impl ([`FavoriteEmojisEditorViewModel.swift`](Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift)),
  mock + snapshot testy.
- **Tuist registrace featury:** `Feature(...)` helper
  ([`FavoriteEmojisEditor.swift`](Tuist/ProjectDescriptionHelpers/Targets/Features/FavoriteEmojisEditor.swift)).
- **Lokalizace:** SwiftGen-generovaný `L10n` (`KeymojiResourcesStrings`,
  [`Aliases.swift`](KeymojiResources/Sources/Aliases.swift)) z `Localizable.strings`. Existující klíče
  `settings.suggestions.*` v [`en.lproj/Localizable.strings:93-101`](KeymojiResources/Resources/en.lproj/Localizable.strings:93).

## Scope

### 1. `PersonalRecentsStore` — list + delete jednoho slova

`KeyboardCore/Sources/Storage/PersonalRecentsStore.swift`. Přidat do `PersonalRecentsStore`
(NE do `PersonalRecentsReading` — to je úzký read protokol pro completion provider, sem nepatří):

```swift
/// One learned word with its frequency and last-used time. Drives the management screen.
public struct LearnedWord: Sendable, Equatable {
    public let word: String
    public let count: Int
    /// Seconds since 1970, from the last-used map. Used only for recency sorting.
    public let lastUsed: Double
}

/// All learned words, unsorted. The management screen owns the sort order.
public func allLearnedWords() -> [LearnedWord] {
    let counts = loadCounts()
    let lastUsed = loadLastUsed()
    return counts.map { LearnedWord(word: $0.key, count: $0.value, lastUsed: lastUsed[$0.key] ?? 0) }
}

/// Remove a single word from both maps. No-op if absent.
public func remove(_ word: String) {
    var counts = loadCounts()
    var lastUsed = loadLastUsed()
    guard counts[word] != nil || lastUsed[word] != nil else { return }
    counts[word] = nil
    lastUsed[word] = nil
    save(counts: counts, lastUsed: lastUsed)
}
```

> `loadCounts/loadLastUsed/save` jsou dnes `private` — `allLearnedWords`/`remove` je volají zevnitř,
> takže zůstávají private. `remove` drží oba mapy v synchronizaci stejně jako `learn`.
> Mazání je konzistentní s `clear()`: klávesnice čte recents živě, takže další keystroke vidí změnu
> bez cross-process pingu (žádný `notifier.post`).

### 2. Nový feature modul `LearnedWordsEditor`

Struktura dle [Feature Module Structure](../CLAUDE.md) a vzoru `FavoriteEmojisEditor`:

```
Features/LearnedWordsEditor/
├── Sources/
│   ├── LearnedWordsEditorView.swift
│   └── LearnedWordsEditorViewModel.swift
├── Testing/
│   └── LearnedWordsEditorViewModelMock.swift
└── Tests/
    └── LearnedWordsEditorSnapshots.swift
```

> Pozn.: vzorová `FavoriteEmojisEditor` nemá `*Dependencies.swift` (VM si bere `AppGroupStore = .shared`
> v initu). Držet stejný vzor — žádný `*Dependencies` soubor, pokud nepřibude netriviální závislost.

**Tuist target** `Tuist/ProjectDescriptionHelpers/Targets/Features/LearnedWordsEditor.swift`:

```swift
import Foundation

public let learnedWordsEditor = Feature(
    name: "LearnedWordsEditor",
    dependencies: [
        .target(name: core.name),
        .target(name: design.name),
        .target(name: resources.name),
        .target(name: keyboardCore.name) // PersonalRecentsStore / LearnedWord žijí v KeyboardCore
    ]
)
```

A zaregistrovat tam, kde se registruje `favoriteEmojisEditor` (najít všechna místa, kde se feature
list skládá — Workspace/Project agregace + Settings target dependency níže). `tuist generate` po přidání.

### 3. `LearnedWordsEditorViewModel`

Vzor `FavoriteEmojisEditorViewModel`. Sort je view-level stav řízený VM:

```swift
public enum LearnedWordsSort: Sendable {
    case recency      // naposledy použité první (default)
    case alphabetical // A→Z, case-insensitive
}

@MainActor
public protocol LearnedWordsEditorViewModeling: Observable, AnyObject {
    var words: [LearnedWord] { get }   // už seřazené dle `sort`
    var sort: LearnedWordsSort { get set }
    func remove(at offsets: IndexSet)  // offsets do AKTUÁLNĚ zobrazeného (seřazeného) pole
    func clearAll()
}
```

- `words` vrací seřazené pole podle `sort`:
  - `.recency`: `sorted { $0.lastUsed > $1.lastUsed }`, tie-break `word` ASC pro stabilitu.
  - `.alphabetical`: `sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }`.
- `sort` `didSet` jen přerovná (data se nenačítají znovu z disku).
- `remove(at:)`: namapovat offsety na slova z *aktuálně zobrazeného* pole → `store.remove(word)` pro
  každé → reload `words` ze store. (Mazat podle slova, ne podle indexu do store — pořadí ve store je
  dictionary-undefined.)
- `clearAll()`: `store.clear()` → `words = []`.
- Init si načte slova ze `store.allLearnedWords()` (default `recentsStore = PersonalRecentsStore(store: .shared)`).
- Factory `public func learnedWordsEditorVM() -> some LearnedWordsEditorViewModeling`.

### 4. `LearnedWordsEditorView`

Vzor `FavoriteEmojisEditorView`:

- `navigationTitle(Texts.title)`, `.navigationBarTitleDisplayMode(.inline)`.
- **Empty state** (`words.isEmpty`): `ContentUnavailableView` — ikona `text.book.closed` / `character`,
  title + message vysvětlující, že appka se učí slova z psaní (viz lokalizace).
- **Seznam** (neprázdný): `List` se sekcí:
  - nahoře (header nebo samostatná sekce) **Picker / segmented** pro `sort`
    (`Recently used` ↔ `Alphabetical`), bind na `$viewModel.sort`. (Zadání říká „switch na abecední
    řazení" — segmented picker se 2 hodnotami je čistší než `Toggle` a rozšiřitelný.)
  - `ForEach(viewModel.words, id: \.word)` → řádek `slovo` (primary) + `count` jako sekundární
    trailing text (`"\(count)×"` nebo přes formátovaný string — viz lokalizace), `.foregroundStyle(.secondary)`.
  - `.onDelete { viewModel.remove(at: $0) }`.
- **Toolbar:**
  - `.topBarLeading`: `EditButton()` (jen když neprázdné).
  - `.topBarTrailing`: tlačítko **„Smazat vše"** (role `.destructive`), které ukáže potvrzovací
    `alert` (přesunutý ze Settings) → `viewModel.clearAll()`.
- Accessibility: `accessibilityLabel` „slovo, naučeno Nkrát".
- `#if DEBUG` previews: „With words" (mock s pár slovy v obou sortech) + „Empty".

> `id: \.word` je stabilní (slova jsou unikátní klíče v mapě) → SwiftUI diffuje reorder při změně sortu
> i delete korektně.

### 5. Settings — řádek na navigaci

`Features/Settings/Sources/SettingsView.swift`, `suggestionsSection`
([`SettingsView.swift:128-145`](Features/Settings/Sources/SettingsView.swift:128)):

- Nahradit blok „počet + destruktivní Clear tlačítko" za **`NavigationLink`** na
  `LearnedWordsEditorView(viewModel: learnedWordsEditorVM())`, label = `Texts.Suggestions.learnedWordsLabel`
  s počtem v trailing pozici (vzor: `HStack { Text(label).maxWidthLeading(); Text("\(count)").foregroundStyle(.secondary) }`
  uvnitř `NavigationLink`, nebo `LabeledContent`-style). Počet zůstává viditelný — splňuje „user dál
  vidí, kolik slov se app naučila".
- **Odstranit** ze `SettingsView`: `showClearLearnedWordsAlert` state ([`SettingsView.swift:23`](Features/Settings/Sources/SettingsView.swift:23)),
  `.alert(...)` blok ([`SettingsView.swift:43-50`](Features/Settings/Sources/SettingsView.swift:43)),
  „Clear" tlačítko. Alert + clear logika se stěhuje do nové obrazovky.
- `import LearnedWordsEditor` nahoře ([`SettingsView.swift:15-18`](Features/Settings/Sources/SettingsView.swift:15)).
- **Settings Tuist target** musí přibrat dependency na `learnedWordsEditor` (vedle `favoriteEmojisEditor`,
  `emojiCodes`, `about`, `onboarding`) — najít Settings `Feature(...)` definici a přidat.

> **`clearLearnedWords()` v `SettingsViewModel`:** po přesunu alertu už ho `SettingsView` nevolá. Buď
> ho z `SettingsViewModeling` odstranit (+ z mocku), NEBO ponechat a nechat `clearAll` žít jen v nové
> VM. **Doporučení:** odstranit `clearLearnedWords()` z `SettingsViewModeling`/`SettingsViewModel`/mocku
> — clear logika nově patří `LearnedWordsEditorViewModel`. `refreshLearnedWordCount()` zůstává (počet se
> dál ukazuje a klávesnice ho mění out-of-process; refresh na `onAppear` Settings je stále potřeba, aby
> se po návratu z editoru počet aktualizoval).

### 6. `SettingsViewModelMock`

Po odstranění `clearLearnedWords()` z protokolu smazat i z mocku
([`SettingsViewModelMock.swift:50-52`](Features/Settings/Testing/SettingsViewModelMock.swift:50)).

### 7. Lokalizace

`KeymojiResources/Resources/en.lproj/Localizable.strings` — nové klíče:

```strings
"settings.learnedWords.title" = "Learned words";
"settings.learnedWords.sort.recency" = "Recently used";
"settings.learnedWords.sort.alphabetical" = "A–Z";
"settings.learnedWords.count" = "%d×";   // počet napsání za slovem
"settings.learnedWords.clearAll" = "Clear all";
"settings.learnedWords.emptyTitle" = "No learned words yet";
"settings.learnedWords.emptyMessage" = "Keymoji learns words as you type and offers them as suggestions — all on this iPhone. They'll appear here.";
"settings.learnedWords.listFooter" = "Swipe a word to delete it. Apple's built-in suggestions are not affected.";
```

- Přesunout/recyklovat existující clear-alert klíče `settings.suggestions.clearAlert*` +
  `settings.suggestions.clearButton`/`clearFooter` ([`Localizable.strings:97-101`](KeymojiResources/Resources/en.lproj/Localizable.strings:97))
  pro alert na nové obrazovce (alert text „This permanently removes all words…" sedí 1:1). Nepoužité
  klíče po přesunu odstranit, ať `L10n` nebobtná.
- Po úpravě `.strings` přegenerovat SwiftGen `L10n` (dle build pipeline projektu) — `L10n.Settings.LearnedWords.*`.
- Pokud existují další lokalizace (`*.lproj`), přidat klíče i tam (nebo nechat fallback na en).

### 8. Testy

**`PersonalRecentsStoreTests`** ([`KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift`](KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift)):
- `allLearnedWords()` vrátí všechna slova s odpovídajícím `count` a `lastUsed`.
- `remove(word)` smaže z obou map; `count` klesne o 1; ostatní slova beze změny.
- `remove` neexistujícího slova = no-op (nic se nerozbije).
- `allLearnedWords()` na prázdném store = `[]`.

**`LearnedWordsEditorSnapshots`** (nová, vzor `FavoriteEmojisEditorSnapshots`):
- Seznam, `.recency` sort (dark).
- Seznam, `.alphabetical` sort (dark) — vizuální důkaz přerovnání.
- Empty state (dark).

**`SettingsSnapshots`** ([`Features/Settings/Tests/SettingsSnapshots.swift`](Features/Settings/Tests/SettingsSnapshots.swift)):
- suggestions sekce se mění (řádek → navigace, pryč „Clear" tlačítko) → re-record dotčených referencí.

**VM unit test (volitelně, doporučeno):** `LearnedWordsEditorViewModel` — sort přerovná správně,
`remove(at:)` na recency-seřazeném poli smaže to správné slovo, `clearAll` vyprázdní.

## Mimo scope

- **Editace slov** (přejmenování/úprava) — jen zobrazení + mazání, ne edit.
- **Přidání slova ručně** — pool se plní jen psaním na klávesnici.
- **`firstLearned` timestamp / „date added"** — neukládáme, „nejnovější" = naposledy použité (rozhodnutí 3).
- **Hledání/filtrování v seznamu** — při capacity 500 není search nutný. (Pozn.: kdyby UX při ~500
  slovech drhl, je to follow-up, ne tento task.)
- **Per-word „nikdy nenabízej" blocklist** — mazání slovo jen odstraní; když ho user napíše znova,
  appka se ho znovu naučí. Trvalý blocklist je out of scope.
- **Cross-process notifikace** — klávesnice čte recents živě, mazání se projeví dalším keystrokem.

## Hotovo když

- `PersonalRecentsStore.allLearnedWords()` a `remove(_:)` existují + pokryté testy (green).
- Nový modul `LearnedWordsEditor` (View + VM + mock + snapshoty), zaregistrovaný v Tuistu, `tuist generate`/`build` projde.
- Ze Settings → Suggestions vede `NavigationLink` „Learned words" s počtem v trailing pozici na novou obrazovku.
- Obrazovka řadí default od naposledy použitého; segmented switch přepne na abecední řazení.
- Swipe-to-delete + EditButton mažou jednotlivá slova; „Smazat vše" s potvrzovacím alertem maže všechna.
- Po smazání (jednotlivě i vše) a návratu do Settings je počet aktualizovaný (`refreshLearnedWordCount` na `onAppear`).
- Empty state se zobrazí, když nejsou žádná slova.
- `clearLearnedWords()` + alert odstraněny ze `SettingsView`/`SettingsViewModel`/mocku; clear žije v nové VM.
- Re-recorded `SettingsSnapshots` + nové `LearnedWordsEditorSnapshots` green.

## Rizika

- **Sort offset mapping u mazání** — `.onDelete` offsety jsou do *zobrazeného* (seřazeného) pole.
  Mazat podle `word`, ne podle indexu do dictionary, jinak smaže špatné slovo. Pokrýt VM testem.
- **Settings Tuist dependency** — bez přidání `learnedWordsEditor` do Settings targetu `import` neslinkuje.
  Stejně jako u `favoriteEmojisEditor` ověřit linkování po `tuist generate`.
- **Snapshot drift** — změna suggestions sekce posune Settings layout → očekávaný re-record, zkontrolovat
  diff vizuálně. Ne bug.
- **PII v previews/snapshotech** — mock data použít neutrální/smyšlená slova (`hello`, `keyboard`, `emoji`…),
  nikdy ne reálná PII. Snapshoty se commitují do repa.
- **Prázdná `lastUsed` u starých záznamů** — fallback `?? 0` → seřadí se na konec recency listu. OK,
  ale ověřit, že to nerozbije stabilní řazení (tie-break na `word`).

## Reference

- [40 — Word completion suggestions](40-word-completion-suggestions.md) — odkud se `PersonalRecentsStore` a learned words berou.
- [33 — Feature modules & VM refactor](33-feature-modules-and-vm-refactor.md) — vzor split featur + VM pattern.
- `FavoriteEmojisEditor` (modul) — nejbližší vzor: NavigationLink ze Settings → List + onDelete + EditButton + empty state + snapshoty.

## Codex review

**Ano** — dotýká se persistence (`PersonalRecentsStore` mazání, synchronizace dvou map) a PII-adjacent
dat. Spustit `codex review --uncommitted` před closing commitem, primárně na: korektnost `remove`
(sync obou map), sort/offset mapping při mazání, a že clear logika nezůstala duplicitně na dvou místech.
