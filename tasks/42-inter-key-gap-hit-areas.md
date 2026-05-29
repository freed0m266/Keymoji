# 42 — Kliknutí do mezery mezi klávesami nesmí propadnout

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** High (daily-use: každý stisk co trefí 6pt/11pt gap propadne a nic se nestane — působí jako „nereagující" klávesnice)

## Souhrn

Mezery mezi klávesami jsou aktuálně **mrtvé zóny**. Když prst dopadne do horizontální mezery mezi dvěma klávesami (`HStack(spacing: 6)` v [`KeyRowView`](../KeyboardUI/Sources/Views/KeyRowView.swift)) nebo do vertikální mezery mezi řádky (`VStack(spacing: rowSpacing = 11)` v [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift)), nestane se nic — gesture nepatří žádné klávese, takže `onTap` nikdy nevystřelí.

**Cíl:** mezera mezi dvěma klávesami funkčně neexistuje. Tap kamkoliv do gapu mezi „f" a „g" se vždy programově stane jednou z akcí (klik na f **nebo** g). Totéž vertikálně — tap do mezery mezi řádky (např. mezi „k" v ASDF řádku a „m" ve spodním řádku) se vždy stane stiskem jedné ze sousedních kláves.

**Vizuálně se klávesnice nesmí změnit ani o pixel.** Klávesy si zachovají současné rozměry, 6pt vizuální mezery, rounded rect, rozestupy. Mění se **jen hit area**, ne render. Snapshot testy musí zůstat zelené — pokud spadnou, vizuál se změnil a to je bug.

## Co přesně chceme (a co ne)

**Rozdělit každou mezeru _mezi dvěma klávesami_ napůl** mezi oba sousedy:

- Horizontální 6pt gap mezi sousedními klávesami v řádku → každá ze sousedních kláves dostane +3pt hit area směrem do gapu. Potkají se přesně na ose mezery, žádný overlap, žádná díra.
- Vertikální 11pt gap mezi sousedními řádky → každý řádek dostane +5.5pt hit area směrem do gapu. Řádky mají různé dělení (qwertyuiop = 10 kláves, asdfghjkl = 9, shift+zxcvbnm+delete), takže pro daný bod platí: nad osou mezery patří bod klávese z horního řádku co je v jeho x-rozsahu, pod osou klávese ze spodního řádku. Tím se přirozeně vyřeší i offset případ „k / m" — žádný bod v mezeře nezůstane bez majitele a nikdy nedojde k overlapu (každá klávesa se roztáhne maximálně k ose, ne za ni).

**NESMÍ se absorbovat okraje a insety** (toto je explicitní požadavek — viz „a" zcela vlevo):

- Vnější okraje klávesnice — `horizontalPadding = 6` a `topPadding = 3` v [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift:70) — **se nesmí přidat** do hit area krajních kláves. Pravá hrana posledního klávesy v řádku, levá hrana prvního, horní hrana top řádku a dolní hrana spodního řádku zůstávají tam, kde jsou teď.
- Centrovací insety řádků — `insetWidth` Spacery v [`KeyRowView`](../KeyboardUI/Sources/Views/KeyRowView.swift:51) (přesně to prázdné místo ~půl klávesy nalevo od „a" v ASDF řádku, a kolem shift/delete řádku) — **se nesmí absorbovat**. „a" tedy NEzíská větší clickable area jen proto, že má vlevo od sebe prázdné místo.

Pravidlo jednou větou: hit area se rozšiřuje **pouze do gapu, který leží mezi dvěma reálnými klávesami**; nikdy do okraje klávesnice ani do centrovacího insetu řádku.

## Doporučený přístup

Klíčové omezení: SwiftUI gesture vystřelí jen v rámci **layout bounds** dané View. Pouhé zvětšení `.contentShape(Rectangle())` nestačí — `contentShape` definuje tvar jen _uvnit_ framu View, nerozšíří hit area za jeho hranice. Footprint klávesy musí reálně narůst.

**Doporučeno: rozšířit layout footprint klávesy o polovinu sousedního gapu a viditelný „cap" zachovat původní velikosti přes per-edge inset.** Tím zůstane gesture ownership v `KeyView` (kde žije veškerý stav — pressed feedback, long-press popover, backspace repeat, trackpad-on-space, highlight tracking) a nehrozí riskantní přepojení tohoto stavu do containeru.

Konkrétně:

1. **`KeyRowView`** ([KeyRowView.swift](../KeyboardUI/Sources/Views/KeyRowView.swift)):
   - `HStack` spacing → `0`. Footprint každé klávesy = vizuální šířka + 3pt za každou _vnitřní_ hranu (hranu sousedící s reálnou klávesou). Krajní klávesy: 0 na vnější straně (okraj/inset), 3pt na vnitřní. Insetové Spacery zůstávají beze změny.
   - KeyRowView zná index i `insetWidth`, takže umí spočítat per-side horizontal allowance (leading/trailing) pro každou klávesu a předat ho do `KeyView`.
2. **`KeyboardView`** ([KeyboardView.swift](../KeyboardUI/Sources/Views/KeyboardView.swift)):
   - Analogicky vertikálně: `VStack(spacing: 11)` → footprint řádku zahrne polovinu sousedního inter-row gapu (jen vnitřní hrany grid řádků), viditelné klávesy se odsadí zpět. Předat per-row top/bottom allowance do `KeyRowView` → `KeyView`.
   - Gap se vyplňuje **jen mezi řádky klávesové mřížky** (number row + QWERTY/symbol řádky + spodní funkční řádek). Mezery sousedící se suggestion barem ([SlackSuggestionBarView](../KeyboardUI/Sources/Views/SlackSuggestionBarView.swift)) a s emoji-search chrome se nevyplňují — jsou to jiné interaktivní povrchy.
3. **`KeyView`** ([KeyView.swift](../KeyboardUI/Sources/Views/KeyView.swift)):
   - Přijme per-edge gap allowances (leading/trailing/top/bottom). Viditelný `RoundedRectangle` + content odsadit per-edge paddingem tak, aby render zůstal pixel-identický se současným stavem. `.contentShape(Rectangle())` + `.gesture` pak pokrývají celý (rozšířený) footprint.

### Hlavní implementační past — souřadnice pro popover a trackpad

`KeyView` používá `keyWidth` a absolutní `location.x` na několika místech, která počítají s **vizuální** geometrií:

- `popoverOriginX(popoverWidth:)` a `popoverAlignment` ([KeyView.swift:399](../KeyboardUI/Sources/Views/KeyView.swift:399), [KeyRowView.swift:64](../KeyboardUI/Sources/Views/KeyRowView.swift:64)) — pozicování long-press popoveru.
- `updateHighlight(from:)` ([KeyView.swift:380](../KeyboardUI/Sources/Views/KeyView.swift:380)) — mapuje `location.x` na index alternativy.
- `handleSpaceDrag` / `trackpadAnchorX` ([KeyView.swift:246](../KeyboardUI/Sources/Views/KeyView.swift:246)) — trackpad scrubbing; je delta-based, takže relativně přežije, ale počátek souřadnic se posune o leading allowance.

Pokud footprint naroste, `location.x = 0` už není levá hrana viditelného capu, ale levá hrana footprintu (o `leadingAllowance` víc vlevo). Implementace musí tyto výpočty smířit — buď posunout souřadnicovou matematiku o `leadingAllowance`, nebo viditelný cap měřit ve vlastním child coordinate space. **`keyWidth` předávané do popover matiky musí zůstat vizuální šířka, ne footprint šířka.** Toto je hlavní zdroj regresí — otestovat popover na krajních i vnitřních klávesách a trackpad na space po změně.

### Alternativa (nedoporučeno, zvážit jen když výše uvedené nevyjde)

Centralizované coordinate-based hit testing na úrovni containeru (jeden gesture na `KeyboardView`, spočítat rect každé klávesy, routovat tap nejbližší klávese). Čisté pro gap logiku, ale vyžaduje přepojit _veškerý_ per-key gesture stav (popover, trackpad, backspace repeat, highlight) nahoru — velký refactor s vysokým rizikem regresí v tasku [07](07-long-press-popover.md), [09](09-delete-repeat.md), [23](23-trackpad-on-space.md). Proto až jako fallback.

## Scope

1. Rozšířit horizontální hit area do inter-key gapů v `KeyRowView` (split 50/50, jen mezi reálnými klávesami).
2. Rozšířit vertikální hit area do inter-row gapů přes `KeyboardView` → `KeyRowView` → `KeyView` (jen mezi grid řádky).
3. Zachovat vizuální geometrii kláves přes per-edge inset viditelného capu (pixel parita).
4. Smířit popover/highlight/trackpad souřadnicovou matiku s posunutým počátkem.
5. Honorovat vyloučení okrajů a insetů (krajní hrany kláves beze změny).

## Mimo scope

- **Emoji panel / emoji search grid.** [EmojiPanelView](../KeyboardUI/Sources/Views/EmojiPanelView.swift) a [EmojiSearchView](../KeyboardUI/Sources/Views/EmojiSearchView.swift) jsou scrollovací mřížky s vlastním layoutem — jiný problém, neřešit tady.
- **Suggestion bar.** Gapy okolo [SlackSuggestionBarView](../KeyboardUI/Sources/Views/SlackSuggestionBarView.swift) se nevyplňují.
- **Jakákoliv vizuální změna.** Žádné zvětšování kláves, zmenšování mezer, ani „skoro neviditelný" posun. Cíl je čistě hit area.
- **Long-press popover clipping** (task [21](21-popover-top-row-clipping.md)) — samostatný problém.

## Hotovo když

- [ ] Tap do horizontální mezery mezi dvěma klávesami (např. f/g) vždy vystřelí jednu z obou akcí — měřitelně, žádný propadlý tap.
- [ ] Tap do vertikální mezery mezi řádky (např. k/m offset případ) vždy vystřelí jednu ze sousedních kláves.
- [ ] „a" (a další krajní klávesy) **nezískaly** větší clickable area z okraje/insetu — levá hrana hit area „a" zůstává tam, kde končí viditelný cap.
- [ ] Pravá hrana posledních kláves a vnější okraje klávesnice se do hit area neabsorbovaly.
- [ ] Snapshot testy zelené (důkaz, že se vizuál nezměnil). Pokud spadnou kvůli intentional re-layoutu, prozkoumat zda render zůstal identický a teprve pak re-recordovat.
- [ ] Long-press popover funguje na krajních i vnitřních klávesách (alignment + highlight index correct po posunu počátku).
- [ ] Trackpad-on-space (long-press + drag) scrubuje kurzor správným tempem (delta math nedotčená).
- [ ] Backspace repeat / word-delete a haptika/click feedback beze změny.
- [ ] Funguje na letters i symbols stránkách, s number row i bez.

## Reference

- [`KeyboardUI/Sources/Views/KeyView.swift`](../KeyboardUI/Sources/Views/KeyView.swift) — single key, `.frame(minHeight: 36)` + `.contentShape(Rectangle())` + `DragGesture`, popover/trackpad souřadnicová matika.
- [`KeyboardUI/Sources/Views/KeyRowView.swift`](../KeyboardUI/Sources/Views/KeyRowView.swift) — `HStack(spacing: 6)`, `width(for:)`, `insetWidth`.
- [`KeyboardUI/Sources/Views/KeyboardView.swift`](../KeyboardUI/Sources/Views/KeyboardView.swift) — `VStack(spacing: 11)`, `horizontalPadding`/`topPadding`.
- [`KeyboardCore/Sources/Logic/LayoutBuilder.swift`](../KeyboardCore/Sources/Logic/LayoutBuilder.swift) — definice řádků a vah.
- Souvisí s taskem [07](07-long-press-popover.md), [09](09-delete-repeat.md), [23](23-trackpad-on-space.md) — jejich gesture stav nesmí task rozbít.
