# 56 — SuggestionBar: zobrazovat i na symbol page (jen ne emoji / emoji-search)

**Status:** Done — 2026-06-08

> **Aktualizace 2026-06-13 (task 62 / favorites baseline):** Sekce „Co zůstává beze změny" níže
> už **neplatí** pro viditelnost baru. `KeyboardView.showsBarContent` je nově **odpojené** od
> `showsSuggestionBar` (master toggle + eligibilita): protože favorites jsou po onboardingu vždy
> neprázdné (task 62), top region na letter/symbol stránkách **vždy** ukazuje obsah — buď word/Slack
> suggestions při psaní, jinak fallback na favorites quick-access. Master toggle a `allowDisplay`
> teď gateují **jen výpočet word/Slack suggestions**, ne renderování baru (favorites se ukážou i ve
> secure poli). Viz `KeyboardView.showsBarContent` a `KeyboardViewController.showsSuggestionBar`.

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Medium (UX — bar dostupný i na symbol page)

## Cíl

Rozšířit viditelnost `SuggestionBarView` ze samotných `.letters` stránek i na symbol page.
Pravidlo zní:

> Suggestion bar se zobrazuje **vždy** (když to dovolí master toggle a eligibilita pole),
> **kromě** případů, kdy je aktivní emoji panel (`KeyboardView.isEmojiKeyboard`) nebo emoji
> search (`KeyboardView.isEmojiSearchKeyboard`).

Jediná reálná změna oproti dnešku: **odpadá omezení jen na `.letters`** — bar se nově ukáže
i na symbol page (`.symbols`).

**Co zůstává beze změny:** master toggle `suggestionsEnabled` a field eligibility
(`currentEligibility.allowDisplay`) **platí dál** — pokud je suggestions vypnuté nebo pole
nedovoluje zobrazení, bar se nezobrazí (jako dnes).

## Klíčová zjištění z průzkumu kódu

Viditelnost baru je dnes řešená **na dvou paralelních místech**, která musí dávat stejnou
odpověď, jinak se rozejde výška hostu a výška SwiftUI obsahu a iOS obsah ořízne (stejná třída
bugu, jako řešil task 53/54 a komentář u `.emojiSearch`):

1. **View-side gate** — [`KeyboardView.effectiveShowsBar`](KeyboardUI/Sources/Views/KeyboardView.swift:93):
   ```swift
   guard showsSuggestionBar, !isEmojiKeyboard, !isEmojiSearchKeyboard else { return false }
   if case .letters = layout.page { return true }   // ← tahle .letters podmínka pryč
   return false
   ```
   Řídí jak **renderování** baru ve `body`, tak **výšku SwiftUI framu** přes
   [`keyboardHeight`](KeyboardUI/Sources/Views/KeyboardView.swift:257)
   (`KeyboardMetrics.keyboardHeight(for:showsSuggestionBar: effectiveShowsBar)`).

2. **Controller-side gate** — [`KeyboardViewController.showsSuggestionBar`](KeyboardExtension/Sources/KeyboardViewController.swift:501):
   ```swift
   guard state.suggestionsEnabled, state.currentEligibility.allowDisplay else { return false }
   if case .letters = state.page { return true }   // ← tahle .letters podmínka pryč
   return false
   ```
   Řídí (a) **výšku height constraintu hostu** přes
   [`desiredKeyboardHeight()`](KeyboardExtension/Sources/KeyboardViewController.swift:432),
   (b) jestli se vůbec počítají suggestions a co se předá do `KeyboardRoot`
   ([`makeRoot`](KeyboardExtension/Sources/KeyboardViewController.swift:440)),
   (c) viditelnost favorites (`favoritesVisible`).

Obě místa dnes kódují **stejnou logiku** a musí jí kódovat i po změně — jinak drift výšky →
clipping. Změna je na obou stejná: smazat větev `.letters` a nechat jen výjimku na emoji /
emoji search.

