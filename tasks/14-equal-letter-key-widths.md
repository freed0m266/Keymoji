# 14 — Stejná šířka kláves v ASDF řádku

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** High (vizuální parita se SwiftKey / Apple stock)

## Cíl

Klávesy `a s d f g h j k l` v prostředním letter řádku musí mít **stejnou šířku** jako klávesy `q w e r t y u i o p` v horním letter řádku. Aktuálně `KeyRowView` distribuje šířku poměrně mezi všechny klávesy v rámci řádku — protože ASDF řádek má 9 kláves a QWERTY 10, ASDF klávesy vycházejí o ~11 % širší. Vizuálně to odhalí, že to *není* dospělá klávesnice.

Apple a SwiftKey to řeší tak, že ASDF řádek má **vnitřní inset (padding)** na obou stranách v hodnotě ~0.5 šířky standardní klávesy. Tím se klávesy zarovnají na šířku QWERTY řádkové klávesy a zbylé místo zůstane jako symmetrický prostor po stranách.

## Kontext

- `KeyboardRow.keys: [Key]` v `KeyboardCore/Sources/Models/KeyboardRow.swift` neobsahuje informaci o vnějším insetu řádku.
- `KeyRowView` v `KeyboardUI/Sources/Views/KeyRowView.swift` počítá `width(for:)` na základě `totalWidth - totalSpacing` rozděleného poměrně přes `key.visualWeight.value / totalWeight`.
- Result: row 1 má 10 kláves × weight 1.0 → totalWeight 10. Row 2 má 9 kláves × weight 1.0 → totalWeight 9. Při stejné `totalWidth` rozdíl ~11 % per klávesa.
- Row 3 (`shift z x c v b n m delete`) má 7×1.0 + 2×1.5 = totalWeight 10. Tj. row 3 klávesy uprostřed sedí na stejnou šířku jako row 1 (jen wide shift/delete jsou jiné). Tento řádek je už OK.
- Row 1 a row 3 mají efektivní `totalWeight = 10`. Row 2 by měl být dotažen na 10.

## Scope

### 1. Model: rozšířit `KeyboardRow` o reference weight

`KeyboardCore/Sources/Models/KeyboardRow.swift`:

```swift
public struct KeyboardRow: Identifiable, Sendable, Equatable {
	public let id: String
	public let keys: [Key]
	/// If set, the row's keys are widened/insetted so that their per-key width matches
	/// the width they would have if the row contained `referenceWeight` units total.
	/// `nil` keeps current "fill the row" behavior.
	public let referenceWeight: Double?

	public init(id: String, keys: [Key], referenceWeight: Double? = nil) {
		self.id = id
		self.keys = keys
		self.referenceWeight = referenceWeight
	}
}
```

`LayoutBuilder.makeLetterRows` set `referenceWeight: 10` jen pro řádek 2 (`a..l`). Ostatní řádky `nil`.

Důvod, proč to dělat na modelu a ne ve view: pure layout logika, kterou jde testovat unit testem (jeden test: row 2 layout má `referenceWeight == 10`).

### 2. View: respektovat referenceWeight v `KeyRowView`

`KeyboardUI/Sources/Views/KeyRowView.swift`:

```swift
private var effectiveTotalWeight: Double {
	row.referenceWeight ?? actualTotalWeight
}

private var actualTotalWeight: Double {
	row.keys.reduce(0) { $0 + $1.visualWeight.value }
}

private var insetWidth: CGFloat {
	guard let ref = row.referenceWeight, ref > actualTotalWeight else { return 0 }
	let totalSpacing = spacing * CGFloat(max(0, row.keys.count - 1))
	let available = max(0, totalWidth - totalSpacing)
	let unitWidth = available / CGFloat(ref)
	let missingWeight = ref - actualTotalWeight
	return unitWidth * CGFloat(missingWeight) / 2.0  // half on each side
}

private func width(for key: Key) -> CGFloat {
	let totalSpacing = spacing * CGFloat(max(0, row.keys.count - 1))
	let available = max(0, totalWidth - totalSpacing - insetWidth * 2)
	return available * CGFloat(key.visualWeight.value / actualTotalWeight)
}

var body: some View {
	HStack(spacing: spacing) {
		if insetWidth > 0 { Spacer().frame(width: insetWidth) }
		ForEach(row.keys) { key in
			KeyView(...).frame(width: width(for: key))
		}
		if insetWidth > 0 { Spacer().frame(width: insetWidth) }
	}
}
```

