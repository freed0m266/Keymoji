# 59 — Auto numberpad pro číselná pole

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium (číselný vstup — částky v bankovnictví, kódy, množství)

## Cíl

Když uživatel klikne do pole, které žádá číselnou klávesnici (`UIKeyboardType.numberPad` nebo
`.decimalPad`), Keymoji se **automaticky** přepne na vlastní numpad — Apple-style mřížka
`1-2-3 / 4-5-6 / 7-8-9 / [sep|␀] 0 ⌫` — místo aby ukázala QWERTY. Při návratu do běžného
textového pole se vrátí na písmena. Žádné ruční přepínání, žádné nastavení.

Po dokončení: otevřu v bankovní (nebo jakékoli) appce pole pro částku → Keymoji ukáže číselník;
kliknu do běžného textového pole → Keymoji ukáže QWERTY.

## Kontext / klíčová zjištění z průzkumu kódu

- **`keyboardType` se dnes čte, ale jen pro suggestion bar.** `KeyboardViewController.refreshEligibility`
  ([KeyboardViewController.swift:273](../KeyboardExtension/Sources/KeyboardViewController.swift:273))
  mapuje `textDocumentProxy.keyboardType` přes
  [`SuggestionFieldTraitsMapping.keyboardKind`](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift:77)
  na `KeyboardInputKind` kvůli eligibilitě baru. Pro **layout** se `keyboardType` nikde nepoužívá —
  číselné pole tedy dnes pořád ukáže QWERTY.

- **Stránky jsou enum `KeyboardPage`** ([KeyboardPage.swift](../KeyboardCore/Sources/Models/KeyboardPage.swift))
  stavěný čistou funkcí [`LayoutBuilder.layout`](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:8).
  Žádná numeric stránka neexistuje. Přidání = nový case + větev v builderu — sedí do existujícího patternu
  (stejně jako `.emojis`, `.emojiSearch`).

- **Lifecycle hook už existuje.** `textDidChange`
  ([KeyboardViewController.swift:259](../KeyboardExtension/Sources/KeyboardViewController.swift:259))
  dnes při každé změně fokusu volá `refreshReturnKeyType / refreshAutoCapitalization / refreshEligibility /
  refreshLanguage`. Numpad detekci sem jen **přidáme** dalším `refresh…`. `viewWillAppear`
  ([:114](../KeyboardExtension/Sources/KeyboardViewController.swift:114)) je fallback pro první zobrazení.

- **Výška se vyřeší sama.** [`KeyboardMetrics.keyboardHeight`](../KeyboardCore/Sources/Logic/KeyboardMetrics.swift:49)
  pro ne-emoji stránky sčítá **reálné** `layout.rows`. Numpad = 4 řádky bez number row → správná výška
  automaticky. Suggestion bar je u `numberPad`/`decimalPad` `.denied`
  ([SuggestionEligibility.swift:90](../KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift:90)),
  takže `showsSuggestionBar == false` a bar do výšky nevstupuje. **Jediné must-do je vyřadit numeric
  z `includeNumberRow`** ([LayoutBuilder.swift:24](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:24)),
  jinak by se nahoru přidal number row a host výška by se rozešla s obsahem.

- **Klávesa zdarma dědí chování.** Číslice s `role: .character` dostanou haptiku, zvuk i key-preview
  přes `KeyView` bez jakékoli práce navíc. `.number(String)` content (task 37) zajistí správné
  vertikální zarovnání digitů.

- **Žádný globe/ABC únik (vědomě).** Keymoji nemá globe (task 30) a numpad je **locked** — viz
  rozhodnutí níže. Dokud je číselné pole ve fokusu, klávesnice ukazuje jen číslice + delete (+ separátor).
  To je přesná parita s Apple systémovým numberPad.

### Rozhodnutí (z grillingu)

| Otázka | Rozhodnutí |
|---|---|
| Jak se vyvolá | **Auto** podle `textDocumentProxy.keyboardType`. Žádné ruční přepnutí. |
| Tvar | **Plnohodnotný grid** jako iOS numberPad (3 sloupce). |
| Spouštěče | **`numberPad` + `decimalPad`.** `asciiCapableNumberPad` (chce písmena) a `phonePad` (iOS pustí systémovou) **ne**. |
| Únik na ABC | **Ne — locked.** Jen číslice + delete (+ separátor). Žádný ABC, globe, return, long-press. |
| Return | **Ne.** Parita s Apple; odeslání řeší hostující appka. |
| decimalPad separátor | **Locale-aware** (`,` pro CZ, `.` pro EN). Předán do `LayoutBuilder` jako param vedle `returnKeyType`. |
| Lepkavost | **Nelepkavý.** Při odchodu z číselného pole → `letters(.lower)`. Předchozí stránku (emoji…) neobnovujeme. |
| Nastavení | **Žádné.** Vždy zapnuto. |
| Secure pole (PIN) | Mimo dosah — iOS u `isSecureTextEntry` vždy nahradí klávesnici 3. strany systémovou. Numpad se tam nikdy neukáže. |

