# 58 — Jazykové sady letterAlternates + popup vždy se základním písmenem

**Status:** Done — 2026-06-12

**Priorita:** v1.x · **Úsilí:** M · **Dopad:** High (daily typing flow pro neanglické jazyky)

## Cíl

Dvě provázané věci kolem long-press diakritiky:

1. **Jazykové sady diakritiky.** Dnes je `letterAlternates` jeden napevno zadrátovaný seznam míchající češtinu + západoevropskou diakritiku — pod `a` vyskočí 8 znaků, z nichž čeština používá jediný (`á`). Uživatel si v host appce zvolí **jednu aktivní sadu** podle jazyka; každá sada obsahuje **jen** diakritiku, kterou daný jazyk reálně používá. Podporované sady: **Čeština, Slovenčina, Deutsch, Polski, Français, Español** + **Vše** (dnešní kompletní mapa, fallback pro bilingvní / nepodporovaný region).

2. **Popup se objeví vždy (u písmen) a začíná základním písmenem.** Dnes podržení klávesy s jediným alternátem (např. `r` → `ř`) rovnou commitne bez popupu. Nově popup u písmen vyskočí vždy a jeho **první buňka je základní písmeno** — `r` → `[r, ř]`. Defaultně zvýrazněná je buňka 0 (základní písmeno), takže podržení + puštění bez slajdu vloží **základní písmeno** (totéž co tap); akcent se vybere slajdem doprava. Písmeno bez diakritiky v dané sadě má prázdné pole alternátů → žádný popup.

Default sada se při prvním (i upgrade) spuštění odvozuje z locale: **jazyk primárně, region jako fallback, „Vše" jako poslední záchrana**.

## Kontext

- `letterAlternates` je dnes `private static let [Character: [String]]` v [KeyboardCore/Sources/Logic/LayoutBuilder.swift:85](KeyboardCore/Sources/Logic/LayoutBuilder.swift). Konzumuje ho `makeLetterKey(_:shift:)` ([:147](KeyboardCore/Sources/Logic/LayoutBuilder.swift:147)) — sestaví `alternates` z mapy, nacasuje podle shiftu přes `posixUppercased()`.
- Auto-commit jednoho alternátu žije v UI: [KeyboardUI/Sources/Views/KeyView.swift:404](KeyboardUI/Sources/Views/KeyView.swift) v `startLongPressTimer()` — `if key.alternates.count == 1 { commit immediately }`. **Tuhle větev NEODSTRAŇUJEME** — slouží number row (viz níže).
- **Mechanika „popup vždy u písmen" se řeší v datech, ne v gestures:** když do letter-alternátů předřadíme základní písmeno, je `alternates.count` u písmene buď `0` (žádná diakritika → žádný popup), nebo `≥ 2` (base + ≥1 akcent → popup). Větev `count == 1` tak písmena nikdy netrefí. Number row si svůj `count == 1` auto-commit (`1` → `!`) ponechá beze změny. Nižší riziko než sahat do gesture kódu.
- Vzor pro string-enum preferenci řízenou locale neexistuje 1:1, ale skládá se ze dvou hotových vzorů:
  - `LetterLayout` ([KeymojiCore/Sources/Shared/LetterLayout.swift](KeymojiCore/Sources/Shared/LetterLayout.swift)) — enum v `KeymojiCore`, raw value v `AppGroupStore`, data (řádky) v `LayoutBuilder` (`KeyboardCore`). Stejný dvoumodulový split použijeme: **enum + detekce v `KeymojiCore`, znakové mapy v `LayoutBuilder`**.
  - `spaceDoubleTapAction` (task 36) — kompletní plumbing string-enum preference: `AppGroupStoreKey` → typed accessor → `KeyboardState` → `viewWillAppear` re-read → `SettingsViewModel` `didSet` + notifier → Picker → L10n.
