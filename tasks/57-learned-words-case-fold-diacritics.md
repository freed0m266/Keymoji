# 57 — Learned words: lowercase kanonizace + diakriticky tolerantní hledání

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium (kvalita learned words + návrhů; odstraní case duplicity, zlepší hledání s/bez diakritiky)

## Cíl

Tři propojené změny v learned words:

1. **Konec case duplicit.** Dnes jsou "ale" a "Ale" dva oddělené záznamy (klíč = doslovný řetězec). Nově se vše ukládá **lowercase (diakritika zachovaná)**, takže existuje jen jeden záznam na slovo bez ohledu na velikost písmen.
2. **Zobrazení a nabízení s velkým počátečním písmenem dle pozice ve větě.** V editoru se slovo zobrazí s velkým počátečním písmenem ("Ale"). V návrzích se kapitalizace řídí tím, co uživatel napsal — na začátku věty "Ale", uprostřed "ale". (Tato část je z velké míry už hotová stávající logikou — viz níže.)
3. **Diakriticky tolerantní hledání, směrově.** Napsání bez diakritiky najde i slova s diakritikou ("cauk" → "Čauko"). Napsání s diakritikou je striktní a najde jen přesné diakritické tvary ("čauk" → jen "čauko", ne "cauko").

> **Vědomě mimo:** ALL-CAPS / zkratková logika (FOMO) a proper-noun casing uprostřed věty (Praha). Casing model **celý zahazujeme**. "FOMO" se uloží jako "fomo" a nabídne jako "Fomo"; "Praha" se uprostřed věty nabídne jako "praha". Pokud to bude vadit, vrátíme casing model celý a pořádně v samostatném tasku — míchat půlku zpět nedává smysl. Viz [task 48](48-learned-words-list-management.md), [task 50](50-learned-words-sort-by-count.md).

> **Migrace dat: žádná.** Existující learned words se neslučují ani nepřevádějí — uživatel si pool premaže ručně (Settings → Clear learned words). Nová logika zajistí, že duplicity už nevzniknou.

## Rozhodnutí z analýzy (shrnutí grillingu)

| Téma | Rozhodnutí |
|------|-----------|
| ALL-CAPS / zkratky (FOMO) | **Zahodit** — moc složité, nevyplatí se teď |
| Kanonický tvar v úložišti | **lowercase + diakritika zachovaná** ("Čauko" → "čauko") |
| Dedup v úložišti | jen podle **velikosti písmen**, NE podle diakritiky — "rada" a "ráda" zůstávají dva záznamy |
| Hledání: case | case-insensitive (jako dnes) |
| Hledání: diakritika | **směrové**: prefix bez diakritiky = benevolentní, prefix s diakritikou = striktní |
| Self-match drop | zahazovat jen **přesně identický** napsaný řetězec; ostatní foldnuté varianty ponechat ("rada" → nabídne "ráda") |
| Proper nouns uprostřed věty (Praha) | **smířit se** — padnou na malé, casing model je celý venku |
| Locale pro fold | pevné `Locale(identifier: "en_US_POSIX")`, ne locale uživatele (turecké `i`/`ı`) |
| Migrace | žádná, data se premažou ručně |
| Kde se lowercasuje | uvnitř `PersonalRecentsStore` (invariant storu), ne v dispatcheru |

## Klíčová zjištění z průzkumu kódu

### Úložiště — `PersonalRecentsStore`
[`KeyboardCore/Sources/Storage/PersonalRecentsStore.swift`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift)

- Backováno dvěma JSON bloby v `AppGroupStore`: `{word: count}` a `{word: timestamp}`. Klíč = **doslovné** slovo → odtud case duplicity.
- [`learn(_:fromContextType:now:)`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:80) — `counts[word, default: 0] += 1` ukládá verbatim (řádek 86). **Jediné místo zápisu** — sem patří lowercasing.
- [`matches(prefix:)`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:55) — dnes `$0.key.lowercased().hasPrefix(prefix.lowercased())`. Case-insensitive, ale **NE** diakriticky. Sem patří směrový fold.
- [`remove(_:)`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:97) keyuje verbatim — po lowercasingu zápisu jsou klíče lowercase, takže `remove` musí dostat taky lowercase klíč (editor ho má v `LearnedWord.word`, viz níže — funguje samo).
- `passesFilters` (length 3–25, no all-digit/alfanum) — na lowercased slově funguje beze změny.