## Scope

### 1. `KeyboardPage` — nový case

[KeyboardCore/Sources/Models/KeyboardPage.swift](../KeyboardCore/Sources/Models/KeyboardPage.swift):

```swift
public enum KeyboardPage: Sendable, Equatable {
	case letters(ShiftState)
	case symbols(SymbolPage)
	case emojis
	case emojiSearch
	case emojiSearchSymbols(SymbolPage)
	case numeric(NumericKind)          // ← nový
}

/// Která číselná varianta numpadu se renderuje. `.integer` = `numberPad` (žádný separátor),
/// `.decimal` = `decimalPad` (levý dolní slot je separátor). Konkrétní znak separátoru je
/// locale-aware a teče do `LayoutBuilder` zvlášť (jako `returnKeyType`), aby `KeyboardPage`
/// zůstal locale-agnostický a `Equatable`-čistý.
public enum NumericKind: Sendable, Equatable {
	case integer
	case decimal
}
```

Přidat predikát `isNumeric` (mirror `isEmojiSearch`) pro guardy v builderu/views:

```swift
public extension KeyboardPage {
	var isNumeric: Bool {
		if case .numeric = self { return true }
		return false
	}
}
```

Doplnit `.numeric` do `switch` v `isEmojiSearch` (do `false` větve).

### 2. `LayoutBuilder` — numpad grid + separátor param + number-row guard

[KeyboardCore/Sources/Logic/LayoutBuilder.swift](../KeyboardCore/Sources/Logic/LayoutBuilder.swift):

- **Signatura** ([:8](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:8)) — přidat param:

  ```swift
  public static func layout(
  	page: KeyboardPage,
  	showNumberRow: Bool,
  	returnKeyType: ReturnKeyType,
  	letterLayout: LetterLayout = .qwerty,
  	alternateSet: LetterAlternateSet = .all,
  	decimalSeparator: String = "."        // ← nový; použit jen pro .numeric(.decimal)
  ) -> KeyboardLayout
  ```

- **`includeNumberRow` guard** ([:24](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:24)) — vyřadit numeric:

  ```swift
  let includeNumberRow = showNumberRow && page != .emojis && !page.isEmojiSearch && !page.isNumeric
  ```

- **Hlavní `switch page`** ([:29](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:29)) — přidat case, který postaví
  **všechny 4 řádky** numpadu (číselný grid si dělá vlastní spodní řádek, nesdílí `makeBottomRow`):

  ```swift
  case .numeric(let kind):
  	rows.append(contentsOf: makeNumericRows(kind: kind, decimalSeparator: decimalSeparator))
  ```

- **Trailing `makeBottomRow`** ([:50](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:50)) — přeskočit pro numeric:

  ```swift
  if !page.isNumeric {
  	rows.append(makeBottomRow(page: page))
  }
  ```

- **Nová `makeNumericRows`:**

  ```swift
  private static func makeNumericRows(kind: NumericKind, decimalSeparator: String) -> [KeyboardRow] {
  	func digit(_ d: String) -> Key {
  		Key(id: "numeric.\(d)", primary: .number(d), alternates: [],
  		    action: .insertText(d), visualWeight: .standard, role: .character)
  	}
  	let row1 = KeyboardRow(id: "numeric.row1", keys: ["1", "2", "3"].map(digit))
  	let row2 = KeyboardRow(id: "numeric.row2", keys: ["4", "5", "6"].map(digit))
  	let row3 = KeyboardRow(id: "numeric.row3", keys: ["7", "8", "9"].map(digit))

  	let zero = digit("0")
  	let delete = makeDeleteKey(weight: .standard)
  	let bottomKeys: [Key]
  	switch kind {
  	case .integer:
  		// Levý třetinový slot prázdný → 0 zůstává opticky uprostřed (Apple parita).
  		// Reuse existující gap mechaniky, žádná nová KeyAction / inertní klávesa.
  		bottomKeys = [zero.addingGaps(leading: 1.0), delete]
  	case .decimal:
  		let sep = Key(id: "numeric.separator", primary: .text(decimalSeparator), alternates: [],
  		              action: .insertText(decimalSeparator), visualWeight: .standard, role: .character)
  		bottomKeys = [sep, zero, delete]
  	}
  	let row4 = KeyboardRow(id: "numeric.row4", keys: bottomKeys)
  	return [row1, row2, row3, row4]
  }
  ```

  Pozn.: 3 klávesy v řádku se přes weight normalizaci v `KeyRowView` rozprostřou na třetiny — grid drží
  sloupce sám. `addingGaps(leading: 1.0)` na nule v `.integer` variantě udělá prázdnou levou třetinu;
  delete sedí vpravo. Žádné rozšíření `Key`/`KeyAction` modelu není potřeba.

