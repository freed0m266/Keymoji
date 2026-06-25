# 82 — Favorites bar: vycentrovat pro free uživatele

**Status:** Todo — připraveno z grill session 2026-06-25.

**Priorita:** v1.x (kosmetika suggestion baru pro free uživatele) · **Úsilí:** XS (jeden flag protáhnout do view + podmíněný Spacer + snapshot) · **Dopad:** Low (vizuální vyladění; free user má ≤6 favoritů nalevo, působí to nedotaženě).

**Souvisí s:** [44 — favorites v suggestion baru](44-favorite-emojis-in-suggestion-bar.md), [49 — favorites paging (Plus)](49-favorites-bar-tabview-paging.md), [63 — monetizace / Plus](63-monetization-keymoji-plus.md). Glosář **Effective Plus** v [`CONTEXT.md`](../CONTEXT.md). Dotýká se [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift), [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift), [`KeyboardViewController`](../KeyboardExtension/Sources/KeyboardViewController.swift).

## Kontext / proč

**Co kód dnes dělá:** [`SuggestionBarView.favoritesBar`](../KeyboardUI/Sources/Views/SuggestionBarView.swift) (ř. 156–179) skládá emoji **doleva** s trailing `Spacer(minLength: 0)`. Free uživatel je vždy **jedna stránka** (≤6 favoritů; paging i frequency sort jsou Plus-only — viz controller `orderedFavorites`/`FavoritesEntitlement.visibleFavorites`). Trailing Spacer u Plus zarovnává **poslední neúplnou stránku** doleva (multi-page).

**Bolest:** free user vidí ≤6 favoritů nalepených doleva s prázdnem vpravo → působí to nedotaženě.

**Co chceme:** free uživateli **vycentrovat** skupinu favoritů. Plus uživateli se **nesmí nic změnit** (centrování nesmí rozbít zarovnání poslední neúplné stránky u multi-page).

## Cíl

1. Free (`!effectiveIsPlus`) → skupina favoritů vystředěná.
2. Plus → beze změny (trailing-Spacer leading zarovnání zůstává).
3. View nezná monetizaci — dostane sémantický flag, ne `isPlus`.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Interpretace „na střed"** | **Vystředěný cluster** — emoji drží 42pt sloty, skupina je horizontálně na středu (symetrické mezery). NE rovnoměrné rozprostření přes celou šířku (u 2–3 favoritů by vypadalo rozházeně). |
| **Flag** | Sémantický `centersFavorites: Bool = false` na `SuggestionBarView` (default false → stávající call-sites a snapshoty beze změny). Controller spočítá `!state.effectiveIsPlus`. View neví o Plus. |
| **Implementace centrování** | Při `centersFavorites == true` přidat **leading** `Spacer(minLength: 0)` (trailing zůstává) → dvě stejné mezery vystředí cluster. Při false beze změny (jen trailing). |
| **Plus / multi-page** | Netknuté — flag je false → leading Spacer se nepřidá → poslední neúplná stránka dál zarovnaná doleva. |
| **Vrstvení flagu** | Protáhnout `KeyboardViewModel` → [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift) (instancuje `SuggestionBarView`, ř. 144) → `SuggestionBarView`. Controller nastaví v `makeViewModel`/`syncModel` jako `!state.effectiveIsPlus`. |

## Scope

- [`SuggestionBarView`](../KeyboardUI/Sources/Views/SuggestionBarView.swift): přidat `public let centersFavorites: Bool` (default `false` v initu); v `favoritesBar` HStacku podmíněně prepend leading `Spacer(minLength: 0)`.
- [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift): přidat průchozí property (default false), předat do `SuggestionBarView(...)` (ř. ~144).
- `KeyboardViewModel` (observable model): přidat `centersFavorites` (nebo `isPlus`); controller ji plní `!state.effectiveIsPlus`.
- [`KeyboardViewController`](../KeyboardExtension/Sources/KeyboardViewController.swift): nastavit flag v `makeViewModel`/`syncModel` (`state.effectiveIsPlus` už se používá v `orderedFavorites`).

## Non-goals

- Jakákoli změna chování pro Plus (multi-page, paging, sort, zarovnání poslední stránky).
- Rovnoměrné rozprostření / justified layout (zamítnuto — chceme cluster na střed).
- Změna free limitu (zůstává `freeFavoritesLimit = 6`).
- Centrování emoji panelu / recents řádku (mimo scope — jen `favoritesBar` v suggestion baru).
- Předání `isPlus` přímo do view (raději sémantický `centersFavorites`).

## Akceptační kritéria

- Free, 6 favoritů → cluster vystředěný (symetrické mezery vlevo/vpravo), ne nalepený doleva.
- Free, 3 favority → cluster na středu (větší symetrické mezery).
- Plus → beze změny (i s neúplnou poslední stránkou zarovnáno doleva, paging funguje).
- Default `centersFavorites = false` → stávající snapshoty/call-sites se nehnou.

## Regresní síť

**Existující — musí projít beze změny:**
- Existující `SuggestionBarView` snapshoty/preview (default false) — beze změny.
- Plus paging (task 49), free clamp na 6 (task 63) — beze změny.
- `refreshFavoritesDisplayOrder` / freeze-while-visible logika v controlleru — beze změny.

**Nové:**
- Free centrovaný cluster (snapshot pro 3 a 6 favoritů).
- Flag default false zachová stávající chování.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, simulátor iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Manuálně: free účet (debug simulate-free, task 67) → klávesnice → favorites bar vycentrovaný; přepnout na Plus → zpět doleva + paging.
- Nový snapshot: re-record přes `SIMCTL_CHILD_SNAPSHOT_TESTING_RECORD` nebo smazat `.png` (memory *keymoji-snapshot-rerecord*).
- Pre-existing flaky paywall snapshot (memory *keymoji-paywall-snapshot-flaky*) není regrese tohoto tasku.
