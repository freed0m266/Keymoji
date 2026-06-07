# 55 — Shodné hrany a cluster mezi řádkem 3 (písmena) a řádkem C (symboly)

**Status:** Done — 2026-06-07

**Priorita:** v1.2 · **Úsilí:** S · **Dopad:** Medium (vizuální parita písmena ↔ symboly)

## Cíl

Sjednotit šířky kláves ve **třetím řádku** tak, aby při přepínání `letters` ↔ `symbols` nic neskákalo,
hrany seděly na pixel a punctuation cluster zabíral stejnou šířku jako písmenný cluster:

- **`shift`** (page.letters, řádek 3, levá hrana) == **levá klávesa řádku C symbolů** (`#+=` / `123`
  toggle, id `symbols.row3.toggleAlt` / `symbols.row3.togglePrimary`) — na pixel stejná šířka.
- **`delete`** (page.letters) == **`delete`** (page.symbols) — na pixel stejná šířka.
- **`rowCPunctuation` jako celek** (součet 5 kláves `.,?!'`) == **`row3Letters` jako celek** (součet
  7 kláves `zxcvbnm`) — stejně široký cluster. Jednotlivá punctuation klávesa je přitom **širší** než
  jednotlivé písmeno (5 kláves musí pokrýt stejnou šířku jako 7).
- **Breathing mezery** kolem hran zůstanou (vizuální mezera), ale **nezmenšují tap area** shift/delete/toggle.
- **Písmena řádku 3 zůstanou `W/10`** — zarovnaná s řádky 1/2 (task 52 se neregresuje).

> **Pozn. k zadání:** v původní zprávě byl jako reference pro shift uveden `bottom.pageToggle` (spodní
> `123`/`ABC`). Myšlena byla **levá klávesa řádku C symbolů** (rowC toggle), ne spodní klávesa.

## Kontext

### Jak se šířka počítá

Šířka = váhy. V [`KeyRowView`](KeyboardUI/Sources/Views/KeyRowView.swift): `unitWidth = totalWidth /
Σváhy`, `šířka klávesy = unitWidth × visualWeight`. Edge mezery se přidávají přes `key.addingGaps(...)`,
které navyšují `leadingGapWeight` / `trailingGapWeight` a počítají se **do** `Σváhy`
([KeyRowView.swift:49-99](KeyboardUI/Sources/Views/KeyRowView.swift:49)). Gap area přitom **patří do tap
area** dané hrany — `KeyView` ji vykreslí jako prázdnou (cap se odsune), ale hit-testing i background
fill ji pokrývá ([KeyView.swift:11-15, 120-131](KeyboardUI/Sources/Views/KeyView.swift:11)). Takže
„zvětšená mezera" = vizuální mezera **bez** zmenšení tap area. Mezi každými dvěma klávesami je navíc
uniformní 3pt mezera z `KeyView` horizontálního paddingu — ta zůstává a tímhle taskem se nemění.

### Současný stav (po tasku 52)

Šířka klávesnice = `W`.

**Letter row 3** ([LayoutBuilder.swift:133-142](KeyboardCore/Sources/Logic/LayoutBuilder.swift:133)):
```
shift(1.2) + 0.3 gap + 7× písmeno(1.0) + 0.3 gap + delete(1.2) = 10.0  → unitWidth = W/10
  → shift = delete = 1.2·u = 0.12 W ;  písmeno = 0.10 W (= řádky 1/2)
```
Používá `letterRowEdgeKeyWeight = KeyWeight(1.2)` ([:286](KeyboardCore/Sources/Logic/LayoutBuilder.swift:286))
a `symbolEdgeGapWeight = 0.3` ([:191](KeyboardCore/Sources/Logic/LayoutBuilder.swift:191)).