Pozor — math: pokud row má actual weight 9 a reference weight 10, klávesy mají dostat šířku jako kdyby tu bylo 10 jednotek. Per-unit width = `available_for_10 / 10`. Inset celkem = `1 unit width` (zbývající jednotka), rozděleno půl-půl = `0.5 unit width` na každé straně.

### 3. Unit test (KeyboardCore)

Přidat do `LayoutBuilderTests`:

```swift
func testLettersRow2_hasReferenceWeight10() {
	let row = letterRow(at: "letters.row2", page: .letters(.lower))
	XCTAssertEqual(row.referenceWeight, 10)
}

func testLettersRow1_hasNoReferenceWeight() {
	let row = letterRow(at: "letters.row1", page: .letters(.lower))
	XCTAssertNil(row.referenceWeight)
}
```

### 4. Snapshot testy

`KeyboardUI/Tests/__Snapshots__/` referenční obrázky se shíftnutým ASDF řádkem **už nebudou matchovat**. Postup:

1. Implementovat (1) + (2).
2. Spustit `KeyboardUI_Tests` s `record: true` v `SnapshotHelpers` (dočasně).
3. Vizuálně překontrolovat každý refresh — všechny letter klávesy mají stejnou šířku.
4. Vrátit `record: false`, re-run, verify all pass.
5. Commit i nové reference PNG.

### 5. Apply taky na symbols page?

Symbols row 3 má `[ABC] . , ? ! ' [delete]` (7 kláves, weights 1.5 + 5×1 + 1.5 = 8). Měl by být zarovnaný na 10 jako row 2? Nebo nechat tak jak je?

**Doporučení:** v rámci tohoto tasku **NEzasahovat** symbols layout — to je separátní design decision. Aktuální symbols row 3 vypadá funkčně OK (středovo-roztažené keys). Pokud se ukáže, že to vadí vizuálně, přidat `referenceWeight: 10` i pro symbols row 3 v navazujícím tasku.

## Mimo scope

- Symbols page layout úpravy (viz scope 5).
- Číselný řádek — má 10 kláves jako QWERTY, žádný inset není potřeba.
- Bottom row — má 5 kláves s explicitními weights (space wide, …), žádný inset.
- Letter row 3 (`shift z x c v b n m delete`) — už má totalWeight 10 přes wide shift/delete.

## Hotovo když

- ASDF řádek má klávesy stejně široké jako QWERTY řádek (vizuální verify v simulátoru / snapshotem).
- ASDF řádek je vodorovně vycentrovaný se symetrickým paddingem na okrajích.
- Existující ~14 reference snapshotů refreshnuto a commitnuto.
- 2 nové unit testy v `LayoutBuilderTests` green.
- Žádná regrese na ostatních řádcích (row 1, row 3, number row, symbols, bottom).

## Rizika

- **Half-unit inset může vypadat na malých zařízeních (iPhone SE) jako moc velký prostor** — math `available_for_10/10 * 0.5` na pravém i levém okraji. Na 393pt screen je to ~17pt × 2. Subjektivně by mělo být OK. Pokud ne, doladit faktor.
- **Snapshot refresh** zdvojnásobí počet binary PNG v commitu — 14 souborů, ~200 KB. Není problém.

## Reference

- `KeyboardCore/Sources/Models/KeyboardRow.swift` — model rozšířený o `referenceWeight`
- `KeyboardCore/Sources/Logic/LayoutBuilder.swift:makeLetterRows` — set `referenceWeight: 10` pro row 2
- `KeyboardUI/Sources/Views/KeyRowView.swift` — inset logic
- Apple HIG: Keyboards — visual reference

## Codex review

**Skip** — pure layout math + snapshot refresh. Vizuální verify pokryje vše.