- Cross-process refresh: `KeyboardViewController.viewWillAppear` → `refreshFromStore()` ([:193](KeyboardExtension/Sources/KeyboardViewController.swift:193)) + Darwin observer v `installSettingsObservers()` ([:167](KeyboardExtension/Sources/KeyboardViewController.swift:167)). `letterLayout` je tam přesný vzor ([:172](KeyboardExtension/Sources/KeyboardViewController.swift:172), [:205](KeyboardExtension/Sources/KeyboardViewController.swift:205)).
- `.insertText` vs `.insertRawText` ([KeyboardCore/Sources/Logic/InputDispatcher.swift:35](KeyboardCore/Sources/Logic/InputDispatcher.swift) a [:43](KeyboardCore/Sources/Logic/InputDispatcher.swift:43)): downstream identické (ShiftStateMachine, space-tracking, slack, učení slov), liší se jen tím, že `.insertRawText` přeskakuje shift-casing (alternáty chodí už nacasované). Commit základního písmene přes `.insertRawText(displayed)` se proto chová jako tap — bez divergence auto-capu/sugescí.
- Layout se reused i v emoji search ([LayoutBuilder.swift:42](KeyboardCore/Sources/Logic/LayoutBuilder.swift:42)) — sady se tam projeví taky, což je konzistentní a žádoucí.

## Rozhodnutí z grill session (závazná)

| Téma | Rozhodnutí |
|---|---|
| Popup u písmen | Vždy; první buňka = základní písmeno; default zvýraznění = buňka 0 (base) |
| Bez diakritiky | Prázdné pole alternátů → žádný popup |
| Number row | **Beze změny** (podržení `1` rovnou píše `!`) |
| Výběr sady | Jedna aktivní sada |
| Sady | Čeština, Slovenčina, Deutsch, Polski, Français, Español, **Vše** |
| Řazení v popupu | Podle frekvence v jazyce (za základním písmenem) |
| Německé ß | **Nezahrnout** (jen ä ö ü) — vyhne se `ß`→`SS` uppercase problému |
| Default sady | Jazyk → region → „Vše" |
| Persistence | Detekovaný default se počítá v getteru když klíč chybí; zápis až při explicitní volbě |
| Migrace | Detekce pro všechny (i stávající uživatele), žádný `onboardingComplete` speciál |
| Labely pickeru | Endonymy (Čeština, Deutsch, …), `.menu` styl |

## Scope

### 1. `LetterAlternateSet` enum + detekce (`KeymojiCore`)

Nový soubor `KeymojiCore/Sources/Shared/LetterAlternateSet.swift`:

```swift
import Foundation

/// Which language's diacritic set the long-press alternates use. Persisted as a string
/// in `AppGroupStore` under `letterAlternateSet`. The actual per-set character maps live
/// in `LayoutBuilder` (KeyboardCore) — this enum is just the selector, mirroring how
/// `LetterLayout` selects row data.
public enum LetterAlternateSet: String, Sendable, CaseIterable {
    case czech
    case slovak
    case german
    case polish
    case french
    case spanish
    /// Union / comprehensive map (today's behavior). Fallback for bilingual users and
    /// unsupported locales.
    case all

    /// Locale-derived default used when the user hasn't explicitly chosen a set.
    /// Language primary (direct signal of what the user writes), region fallback
    /// (catches e.g. a Czech with an English phone UI), `.all` as last resort.
    public static func detectedDefault(
        preferredLanguageCode: String? = Locale.preferredLanguages.first
            .map { Locale(identifier: $0).language.languageCode?.identifier ?? "" },
        regionCode: String? = Locale.current.region?.identifier
    ) -> LetterAlternateSet {
        if let lang = preferredLanguageCode, let set = byLanguage[lang] {
            return set
        }
        if let region = regionCode, let set = byRegion[region] {
            return set
        }
        return .all
    }

    private static let byLanguage: [String: LetterAlternateSet] = [
        "cs": .czech, "sk": .slovak, "de": .german,
        "pl": .polish, "fr": .french, "es": .spanish
    ]

    /// Jen jednoznačné regiony; vícejazyčné (CH, BE, LU…) záměrně vynechány → spadnou na `.all`.
    private static let byRegion: [String: LetterAlternateSet] = [
        "CZ": .czech, "SK": .slovak, "DE": .german, "AT": .german,
        "PL": .polish, "FR": .french, "ES": .spanish
    ]
}
```

> **Pozn. k testovatelnosti detekce:** parametry `preferredLanguageCode` / `regionCode` mají default odvozený z `Locale`, ale jdou injektnout v unit testech (žádné mockování `Locale` globálně). Ověřit, že `Locale.preferredLanguages.first` parsing nepadne na prázdném stringu.

