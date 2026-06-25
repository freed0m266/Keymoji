# 79 — Whitespace-only tokenizer + doplňování emailu přes tečku

**Status:** Todo — připraveno z grill session 2026-06-25. **Mění** tokenizační model z [tasku 40](40-word-completion-suggestions.md)/[74](74-learning-quality-numbers-emails.md). Rozhodnutí zafixované v [ADR 0003](../docs/adr/0003-whitespace-only-tokenizer-normalize-on-store.md).

**Priorita:** v1.x (uživatel si dnes nemůže nechat nabídnout vlastní email s tečkou v local-partu — `sv.mar@email.cz`) · **Úsilí:** M (změna hranice slova + normalizace při ukládání + testy; tokenizer má velkou test-churn) · **Dopad:** High pro uživatele s tečkou/číslicí v emailu nebo nicku; zároveň čistší architektura (mizí `trailingEmail` reassembly).

**Souvisí s:** [40 — completion model](40-word-completion-suggestions.md), [74 — kvalita učení (čísla/emaily, accept-learn)](74-learning-quality-numbers-emails.md), [77 — uniformní práh](77-learned-words-uniform-suggest-threshold.md), [80 — soft-boost ranking](80-personal-recents-soft-boost-ranking.md) (souběžná změna v completion cestě; nezávislé). Glosář **Learned word** v [`CONTEXT.md`](../CONTEXT.md) zůstává přesný (beze změny). Dotýká se [`WordPrefixExtractor`](../KeyboardCore/Sources/Logic/Suggestions/WordPrefixExtractor.swift), [`InputDispatcher`](../KeyboardCore/Sources/Logic/InputDispatcher.swift), [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift), [`PersonalRecentsStore`](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift), [`EmailQuickPickProvider`](../KeyboardCore/Sources/Logic/Suggestions/EmailQuickPickProvider.swift).

## Kontext / proč

