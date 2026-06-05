# 50 — Řazení naučených slov podle četnosti (`count`) + nový default

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Low

## Cíl

V `LearnedWordsEditorView` (task [48](48-learned-words-list-management.md)) jde dnes řadit jen dvěma
způsoby: `.recency` (default) a `.alphabetical`. Přidat **třetí** case do `LearnedWordsSort`, který
řadí `[LearnedWord]` podle `LearnedWord.count` **sestupně** (nejčastěji psaná slova nahoře), a udělat
z něj **nový default** místo `.recency`.

Po dokončení: editor se otevře seřazený od nejčastěji psaného slova; segmented picker nabízí tři
hodnoty (četnost / naposledy použité / A–Z).

## Kontext

- Sort enum + obě sortovací místa žijí v
  [`LearnedWordsEditorViewModel.swift`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift):
  - `enum LearnedWordsSort` ([:15-20](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift:15))
  - `init(..., sort: LearnedWordsSort = .recency)` ([:50-58](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift:50)) — **default tady**
  - `private func sorted(_:)` switch ([:86-96](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift:86))
- **Mock** má vlastní kopii sort logiky (musí zůstat v sync):
  [`LearnedWordsEditorViewModelMock.swift`](Features/LearnedWordsEditor/Testing/LearnedWordsEditorViewModelMock.swift) —
  `sorted(_:by:)` ([:36-46](Features/LearnedWordsEditor/Testing/LearnedWordsEditorViewModelMock.swift:36)) + default `sort: .recency` v initu ([:23](Features/LearnedWordsEditor/Testing/LearnedWordsEditorViewModelMock.swift:23)).
- **View** renderuje picker s explicitními `.tag(...)` per case:
  [`LearnedWordsEditorView.swift:31-34`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift:31).
  Přidání case → přibude `Text(...).tag(.mostUsed)`.
- **Lokalizace:** klíče `settings.learnedWords.sort.*` v
  [`en.lproj/Localizable.strings:99-100`](KeymojiResources/Resources/en.lproj/Localizable.strings:99),
  čteno přes `L10n.Settings.LearnedWords.Sort.*` (alias `Texts.Sort`).
- `LearnedWord.count` je `Int` (četnost napsání), žije v
  [`PersonalRecentsStore.swift`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift) — **beze změny**,
  jen ho čteme.

## Scope

### 1. Enum + nový default

`LearnedWordsEditorViewModel.swift`:

```swift
public enum LearnedWordsSort: Sendable, Hashable {
    /// Most-written first (default).
    case mostUsed
    /// Last-used first.
    case recency
    /// A→Z, case-insensitive.
    case alphabetical
}
```

- `init(..., sort: LearnedWordsSort = .mostUsed)` — změnit default z `.recency` na `.mostUsed`.
- `sorted(_:)` switch — přidat case:

```swift
case .mostUsed:
    return input.sorted {
        if $0.count != $1.count { return $0.count > $1.count }
        return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
    }
```

> Tie-break na `word` ASC (stejně jako `.recency`) → stabilní řazení, když má víc slov stejný `count`.

### 2. Mock v sync

`LearnedWordsEditorViewModelMock.swift`:
- default v initu `sort: LearnedWordsSort = .mostUsed`.
- `sorted(_:by:)` — přidat identický `.mostUsed` case.

### 3. View — picker

`LearnedWordsEditorView.swift`, picker ([:31-34](Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift:31)):
přidat řádek (jako první, ať je default vlevo):

```swift
Text(Texts.Sort.mostUsed).tag(LearnedWordsSort.mostUsed)
```

### 4. Lokalizace

`KeymojiResources/Resources/en.lproj/Localizable.strings` — nový klíč k existujícím `sort.*`:

```strings
"settings.learnedWords.sort.mostUsed" = "Most used";
```

- Přegenerovat SwiftGen `L10n` → `L10n.Settings.LearnedWords.Sort.mostUsed`.
- Pokud existují další `*.lproj`, přidat i tam (jinak fallback na en).

### 5. Testy

**`LearnedWordsEditorViewModelTests`**
([`...Tests.swift`](Features/LearnedWordsEditor/Tests/LearnedWordsEditorViewModelTests.swift)):
- Nový test: `.mostUsed` řadí podle `count` sestupně (seed slova s různými `count` — pozor, dnešní
  `seed(...)` dává všem count 1; rozšířit seed nebo seedovat víc `learn(...)` volání pro stejné slovo,
  aby `count` rostl).
- Nový test: **default je `.mostUsed`** — `LearnedWordsEditorViewModel(store:)` bez `sort:` argumentu
  vrátí slova seřazená podle `count`.
- Stávající testy `testRecencySort...` / `testAlphabeticalSort...` nastavují `sort` explicitně, takže
  zůstanou green. Ověřit, že `testRemoveAt_deletesTheDisplayedWord` (default sort) počítá se správným
  zobrazeným pořadím — dnes spoléhá na `.recency` default; po změně defaultu na `.mostUsed` buď
  explicitně nastavit `sort: .recency` v tom testu, **nebo** přepočítat očekávané pořadí.

**`LearnedWordsEditorSnapshots`**
([`...Snapshots.swift`](Features/LearnedWordsEditor/Tests/LearnedWordsEditorSnapshots.swift)):
- Přidat snapshot `testLearnedWordsEditor_mostUsed_dark` (sampleWords, `.mostUsed`) — vizuální důkaz
  řazení podle četnosti + nový 3-segment picker.
- Stávající `recency`/`alphabetical` snapshoty: picker teď má 3 segmenty místo 2 → layout se posune →
  **re-record** těchto dvou referencí.

## Mimo scope

- Vzestupné řazení podle `count` (nejmíň psaná nahoře) — nepotřebné.
- Změna persistence / `PersonalRecentsStore` — jen čteme `count`.
- Zobrazení/změna pořadí segmentů v pickeru nad rámec přidání `mostUsed` jako prvního.

## Hotovo když

- `LearnedWordsSort.mostUsed` existuje, řadí `[LearnedWord]` podle `count` sestupně (tie-break `word`).
- `.mostUsed` je default ve VM i mocku — editor se otevře seřazený podle četnosti.
- Picker nabízí 3 hodnoty; přepínání mezi nimi přerovná seznam.
- Mock sort logika je identická s VM.
- Lokalizační klíč `sort.mostUsed` přidán + `L10n` přegenerován.
- Nové VM testy (most-used řazení + default) green; upravené/stávající testy green.
- Nový `mostUsed` snapshot + re-recorded `recency`/`alphabetical` snapshoty green.

## Rizika

- **Posun defaultu rozbije test spoléhající na implicitní `.recency`** — `testRemoveAt...` ve VM testech.
  Opravit explicitním `sort:` nebo přepočítaným očekáváním.
- **Mock/VM drift** — sort logika je duplikovaná na dvou místech; přidat case do obou.
- **Snapshot drift** — 2 → 3 segmenty v pickeru posunou layout; re-record je očekávaný, ne bug.
  Zkontrolovat diff vizuálně.

## Reference

- [48 — Seznam naučených slov se správou](48-learned-words-list-management.md) — kde `LearnedWordsSort` a editor vznikly.
