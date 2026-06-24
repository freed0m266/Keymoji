# 77 — Learned words: uniformní suggest práh (skrýt 1×, zrušit e-mail výjimku)

**Status:** Done — 2026-06-24 (obě fáze A+B v `feature/77-learned-words-uniform-suggest-threshold`; Codex review: navíc zviditelněn Clear All i při poolu jen ze skrytých singletonů přes `hasLearnedWords`). Navazuje na [74](74-learning-quality-numbers-emails.md) a **mění jedno jeho rozhodnutí** (viz „Supersedes").

**Priorita:** v1.x (kvalita UX learned-words editoru + konzistence návrhů) · **Úsilí:** S (jeden filtr v editoru + odebrání jedné větve + jeden gate; fázované) · **Dopad:** Medium (čistší seznam naučených slov + jeden jediný práh napříč celým systémem).

**Souvisí s:** [74 — kvalita učení a návrhů](74-learning-quality-numbers-emails.md) (zavedl `minSuggestCount` a e-mail výjimku — tu tady rušíme), [48 — seznam naučených slov](48-learned-words-list-management.md), [40 — completion model](40-word-completion-suggestions.md). Glosář: termín **Learned word** v [`CONTEXT.md`](../CONTEXT.md) (zpřesněn touto session: *learned* ≠ *offered*). Dotýká se [`LearnedWordsEditorViewModel`](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift), [`LearnedWordsEditorView`](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift), [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift), [`EmailQuickPickProvider`](../KeyboardCore/Sources/Logic/Suggestions/EmailQuickPickProvider.swift).

## Kontext / proč

Dvě věci, jedno sjednocující rozhodnutí:

1. **Editor learned words dnes ukazuje i `count == 1` slova.** Ta se ale nikdy nenabízejí (práh `minSuggestCount = 2` z tasku 74) → jsou v seznamu jen balast, který ho aktivnímu pisateli zaplaví.
2. **Task 74 (Fáze C) dal e-mailovým adresám výjimku z prahu** — `@`-token se nabízí už po `count == 1` (v `WordCompletionProvider` přes `isAddress` bypass + v `EmailQuickPickProvider` bez prahu). Tím se ale „seznam = co se nabízí" rozchází: `count==1` adresa se nabízí, ale chtěli bychom ji v editoru skrýt.

**Rozhodnutí, které obojí sjednocuje:** udělat `minSuggestCount` **jediným zdrojem pravdy** pro práh — pro prose slova, pro adresy **i** pro viditelnost v editoru. Tím:
- editor skryje vše pod prahem (řeší bod 1),
- e-mail výjimka zmizí, takže adresy se taky nabízejí až od `count >= 2` (řeší rozpor v bodě 2),
- platí čistý invariant: **„learned-words editor zobrazuje přesně ty záznamy z poolu, které pool umí nabídnout."**

### Auditovatelnost (vědomě přijatá cena)

Skrytí singletonů odebere jediné místo, kde uživatel vidí a *cíleně maže* jednorázový token (task 74 učí i čísla/nicky, takže např. jednorázové OTP-like číslo z ne-secure pole se uloží jako singleton). Vážili jsme **přepínač „Zobrazit vše"** (zachoval by granulární audit) — **zamítnuto** pro tuhle session: je to UI navíc a purge potřebu pokrývá **Clear All** (smaže celý pool včetně skrytých singletonů) + LRU eviction. Mizí jen *granulární* mazání singletonu, což je niche. (Revisitable — přepínač je levný upgrade, kdyby to vadilo.)

### Cold-start adresy (vědomě přijatá cena)

Zrušením výjimky se nejlepší adresa nabídne až od **3. e-mailového pole** místo dnešního 2. (musíš ji napsat ručně 2×; field-end harvest zvedne count na konci pole). Jedno napsání navíc. Přijato vědomě v rámci preference konzistence nad early-offer pohodlím.

## Supersedes

**Task 74, Fáze C — e-mail výjimka z `minSuggestCount`.** Task 74 ji zavedl s odůvodněním „jedna adresa se vyplatí nabídnout i po jednom výskytu". Tahle session to rozhodnutí **otáčí** ve prospěch jednoho uniformního prahu. Quick-pick jako **featura zůstává** (proaktivní nabídka v prázdném e-mailovém poli) — jen se brzdí stejným prahem. Příslušné testy se invertují (viz Regresní síť).

## Cíl

1. Learned-words editor nezobrazuje slova s `count < minSuggestCount`.
2. Filtr je **navázaný na konstantu `minSuggestCount`** (ne natvrdo `< 2`), takže je jeden zdroj pravdy a budoucí ladění konstanty seznam následuje.
3. E-mailová výjimka z prahu **zrušena** v obou cestách (prefix-match i quick-pick) → adresy se nabízejí až od `count >= 2`.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Editor filtr** | Skrýt `count < WordCompletionProvider.minSuggestCount`. Aplikovat na `allWords` (na vstupu, ne až na zobrazený `words`), aby search i sort běžely nad už profiltrovaným poolem. |
| **Zdroj prahu** | **Stejná konstanta `minSuggestCount`** sdílená editorem i providery. Žádná duplicitní/lokální konstanta. |
| **E-mail výjimka — prefix-match** | Odstranit `isAddress` bypass i `inEmailField` proměnnou ve [`WordCompletionProvider`](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift) (řádky ~100–103) → `guard match.count >= Self.minSuggestCount` uniformně. |
| **E-mail výjimka — quick-pick** | [`EmailQuickPickProvider`](../KeyboardCore/Sources/Logic/Suggestions/EmailQuickPickProvider.swift) `.filter` rozšířit o `&& $0.count >= WordCompletionProvider.minSuggestCount`. Quick-pick zůstává, jen nabízí adresu až od 2×. Aktualizovat doc-comment (řádky 15–16 „Exempt from minSuggestCount" už nebude platit). |
| **Granularní audit singletonů** | Přijato, že mizí; Clear All zůstává jako purge escape hatch. Bez přepínače „Zobrazit vše" (zamítnuto pro tuto session). |
| **Empty-state copy** | Ověřit, že empty-state editoru čte rozumně i pro uživatele, jehož pool obsahuje **jen** podprahové singletony (`words` je po filtru prázdné, ale pool ne). Pokud current copy implikuje „nic naučeného" moc silně, lehce upravit. Drobnost, ne blocker. |
| **Clear All / remove** | Beze změny chování. `clearAll()` maže celý store (i skryté). `remove(at:)` mapuje offsety na *zobrazené* (profiltrované) řádky → maže správné. |

## Scope (fázovaně)

### Fáze A — Editor filtr *(řeší balast v seznamu)*
- V [`LearnedWordsEditorViewModel`](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorViewModel.swift): v `reload()` profiltrovat `store.allLearnedWords()` na `count >= WordCompletionProvider.minSuggestCount` **před** `sorted(...)`. (Filtr patří k `allWords`, ne k `applyFilter()`, který je pro search.)
- Ověřit empty-state větvení v [`LearnedWordsEditorView`](../Features/LearnedWordsEditor/Sources/LearnedWordsEditorView.swift) (`words.isEmpty` + `searchText.isEmpty` → `emptyState`). Případně upravit copy (viz rozhodnutí).
- Import `KeyboardCore` v editoru už je (kvůli `LearnedWord`/`PersonalRecentsStore`) → konstanta je dostupná.

### Fáze B — Zrušení e-mail výjimky *(sjednocení prahu)*
- `WordCompletionProvider`: odstranit `isAddress`/`inEmailField` → uniformní `count >= minSuggestCount`. Aktualizovat doc-comment (řádky ~96–99 popisující address výjimku).
- `EmailQuickPickProvider`: přidat práh do `.filter`; aktualizovat doc-comment.

## Non-goals

- Změna hodnoty `minSuggestCount` (zůstává 2).
- Přepínač „Zobrazit vše" / sekce „Navrhované vs nenavrhované" (zamítnuto — viz Auditovatelnost).
- Jakákoli per-kind výjimka (právě je rušíme — žádné nové).
- Zrušení quick-picku (zůstává, jen se brzdí prahem).
- Změna scoringu / diakritického matchování / accept-learn z tasku 74 (beze změny).

## Akceptační kritéria

- Editor: slovo s `count == 1` **není** v seznamu; `count >= 2` je. Práh čte z `minSuggestCount`.
- `count == 1` adresa se **nenabízí** ani prefix-matchem, ani quick-pickem; od `count >= 2` se nabízí (quick-pick v prázdném e-mailovém poli funguje).
- Clear All smaže celý pool (včetně skrytých singletonů); swipe-delete v editoru maže správný (zobrazený) záznam.
- Prose chování z tasku 74 (učení od `count==1`, accept-learn, čísla/nicky) beze změny.
- Žádná telemetrie; pool zůstává on-device.

## Regresní síť

**Existující — záměrně mění chování (invertovat/aktualizovat):**
- [`EmailQuickPickProviderTests`](../KeyboardCore/Tests/Suggestions/EmailQuickPickProviderTests.swift): test, že `count==1` adresa se nabídne → **invertovat** (nově se nenabídne; nabídne se od `count>=2`).
- [`WordCompletionProviderTests`](../KeyboardCore/Tests/Suggestions/WordCompletionProviderTests.swift): pokud existuje test address-výjimky (`isAddress` → nabídne `count==1` v e-mailovém poli) → **invertovat** (nově gateováno prahem).

**Existující — musí projít beze změny:**
- Prose práh `count >= 2` (task 74 Fáze A) — beze změny.
- `SuggestionEligibilityTests` — `denied`/secure/numeric pole beze změny.
- Accept-learn (task 74 Fáze D) — beze změny.
- KeymojiUI/editor snapshot suite — pokud existuje, sample data mají `count >= 2` (žádný singleton), takže by se nemělo hnout; ověřit.

**Nové:**
- Editor skryje `count==1`, ukáže `count>=2`; filtr navázán na `minSuggestCount`.
- Editor s poolem obsahujícím jen singletony → zobrazí empty-state (ne crash, čitelná copy).
- Uniformní práh: prose i adresa i quick-pick se shodují na `count>=2`.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: napsat slovo 1× → v editoru není; napsat 2× → je. Napsat adresu 1× → quick-pick mlčí; 2× → quick-pick nabídne.
- Pozn.: pre-existing flaky snapshot (memory *keymoji-paywall-snapshot-flaky*) není regrese tohoto tasku.
