# 74 — Kvalita učení a návrhů: anti-překlep, čísla & nicky, e-mail quick-pick

**Status:** Done — 2026-06-23

**Status:** Spec — připraveno z design session 2026-06-23 (navazuje na [73 — výkon storage](73-keyboard-perf-smooth-at-10k-learned-words.md), který přepsal storage na rychlý in-memory index, takže učení/lookup je teď O(1) a je prostor řešit *kvalitu* místo výkonu).

**Priorita:** v1.x (kvalita psaní — přímý dopad na to, jak dobré návrhy uživatel dostává) · **Úsilí:** M (filtr + scoring + nový provider + UI quick-pick, fázované) · **Dopad:** High (méně balastu v návrzích + nové užitečné návrhy: čísla, telefony, nicky, e-maily)

**Souvisí s:** [73 — výkon storage](73-keyboard-perf-smooth-at-10k-learned-words.md) (sdílí `PersonalRecentsStore`/`LearnedWordsIndex`), [65 — accent-aware completions](65-accent-aware-completions-capslock-limits.md), [56 — suggestion bar](56-suggestion-bar-always-except-emoji.md), [40 — completion model](40-word-completion.md). Dotýká se [`PersonalRecentsStore`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift), [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift), [`WordPrefixExtractor`](../KeyboardCore/Sources/Logic/Suggestions/WordPrefixExtractor.swift), [`SuggestionCoordinator`](../KeyboardCore/Sources/Logic/Suggestions/SuggestionCoordinator.swift), [`SuggestionEligibility`](../KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift), [`KeyboardViewController`](../KeyboardExtension/Sources/KeyboardViewController.swift), [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift).

## Kontext / proč

Uživatel má dlouhodobě pocit, že se klávesnice **občas učí překlepy** a nabízí je zpět. Zároveň jsou **díry v užitečnosti**: neučí se čísla (telefony, roky), neučí se „nickname" tokeny (`freedom266`), a v e-mailovém poli si nepamatuje adresy proaktivně (jen po napsání prefixu).

Jádro řešení je jeden princip, který sjednocuje všechny tři níže:

> **Uč se velkoryse, nabízej konzervativně.** Drahé/riskantní filtrování přesuneme z „co se uloží" na „co se ukáže". Konkrétně: **práh `count ≥ 2` pro zobrazení** návrhu. Překlepy i jednorázová citlivá čísla (OTP, kódy) jsou skoro vždy singletony → nikdy se nenabídnou; reálná slova/čísla/nicky, co píšeš opakovaně, ano. Tím se anti-překlep (bod 1) stává *zároveň* bezpečnostní pojistkou pro čísla (bod 3).

### Co jsme zvážili a zamítli

- **Učení prose až na „konci pole"** (původní nápad): zamítnuto. Klávesnicové rozšíření **spolehlivě nepozná konec pole** — v chatu uživatel dá *Odeslat*, ale pole i klávesnice zůstávají (žádný `viewWillDisappear`, žádná změna eligibility). Navíc host může osekat `documentContext`, takže u dlouhé zprávy bys celý text ani nedostal. Perf zisk je nulový (učení je už O(1) + debounced zápis). Práh `count ≥ 2` řeší stejný cíl (redukci překlepů) robustně a bez detekce konce pole.
- **3 e-maily v baru s `lineLimit(1)`**: zamítnuto. 3 dlouhé adresy v jednom `HStack`u na úzkém telefonu jsou po useknutí nerozlišitelné (`martin.svo…` ×3). Lepší: **jeden nejlepší, čitelný.**
- **Návrhy na numpadu / v `denied` polích** (telefon/OTP/heslo): mimo scope. Tyhle pole jsou citlivé a zůstávají `denied`.

## Cíl