- **`makeBottomRow` switch** ([:380](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:380)) — doplnit
  `.numeric` case kvůli exhaustivnosti. Je unreachable (numeric staví řádky sám), takže
  `fatalError("numeric page builds its own rows in makeNumericRows")` — stejný vzor jako emoji unreachable
  větev tamtéž.

### 3. `keyboardType` → page mapper (pure, testovatelný)

Nová čistá funkce v `KeyboardCore` (vedle existujícího `KeyboardInputKind`/eligibility světa — drží UIKit
mimo `KeyboardCore`). Vstup je `KeyboardInputKind` (už existující mirror `UIKeyboardType` z
[SuggestionEligibility.swift:22](../KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift:22)),
výstup `KeyboardPage?` — `nil` = „není to numerické pole, nech aktuální typing layout":

```swift
public enum NumericPageResolver {
	/// Mapuje typ fokusovaného pole na vynucenou numpad stránku, nebo `nil` když pole numpad nežádá.
	/// Jen `.numberPad` → `.numeric(.integer)` a `.decimalPad` → `.numeric(.decimal)`. Ostatní
	/// (vč. `.asciiCapableNumberPad`, `.phonePad`) vrací `nil` — locked numpad by blokoval písmena.
	public static func numericPage(for kind: KeyboardInputKind) -> KeyboardPage? {
		switch kind {
		case .numberPad:  return .numeric(.integer)
		case .decimalPad: return .numeric(.decimal)
		default:          return nil
		}
	}
}
```

### 4. `KeyboardViewController` — drátování

- **Nový `refreshKeyboardPageForInputType()`**, volaný z `textDidChange`
  ([:259](../KeyboardExtension/Sources/KeyboardViewController.swift:259)) a z `viewWillAppear`:

  ```swift
  private func refreshKeyboardPageForInputType() {
  	let kind = SuggestionFieldTraitsMapping.keyboardKind(textDocumentProxy.keyboardType ?? .default)
  	let desired: KeyboardPage = NumericPageResolver.numericPage(for: kind)
  		?? defaultTextPage()   // numerické → numpad; jinak letters(.lower)
  	guard state.page != desired else { return }
  	state.page = desired
  	rebuild()
  }
  ```

  - `desired` pro **ne-numerické** pole = `letters(.lower)` — tím je splněna nelepkavost (návrat
    z numpadu i z emoji/symbols na písmena). Ošetřit hranu: nepřepisovat na `letters(.lower)`, pokud už
    jsme na nějaké `letters`/`symbols`/`emoji` stránce a pole je netextové **jen** kvůli tomu, že uživatel
    aktivně přepnul (toto v praxi nenastane — bez numpadu se page mění jen přes `switchPage`, který běží
    v dispatcheru, ne přes tento refresh; ale `desired` musí brát ohled na to, aby se běžné typing přepínání
    stránek nerozbilo). **Doporučený přístup:** mapper přepíná page **jen** mezi „numpad" a „ne-numpad"
    a do ne-numpadu sahá pouze tehdy, když aktuální page **je** `.numeric`. Tj.:

    ```swift
    let desired: KeyboardPage
    if let numeric = NumericPageResolver.numericPage(for: kind) {
    	desired = numeric                       // numerické pole → vždy numpad
    } else if state.page.isNumeric {
    	desired = .letters(.lower)              // opustili jsme numerické pole → zpět na písmena
    } else {
    	return                                  // netextové numpad-irelevantní; nech typing stránku být
    }
    ```

    Tím se běžné `letters`/`symbols`/`emoji` přepínání vůbec nedotkne; numpad se jen „vsune" a zase „vysune".

