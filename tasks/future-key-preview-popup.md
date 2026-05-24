# Future — Key preview popup (Apple-style bublina nad prstem)

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** M · **Dopad:** Low (polish)

## Souhrn

Apple iOS klávesnice zobrazuje malou „popup bublinu" se zvětšeným znakem nad prstem při tapu. Pomáhá při psaní velkými palci, kdy prst zakrývá klávesu. V SwiftKey je toto vypínatelné.

## Scope (až přijde čas)

- `KeyPreviewPopup` view v `KeyboardUI` — bublina ~80×80 pt, zvětšený `KeyContent` uvnitř, tail (trojúhelník) směřující na klávesu.
- Příklad při touch down v `KeyView` → ukázat preview overlay nad klávesou.
- Při touch up → fade out (50 ms).
- Settings toggle „Show key previews".
- Edge cases: u edge keys (q, p) horizontální offset.
- Pozor: nesmí interferovat s long-press popoverem (task 07). Jeden ovládá short-tap, druhý long-hold.

## Závislosti

Tasky 03, 07 hotové.

## Proč ne v v1.0

Polish layer, není v původním prompt seznamu jako must-have. Apple ho má, SwiftKey ho dovoluje vypnout — tj. UX preference je split.