**Co kód dnes dělá:** [`WordPrefixExtractor.isWordCharacter`](../KeyboardCore/Sources/Logic/Suggestions/WordPrefixExtractor.swift) bere jako znak slova písmena, číslice, apostrof a kombinační značky; `.`, `@`, pomlčku a rodinu `,.;:?!()[]{}/\` bere jako **tvrdou hranici slova**.

**Bolest:** uložený email `sv.mar@email.cz` se nabídne po napsání `sv` (prefix matchuje celý uložený token), ale jakmile uživatel napíše `.`, aktivní prefix se vynuluje (tečka = hranice) a chip zmizí. **Přes první tečku ve vlastním emailu se uživatel nikdy nedostane.** `EmailQuickPickProvider` řeší jen prázdné email-typované pole, ne běžný textfield uprostřed psaní.

**Smell:** už dnes existuje druhá regex cesta `trailingEmail`, jejímž jediným úkolem je **složit email zpátky** z fragmentů (`gmail`, `com`), na které ho tokenizer rozsekal. Tokenizer bojuje s daty.

**Co chceme (návrh z grillu — zjednodušit, ne přidat provider):** hranicí slova bude **jen whitespace/newline**. Aktivní prefix = celý úsek od poslední mezery (`sv.mar@e` zůstane jeden token, matchuje uložený email, a accept smaže přesně ten úsek — zadarmo). Interpunkce, kterou stará hranice slévala, se rozdělí na tři koncepty, kterými vždycky byla.

### Co jsme zvážili a zamítli

- **Samostatný email-prefix provider** (koncový token včetně teček, matchovaný proti naučeným `@`-tokenům), tokenizer beze změny. **Zamítnuto:** přidává provider a paralelní pojem „slova", roste složitost kvůli záplatě tokenizeru, který sekal data, co neměl. Zjednodušení tokenizeru maže víc, než přidává, a opraví i mazací matiku při accept.
- **Sebrat whitespace všemu včetně spouštěče učení** (maximální zjednodušení). **Zamítnuto:** ztratili bychom učení posledního slova zprávy odeslané bez koncové mezery (časté v chatu). Spouštěč učení je zadarmo a chování zachová.

## Tři koncepty (dříve slité do „hranice slova")

1. **Tokenizační hranice** — nově **jen whitespace/newline**. Řídí completion prefix i sklízený token.
2. **Spouštěč učení** — **ponecháváme** `[" ", ".", ",", "!", "?"]` (`InputDispatcher.learningBoundaries`), ať se konec věty naučí i bez mezery. **Záměrně asymetrické s tokenizační hranicí** (viz ADR 0003 Consequences — neopravovat).
3. **Filtr tvaru při ukládání** — při učení **ořízni krajní ne-alfanumerické znaky**, pak klasifikuj: token s `@` ulož jen když matchuje email-regex (`local@domain.tld`, ≤100), jinak ne-`@` token podle prose pravidla délky `[3, 25]`. **Nahrazuje** `trailingEmail` reassembly.

## Cíl

1. `sv.mar@email.cz` se nabízí napříč napsáním tečky: `sv` → `sv.` → `sv.mar@e` → … pořád nabízeno (po ≥2 výskytech, práh tasku 77).
2. Hranice slova = whitespace/newline. `trailingEmail` reassembly zmizí (regex se přepoužije jako store-gate detektor).
3. Próza nepoškozená: koncová interpunkce se nikdy neuloží (`ahoj,` → `ahoj`); `e.g.`/`i.e.` se neuloží jako email; `well-known`/`3.14` jsou jeden token.
4. `@`-token completion ignoruje chytrou kapitalizaci → vkládá uloženou lowercase podobu (žádné `Sv.mar@email.cz`).

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Tokenizační hranice** | `WordPrefixExtractor.isWordCharacter` → „znak slova = **není whitespace**" (newline taky hranice). Žádný speciál na `.`/`@`/pomlčku/interpunkci. |
| **Spouštěč učení** | Beze změny: `learningBoundaries = [" ", ".", ",", "!", "?"]`. Asymetrie s tokenizerem je záměr. |
| **Normalizace při ukládání** | Nový krok: ořež z obou konců znaky, co nejsou písmeno ani číslice. Pak klasifikuj a route do existujícího store filtru: `@`-shaped (email regex, `^local@domain.tld$`, ≤100) → `learn(_, .emailAddress)`; ne-`@` token → `learn(_, .prose)` (délka `[3,25]`); `@`-token, co **není** email-shaped → **zahodit** (neučit). |
| **`trailingEmail`** | Přepoužít regex jako celo-tokenový email detektor (`^…$`). Stará `$`-anchored reassembly v dispatcheru (ř. ~345–350) zmizí — token už přichází celý. |
| **Kapitalizace `@`-tokenů** | `WordCompletionProvider.displayCapitalization`: pokud kandidát obsahuje `@`, vrať uloženou (lowercase) podobu doslova; běžná slova beze změny. |
| **Accept mechanika** | Beze změny — díky whitespace hranici je `activeWordPrefix` celý úsek, takže `.suggestionAccept` smaže správný počet znaků a vloží celý email. |
| **`EmailQuickPickProvider`** | Featura zůstává (prázdné email pole, nula stisků). Jen aktualizovat doc-comment, který se odkazuje na staré `@`/`.`-jako-hranice odůvodnění (ř. ~12–17). |
| **Mid-word guard** | Zůstává; „znak slova" je teď „ne-whitespace" → guard při kurzoru mezi dvěma ne-whitespace znaky pořád platí. |

## Scope (fázovaně)

### Fáze A — Tokenizer *(řeší email přes tečku)*
- [`WordPrefixExtractor.isWordCharacter`](../KeyboardCore/Sources/Logic/Suggestions/WordPrefixExtractor.swift): → `!character.isWhitespace && !character.isNewline` (nebo ekvivalent). Aktualizovat doc-comment třídy (ř. 4–8 popisují starou interpunkční rodinu).
- Ověřit guard v [`InputDispatcher.swift:343`](../KeyboardCore/Sources/Logic/InputDispatcher.swift) (`isWordCharacter(chars[count-2])`) — sémantika „znak před koncovou hranicí je znak slova" platí dál.

### Fáze B — Normalize-on-store *(jediný kus nového kódu; nahrazuje `trailingEmail` speciál)*
- Helper na ořez krajní interpunkce (trim ne-alfanumerických z obou konců) — umístění na `WordPrefixExtractor` nebo malý util (vybrat při implementaci).
- V [`InputDispatcher.learnIfWordBoundary`](../KeyboardCore/Sources/Logic/InputDispatcher.swift) (ř. ~329–354): po sklizení `lastCompletedWord` aplikovat trim → klasifikovat (email-shape) → route do `.emailAddress`/`.prose`/drop. Odstranit stávající `trailingEmail`-based větev (ř. ~345–350).
- Přepoužít/zkonsolidovat email regex (dnes `…$`-anchored v `WordPrefixExtractor`) na celo-tokenový `^…$` match pro store-gate.
- `PersonalRecentsStore.passesFilters` zůstává (`.emailAddress` ≤100, `.prose` `[3,25]`) — klasifikaci dělá volající (dispatcher), jak velí kontrakt.

### Fáze C — Display kapitalizace
- [`WordCompletionProvider.displayCapitalization`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift): early-return uložené podoby pro kandidáta s `@`.

## Non-goals

- Nový email/completion provider (zamítnut — řešíme zjednodušením tokenizeru).
- Sebrání interpunkce i spouštěči učení (zamítnuto — ztráta učení konce věty).
- Změna prahu `minSuggestCount` (zůstává 2; email se nabídne až po 2× — to je task 77, ne tento).
- Změna scoringu (to je [task 80](80-personal-recents-soft-boost-ranking.md)).
- Zrušení `EmailQuickPickProvider` (zůstává).
- Zvláštní zacházení s URL/`/` tokeny (necháno na délkovém filtru — vědomě, viz grill).

## Akceptační kritéria

- V běžném textfieldu (po ≥2 dřívějších výskytech): psaní `s` → `sv` → `sv.` → `sv.mar` → `sv.mar@e` nabízí `sv.mar@email.cz` v každém kroku; tap vloží celý email a smaže napsaný úsek (žádné `sv.sv.mar@…`).
- Auto-cap na začátku pole: `Sv…` → chip i vložení je `sv.mar@email.cz` (lowercase, ne `Sv.…`).
- Próza: `Mám rád pizzu.` (i bez koncové mezery) naučí `pizzu` (ne `pizzu.`). `ahoj,` naučí `ahoj`.
- `e.g.` ani `i.e.` se neuloží (není email-shaped, a po trimu krátké/odmítnuté).
- `foo@bar` (bez TLD tečky) se **neuloží** (není email-shaped); `sv.mar@email.cz` se uloží celé.
- `well-known` je jeden naučený token (ne `known`).
- Žádná telemetrie; pool on-device.

## Regresní síť

**Existující — záměrně mění chování (aktualizovat):**
- [`WordPrefixExtractorTests`](../KeyboardCore/Tests/Suggestions/WordPrefixExtractorTests.swift): testy interpunkčních hranic (`well-known` → `known`, `@`/`.` splituje, `e.g.` reject) → **přepsat** na whitespace-only sémantiku.
- Testy `trailingEmail` (reassembly) → přepsat na store-gate detektor (celo-tokenový match).
- [`InputDispatcherSuggestionTests`](../KeyboardCore/Tests/Suggestions/InputDispatcherSuggestionTests.swift) / learning testy: harvest sklízí whitespace-delimited token + trim; email klasifikace.

**Existující — musí projít beze změny:**
- Mazání po slovech (`CursorLineWalkerTests`) — nepoužívá `isWordCharacter`.
- Slack `:shortcode:` boundary (`SlackEmojiParserTests`, `SlackEmojiSuggesterTests`) — vlastní logika.
- `SuggestionEligibilityTests` — deny-list beze změny.
- Práh `minSuggestCount` (task 77) — beze změny.

**Nové:**
- Email přes tečku (prefix `sv.`, `sv.mar@e` → match).
- Trim krajní interpunkce při učení; drop ne-email `@` tokenů.
- `@`-token kapitalizace bypass.
- Accept smaže celý úsek (žádná duplikace prefixu).

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: 2× napiš `sv.mar@email.cz ` v běžném poli (Notes/Messages) → pak začni psát `sv.` → ověř průběžnou nabídku; tap → celý email bez duplikace.
- Nové `.swift` soubory (helper): `tuist generate` před `xcodebuild test` (memory *keymoji-tuist-new-files-silent-skip*).
- Pre-existing flaky paywall snapshot (memory *keymoji-paywall-snapshot-flaky*) není regrese tohoto tasku.