1. Návrhy přestanou zobrazovat jednorázové překlepy (a jednorázová citlivá čísla) — práh `count ≥ 2`.
2. Klávesnice se učí a nabízí **čísla** (roky, telefony) a **alfanumerické nicky** (`freedom266`) z běžného textu.
3. V e-mailovém poli se proaktivně nabídne **jedna nejlepší** dříve napsaná adresa i bez psaní prefixu.
4. **Potvrzení návrhu se počítá jako použití** — accept word-completion chipu slovo naučí/inkrementuje, takže counter odráží skutečné používání, ne jen „kolikrát jsi to vyťukal celé".
5. Beze změny chování v `denied`/secure polích a beze změny výkonu (vše zůstává na rychlém indexu z tasku 73).

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Anti-překlep mechanismus** | **Tvrdý práh `count ≥ 2` pro *zobrazení*** word-completion návrhu (učení zůstává word-by-word, slovo se dál ukládá od prvního výskytu). Práh je **laditelná konstanta** (`minSuggestCount`, default 2). Ne učení na konci pole. |
| **Kde práh platí** | Na výstup `WordCompletionProvider` (prose slova, čísla, nicky). **E-mailový quick-pick je z prahu vyňatý** (jedna adresa se vyplatí nabídnout i po jednom výskytu). `UITextChecker`/`UILexicon`/Slack práh neřeší (nejsou z personal poolu). |
| **Čísla & nicky — učení** | Zrušit v `passesFilters` zákazy `all-digit` a `mixed-alphanumeric`. Délkové meze a `denied` kontext zůstávají. → naučí se `2026`, `604593010`, `freedom266` z **prose**. |
| **Číselná/secure pole** | Beze změny — `phonePad`/`numberPad`/`oneTimeCode`/`creditCardNumber`/heslo/secure zůstávají `denied` (neučí se) a numpad. Telefony se učí jen z běžného textu. |
| **Bezpečnost relaxace** | Pojistka = existující field deny-list **+** práh `count ≥ 2`. OTP/jednorázový kód v běžném poli se naučí, ale jako singleton se **nikdy nenabídne**. (Reziduum: opakovaně psané citlivé číslo v ne-secure poli — akceptujeme, secure pole patří do `denied`.) |
| **Completion stránky** | Sjednotit: provider běží na **`.letters` i `.symbols`** (dnes jen `.letters`). `suggestionsActive` v controlleru už symbols považuje za aktivní, takže se provider jen srovná s controllerem. S number row jsou číslice na `.letters` → tam to běží i bez změny; symbols pokrývá uživatele bez number row. Ne `.emojis`/`.emojiSearch`/`.numeric`. |
| **`+` u telefonu** | Vedoucí `+` zůstává hranicí slova (token se uloží bez `+`, např. `420604731026`). Funkčně OK: když uživatel napíše `+` ručně, `suggestionAccept` nahradí jen číselný prefix a `+` zůstane. Chip ukáže číslo bez `+`. (Revisitable — alternativa: udělat vedoucí `+` součástí číselného tokenu, ale to má vedlejší efekty na tokenizaci.) |
| **Délka** | ~~`maxLength` prose 25 → **30**~~ → **revert na 25** (rozhodnuto při implementaci 2026-06-23): bump byl zbytečný — e-maily se učí přes `.emailAddress` kontext (vlastní cap 100, viz níže), takže prose limit se jich netýká, a telefon `420604731026` (12 znaků, vedoucí `+` se odřízne) se pohodlně vejde do 25. `minLength` 3 beze změny (rok `2026` projde). |
| **E-mail quick-pick** | Nový `EmailQuickPickProvider`: když `eligibility.learningContext == .emailAddress` **a** není aktivní word prefix (prázdné/začátek pole), vrátí **jednu** adresu z poolu (token obsahuje `@`), nejvyšší `count`, tie-break `lastUsed`. Renderuje se jako běžný plain chip; tap = vloží celou adresu. Když prefix je, řeší to normální prefix-match (už dnes funguje). |
| **„Učí se víc e-mailů?"** | Už dnes ano — každá adresa je samostatný záznam v poolu. Žádná změna učení e-mailů není potřeba (kromě quick-picku na zobrazení). |
| **Accept = usage signál** | Potvrzení **word-completion** chipu naučí/inkrementuje slovo. Implementace: v `.suggestionAccept` (po vložení) **stejný `.prose`-only guard** jako `learnIfWordBoundary` → `learning.learn(replacementText, .prose)`, gateované `suggestionsEnabled` + eligibility. Casing normalizuje `learn()` (pool je lowercase). |
| **Accept e-mailu** | Žádná nová cesta. `.prose` guard accept-learnu e-mail automaticky vynechá (v e-mailovém poli je kontext `.emailAddress`), a accept e-mailu **už dnes započítá existující field-end whole-field harvest** (`updatePendingEmail` → `commitPendingEmail`). Tím se vyhneme dvojímu počítání a navíc se e-mail správně **nezapočítá, když ho po acceptu smažeš** (field-end vidí prázdné pole). |
| **Accept emoji / Slack** | Beze změny — emoji mají vlastní `emojiUsageCounts` (bumpované svými cestami), word-completion accept-learn se jich netýká. |
| **Feedback loop** | Ohraničený — skóre osobních recents používá `min(count, 10)`, takže „accept → vyšší count → častější nabízení" saturuje na 10 a nemůže utéct. Skládá se s prahem `count ≥ 2`: překlepy se nenabízejí → nejdou potvrdit → accept-learn je vůči překlepům bezpečný. |
| **Chování diakritiky/scoringu jinak** | Beze změny. `matches`, směrový diakritický match, váhy ostatních zdrojů zůstávají. |

