# 66 — Číslice nejdou napsat při vypnutém number row → nativní rozložení symbolů

**Status:** Todo

**Priorita:** v1.x · **Úsilí:** M · **Dopad:** High (bug — uživatel nemůže psát číslice)

**Souvisí s:** [15 — Symbol page parity](15-symbol-page-parity.md) (kde se zavedlo dnešní rozložení), [54 — Hide number row in landscape](54-hide-number-row-in-landscape.md), [53](53-keyboard-switch-height-flash.md)/[61](61-constant-height-top-region.md) (konstantní výška napříč stránkami), [39 — Emoji search](39-emoji-search.md) (search symbols sdílí builder).

## Bug

Když si uživatel vypne **„Always show number row"**, nemá jak napsat číslice — nejsou na žádné stránce. Stejný problém je v **landscape** a v **emoji-search**, kde se number row nikdy nezobrazuje.

Příčina: číslice v Keymoji žijí **jen** v nepovinném number row (`LayoutBuilder.makeNumberRow()`). Symbolové stránky číslice nemají — [task 15](15-symbol-page-parity.md) schválně dal na primary symbol page závorky `[ ] { } # % ^ * + =` s předpokladem, že number row je vždycky po ruce. Ten předpoklad padá, jakmile je number row vypnutý / skrytý.

Nativní iOS dává číslice na `123` stránku:
- **`123`:** `1 2 3 4 5 6 7 8 9 0` / `- / : ; ( ) $ & @ "` / `#+= . , ? ! ' ⌫`
- **`#+=`:** `[ ] { } # % ^ * + =` / `_ \ | ~ < > € £ ¥ ·` / `123 . , ? ! ' ⌫`

(Screenshoty: dva z Keymoji = dnešní stav, dva z native = cílové rozložení. Martin je dodá do implementační session.)

## Cíl

Redefinovat rozložení symbolových stránek podle nativní iOS klávesnice tak, aby **číslice byly vždy dostupné** — buď v number row, nebo na `123` stránce — bez skákání výšky klávesnice a bez dvojitých číslic.

## Zvolený přístup — podmíněné rozložení