### Obě learning cesty ústí do storu
- Prose: [`InputDispatcher.swift:319`](KeyboardCore/Sources/Logic/InputDispatcher.swift:319) `learning.learn(word, .prose)` → hook → [`KeyboardViewController.swift:43`](KeyboardExtension/Sources/KeyboardViewController.swift:43) `recentsStore.learn(...)`.
- Email: [`KeyboardViewController.swift:327`](KeyboardExtension/Sources/KeyboardViewController.swift:327) `recentsStore.learn(email, fromContextType: .emailAddress)`.

→ Lowercasing **uvnitř `learn`** pokryje obě cesty jedním místem. (E-maily jsou už dnes prakticky vždy lowercase, takže je to nepokazí.)

### Návrhy — kapitalizace už z velké míry hotová
[`WordCompletionProvider.swift`](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift)

- [`displayCapitalization(for:prefix:context:)`](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:116) odvozuje velikost písmen z **napsaného prefixu** (`prefix.first?.isUppercase`) a shift stavu.
- Na začátku věty auto-cap ([`AutoCapitalizer.swift`](KeyboardCore/Sources/Logic/AutoCapitalizer.swift)) nastaví shift `.upper` → uživatel zmáčkne "a" → vloží "A" → prefix "A" → kandidát "ale" se zobrazí jako "Ale". Uprostřed věty prefix "a" → zůstane "ale".
- **Důsledek:** jakmile bude base z recents lowercase ("ale" místo dnešní zaseklé varianty), kapitalizace dle pozice ve větě **funguje sama**. Žádná nová detekce pozice věty není potřeba.
- [Self-match drop](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:93) `merged[prefix.lowercased()] = nil` keyuje na **lowercased prefix**, ne foldnutý → "rada" zahodí jen "rada" a "ráda" ponechá. **To přesně chceme — beze změny.**
- Komentář na [řádcích 60–62](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:60) ("learned proper-noun casing survives") se stane **zastaralým** (casing už neukládáme) — aktualizovat.

### Editor
- [`LearnedWordsEditorView.row(for:)`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift:80) zobrazuje `Text(word.word)` (řádek 82) → sem patří **display transform** na velké počáteční písmeno.
- [`LearnedWordsEditorViewModel.remove(at:)`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift:64) maže přes `words[$0].word` = uložený (nově lowercase) klíč → `store.remove` dostane správný klíč. **Display transform je čistě kosmetický, `LearnedWord.word` zůstává raw lowercase.**

## Návrh

### 1. `PersonalRecentsStore` — lowercase invariant + směrový fold

**(a) Lowercasing při zápisu.** V [`learn`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:80) na začátku znormalizovat:
```swift
public func learn(_ word: String, fromContextType context: TextContextType, now: Date = Date()) {
    let key = word.lowercased()              // diakritika zachovaná, jen case
    guard passesFilters(key, context: context) else { return }
    // ... dál pracovat s `key` místo `word`
}
```
Tím duplicity case variant už nikdy nevzniknou (learn "Ale" i "ale" → klíč "ale").

**(b) Směrový diakritický fold v [`matches`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:55).** Nahradit `hasPrefix` smyčkou přes znaky:
```swift
private static let foldLocale = Locale(identifier: "en_US_POSIX")

private static func fold(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: foldLocale).lowercased()
}

/// `prefix` matchne `word`, pokud:
///  - znak prefixu bez diakritiky → matchne libovolný znak se stejným základem (c → c i č)
///  - znak prefixu s diakritikou  → matchne jen ten samý znak case-insensitive (č → č/Č, ne c)
private static func directionalPrefixMatch(prefix: String, word: String) -> Bool {
    let p = Array(prefix), w = Array(word)
    guard w.count >= p.count else { return false }
    for i in p.indices {
        let pc = p[i], wc = w[i]
        guard fold(String(pc)) == fold(String(wc)) else { return false }  // základ musí sedět
        let pcLower = String(pc).lowercased()
        let pcHasDiacritic = pcLower != fold(String(pc))
        if pcHasDiacritic && pcLower != String(wc).lowercased() { return false } // diakritika striktně
    }
    return true
}

public func matches(prefix: String) -> [(word: String, count: Int)] {
    guard !prefix.isEmpty else { return [] }
    return loadCounts()
        .filter { Self.directionalPrefixMatch(prefix: prefix, word: $0.key) }
        .map { (word: $0.key, count: $0.value) }
}
```
Foldne se za běhu (≤500 slov, levné — netřeba ukládat fold-klíč). Aktualizovat doc komentář protokolu [`PersonalRecentsReading.matches`](KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:7–8) — "case-insensitive form starts with prefix" → doplnit směrové diakritické chování.