## Scope (fázovaně)

### Fáze A — Anti-překlep: práh `count ≥ 2` *(řeší původní bolest)*

- Nová laditelná konstanta `WordCompletionProvider` / `PersonalRecentsStore` `minSuggestCount = 2`.
- V `WordCompletionProvider`: záznamy z `recents.matches(prefix:)` s `count < minSuggestCount` **nevkládat** do merge (ostatní zdroje beze změny). Slovo se dál učí od prvního výskytu — práh je čistě na *zobrazení*.
- Ověřit interakci se scoringem: práh je tvrdý cut, ne změna vah.

### Fáze B — Čísla & nicky *(řeší díru v užitečnosti + sjednocení stránek)*

- `PersonalRecentsStore.passesFilters`: odstranit větve `all-digit` a `mixed-alphanumeric` reject; ~~`maxLength` 25 → 30~~ (zůstává **25**, viz rozhodnutí výše). `denied` a délkové meze zůstávají.
- `WordCompletionProvider`: `guard case .letters` → povolit `.letters` **i** `.symbols` (ostatní stránky dál `[]`).
- Ověřit `WordPrefixExtractor` na číselných/alfanum prefixech (už je bere — `isWordCharacter` zahrnuje `isNumber`); přidat testy pro `604`, `freedom266`, vedoucí `+`.
- `+`: nechat jako hranici (viz rozhodnutí); test, že `+420…` se uloží/nabídne jako `420…` a že výsledný vložený text po ručním `+` je správný.

### Fáze C — E-mail quick-pick

- Nový `EmailQuickPickProvider: SuggestionProviding` (injektovaný `PersonalRecentsReading`). Aktivní jen pro `emailAddress` learning context + prázdný/žádný word prefix; vrátí 1 nejlepší adresu (`@` token, max `count`, tie `lastUsed`). Vyňato z prahu count≥2.
- Zaregistrovat v `SuggestionCoordinator` (pořadí tak, aby quick-pick neválcoval normální prefix-match, když uživatel píše).
- Ověřit, že se nepřekrývá s prefix-match cestou (když je prefix, quick-pick mlčí).

### Fáze D — Accept = usage signál *(counter odráží používání, ne jen ťukání)*

- V [`InputDispatcher`](../KeyboardCore/Sources/Logic/InputDispatcher.swift) `.suggestionAccept` (po `insertText`): zavolat učení se **stejným guardem** jako `learnIfWordBoundary` — `guard let learning, state.currentEligibility.learningContext == .prose else { … }` → `learning.learn(replacementText, .prose)`. Vytáhnout do sdíleného helperu, ať se logika neduplikuje.
- `.prose` guard automaticky vynechá e-maily (kontext `.emailAddress`) → e-maily zůstávají na field-end harvestu (žádné dvojí počítání). Emoji/Slack accept se netýká (jiná akce / vlastní counter).
- Ověřit gating: s vypnutými Návrhy (`learning == nil`) se nic neučí; v `denied` poli se chip stejně nezobrazí.
- Pozn.: accept-learn slovo ukládá od `count==1`, ale **zobrazení** pořád řídí práh z Fáze A (`count ≥ 2`).

## Regresní síť

