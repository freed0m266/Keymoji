# 80 — Soft-boost naučených slov nad iOS slovník

**Status:** Todo — připraveno z grill session 2026-06-25. Ladí scoring z [tasku 40](40-word-completion-suggestions.md); nemění jeho strukturu.

**Priorita:** v1.x (učení dnes „nesedí" — tvé naučené slovo dlouho prohrává s obecným iOS tipem) · **Úsilí:** S (jedna konstanta + úprava jednoho výpočtu skóre + přepis lživého komentáře + testy) · **Dopad:** Medium (naučená slova se chovají podle slibu „přizpůsobí se mně").

**Souvisí s:** [40 — completion model](40-word-completion-suggestions.md) (scoring), [77 — uniformní práh](77-learned-words-uniform-suggest-threshold.md), [79 — whitespace tokenizer](79-whitespace-word-tokenizer-email-completion.md) (souběžná, nezávislá; po 79 dostane boost i email-token). Dotýká se výhradně [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift).

## Kontext / proč

**Co kód dnes dělá** ([`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift)):
- **Naučené slovo:** `min(0.55 + 0.05·min(count,10), 1.0)` → count 2 = **0.65**, count 7 = **0.90**, count 8 = **0.95**, count 9+ = **1.0**.
- **iOS `UITextChecker`:** nejlepší tip = **0.9**, lineárně dolů k 0.4.
- **`UILexicon`:** placatě **0.3**.

**Bolest:** naučené slovo potřebuje **~8 výskytů**, aby přebilo *nejlepší* tip iOS. Komentář u providera přitom tvrdí *„personal recents — the strongest signal"* (ř. 18) — **záměr a čísla si protiřečí** pro málo používaná slova.

**Co chceme (grill rozhodnutí — varianta C, „soft boost"):** naučené slovo dostane konstantní přídavek, takže vyhraje horní slot dřív, ale **čerstvě naučené (2–3×) ještě ustoupí** nejlepšímu iOS tipu. Bar ukazuje až 3 chipy, takže typicky se vejdou oba — řešíme jen, kdo bere horní/nejvýraznější slot.

### Co jsme zvážili a zamítli

- **(A) Learned-first (absolutní priorita):** jakékoli naučené slovo nad prahem přebije jakýkoli slovníkový tip. **Zamítnuto** — count-2 fragment by přeskočil i perfektní slovníkové slovo; chceme měkčí náběh.
- **(B) Status quo (blend):** necháme jak je. **Zamítnuto** — naučené dlouho prohrává a komentář dál lže.

## Cíl

1. Naučené slovo dostane laditelný `personalBoost` (default **+0.2**).
2. Přechod: count 2 = 0.85 (iOS top 0.9 vyhraje), count 3 = 0.90 (remíza), count **4 = 0.95 → naučené vyhraje**, count 5+ vyhraje.
3. Na nižších slotech (2./3. chip) naučená slova přebijí slabší iOS tipy už od count 2.
4. Lživý komentář přepsán na pravdu.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Boost** | Konstanta `personalBoost = 0.2`, přičtená ke skóre personal recents. **Laditelná** (vedle `minSuggestCount`), ať se přechod dá hýbat bez přepisu logiky. |
| **Přechod** | Count 4 (= naučené vyhraje horní slot). Ekvivalent +0.2. (+0.25 → count 3, +0.15 → count 5 — kdyby se ladilo.) |
| **Strop `[0,1]`** | Na personal recents cestě **zvednout** (nebo zrušit clamp), jinak by se boost na vrcholu „sežral" a count 8/9/10 by splynuly na 1.0 a ztratily řazení podle count. Skóre je jen řadicí, horní mez nevadí. |
| **Merge / dedupe** | Beze změny — `consider` drží max; slovo, co je naučené i ve slovníku, dostane vyšší (boostnuté) skóre. Sub-prahové naučené slovo, co vouchne slovník, se pořád ukáže přes slovníkové skóre. |
| **iOS / lexikon skóre** | Beze změny (0.9→0.4 ordinálně; lexikon 0.3). „Sebejistost" iOS = jen ordinální pořadí, žádná pravděpodobnost z `UITextChecker`. |
| **Komentář** | Přepsat doc-comment (ř. 17–24 a blok (a) ~90–95) na reálné chování: *personal recents get a soft `+personalBoost` so a well-used learned word (≥4×) outranks the best `UITextChecker` hit, while a freshly-learned (2–3×) one still yields to it; below the top slot, learned outrank weaker dictionary hits from count 2.* |

## Scope

- [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift):
  - přidat `public static let personalBoost = 0.2`,
  - v bloku (a) (personal recents, ř. ~96–100) přičíst boost a zvednout/odstranit `[0,1]` clamp,
  - přepsat doc-comment třídy + blok (a).

## Non-goals

- Změna `minSuggestCount` (zůstává 2).
- Změna iOS/`UILexicon` skóre nebo merge/dedupe pravidla.
- Změna struktury providerů nebo coordinatoru.
- Learned-first absolutní priorita (zamítnuto).

## Akceptační kritéria

- Naučené slovo `count == 2` (skóre 0.85) prohraje horní slot s iOS top (0.9), ale přebije iOS tip pod ~prostředkem pole.
- Naučené slovo `count == 4` (0.95) přebije iOS top (0.9).
- Dvě naučená slova se mezi sebou řadí podle count i nad count 8 (clamp nezploští řazení).
- Slovo naučené i ve slovníku se neduplikuje (dedup drží max).
- Sub-prahové naučené slovo, co je i ve slovníku, se pořád nabídne (přes slovníkové skóre).
- Komentár popisuje reálné chování.

## Regresní síť

**Existující — záměrně mění chování (aktualizovat):**
- [`WordCompletionProviderTests`](../KeyboardCore/Tests/Suggestions/WordCompletionProviderTests.swift): testy, co asertují konkrétní skóre personal recents (0.65 apod.) → přepočítat na boostnuté hodnoty.
- [`SuggestionCoordinatorTests`](../KeyboardCore/Tests/Suggestions/SuggestionCoordinatorTests.swift): pokud asertuje pořadí learned-vs-checker → aktualizovat na nový přechod.

**Existující — musí projít beze změny:**
- Slack-wins-wholesale priorita v coordinatoru.
- Dedupe case-insensitive (drží max).
- Práh `minSuggestCount` (task 77).

**Nové:**
- Přechod count 4 (learned přebije iOS top); count 2–3 ustoupí.
- Clamp nezploští řazení nad count 8.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: napiš nové slovo, co je i v iOS slovníku, 4× → ověř, že se posune nad iOS tip; po 2× je pod ním.