- **`KeyboardMetrics.keyboardHeight(for:showsSuggestionBar:)`** přičítá
  `suggestionBarFootprint` (= `suggestionBarHeight 40 + suggestionBarGap 2`) jen když je
  `showsSuggestionBar == true` ([`KeyboardMetrics.swift:49`](KeyboardCore/Sources/Logic/KeyboardMetrics.swift:49)).
  Jakmile bar nově svítí i na symbol page, **musí o tom vědět oba výpočty výšky** (host i view) —
  což zařídí to, že oba čtou stejně upravenou podmínku.

- **`SuggestionBarView` je už dnes content-agnostické** ([SuggestionBarView.swift:5](KeyboardUI/Sources/Views/SuggestionBarView.swift:5)):
  prázdné `suggestions` → fallback na favorites scroll; prázdné suggestions i favorites →
  bar zabírá slot, ale nic nekreslí (decision C1). Na symbol page se tedy bezpečně ukáže
  favorites, případně prázdný slot — žádné artefakty.

## Návrh

Minimální, symetrická úprava na obou gate místech — **smazat větev `.letters`**, zbytek nechat.

1. **View** — [`effectiveShowsBar`](KeyboardUI/Sources/Views/KeyboardView.swift:93):
   ```swift
   private var effectiveShowsBar: Bool {
       showsSuggestionBar && !isEmojiKeyboard && !isEmojiSearchKeyboard
   }
   ```
   Aktualizovat doc komentář na [řádku 89–92](KeyboardUI/Sources/Views/KeyboardView.swift:89) —
   už neplatí „shown only on letter pages“; nově „shown everywhere except emoji / emoji-search“.

2. **Controller** — [`showsSuggestionBar`](KeyboardExtension/Sources/KeyboardViewController.swift:501):
   ```swift
   private var showsSuggestionBar: Bool {
       guard state.suggestionsEnabled, state.currentEligibility.allowDisplay else { return false }
       return state.page != .emojis && !state.page.isEmojiSearch
   }
   ```
   Master toggle + eligibilita zůstávají jako guard (beze změny). Aktualizovat doc komentář
   na [řádku 499–500](KeyboardExtension/Sources/KeyboardViewController.swift:499).

   > Pozor na konzistenci: `showsSuggestionBar` (controller) a `effectiveShowsBar` (view) musí
   > vrátit **totéž** pro každou stránku. Obě = „toggle ✔ + eligible ✔ + není emoji ani emoji
   > search“. Když se v budoucnu jedna změní, druhá musí taky — jinak clipping.

3. **`page.isEmojiSearch` / `page == .emojis`** je už existující API používané jinde
   (LayoutBuilder, desiredKeyboardHeight) — žádné nové signály se nezavádějí.

## Mimo scope

- **Word suggestions na symbol page.** Tady jen *zviditelňujeme* slot. Na symbol page nejsou
  word/Slack suggestions relevantní (počítají se z textu, ne ze symbolů) — bar tam reálně ukáže
  favorites, případně bude prázdný. Žádnou symbol-specific nabídku nevymýšlíme.
- **Master toggle / eligibilita.** Beze změny — `suggestionsEnabled` i `allowDisplay` dál
  rozhodují, jestli se bar vůbec ukáže.
- **Nový height/spacing.** `suggestionBarHeight` (40) + `suggestionBarGap` (2) beze změny.

## Testy

- **`KeyboardViewSnapshots`** — nový snímek: symbol page (`.symbols`) **s** suggestion barem
  (dnes by tam bar nebyl). Ověřit, že se bar renderuje a výška sedí (footprint přičten).
- **Konzistence výšky** — ověřit, že `desiredKeyboardHeight()` a `KeyboardView.keyboardHeight`
  dají stejnou hodnotu na symbol page i letters page (oba berou `showsSuggestionBar == true`).
- **Emoji / emoji-search** — bar **není** vidět (regrese): existující emoji snímky musí zůstat
  beze změny (žádný bar, žádná změna výšky).
- **Toggle off / neeligibilní pole** — bar se **nezobrazí** ani na symbol page (regrese guardu).

## Závislosti

Žádné blokující. Staví na stávající `showsSuggestionBar` / favorites infrastruktuře
(task 40 word completion, task 44 favorites v baru, task 49 favorites paging).
Pozor na společnou výškovou logiku zavedenou v tasku 53/54.