### 2. Znakové mapy per sada (`LayoutBuilder`, `KeyboardCore`)

V [LayoutBuilder.swift](KeyboardCore/Sources/Logic/LayoutBuilder.swift) nahradit jediné `letterAlternates` funkcí `letterAlternates(for set:)`. **Mapy obsahují jen akcenty (lowercase); základní písmeno se předřazuje až v `makeLetterKey` (scope 4).** Řazení = frekvence v jazyce (k revizi):

```swift
private static func letterAlternates(for set: LetterAlternateSet) -> [Character: [String]] {
    switch set {
    case .czech:   return czechAlternates
    case .slovak:  return slovakAlternates
    case .german:  return germanAlternates
    case .polish:  return polishAlternates
    case .french:  return frenchAlternates
    case .spanish: return spanishAlternates
    case .all:     return allAlternates
    }
}

private static let czechAlternates: [Character: [String]] = [
    "a": ["á"], "c": ["č"], "d": ["ď"], "e": ["é", "ě"], "i": ["í"],
    "n": ["ň"], "o": ["ó"], "r": ["ř"], "s": ["š"], "t": ["ť"],
    "u": ["ú", "ů"], "y": ["ý"], "z": ["ž"]
]

private static let slovakAlternates: [Character: [String]] = [
    "a": ["á", "ä"], "c": ["č"], "d": ["ď"], "e": ["é"], "i": ["í"],
    "l": ["ľ", "ĺ"], "n": ["ň"], "o": ["ó", "ô"], "r": ["ŕ"], "s": ["š"],
    "t": ["ť"], "u": ["ú"], "y": ["ý"], "z": ["ž"]
]

private static let germanAlternates: [Character: [String]] = [
    "a": ["ä"], "o": ["ö"], "u": ["ü"]      // bez ß (viz rozhodnutí)
]

private static let polishAlternates: [Character: [String]] = [
    "a": ["ą"], "c": ["ć"], "e": ["ę"], "l": ["ł"], "n": ["ń"],
    "o": ["ó"], "s": ["ś"], "z": ["ż", "ź"]
]

private static let frenchAlternates: [Character: [String]] = [
    "a": ["à", "â", "æ"], "c": ["ç"], "e": ["é", "è", "ê", "ë"],
    "i": ["î", "ï"], "o": ["ô", "œ"], "u": ["ù", "û", "ü"], "y": ["ÿ"]
]

private static let spanishAlternates: [Character: [String]] = [
    "a": ["á"], "e": ["é"], "i": ["í"], "n": ["ñ"], "o": ["ó"], "u": ["ú", "ü"]
]

// `.all` = dnešní kompletní mapa beze změny (dnešní LayoutBuilder.swift:85).
private static let allAlternates: [Character: [String]] = [
    "a": ["á", "à", "â", "ä", "ã", "å", "ā", "æ"],
    "c": ["č", "ç", "ć", "ĉ"],
    "d": ["ď"],
    "e": ["é", "ě", "è", "ê", "ë", "ē", "ė", "ę"],
    "i": ["í", "ì", "î", "ï", "ī", "į"],
    "l": ["ł"],
    "n": ["ñ", "ň"],
    "o": ["ó", "ò", "ô", "ö", "õ", "ø", "ō", "œ"],
    "r": ["ř"],
    "s": ["š", "ś", "ŝ"],
    "t": ["ť"],
    "u": ["ú", "ù", "û", "ü", "ū", "ů"],
    "y": ["ý", "ÿ"],
    "z": ["ž", "ź", "ż"]
]
```

> **K revizi při implementaci:** přesné pořadí (frekvence) u `e` (cs: é/ě), `u` (cs: ú/ů), `z` (pl: ż/ź), `o` (sk: ó/ô), `e` (fr: é/è/ê/ë). Marginální znaky `ÿ` (fr), `ĺ` (sk) ponechány — pokud budou rušit, lze ořezat. Žádný z těchto znaků nedělá problém s `posixUppercased()` (`æ→Æ, œ→Œ, ñ→Ñ, ł→Ł, ÿ→Ÿ`).

### 3. `AppGroupStoreKey` + typed accessor (computed default)

