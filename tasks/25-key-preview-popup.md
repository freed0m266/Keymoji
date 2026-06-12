# 25 — Key preview popup (Apple-style bublina nad prstem)

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Low (polish)

## Souhrn

Apple iOS klávesnice zobrazuje malou „popup bublinu" se zvětšeným znakem nad prstem při tapu. Pomáhá při psaní velkými palci, kdy prst zakrývá klávesu. V SwiftKey je toto vypínatelné.

## Scope (až přijde čas)

- `KeyPreviewPopup` view v `KeyboardUI` — bublina ~80×80 pt, zvětšený `KeyContent` uvnitř, tail (trojúhelník) směřující na klávesu.
- Příklad při touch down v `KeyView` → ukázat preview overlay nad klávesou.
- Při touch up → fade out (50 ms).
- Settings toggle „Show key previews".
- Edge cases: u edge keys (q, p) horizontální offset.
- Pozor: nesmí interferovat s long-press popoverem (task 07). Jeden ovládá short-tap, druhý long-hold.
- **Top-row clipping:** preview bublina (~92 pt nad klávesou) je vyšší než long-press popover (~56 pt), takže na top row trpí clippingem ještě víc. [Task 61](61-constant-height-top-region.md) (vždy-rezervovaný `topRegion` 42 pt) headroom pomáhá, ale na bublinu **nestačí** ani s number row (`90 < 92`, těsně) — plný fix je pořád resize `inputView` ([task 21](21-popover-top-row-clipping.md)). Tj. tenhle preview popup nezavádět dřív, než je task 21 hotový, jinak bude nahoře ořezaný.

## Závislosti

Tasky 03, 07 hotové.

## Proč ne v v1.0

Polish layer, není v původním prompt seznamu jako must-have. Apple ho má, SwiftKey ho dovoluje vypnout — tj. UX preference je split.
