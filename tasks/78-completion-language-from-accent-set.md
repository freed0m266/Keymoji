# 78 — Jazyk doplnění dle Accent setu (accent → systém → EN)

**Status:** Todo — připraveno z grill session 2026-06-24. **Mění** jazykový model z [tasku 65](65-accent-aware-completions-capslock-limits.md) (viz „Supersedes"). Rozhodnutí zafixované i v [ADR 0002](../docs/adr/0002-single-completion-language-from-accent-set.md).

**Priorita:** v1.x (přímý dopad na relevanci systémových návrhů pro ne-anglické uživatele) · **Úsilí:** S (přepis výběru jazyka v jedné metodě + helper pro systémový jazyk + testy) · **Dopad:** High pro lokalizované uživatele (přestane lézt angličtina, když mají konkrétní accent).

**Souvisí s:** [65 — accent-aware doplňování](65-accent-aware-completions-capslock-limits.md) (zavedl aditivní base+accent model — ten měníme), [40 — completion model](40-word-completion-suggestions.md), [58 — jazykové sady letterAlternates](58-letter-alternates-language-sets.md). Glosář: **Completion language** (nový termín), zpřesněné **Accent set** a **Primary language** v [`CONTEXT.md`](../CONTEXT.md). Dotýká se [`KeyboardViewController.makeSuggestionContext`](../KeyboardExtension/Sources/KeyboardViewController.swift), [`LetterAlternateSet`](../KeymojiCore/Sources/Shared/LetterAlternateSet.swift), [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift) (konzument `completionLanguages`), [`UITextCheckerAdapter.resolveLanguage`](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift).

## Kontext / proč

**Co kód dnes dělá** ([`makeSuggestionContext`](../KeyboardExtension/Sources/KeyboardViewController.swift), ~ř. 769–785):
```swift
var completionLanguages = [state.currentLanguage ?? "en"]   // base
if let accent = state.letterAlternateSet.accentLanguageCode, !contains { append(accent) }
```
`state.currentLanguage` = `textInputMode?.primaryLanguage` = statický `PrimaryLanguage` z Info.plistu = **`"mul"` → adapter mapuje na angličtinu**. iOS u custom klávesnice **neprozradí jazyk pole ani jazyk zařízení** (glosář: *Primary language*). 

**Důsledek dnešního stavu:** base je **vždycky angličtina** (ne „jazyk systému", jak se může zdát), a accent jazyk se k ní jen *přidá*. Uživatel s Accent = Czech tak dostává **angličtinu i češtinu rovnocenně** (obě dotázané zvlášť, merge přes max skóre) → leze mu spousta anglických návrhů, i když má český accent. To je ta bolest.

**Co chceme:** jazyk systémového slovníku (`UITextChecker`) volit **primárně podle Accent setu**, a teprve když je Accent = All, vzít **skutečný jazyk zařízení** (ne natvrdo angličtinu), s angličtinou jako poslední záchranou.

### Co jsme zvážili a zamítli

- **Zachovat angličtinu jako sekundární jazyk (biased aditivní model)** — pořád dotázat accent i angličtinu, jen accentu dát bias, ať vyhrává. **Zamítnuto:** není to „jeden jazyk", vyžaduje ladit skóre (nová konstanta, víc složitosti) a accent uživateli stejně občas proleze angličtina. Jednojazyčný model je čistší a řeší bolest u kořene.
- **Pouhé přeřazení `completionLanguages`** — nefunguje: skóre závisí jen na *pořadí slova v rámci jazyka*, ne na pozici jazyka v poli, takže přeházení pole nezmění výstup. „Accent primárně" jde docílit jen výběrem jednoho jazyka (nebo změnou vah).

**Změkčení ztráty angličtiny:** *naučená* slova (personal recents) **nejsou filtrovaná jazykem** — anglická slova, co reálně píšeš (≥2×), se nabízejí dál. Ztratíš jen *slovníkové* doplnění dosud nenapsaných anglických slov (a ta se po prvním napsání naučí). Viz [ADR 0002](../docs/adr/0002-single-completion-language-from-accent-set.md).

## Supersedes

**Task 65 — aditivní base+accent jazykový model.** Tahle session ho nahrazuje **jednojazyčným fallback řetězcem**. Caps-lock / eligibility limity z tasku 65 se **nemění** — mění se výhradně volba jazyka(ů) pro `UITextChecker`.

## Cíl

1. `completionLanguages` obsahuje **právě jeden** jazyk, zvolený řetězcem: **accent jazyk → jazyk zařízení → angličtina**.
2. Natvrdo zadrátovaná anglická base (`state.currentLanguage` v completion cestě) **zmizí**.
3. Accent = All → použít **jazyk zařízení** (`Locale.preferredLanguages`), ne angličtinu; angličtina je až fallback, když je systémový jazyk nedostupný.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Model** | **Jednojazyčně.** `completionLanguages = [resolved]`, kde `resolved = accentLanguageCode ?? deviceLanguageCode ?? "en"`. Žádná trvalá anglická co-base. |
| **Accent != All** | `LetterAlternateSet.accentLanguageCode` (cs/sk/de/pl/fr/es). |
| **Accent == All** | `deviceLanguageCode` = `Locale.preferredLanguages.first` → `Locale(identifier:).language.languageCode?.identifier` (stejný vzor jako `LetterAlternateSet.detectedDefault`). **Jakýkoli** jazyk, ne jen 6 accent jazyků (klidně `ja`, `ru`…). |
| **Fallback** | Když `deviceLanguageCode` je nil → `"en"`. Navíc adapter `resolveLanguage` si nepodporovaný jazyk stejně srovná na angličtinu (dvojitá pojistka). |
| **`state.currentLanguage`** | Přestává krmit completion jazyk. **Nepřemazávat ho ani neodstraňovat** — `refreshLanguage()`/rebuild ho drží z jiných důvodů; jen ho přestaneme číst v `makeSuggestionContext`. Pokud se ukáže jako úplně mrtvý pro completion-only účel, drobný cleanup je volitelný (ne blocker). |
| **Typ `completionLanguages`** | Zůstává `[String]` (teď vždy délky 1) — `WordCompletionProvider` smyčka přes jeden prvek funguje beze změny; typ necháváme kvůli budoucí flexibilitě. |
| **Helper pro systémový jazyk** | Extrahovat detekci do injektovatelného helperu (ať je testovatelná bez mutace globálního `Locale`), analogicky parametrům `detectedDefault`. Umístění: na `LetterAlternateSet` nebo malý `Locale` util v KeymojiCore (vybrat při implementaci). |

## Scope

- [`KeyboardViewController.makeSuggestionContext`](../KeyboardExtension/Sources/KeyboardViewController.swift): nahradit výpočet `completionLanguages` jednojazyčným řetězcem. Aktualizovat doc-comment (ř. 770–773 popisuje aditivní model — už neplatí).
- Helper `deviceLanguageCode` (injektovatelný `preferredLanguageCode` default z `Locale.preferredLanguages.first`).
- Ověřit, že [`resolveLanguage`](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift) korektně zpracuje libovolný systémový kód (už dnes: exact → base → english variant → first available).

## Non-goals

- Biased / aditivní multi-language model (zamítnut — viz výše).
- Změna accent setů nebo jejich jazykového mapování (`byLanguage`/`byRegion`).
- Pokus expozovat jazyk pole (iOS to u custom klávesnice neumí — viz glosář *Primary language*).
- Změna caps-lock / eligibility limitů z tasku 65.
- Filtrování personal recents jazykem (zůstávají language-agnostic — to je právě to změkčení).

## Akceptační kritéria

- Accent = Czech → `completionLanguages == ["cs"]` (žádná angličtina v dotazu).
- Accent = All, zařízení `cs` → `["cs"]`; zařízení `en` → `["en"]`; zařízení `ja` → `["ja"]` (a adapter si poradí s dostupností).
- Accent = All, `Locale.preferredLanguages` prázdné/nil → `["en"]`.
- Personal recents se nabízejí nezávisle na zvoleném jazyce (anglické naučené slovo se nabídne i při Accent = Czech).
- Žádná telemetrie; vše on-device.

## Regresní síť

**Existující — záměrně mění chování (aktualizovat):**
- Test(y) ve `WordCompletionProvider`/controller suite, které ověřují **aditivní** `[base, accent]` (např. že se dotazuje angličtina + accent) → aktualizovat na **jednojazyčný** výstup.
- Pokud existuje test „base = en vždy" → invertovat na nový řetězec.

**Existující — musí projít beze změny:**
- `UITextCheckerAdapter.resolveLanguage` mapping testy (pokud existují) — beze změny logiky.
- Caps-lock / eligibility (task 65) — beze změny.
- Diakritický směrový match a scoring — beze změny.

**Nové:**
- Řetězec: accent != All → accent; accent == All → device lang; device nil → en.
- Žádná anglická co-base, když je accent nastaven.
- Recents jsou jazykově agnostické (regrese-test: anglické recents slovo se nabídne při Accent = Czech).

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: Accent = Czech → psát → ověřit, že systémové návrhy jsou české, ne anglické; naučené anglické slovo se pořád nabídne. Accent = All na českém zařízení → české návrhy.
- Nové `.swift` soubory (helper): `tuist generate` před `xcodebuild test` (memory *keymoji-tuist-new-files-silent-skip*).