V [AppGroupStoreKey.swift](KeymojiCore/Sources/Shared/AppGroupStoreKey.swift) přidat case:

```swift
case letterAlternateSet
```

V [AppGroupStore.swift](KeymojiCore/Sources/Shared/AppGroupStore.swift) (vedle `letterLayout`):

```swift
/// Active long-press diacritic set. Unlike other prefs, the default is **dynamic** —
/// when unset, it's derived from the device locale (language → region → `.all`). Writing
/// happens only on explicit user choice, so absence of a stored value means "follow
/// detection". Stávající uživatelé bez uloženého klíče dostanou detekovanou sadu (migrace).
var letterAlternateSet: LetterAlternateSet {
    get {
        guard let raw = string(forKey: .letterAlternateSet),
              let set = LetterAlternateSet(rawValue: raw)
        else { return LetterAlternateSet.detectedDefault() }
        return set
    }
    set { setString(newValue.rawValue, forKey: .letterAlternateSet) }
}
```

### 4. `LayoutBuilder` signatura + `makeLetterKey` (předřazení base + casing)

`layout(...)` dostane nový parametr (vedle `letterLayout`):

```swift
public static func layout(
    page: KeyboardPage,
    showNumberRow: Bool,
    returnKeyType: ReturnKeyType,
    letterLayout: LetterLayout = .qwerty,
    alternateSet: LetterAlternateSet = .all
) -> KeyboardLayout
```

Default `.all` = dnešní chování pro volající, co parametr nepředají (testy, previews). `makeLetterRows` / `makeLetterKey` parametr protáhnou dolů.

`makeLetterKey` upravit tak, aby **při ≥1 akcentu předřadil základní (nacasované) písmeno**:

```swift
private static func makeLetterKey(_ char: Character, shift: ShiftState, alternateSet: LetterAlternateSet) -> Key {
    let lower = String(char)
    let displayed = shouldUppercase(shift) ? lower.posixUppercased() : lower
    let accents = letterAlternates(for: alternateSet)[char] ?? []
    // Bez diakritiky → prázdné pole → žádný popup. S diakritikou → [base, ...akcenty].
    let alternates: [KeyContent] = accents.isEmpty
        ? []
        : [.text(displayed)] + accents.map { .text(shouldUppercase(shift) ? $0.posixUppercased() : $0) }
    return Key(
        id: "letter.\(lower)",
        primary: .text(displayed),
        alternates: alternates,
        action: .insertText(displayed),
        visualWeight: .standard,
        role: .character
    )
}
```

> **Důsledek pro `KeyView`:** žádná změna gesture kódu. `highlightedAlternateIndex = 0` (dnešní default) teď ukazuje na základní písmeno → puštění bez slajdu vloží base přes `commitAlternate(at: 0)` → `.insertRawText(displayed)`. To je ekvivalent tapu (viz Kontext). `count == 1` větev zůstává a obsluhuje výhradně number row.

### 5. `KeyboardState` nové pole

V [KeyboardState.swift](KeyboardCore/Sources/Models/KeyboardState.swift) přidat (vedle `letterLayout`):

```swift
public var letterAlternateSet: LetterAlternateSet
```

Do `init(...)` s defaultem `.all` (runtime kopie; `KeyboardViewController` ji plní z `AppGroupStore`).

### 6. `KeyboardViewController` — refresh + build

- V `refreshFromStore()` ([:193](KeyboardExtension/Sources/KeyboardViewController.swift:193)) přidat (vzor `letterLayout` na [:205](KeyboardExtension/Sources/KeyboardViewController.swift:205)):

```swift
let set = store.letterAlternateSet
if state.letterAlternateSet != set {
    state.letterAlternateSet = set
    changed = true
}
```

- V `installSettingsObservers()` ([:167](KeyboardExtension/Sources/KeyboardViewController.swift:167)) přidat observer:

```swift
settingsNotifier.addObserver(for: .letterAlternateSet) { [weak self] in
    self?.refreshFromStore()
},
```

- V `LayoutBuilder.layout(...)` callu (kolem [:430](KeyboardExtension/Sources/KeyboardViewController.swift:430)) předat `alternateSet: state.letterAlternateSet`.

### 7. Settings UI — Picker