**Symbol row C** ([LayoutBuilder.swift:209-220](KeyboardCore/Sources/Logic/LayoutBuilder.swift:209)):
```
toggle(1.5 .wide) + 0.3 gap + 5× punct(1.5) + 0.3 gap + delete(1.5 .wide) = 11.1  → unitWidth = W/11.1
  → toggle = delete = punct = 1.5 · W/11.1 = 0.135 W
```
Používá `symbolRowCPunctuationWeight = KeyWeight(1.5)` ([:195](KeyboardCore/Sources/Logic/LayoutBuilder.swift:195))
přes `makeSymbolPunctuationKey` ([:270-279](KeyboardCore/Sources/Logic/LayoutBuilder.swift:270)).

**Nesoulad dnes:** levá hrana letters 0.12 W vs symbols 0.135 W (skáče), punct 0.135 W vs písmeno 0.10 W
(punct širší, ale jiný součet než písmenný cluster).

## Výsledný design

Zvolené hodnoty: **edge váha 1.3**, **mezera 0.2**, **punct 1.4**. Oba řádky vyjdou na součet **10.0**,
takže `unitWidth = W/10` (= jednotka u). Šířka `W`:

**Letter row 3** — `shift(1.3) + 0.2 gap + 7× písmeno(1.0) + 0.2 gap + delete(1.3) = 10.0`:
```
shift = delete = 1.3·u = 0.13 W ;  písmeno = 1.0·u = 0.10 W (= W/10, zarovnané s řádky 1/2 ✓)
```

**Symbol row C** — `toggle(1.3) + 0.2 gap + 5× punct(1.4) + 0.2 gap + delete(1.3) = 10.0`:
```
toggle = delete = 0.13 W (= shift ✓) ;  punct = 1.4·u = 0.14 W (širší než písmeno)
punct cluster = 5 × 0.14 = 0.70 W  ==  letter cluster = 7 × 0.10 = 0.70 W ✓
```
Punct váha 1.4 je dopočtená tak, aby cluster seděl: `5 × 1.4 = 7.0 = 7 × 1.0` (počet × váha písmene).
Cluster zůstává **centrovaný** (levá strana `toggle 1.3 + gap 0.2 = 1.5` = pravá `gap 0.2 + delete 1.3`).

**Výsledek napříč stránkami:**
| | letters ř.3 | symbols ř.C |
|---|---|---|
| levá hrana | shift **0.13 W** | toggle **0.13 W** ✓ |
| pravá hrana | delete **0.13 W** | delete **0.13 W** ✓ |
| mezera | 0.2·u = 0.02 W | 0.02 W ✓ |
| jedna klávesa středu | písmeno **0.10 W** | punct **0.14 W** (širší) |
| cluster středu | 7 × 0.10 = **0.70 W** | 5 × 0.14 = **0.70 W** ✓ |
| součet vah | **10.0** → písmena W/10 | **10.0** → shift==toggle |

## Scope (vše v [`LayoutBuilder`](KeyboardCore/Sources/Logic/LayoutBuilder.swift))

1. **Smazat `letterRowEdgeKeyWeight`** ([:283-286](KeyboardCore/Sources/Logic/LayoutBuilder.swift:283))
   a nahradit jednou sdílenou edge konstantou pro shift / delete / symbol toggle:
   ```swift
   /// Width weight for the third-row edge keys — shift & delete on the letter row, and the `#+=`/`123`
   /// toggle & delete on the symbol row C. Same on both pages so the edges never jump when toggling.
   /// 1.3 + 0.2 gap each side + 7×1.0 letters = 10.0, so the letters stay at W/10 (aligned with rows 1/2).
   private static let rowEdgeKeyWeight = KeyWeight(1.3)
   ```

2. **`makeShiftKey`** ([:288-303](KeyboardCore/Sources/Logic/LayoutBuilder.swift:288)) — odebrat parametr
   `weight`, vždy `rowEdgeKeyWeight`:
   ```swift
   private static func makeShiftKey(shift: ShiftState) -> Key { … visualWeight: rowEdgeKeyWeight … }
   ```

3. **`makeDeleteKey`** ([:305-314](KeyboardCore/Sources/Logic/LayoutBuilder.swift:305)) — **volitelný**
   parametr `weight` s defaultem `rowEdgeKeyWeight`, takže běžná cesta (letter row 3, symbol row C) je
   bez argumentu, a speciální volání si může vyžádat jinou šířku:
   ```swift
   private static func makeDeleteKey(weight: KeyWeight = rowEdgeKeyWeight) -> Key {
       … visualWeight: weight …
   }
   ```
   > **Emoji spodní řádek se NEMĚNÍ:** `makeEmojiBottomRow` ([:405](KeyboardCore/Sources/Logic/LayoutBuilder.swift:405))
   > musí volat `makeDeleteKey(weight: .wide)`, aby delete na emoji stránce zůstal `.wide` (1.5) jako
   > dnes. (Na emoji spodním řádku není shift ani toggle, se kterým by se měl srovnávat — proto si drží
   > vlastní šířku.) Letter row 3 a symbol row C volají `makeDeleteKey()` bez argumentu (→ 1.3).

4. **Symbol toggle na `rowEdgeKeyWeight`** — v `symbolPageContent`
   ([:234-253](KeyboardCore/Sources/Logic/LayoutBuilder.swift:234)) změnit `visualWeight: .wide`
   → `visualWeight: rowEdgeKeyWeight` u obou toggle (`#+=` i `123`).