Klíčové rozhodnutí (viz [ADR](#adr--proč-podmíněné-rozložení)): **digits se na primary symbol page objeví právě tehdy, když number row v dané layoutu NENÍ.** Podmínka už existuje jako lokální `includeNumberRow` ve `LayoutBuilder.layout`:

```
let includeNumberRow = showNumberRow && page != .emojis && !page.isEmojiSearch
```

`LayoutBuilder` dostává **efektivní** hodnotu `showNumberRow` (calleři předávají `KeyboardState.effectiveShowsNumberRow`, který je `false` v landscape) — takže `!includeNumberRow` automaticky pokrývá všechny tři bug kontexty: vypnutý přepínač, landscape i emoji-search.

### Native config (`!includeNumberRow` → digits na page 1)

Nastává když: přepínač vypnutý **nebo** landscape **nebo** emoji-search.

| Stránka | Row A | Row B | Row C |
|---|---|---|---|
| **Primary `123`** | `1 2 3 4 5 6 7 8 9 0` | `- / : ; ( ) $ & @ "` | `#+=` · `. , ? ! '` · `⌫` |
| **Alternate `#+=`** | `[ ] { } # % ^ * + =` | `_ \ \| ~ < > € £ ¥ ·` | `123` · `. , ? ! '` · `⌫` |

Osiřelé symboly `° § ¶ © ® ™ – — • …` zde **vypadnou** — přesně jako nativní iOS, který pro ně nemá místo (2 řádky symbolů na stránku). Vědomě akceptováno: kdo je potřebuje, nechá number row zapnutý.

### Rich config (`includeNumberRow` → page 1 = závorky)

Nastává když: přepínač zapnutý **a** portrait **a** ne-emoji-search (default stav). **Beze změny oproti dnešku** — number row nese číslice, takže primary symbol page může rovnou nabídnout závorky:

| Stránka | Row A | Row B | Row C |
|---|---|---|---|
| **Primary `123`** | `[ ] { } # % ^ * + =` | `- / : ; ( ) $ & @ "` | `#+=` · `. , ? ! '` · `⌫` |
| **Alternate `#+=`** | `_ \ \| ~ < > € £ ¥ ·` | `° § ¶ © ® ™ – — • …` | `123` · `. , ? ! '` · `⌫` |

### Důsledek: výška se nemění

Obě konfigurace mají na symbol page **3 řádky obsahu + bottom row** = stejný počet jako letters page. Number row (když je) se přidá na obě stránky stejně. Invariant z [tasku 61](61-constant-height-top-region.md) (`testLayoutHeight_lettersAndSymbolsHaveEqualRowCount`) zůstává splněn → žádné skákání při `123` ↔ `ABC`.

### Vědomé nekonzistence

- **Dostupnost `° § ¶ © ® ™ – — • …` závisí na number row** (jsou jen v rich configu). Akceptováno.
- **Regular vs emoji-search 123 page se v rich configu liší** — regular má závorky (number row nese číslice), emoji-search má digits (number row tam nikdy není). Je to logicky konzistentní princip „digits tam, kde nejsou jinde", jen vizuálně odlišné mezi kontexty. Akceptováno.

## Scope

### 1. `LayoutBuilder` — podmíněný obsah symbol stránek

`KeyboardCore/Sources/Logic/LayoutBuilder.swift`:

- `makeSymbolRows(_:inEmojiSearch:)` rozšířit o flag, zda na primary page jdou **digits** místo závorek. Hodnotu odvodit z `!includeNumberRow` v `layout(...)` a propsat dolů (pro `.symbols` i `.emojiSearchSymbols` přes stejnou cestu).
- **Primary page, native config:** Row A = číslice; Row B = `- / : ; ( ) $ & @ "`; Row C = `#+=` toggle + punctuation + delete (beze změny).
- **Primary page, rich config:** beze změny (dnešní `symbolsPrimaryRowA` = závorky).
- **Alternate page, native config:** Row A = `symbolsPrimaryRowA` (závorky); Row B = `symbolsAlternateRowA` (`_ \ | ~ < > € £ ¥ ·`); Row C beze změny. (`symbolsAlternateRowB` = `° § ¶ © ® ™ – — • …` se v native configu nepoužije.)
- **Alternate page, rich config:** beze změny (dnešek).

### 2. Sdílení mapy číslic — POZOR na výšku řádku

Číslice na symbol page **sdílí datový `numberRowMapping`** (takže nesou alternativy `1→!`, `2→@`, … `0→)`), ale **NESMÍ** mít row ID `"numberRow"`:

- `KeyboardRow.isNumberRow` je `id == "numberRow"` a řídí výšku řádku (`KeyboardMetrics.numberRowCapHeight` 36 vs `keyCapHeight` 42).
- Číslice na symbol page musí mít **standardní výšku 42** (jako řádek pod nimi), takže řádek dostane normální ID (`symbols.primary.rowA` / `emojiSearchSymbols.primary.rowA`), ne `"numberRow"`.
- Refaktor: vyčlenit `makeDigitKeys() -> [Key]` (klávesy s `.standard` weight, ID `number.<digit>`, alternativy z `numberRowMapping`). `makeNumberRow()` ho zabalí do řádku s ID `"numberRow"`; symbol primary native ho zabalí do řádku se standardním ID.
- Šířka: 10 číslic × `.standard` = plná šířka, žádný `referenceWeight` (jako dnešní number row i závorkový řádek).

**Row ID vs. key ID — kritické rozlišení:**

| | Number row (letters page) | Řádek číslic (symbol page) |
|---|---|---|
| **ID řádku** | `numberRow` → výška 36 | `symbols.primary.rowA` / `emojiSearchSymbols.primary.rowA` → výška 42 — **jiné** |
| **ID kláves uvnitř** | `number.1` … `number.0` | `number.1` … `number.0` — **stejné, OK** |

- **Řádky musí mít jiné ID** — výšku určuje `isNumberRow` (`id == "numberRow"`), takže stejné ID = stejná (špatná, nižší) výška. Navíc se row ID používá pro SwiftUI `ForEach` identitu při přepínání stránek.
- **Klávesy uvnitř můžou sdílet ID** — number row a symbol page se nikdy nezobrazí současně (number row je v native configu z definice vypnutý), takže ke kolizi ID nedojde.

### 3. Settings hint

`Features/Settings/Sources/SettingsView.swift` + `KeymojiResources/.../Localizable.strings`:

- Pod toggle „Always show number row" přidat footer/hint, např. `"settings.keyboard.showNumberRowHint" = "When off, digits move to the 123 page.";` (a CZ varianta, pokud projekt CZ lokalizaci má — dnes je jen `en.lproj`).
- Použít stávající vzor footeru v `SettingsView` (sekce `.footer` nebo `Text` pod Toggle).

### 4. Unit testy — `KeyboardCore/Tests/LayoutBuilderTests.swift`

Pozor: helper `symbolRow(at:page:)` dnes natvrdo volá `showNumberRow: false` → tím pádem **všechny** stávající symbol testy nově běží v *native configu*. To rozbije content asserce, které čekají závorky.

- Helper `symbolRow` upravit, aby bral `showNumberRow` (default ponechat, ale umožnit obě varianty).
- **Přepsat:**
  - `testSymbolsPrimary_rowA_hasBracketsAndMath` → rozdělit: native config = číslice, rich config (`showNumberRow: true`) = závorky.
  - `testSymbolsAlternate_rowA_hasUnderscoresPipesAndCurrency` → native = závorky, rich = `_ \ | ~ < > € £ ¥ ·`.
  - `testSymbolsAlternate_rowB_hasLegalAndTypography` → rich = `° § ¶ © ® ™ – — • …`; v native config rowB = `_ \ | ~ < > € £ ¥ ·`.
- **Přidat:**
  - `testSymbolsPrimary_withoutNumberRow_rowA_hasDigits()` — native config → `1…0`.
  - `testSymbolsPrimary_digitsCarryNumberRowAlternates()` — `1→!` … `0→)`.
  - `testSymbolsPrimary_digitRow_usesStandardKeyHeight()` — row ID ≠ `"numberRow"` (tedy `isNumberRow == false`), aby výška seděla.
  - `testEmojiSearchSymbolsPrimary_rowA_hasDigits()` — emoji-search vždy native config → číslice (regression pro bug v search).
  - `testSymbolsAlternate_withoutNumberRow_hasBracketsThenUnderscores()`.
- **Ponechat (musí dál projít):** `testLayoutHeight_lettersAndSymbolsHaveEqualRowCount` (row counts se nemění), edge/weight parity testy row C, `testNumberRow_*` (number row na letters page beze změny).

### 5. Snapshot testy — `KeyboardUI/Tests/KeyboardViewSnapshots.swift`

- **Re-record:** `testSymbolsPrimary_withoutNumberRow` (nově číslice), `testEmojiSearchSymbols_primary_query7` (nově číslice na rowA).
- **Beze změny:** `testSymbolsPrimary_withNumberRow`, `testSymbolsAlternate_withNumberRow` (rich config = dnešek) — vizuálně ověřit, že se opravdu nezměnily.
- **Přidat:** `testSymbolsAlternate_withoutNumberRow` (native config — závorky + `_ \ | ~ < > € £ ¥ ·`).
- Snapshot drift musí být intentional — každý překontrolovat očima.

## Mimo scope

- **Třetí symbolová stránka** pro záchranu `° § ¶ © ® ™ – — • …` (native má jen 2). Zamítnuto.
- **Long-press alternativy pro osiřelé symboly** (`–`/`—`/`•` pod `-`, `…` pod `.`, `§` pod `&`, `°` pod `0`). Hezký nativní follow-up, ale samostatný task — ne tady.
- **Odebrání number row featury.** Number row zůstává jako pohodlí na letters page.
- **Změna chování number row v landscape** ([task 54](54-hide-number-row-in-landscape.md)) — beze změny.

## Hotovo když

- Při **vypnutém** number row jdou napsat číslice přes `123` stránku (primary symbol page row A).
- Stejně i v **landscape** a v **emoji-search**.
- Při **zapnutém** number row (default) je symbol page **beze změny** oproti dnešku.
- Klávesnice **neskáče na výšku** při přepínání letters ↔ symbols v žádné konfiguraci.
- Číslice na symbol page mají **standardní výšku klávesy** (sedí s řádkem pod nimi) a nesou long-press `1→!` … `0→)`.
- Settings ukazují hint, kam se číslice přesunou.
- Unit testy (přepsané + nové) a snapshoty zelené; drift překontrolován.
- Manuální verify v simulátoru: vypnout number row → Safari search → `123` → napsat `2026`.

## Rizika

- **Helper `symbolRow` natvrdo `showNumberRow: false`** — snadno přehlédnutelné, že stávající symbol testy tím spadnou do native configu. Upravit jako první.
- **Snapshot drift** — re-record musí být vědomý, ne automatický.
- **`emojiSearchSymbols` sdílí builder** — ověřit, že fix prošel i tam (a že tam nevznikl number row, který tam nepatří).

## Reference

- `KeyboardCore/Sources/Logic/LayoutBuilder.swift` — `makeSymbolRows`, `makeNumberRow`, `numberRowMapping`, `layout(...)` (`includeNumberRow`)
- `KeyboardCore/Sources/Models/KeyboardRow.swift` — `isNumberRow` (řídí výšku)
- `KeyboardCore/Sources/Logic/KeyboardMetrics.swift` — `rowSlotHeight(isNumberRow:)`, `canonicalHeight`
- `KeyboardCore/Sources/Models/KeyboardState.swift` — `effectiveShowsNumberRow` (landscape)
- `Features/Settings/Sources/SettingsView.swift` — toggle + hint
- Nativní iOS `123` / `#+=` stránky — vizuální reference (screenshoty v session)

## ADR — proč podmíněné rozložení

Tři věci, co Keymoji postavilo, si navzájem odporují: (1) **native parita** chce číslice na primary symbol page; (2) **žádné dvojité číslice** — když je number row zapnutý a zobrazený i na symbol page (kvůli výšce), nesmí být číslice ještě jednou v řádku; (3) **konstantní výška** napříč stránkami ([task 53](53-keyboard-switch-height-flash.md)/[61](61-constant-height-top-region.md)).

Zvažované varianty:
- **Vždy native** (číslice na page 1 pořád): při zapnutém number row buď dvojité číslice, nebo musíme number row na symbolech potlačit → skok výšky. ✗
- **Podmíněné** (zvoleno): číslice na page 1 jen když number row není v layoutu. Žádné dvojité číslice, žádný skok, default uživatelé nic nepoznají, bug opraven ve všech třech kontextech. Cena: obsah symbol stránky závisí na nastavení number row. Obhajitelné jako princip „závorky když jsou číslice nahoře, číslice když nejsou".

**Codex review:** Ano — netriviální (conditional layout, refactor symbol testů, snapshot drift).