V [SettingsView.swift](Features/Settings/Sources/SettingsView.swift), nová `Section` v rámci `keyboardSection` (vedle `letterLayout` pickeru, [:78](Features/Settings/Sources/SettingsView.swift:78)):

```swift
Section {
    Picker(Texts.Keyboard.letterAlternateSet, selection: $viewModel.letterAlternateSet) {
        ForEach(LetterAlternateSet.allCases, id: \.self) { set in
            Text(label(for: set)).tag(set)
        }
    }
    .pickerStyle(.menu)
} footer: {
    Text(Texts.Keyboard.letterAlternateSetFooter)
}

private func label(for set: LetterAlternateSet) -> String {
    switch set {
    case .czech:   return "Čeština"
    case .slovak:  return "Slovenčina"
    case .german:  return "Deutsch"
    case .polish:  return "Polski"
    case .french:  return "Français"
    case .spanish: return "Español"
    case .all:     return Texts.Keyboard.LetterAlternateSet.all   // lokalizované „Vše" / „All"
    }
}
```

**Picker styl `.menu`** (7 položek je na segmented moc). Endonymy jsou natvrdo (jazykové názvy se nepřekládají); jen „Vše" jde přes L10n.

### 8. `SettingsViewModel` + protocol + Mock

V [SettingsViewModel.swift](Features/Settings/Sources/SettingsViewModel.swift) (vzor `letterLayout`, [:72](Features/Settings/Sources/SettingsViewModel.swift:72)):

```swift
// protokol SettingsViewModeling:
var letterAlternateSet: LetterAlternateSet { get set }

// impl:
var letterAlternateSet: LetterAlternateSet {
    didSet {
        store.letterAlternateSet = letterAlternateSet
        notifier.post(.letterAlternateSet)
    }
}
// + v initu: self.letterAlternateSet = store.letterAlternateSet
```

V `Features/Settings/Testing/SettingsViewModelMock.swift` přidat property s defaultem (např. `.czech` nebo `.all`).

### 9. Lokalizace

`KeymojiResources/.../en.lproj/Localizable.strings` (+ `cs.lproj` pokud existuje — zkontrolovat):

```strings
"settings.keyboard.letterAlternateSet" = "Accent set";
"settings.keyboard.letterAlternateSetFooter" = "Choose which language's accents appear when you press and hold a letter.";
"settings.keyboard.letterAlternateSet.all" = "All";
```

L10n aliasy pod `L10n.Settings.Keyboard.LetterAlternateSet.all` (vzor `L10n.Settings.Keyboard.LetterLayout.*`).

### 10. Testy

**Unit (`KeyboardCore/Tests/LayoutBuilderTests.swift`):**
- `testCzechSet_rKey_hasBaseThenAccent()` — `alternateSet: .czech`, klávesa `r` → `alternates == [.text("r"), .text("ř")]`.
- `testCzechSet_eKey_orderedByFrequency()` — `e` → `[.text("e"), .text("é"), .text("ě")]`.
- `testCzechSet_letterWithoutDiacritic_hasNoAlternates()` — např. `f` → `alternates.isEmpty`.
- `testGermanSet_excludesEszett()` — `s` → `alternates.isEmpty`; `a` → `[.text("a"), .text("ä")]`.
- `testShiftedSet_basePrefixIsUppercased()` — `.czech`, shift `.upper`, `r` → `[.text("R"), .text("Ř")]`.
- `testAllSet_matchesLegacyPlusBasePrefix()` — `.all`, `a` → base `a` + dnešních 8 akcentů.
- `testNumberRowUnchanged()` — number row `1` má `alternates == [.text("!")]` (žádný base prefix, beze změny).

**Unit (`KeymojiCore/Tests/` — nový `LetterAlternateSetTests.swift`):**
- `testDetectedDefault_languageMatch()` — `preferredLanguageCode: "cs"` → `.czech` (region ignorován).
- `testDetectedDefault_languageMiss_regionFallback()` — `"en"`, region `"CZ"` → `.czech`.
- `testDetectedDefault_bothMiss_returnsAll()` — `"en"`, region `"GB"` → `.all`.
- `testDetectedDefault_ambiguousRegion_returnsAll()` — `"en"`, region `"CH"` → `.all`.