> **Pozn. ke grapheme clusterům:** porovnání po `Character` je pro češtinu bezpečné — `č`, `ř`, `ž`, `á`, `ů` jsou precomposed single-scalar grafémy. `folding(.diacriticInsensitive)` je rozloží na základ (č→c, ř→r, …).

### 2. Editor — zobrazení s velkým počátečním písmenem

V [`LearnedWordsEditorView.row(for:)`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift:80) zobrazit display variantu, **bez dotyku na `word.word`** (ten dál slouží k `remove`):
```swift
Text(word.word.capitalizedFirstLetter())   // "ale" → "Ale", "čauko" → "Čauko"
```
A v [`accessibilityLabel`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift:88) použít stejnou display variantu. Helper `capitalizedFirstLetter()` (uppercase jen prvního znaku, zbytek beze změny) už existuje jako private extension ve [`WordCompletionProvider.swift:142`](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:142) — povýšit na sdílený (např. `KeymojiUI` String extension nebo `KeyboardCore`), ať ho může použít i editor. Alternativně lokální kopie v editoru.

> Sort v [`LearnedWordsEditorViewModel`](Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift:88) běží přes `localizedCaseInsensitiveCompare` na raw `word` — funguje na lowercase beze změny, neměnit.

### 3. Návrhy — žádná logická změna, jen úklid komentáře

`WordCompletionProvider` neměnit logicky:
- Kapitalizace dle pozice věty funguje sama (base je nově lowercase).
- Self-match drop funguje sama (keyuje lowercased prefix → ponechá diakritické varianty).
- Pouze aktualizovat zastaralý komentář na [řádcích 60–62](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:60) o "learned proper-noun casing survives".

## Mimo scope

- **ALL-CAPS / zkratky (FOMO).** Casing model celý zahozen. "fomo" → nabídne "Fomo". Samostatný task, pokud vůbec.
- **Proper-noun casing uprostřed věty (Praha).** Padá na malé. Vrátí se jen s celým casing modelem.
- **Migrace existujících dat.** Žádná — uživatel premaže ručně.
- **`displayCapitalization` all-caps-prefix větev** ([řádky 122–127](KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:122)). Týká se *napsaného prefixu* za běhu (napíšeš "ALE" → nabídne velkými), ne úložiště — **beze změny**.
- **UITextChecker / UILexicon** zdroje návrhů — beze změny, fold se týká jen personal recents.
- **Eviction, capacity, filters** — beze změny (běží na lowercased slově korektně).

## Testy

**`PersonalRecentsStore` (KeyboardCore/Tests):**
- `learn("Ale")` pak `learn("ale")` → jeden záznam "ale" s count 2 (žádná duplicita).
- `learn("Čauko")` → uloženo jako "čauko".
- `matches("cauk")` při uloženém "čauko" → vrátí "čauko" (bez diakritiky → benevolentní).
- `matches("čauk")` při uložených "čauko" i "cauko" → vrátí **jen** "čauko" (s diakritikou → striktní).
- `matches("rad")` při uložených "rada" i "ráda" → vrátí **oba**.
- `matches("CAU")` (velkými) při "čauko" → vrátí "čauko" (case-insensitive zachováno).
- Regrese: čistě ASCII prefix bez diakritiky se chová jako dřív (jen lowercase keys).

**`WordCompletionProvider` (existující testy):**
- Napsání "rada" (lowercase, uprostřed věty) při uložených "rada" i "ráda" → nabídne **jen "ráda"** (identické "rada" self-match drop), display "ráda".
- Napsání "rad" → nabídne "rada" i "ráda".
- Začátek věty (prefix "Rad", shift `.upper`) → kandidáti "Rada" / "Ráda" (velké počáteční).
- Uprostřed věty (prefix "rad") → "rada" / "ráda" (malé).
- Regrese stávajících case testů (base je nově lowercase — některé fixtures možná upravit z "Hello" na "hello").

**`LearnedWordsEditor` (snapshot/VM):**
- Snapshot seznamu: uložené "ale", "čauko" → zobrazí "Ale", "Čauko".
- `remove(at:)` po display transformu pořád maže správný klíč (raw lowercase `word.word`).

## Závislosti

Žádné blokující. Staví na [task 40](40-word-completion-suggestions.md) (word completion infra), [task 48](48-learned-words-list-management.md) (editor), [task 50](50-learned-words-sort-by-count.md) (sort). Po zahození casing modelu může pozdější "proper task" znovu zavést plný casing model (zkratky + proper nouns) — tehdy revidovat lowercase invariant zavedený tady.