5. **Mezera 0.3 → 0.2.** `symbolEdgeGapWeight` se používá na **obou** řádcích (letter row 3 i symbol
   row C). Změnit hodnotu na `0.2` a přejmenovat na výstižnější (už není symbol-only), např.:
   ```swift
   /// Breathing-room gap weight between the third-row edge keys and the middle cluster, on both the
   /// letter row 3 and the symbol row C. Visual gap only — the gap area stays in the edge key's tap area.
   private static let edgeGapWeight: Double = 0.2
   ```

6. **Punct 1.5 → 1.4.** `symbolRowCPunctuationWeight`
   ([:193-195](KeyboardCore/Sources/Logic/LayoutBuilder.swift:193)) → `KeyWeight(1.4)`. Tím
   `5 × 1.4 = 7.0` = letter cluster. `makeSymbolPunctuationKey` **zůstává** (punct má pořád vlastní
   váhu ≠ standard). Aktualizovat komentář (`5×1.5 … 11.1` → `5×1.4 … 10.0`).

7. **Letter row 3** ([:133-142](KeyboardCore/Sources/Logic/LayoutBuilder.swift:133)) — bez weight
   parametrů, mezery `edgeGapWeight` (0.2) zůstávají:
   ```swift
   let row3 = KeyboardRow(
       id: "letters.row3",
       keys: [makeShiftKey(shift: shift).addingGaps(trailing: edgeGapWeight)]
           + row3Letters
           + [makeDeleteKey().addingGaps(leading: edgeGapWeight)]
   )
   ```
   Aktualizovat komentář (`1.2 … 0.3 … = 10.0` → `1.3 … 0.2 … = 10.0`).

8. **Symbol row C** ([:209-220](KeyboardCore/Sources/Logic/LayoutBuilder.swift:209)) — `edgeGapWeight`
   (0.2) místo původní 0.3; toggle/delete teď `rowEdgeKeyWeight`. Platí i pro `inEmojiSearch` variantu
   (stejná funkce). Aktualizovat komentář se součtem na `10.0`.

## Mimo scope

- **Výška kláves / number row / total výška** — task [52](52-key-sizing-bottom-up-refactor.md).
- **Probliknutí při přepnutí klávesnice** — task [53](53-keyboard-switch-height-flash.md).
- **Řádky 1, 2, A, B, number, bottom** — beze změny. Mění se výhradně letter row 3 a symbol row C.
  **Emoji spodní řádek se nemění** — jeho delete zůstává `.wide` (krok 3).
- **`bottom.pageToggle` šířka** — nech být; reference je rowC toggle, ne spodní klávesa. (Po změně bude
  rowC toggle 0.13 W vs bottom.pageToggle 0.135 W — drobně jiné, OK.)
- **Popover alignment** — počítá se z `unitWidth × váhy`, trefí nové váhy sám; jen ověřit (Rizika).