- **Pořadí v `textDidChange`:** zařadit `refreshKeyboardPageForInputType()` tak, aby `refreshAutoCapitalization`
  nepromovala numpad na `letters(.upper)`. Auto-cap promuje jen při `autocapitalizationType == .sentences`
  ([AutoCapitalizer.swift:23](../KeyboardCore/Sources/Logic/AutoCapitalizer.swift:23)) — číselná pole mají
  `.none`, takže v praxi nehrozí; přesto ověřit a případně přidat guard `!state.page.isNumeric` v auto-cap cestě.

- `defaultTextPage()` helper není nutný, pokud použiješ variantu výše (inline `.letters(.lower)`).

### 5. Audit exhaustivních `switch` nad `KeyboardPage`

Nový case rozbije každý exhaustivní `switch`. Projít a doplnit `.numeric`:

```
grep -rn "case .letters\|case .symbols\|case .emojis\|switch.*page\|switch page" \
  --include="*.swift" KeyboardCore/Sources KeyboardUI/Sources KeyboardExtension/Sources
```

Známá místa k ověření:
- [LayoutBuilder.swift](../KeyboardCore/Sources/Logic/LayoutBuilder.swift) — `layout`, `makeBottomRow` (scope 2).
- [KeyboardPage.swift](../KeyboardCore/Sources/Models/KeyboardPage.swift) — `isEmojiSearch` (scope 1).
- [KeyboardMetrics.keyboardHeight](../KeyboardCore/Sources/Logic/KeyboardMetrics.swift:49) — `if layout.page == .emojis`
  else suma řádků; numeric spadne do else a sečte 4 řádky → **beze změny**, jen ověřit. `isEmojiSearch`
  chrome je pro numeric `false`.
- [`KeyboardView`](../KeyboardUI/Sources/Views/KeyboardView.swift) — ověřit, že numeric vykreslí **prosté
  key-rowy** z `layout.rows` (jako letters/symbols), ne emoji panel. Pokud je v `KeyboardView` switch
  emoji-panel vs. rows, numeric patří do rows větve.
- `InputDispatcher` — `if case .symbols = state.page` ([InputDispatcher.swift:77](../KeyboardCore/Sources/Logic/InputDispatcher.swift:77))
  není exhaustivní, OK. Číslice numpadu jdou přes `.insertText` jako každá `.character` klávesa — žádná
  speciální dispatcher větev není potřeba.

### 6. Unit testy (`KeyboardCore`)

- `NumericPageResolverTests` — `.numberPad → .numeric(.integer)`, `.decimalPad → .numeric(.decimal)`,
  `.asciiCapableNumberPad / .phonePad / .default / .emailAddress → nil`.
- `LayoutBuilderTests` (rozšíření):
  - `.numeric(.integer)`: 4 řádky, žádný number row; row1/2/3 mají 3 klávesy `1-2-3 / 4-5-6 / 7-8-9`
    s `primary == .number`; row4 = `[0(leadingGap=1), delete]`, `0` má `.number`, delete `.backspace`.
  - `.numeric(.decimal)` s `decimalSeparator: ","`: row4 = `[",", "0", delete]`, separátor `.text(",")`
    s `.insertText(",")`.
  - `showNumberRow: true` u numeric **nepřidá** number row (guard).
  - Žádná numeric klávesa nemá `alternates` (žádné long-press).
- Idempotence/Equatable: dva stejné cally → stejný layout.

### 7. Snapshot testy (`KeyboardUI`)

- Nové snapshoty `numeric.integer` a `numeric.decimal` (light/dark, případně QWERTZ-irelevantní).
  Postup standardní (`record: true` → vizuální kontrola → `record: false` → green), viz vzor
  [tasks/37-key-content-number-case.md](37-key-content-number-case.md). Ověřit centrovanou `0`, prázdnou
  levou třetinu u `.integer`, separátor u `.decimal`.

### 8. Manuální verify — **spike jako krok 1**

> **Nejdřív ověřit load-bearing předpoklad**, ať nestavíme layout, který se nikdy neukáže.

1. **Spike:** do hostující testovací appky (nebo Notes vedle) dej `UITextField` s `keyboardType = .decimalPad`
   a `.numberPad`. Otevři Keymoji a potvrď, že se **vůbec zobrazí** (potvrzení, že iOS custom klávesnici
   pro tyto typy pouští). Pro `isSecureTextEntry` potvrď, že se Keymoji **nezobrazí** (iOS přebije) — to je
   očekávané, jen kvůli jistotě.
