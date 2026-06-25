# 81 — Settings: čítač = jen nabízitelná naučená slova

**Status:** Done — 2026-06-25 (větev `feature/81-settings-offerable-learned-word-count`). Přidána skladová metoda `LearnedWordsIndex.count(atLeast:)` (jeden alokačně-bezzátěžový průchod `entries` pod `lock`) + průchozí `PersonalRecentsStore.count(atLeast:)`. `SettingsViewModel` (init i `refreshLearnedWordCount()`) teď volá `recentsStore.count(atLeast: WordCompletionProvider.minSuggestCount)` → čítač = nabízitelná slova, souhlasí s editorem; jen-singletony → 0. Tři nové testy v `PersonalRecentsStoreTests`. Codex review: 0 nálezů.

**Status:** Todo — připraveno z grill session 2026-06-25. Dotahuje [task 77](77-learned-words-uniform-suggest-threshold.md) (skryl singletony v seznamu, ale čítač zůstal na totalu).

**Priorita:** v1.x (číslo v Settings nesouhlasí se seznamem v editoru — matoucí) · **Úsilí:** XS (jedna skladová count metoda + jeden řádek ve VM + test) · **Dopad:** Low/Medium (konzistence + číslo dává smysl).

**Souvisí s:** [77 — uniformní práh / skrytí singletonů](77-learned-words-uniform-suggest-threshold.md), [48 — seznam naučených slov](48-learned-words-list-management.md), [50 — sort by count](50-learned-words-sort-by-count.md). Glosář **Learned word** v [`CONTEXT.md`](../CONTEXT.md) (rozdíl *learned* ≠ *offered* — beze změny, jen ho dotahujeme do čítače). Dotýká se [`SettingsViewModel`](../Features/Settings/Sources/SettingsViewModel.swift), [`PersonalRecentsStore`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift), [`LearnedWordsIndex`](../KeyboardCore/Sources/Storage/LearnedWordsIndex.swift).

## Kontext / proč

**Co kód dnes dělá:** Settings řádek „Learned words" ukazuje `recentsStore.count` ([`SettingsViewModel.swift:196`](../Features/Settings/Sources/SettingsViewModel.swift)) = **všechna distinct slova**, včetně sub-prahových singletonů (`count == 1`), které se **nikdy nenabízejí ani nezobrazují** v editoru (ten filtruje na `count >= minSuggestCount`, [`LearnedWordsEditorViewModel.swift:108`](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift)).

**Bolest:** číslo v Settings ≠ délka seznamu v editoru. Aktivní pisatel vidí velké číslo (třeba 1 200), ale v editoru o dost míň → nedává smysl.

**Co chceme:** čítač ukáže **nabízitelná slova** (`count >= minSuggestCount`) = přesně to, co se může reálně nabídnout a co je v seznamu.

## Cíl

1. Settings čítač = počet záznamů s `count >= WordCompletionProvider.minSuggestCount`.
2. Číslo souhlasí s délkou seznamu v editoru (bez aplikovaného search filtru).
3. Práh čte z téže konstanty `minSuggestCount` (jeden zdroj pravdy s editorem i providery).

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Význam čísla** | „Nabízitelná" slova (`count >= minSuggestCount`), ne total. |
| **Vrstvení** | Úložiště dostane čistě **skladovou** operaci `count(atLeast minCount: Int) -> Int` (spočítá záznamy bez alokace pole). `SettingsViewModel` ji volá s `WordCompletionProvider.minSuggestCount` → práh zůstává v suggestion vrstvě, počítání v úložišti. |
| **Label** | „Learned words" beze změny. Mění se jen číslo. |
| **Prázdný stav** | Když pool obsahuje **jen** singletony → čítač ukáže **0** (konzistentní: editor ukáže prázdný seznam, Clear All přes `hasAnyLearnedContent` dál funguje). 0 = „zatím se ti nic reálně nenabízí" — přesnější než dnešní matoucí velké číslo. Bez skrývání řádku, bez extra popisku. |

## Scope

- [`LearnedWordsIndex`](../KeyboardCore/Sources/Storage/LearnedWordsIndex.swift): `func count(atLeast minCount: Int) -> Int` — pod `lock`, jeden průchod `entries` (`entries.reduce/filter` na `value.count >= minCount`). Bez alokace mezipole, O(n), volá se jen on-appear.
- [`PersonalRecentsStore`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift): průchozí `func count(atLeast minCount: Int) -> Int { index.count(atLeast: minCount) }` (vedle stávajícího `var count`).
- [`SettingsViewModel`](../Features/Settings/Sources/SettingsViewModel.swift): v initu (ř. ~185) i v `refreshLearnedWordCount()` (ř. ~196) nahradit `recentsStore.count` → `recentsStore.count(atLeast: WordCompletionProvider.minSuggestCount)`. (`import KeyboardCore` už je, ř. 11.)

## Non-goals

- Změna `minSuggestCount` (zůstává 2).
- Změna labelu nebo layoutu řádku.
- Skrývání řádku při 0 / extra popisek (zamítnuto — 0 je v pořádku).
- Změna editoru (filtr už tam je z tasku 77).
- Vystavení `count(atLeast:)` na `PersonalRecentsReading` (Settings drží konkrétní `PersonalRecentsStore`, ne read protokol — přidávat na protokol jen kdyby to chtěl jiný konzument).

## Akceptační kritéria

- Pool: 5 slov `count >= 2` + 3 singletony → čítač ukáže **5** (ne 8); editor seznam má 5 řádků.
- Pool jen ze singletonů → čítač **0**; editor prázdný; Clear All funguje.
- Čítač se obnoví on-appear (host edit / mazání v editoru se projeví).
- Žádná telemetrie; pool on-device.

## Regresní síť

**Existující — záměrně mění chování (aktualizovat):**
- [`SettingsViewModelTests`](../Features/Settings/Tests) (pokud existují): test `learnedWordCount == store.count` → na `count(atLeast: minSuggestCount)`. Sample data případně doplnit o singleton, ať je rozdíl vidět.

**Existující — musí projít beze změny:**
- `LearnedWordsEditor` filtr/seznam (task 77) — beze změny.
- `LearnedWordsIndex` match/learn/evict/persist — beze změny.
- Clear All / `hasAnyLearnedContent` — beze změny.

**Nové:**
- `count(atLeast:)` v indexu (záznamy nad prahem), průchozí ve store.
- Settings čítač = nabízitelná; 0 při jen-singletonech.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: napiš pár slov 1× a pár 2×+ → Settings číslo = jen ta 2×+; otevři editor → délka seznamu sedí.
- Nové `.swift` soubory nepřibydou (jen metody) → `tuist generate` netřeba, ale neuškodí.