**Unit (`KeymojiCore/Tests/` accessor):**
- `testLetterAlternateSet_unset_returnsDetectedDefault()` a `testLetterAlternateSet_roundTrip()` (reset store, set/get).

**Snapshot:**
- `KeyboardUI/Tests/LongPressPopoverSnapshots.swift` + `KeyboardViewSnapshots.swift` — reference se změní (popup nově začíná základním písmenem). **Refresh referencí.** Zvážit přidat 1 snapshot popupu české sady (`r` → `[r, ř]`) jako doklad chování.
- `Features/Settings/Tests/SettingsSnapshots.swift` — nový Picker řádek; refresh referencí.

### 11. Manuální verify

1. Host appka → Settings → vidět nový „Accent set" picker; default odpovídá locale (na CZ zařízení / s cs UI → „Čeština").
2. V Notes podržet `r` → vyskočí popup `[r, ř]`, default zvýrazněn `r`. Pustit bez slajdu → vloží `r`. Podržet znovu, slajdnout doprava, pustit → `ř`.
3. Podržet `a` (cs) → `[a, á]`. Podržet `f` → nic (žádná diakritika).
4. Přepnout sadu na „Deutsch" → podržet `a` → `[a, ä]`; podržet `s` → nic (žádné ß). Podržet `o` → `[o, ö]`.
5. Přepnout na „Vše" → podržet `a` → base + 8 akcentů (dnešní chování).
6. Number row: podržet `1` → rovnou napíše `!` (beze změny, žádný popup).
7. Shift ON: podržet `R` → `[R, Ř]`.
8. Změna sady v host appce se na otevřené klávesnici projeví živě (Darwin notifikace) i po dismiss/re-open (viewWillAppear).
9. Quit & re-open host appky → volba persistuje.

## Mimo scope

- **Více-výběr / sjednocení sad** (Čeština + Deutsch naráz). v1 je jedna aktivní sada; bilingvní berou „Vše". Případně budoucí task.
- **Number row chování** — zůstává dnešní auto-commit (`1`→`!`). Žádný popup, žádný base prefix.
- **Obrácená interpunkce ¿ ¡** (španělština) — to nejsou akcenty písmen, patří na interpunkční klávesy. Out of scope.
- **Německé ß** — záměrně vynecháno (uppercase `ß`→`SS`). Pokud bude poptávka, samostatný task s `ß`→`ẞ` (U+1E9E) special-casem.
- **Skandinávské / portugalské / maďarské / rumunské sady** — v1 jen jádro 6. „Vše" je pokrývá částečně (å ø ã… jsou v `.all`). Další jazyky = future task (přidat case do enumu + mapu).
- **Cancel gesture** (slajd pryč zruší bez vložení) — nepřidáváme; chování je „release vždy commitne zvýrazněnou buňku", konzistentní s dneškem.
- **Per-pole jazyk** (jiná sada podle `textInputMode.primaryLanguage` fokusovaného pole) — sada je globální uživatelská volba, ne per-pole. Out of scope.

## Hotovo když

- `LetterAlternateSet` enum existuje v `KeymojiCore` s 6 jazyky + `.all`, `detectedDefault(...)` implementuje jazyk→region→`.all` a je unit-testovatelný (injektovatelné kódy).
- `LayoutBuilder` má per-sadu mapy (jen akcenty), `makeLetterKey` předřazuje nacasované základní písmeno a vrací prázdné pole u písmen bez diakritiky.
- `layout(...)` má parametr `alternateSet` (default `.all`); `KeyboardViewController` ho plní z `state.letterAlternateSet`.
- Popup u písmena s diakritikou vyskočí vždy, první buňka = základní písmeno, default zvýraznění buňka 0; podržení+puštění bez slajdu vloží základní písmeno. Number row beze změny.
- `AppGroupStore.letterAlternateSet` vrací detekovaný default když je klíč prázdný (migrace pro stávající uživatele), jinak uloženou hodnotu; zápis při explicitní volbě.
- `KeyboardState.letterAlternateSet` pole, re-read v `refreshFromStore()`, Darwin observer pro `.letterAlternateSet`.
- Settings Picker (`.menu`, endonymy) + footer + L10n; `SettingsViewModel` `didSet` posílá notifikaci; Mock doplněn.
- Unit testy (LayoutBuilder sady + base prefix + number row beze změny; detekce defaultu; accessor) green.
- Snapshot reference (popover, keyboard, settings) refreshnuté.
- Manuální verify pokrývá všechny sady, shift, number row, live update i persistenci.
- Existující testy KeyboardCore / KeyboardUI / Settings green.

