# 17 — Quick emoji key + system emoji picker

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** High

## Souhrn

Z původního prompt seznamu „I liked": SwiftKey má dedicated emoji klávesu, která otevře emoji picker. V Keybo v1.0 to není; uživatel musí přepnout přes globe na system emoji klávesnici (přes long-press globe → emoji).

Upgrade: vlastní emoji klávesa na bottom row (nebo místo emoji symbol vlevo od space?), která buď:
- (a) otevře *vlastní* emoji panel uvnitř Keybo (potřebuje emoji data, search, kategorie — větší práce),
- (b) zavolá `advanceToNextInputMode()` s navigací na system emoji (Apple API neumí cílit specifický keyboard — fail).

Reálná cesta je **(a)** — vlastní emoji panel jako sub-page v `KeyboardPage`.

## Scope (až přijde čas)

- `KeyboardPage.emojis` case.
- `EmojiPanelView` v `KeyboardUI` — grid emoji s kategoriemi (people, food, animals, ...).
- Emoji data (Unicode data + skintone variants) — buď bundled JSON nebo derive z Unicode runtime.
- Search bar uvnitř emoji panel? Probably ne v1.1, jen scrollable.
- Recent emojis sekce (persistence v `AppGroupStore`).
- Switch button v bottom row: `[😀]` vedle `[🌐]`?
- Pozor na memory budget (emoji data může být MB).

## Závislosti

Tasky 02, 03, 04, 10 hotové.

## Proč ne v v1.0

Velký feature, vyžaduje emoji data infrastrukturu. Smyslem v1.0 je psát text, ne emoji.