2. Decimal pole → numpad se separátorem; tap číslic + separátoru vkládá správně; locale CZ → `,`, EN → `.`.
3. Number pole → numpad bez separátoru, `0` centrovaná.
4. Přepnutí fokusu number → textové pole → numpad zmizí, naskočí QWERTY (nelepkavost).
5. Výška numpadu = 4 řádky, žádný number row, žádný suggestion bar; host nic neořízne.
6. Haptika/zvuk/key-preview na číslicích fungují jako na ostatních klávesách.

## Mimo scope

- **`asciiCapableNumberPad` a `phonePad`.** První očekává písmena (locked numpad by je zablokoval),
  druhý iOS typicky pustí systémovou + chce `+ * #` layout. Případně vlastní task.
- **ABC / globe / return / dismiss na numpadu.** Vědomě locked (parita s Apple).
- **Long-press alternates** na číslicích numpadu. Number row má `1→!`; numpad ne.
- **Nastavení pro vyp/zap.** Vždy zapnuto.
- **Obnova předchozí stránky** po odchodu z numpadu (vždy `letters(.lower)`).
- **Sticky numpad / per-field paměť.**

## Hotovo když

- `KeyboardPage` má `.numeric(NumericKind)` + predikát `isNumeric`; všechny exhaustivní switche v repu
  pokrývají nový case (build bez `@unknown default`).
- `LayoutBuilder` staví Apple-style grid pro `.numeric(.integer)` i `.numeric(.decimal)`, separátor je
  locale-aware param; number row se u numeric nikdy nepřidá.
- `NumericPageResolver` mapuje `numberPad`/`decimalPad` na page a vše ostatní na `nil`.
- `KeyboardViewController` při fokusu číselného pole přepne na numpad a při odchodu zpět na písmena
  (nelepkavě), drátováno do existujícího `textDidChange` + `viewWillAppear`.
- Unit testy (resolver + builder) a refreshnuté/nové snapshoty zelené.
- Manuální verify: numpad se reálně zobrazí pro `numberPad`/`decimalPad` v simulátoru, vkládání + separátor
  + výška + návrat na QWERTY fungují.

## Rizika

- **Load-bearing předpoklad zobrazení.** Celá featura stojí na tom, že iOS custom klávesnici pro
  `numberPad`/`decimalPad` ukáže. To dělá (forced-system jsou jen `isSecureTextEntry` a `phonePad`/
  `namePhonePad`), ale **ověřit spikem jako první krok** (scope 8.1), ne až po implementaci layoutu.
- **Exhaustivní switche.** Nový case rozbije buildy na více místech (stejné riziko jako task 02/30/37).
  Mitigace: grep ze scope 5 + překlad odhalí vše.
- **Host výška vs. obsah.** Klasický drift bug (komentář v [LayoutBuilder.swift:18](../KeyboardCore/Sources/Logic/LayoutBuilder.swift:18)).
  U numeric je výška odvozená ze sumy reálných řádků, takže stačí **nepřidat number row** (guard) — pak host
  i SwiftUI obsah souhlasí samy. Ověřit v simulátoru (žádné oříznutí / mezera dole).
- **Auto-cap promo numpadu.** `refreshAutoCapitalization` běží ve stejném `textDidChange`. Číselná pole mají
  `autocapitalizationType == .none`, takže nepromuje — přesto ověřit pořadí a případně přidat
  `!state.page.isNumeric` guard.
- **Separátor vs. locale pole.** `decimalPad` ukazuje separátor regionu zařízení; bereme
  `Locale.current.decimalSeparator`. Pokud appka očekává jiný (vzácné), uživatel vidí svůj regionální —
  shodné s chováním Apple numberPad. Žádná akce, jen poznámka.

## Reference

- [tasks/02-layout-model.md](02-layout-model.md) — datový model layoutu + vzor pro nový page case
- [tasks/37-key-content-number-case.md](37-key-content-number-case.md) — `.number` content + snapshot-refresh postup
- [tasks/54-hide-number-row-in-landscape.md](54-hide-number-row-in-landscape.md) — vzor konzistentní výšky napříč konzumenty
- [tasks/30-remove-globe-key.md](30-remove-globe-key.md) — kontext „jediná klávesnice, žádný globe"
- [KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift](../KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift) — `KeyboardInputKind` mirror + `.denied` pro numerická pole
- Apple App Extension Programming Guide — Custom Keyboard (forced-system pravidla pro secure / phone pad)

## Codex review

**Ano** — dotýká se klíčového enumu `KeyboardPage` s exhaustivními switchi napříč repem a lifecycle logiky
auto-přepnutí (page se mění z controller side-effectu). Spustit `codex review --uncommitted` před closing
commitem, stejné kritérium jako task 02/04.