## Hotovo když

- `shift` (page.letters) je **na pixel stejně široký** jako rowC toggle `#+=`/`123` (page.symbols) — obě `0.13 W`.
- `delete` (page.letters) je **na pixel stejně široký** jako `delete` (page.symbols) — obě `0.13 W`.
- **Součet** šířek 5 punctuation (`.,?!'`) == **součet** šířek 7 písmen (`zxcvbnm`) = `0.70 W`; jednotlivá
  punctuation klávesa je přitom **širší** než jednotlivé písmeno (0.14 W vs 0.10 W).
- Písmena řádku 3 zůstávají `W/10` (zarovnaná s řádky 1/2 — task 52 neregresuje).
- Breathing mezery (0.2) kolem hran vizuálně zůstávají a **nezmenšují tap area** shift/delete/toggle.
- Při přepnutí `letters` ↔ `symbols` levá a pravá hrana 3. řádku **neskáčou**.
- `letterRowEdgeKeyWeight` neexistuje; existuje sdílená `rowEdgeKeyWeight` (1.3); `makeShiftKey` je bez
  weight parametru; `makeDeleteKey` má volitelný `weight` s defaultem `rowEdgeKeyWeight` (emoji řádek
  předává `.wide`); `edgeGapWeight` = 0.2; `symbolRowCPunctuationWeight` = 1.4.
- Delete na **emoji spodním řádku zůstává `.wide`** (1.5) — beze změny.
- Re-recorded snapshoty (letters upper/lower řádek 3, symbols primary/alternate řádek C, emoji-search
  symboly) jsou green a vizuálně ověřené. Emoji panel/spodní řádek snapshoty se nemění.

## Rizika

- **Popover alignment** ([KeyRowView.swift:68-88](KeyboardUI/Sources/Views/KeyRowView.swift:68)) počítá
  X pozici z `unitWidth × (gap + váha)`. Nové váhy by měly sednout samy, ale ověřit long-press popover
  nad krajními písmeny (`z`, `m`).
- **Centrování punct clusteru** závisí na symetrii `toggle + gap == gap + delete`. Obě hrany stejné a
  stejná mezera → symetrické; při budoucí změně počtu punctuation kláves se `symbolRowCPunctuationWeight`
  musí přepočítat (`cluster / početPunct`), komentář to říká.
- **`makeDeleteKey` volání projít.** Default (1.3) chtějí `makeLetterRows` a `makeSymbolRows` (bez
  argumentu); `makeEmojiBottomRow` **musí** explicitně předat `weight: .wide`, jinak by se emoji delete
  omylem zúžil. Ověřit, že žádné jiné volání nezůstalo na špatné šířce.
- **Šířka symbol toggle/delete klesá** (0.135 W → 0.13 W) — ověřit, že se `#+=`/`123` label pořád vejde
  a delete ikona vypadá dobře.
- **Snapshot drift** na symbolech je výraznější (punct užší než dnes: 0.135 → 0.14 W vlastně mírně širší;
  toggle/delete užší; mezery menší) — odlišit zamýšlenou změnu od regrese. Na letters se mění jen šířka
  shift/delete (0.12 → 0.13 W) a mezera (0.3 → 0.2); písmena beze změny (W/10).

## Reference

- [52 — Refaktor výšky/šířky kláves (zdola nahoru)](52-key-sizing-bottom-up-refactor.md) — zavedl
  `letterRowEdgeKeyWeight`; tenhle task ho ruší a **reviduje rozhodnutí #4** (místo „hrany 1.2 + mezery
  0.3" → „hrany 1.3 + mezery 0.2", obojí dává součet 10.0 → písmena zůstávají `W/10`, navíc se srovnají
  hrany a punct cluster se symboly).
- [14 — Stejná šířka kláves v ASDF řádku](14-equal-letter-key-widths.md) — `referenceWeight` vzor.
- [15 — Symbol page parity](15-symbol-page-parity.md) — vznik symbolového řádku C a edge mezer.