## Rizika

- **Snapshot churn.** Předřazení základního písmene změní KAŽDÝ popover snapshot (a layout snapshoty kde je popover vidět). Očekávaný, ale velký diff — projít, že se mění jen obsah popupu, ne geometrie kláves. `updateHighlight` počítá šířku z `key.alternates.count`, takže popup je o jednu buňku širší — ověřit, že se nevejde mimo obrazovku u krajních kláves (existuje task 21 o clippingu horní řady; otestovat `q`/`p` v české sadě i ve „Vše").
- **Default `.all` u `layout(...)` vs. produkční default.** Builder má `alternateSet: .all` jako default parametru (kvůli testům/previews), ale produkční default sady je *detekovaný*, ne `.all`. Nesmí dojít k záměně — produkce vždy předává `state.letterAlternateSet`. Ohlídat, že žádná produkční cesta nevolá `layout` bez parametru.
- **`detectedDefault()` a `Locale` parsing.** `Locale.preferredLanguages.first` může být `"en-CZ"`, `"zh-Hans-CN"` apod. — parsovat language code přes `Locale(identifier:).language.languageCode`, ne string split. Region přes `Locale.current.region?.identifier`. Ošetřit nil/prázdný string (→ `.all`).
- **Migrace = tichá změna chování.** Stávající uživatel s českým locale po updatu uvidí místo 8 alternátů jen `[a, á]`. To je záměr, ale je to viditelná změna — zmínit v release notes. Kdo chce staré chování, přepne na „Vše".
- **Frekvenční pořadí je odhad.** Pořadí akcentů (zejm. cs `u`: ú/ů, fr `e`) je můj best-effort; ne data-driven. Snadno změnitelné, ale stojí za rychlou revizi rodilým citem.
- **`.insertRawText` pro základní písmeno.** Ověřeno, že je ekvivalent tapu (Kontext), ale potvrdit testem, že podržení+puštění základního písmene na auto-kapitalizované klávese se chová stejně jako tap (ShiftStateMachine revert upper→lower).

## Reference

- [tasks/36-space-double-tap-action.md](tasks/36-space-double-tap-action.md) — kompletní vzor plumbingu string-enum preference (store → state → viewWillAppear → VM → Picker → L10n → testy).
- [tasks/07-long-press-popover.md](tasks/07-long-press-popover.md) — původní design popoveru a alternátů.
- [tasks/22-cross-proc-settings-observation.md](tasks/22-cross-proc-settings-observation.md) — Darwin notifikace pro live update.
- [tasks/21-popover-top-row-clipping.md](tasks/21-popover-top-row-clipping.md) — clipping popupu u krajních/horních kláves (širší popup = re-test).
- [KeymojiCore/Sources/Shared/LetterLayout.swift](KeymojiCore/Sources/Shared/LetterLayout.swift) — vzor enumu v `KeymojiCore` konzumovaného `LayoutBuilder`.
- [KeyboardCore/Sources/Logic/LayoutBuilder.swift:85](KeyboardCore/Sources/Logic/LayoutBuilder.swift) — `letterAlternates` k nahrazení; `makeLetterKey` [:147](KeyboardCore/Sources/Logic/LayoutBuilder.swift:147).
- [KeyboardUI/Sources/Views/KeyView.swift:398](KeyboardUI/Sources/Views/KeyView.swift) — `startLongPressTimer` (`count == 1` větev se NEmění).
- [KeyboardExtension/Sources/KeyboardViewController.swift:167](KeyboardExtension/Sources/KeyboardViewController.swift) — observers; [:193](KeyboardExtension/Sources/KeyboardViewController.swift:193) `refreshFromStore`.

## Codex review

**Ano** — feature se dotýká hot pathu (`makeLetterKey`, gesture commit) a má netriviální locale-detekci s fallbacky + migrační chování přes computed default v getteru. Hraniční případy (prázdný popup, base casing, number row beze změny, ambiguous region) stojí za adversarial review.
