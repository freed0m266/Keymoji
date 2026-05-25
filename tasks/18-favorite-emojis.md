# 18 — Favorite emojis editor

**Status:** Done — 2026-05-25

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium

## Souhrn

Uživatel označí oblíbené emoji (např. 10–20) a ty se zobrazují v dedicated „Favorites" sekci v emoji panelu. Možnost reorderu drag-and-drop.

## Scope (až přijde čas)

- Settings screen „Favorite emojis" — editable list, drag-and-drop reorder, swipe-to-delete.
- Persistence v `AppGroupStore.favoriteEmojis: [String]`.
- V emoji panelu (Future task `future-emoji-key.md`) zobrazit „Favorites" jako první sekce.
- Případně přidat „Add to favorites" gesture na emoji panel (long-press → add).

## Závislosti

Future task `future-emoji-key.md` hotový.

## Proč ne v v1.0

Závisí na emoji panelu, který sám není v v1.0.