**Existující — záměrně mění chování (aktualizovat testy):**
- [`PersonalRecentsStoreTests`](../KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift): `testFilter_allDigits_skipped` a `testFilter_mixedAlphanumeric_skipped` → invertovat (nově se **učí**). ~~`testFilter_tooLong_skipped` → posunout hranici na 30~~ (hranice zůstává 25, bump zamítnut — viz rozhodnutí Délka).
- [`WordCompletionProviderTests`](../KeyboardCore/Tests/Suggestions/WordCompletionProviderTests.swift): pokud existuje test „na `.symbols` vrací `[]`", aktualizovat (nově vrací návrhy). Přidat test prahu `count ≥ 2`.

**Existující — musí projít beze změny:**
- [`SuggestionEligibilityTests`](../KeyboardCore/Tests/Suggestions/SuggestionEligibilityTests.swift) — `denied`/secure/numeric pole beze změny.
- [`WordPrefixExtractorTests`](../KeyboardCore/Tests/Suggestions/WordPrefixExtractorTests.swift) — beze změny (jen přidat číselné případy).
- [`InputDispatcherSuggestionTests`](../KeyboardCore/Tests/Suggestions/InputDispatcherSuggestionTests.swift) — `.suggestionAccept` **vkládání** textu (smaž prefix → vlož replacement + space) se nemění; jen přibyde volání learningu. Existující assertions na vložený text musí projít.
- KeyboardUI snapshot suite — UI baru se nemění (jen obsah).

**Nové:**
- Práh: `count==1` slovo se nenabídne, `count>=2` ano; učení stále ukládá od `count==1`.
- Bezpečnost: jednorázové číslo (OTP-like) v ne-secure poli se naučí, ale nenabídne (singleton).
- Čísla/nicky: `2026`, `604593010`, `freedom266` se naučí z prose a nabídnou na `.letters` i `.symbols`.
- `+420…` round-trip (uloží/nabídne bez `+`, finální text s ručním `+` správně).
- E-mail quick-pick: prázdné e-mailové pole nabídne nejčastější adresu; s prefixem se chová jako dřív; mimo e-mailové pole quick-pick mlčí.
- Accept-learn: potvrzení prose chipu naučí/inkrementuje slovo (count `n` → `n+1`; nové slovo → `count==1`, vč. „promotnutí" slovníkového slova z `UITextChecker`/`UILexicon` do osobního poolu). V e-mailovém poli accept **neprojde** prose accept-learnem — e-mail řeší field-end harvest (žádné dvojí počítání); accept + následné smazání e-maily nenaučí. S vypnutými Návrhy se accept neučí.

## Akceptační kritéria

- Jednorázově napsaný překlep se **nikdy nenabídne** (práh `count ≥ 2`), ale po druhém výskytu reálného slova se nabídne.
- `denied`/secure/numeric pole: žádná změna učení ani návrhů.
- Čísla a nicky se učí z běžného textu a nabízejí na letters i symbols stránce.
- E-mailové pole: bez psaní nabídne 1 nejčastější dříve napsanou adresu; tap vloží celou.
- Potvrzení word-completion chipu zvedne count slova (prose); e-maily se nepočítají dvakrát; emoji/Slack accept counter slov neovlivní.
- Výkon beze změny (vše přes index z tasku 73; práh je O(1) filtr, quick-pick je jeden filtrovaný průchod poolem jen při fokusu, ne per-keystroke).
- Žádná nová telemetrie; pool zůstává on-device a gateovaný přepínačem Návrhy.

## Non-goals

- Učení na konci pole (zamítnuto — viz Kontext).
- Návrhy na numpadu / v `denied` polích (telefon/OTP/heslo).
- 3 e-maily najednou v baru (zvoleno: 1 nejlepší).
- Next-word prediction / autocorrect (trvale mimo scope).
- Změna scoringu/diakritického matchování mimo přidaný práh.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`** (ne `.xcodeproj`), simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: v běžném poli napsat 2× telefonní číslo → po 2. výskytu se nabízí; napsat překlep 1× → nenabídne se. V e-mailovém poli ověřit quick-pick.
- Pozn.: pre-existing flaky testy (memory *keymoji-paywall-snapshot-flaky*) nejsou regrese tohoto tasku.
