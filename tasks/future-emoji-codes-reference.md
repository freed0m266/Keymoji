# Future — Emoji codes reference screen

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** S · **Dopad:** Low

## Souhrn

Browse screen v host appce, kde uživatel vidí seznam všech emoji shortcodes (z Future tasku `future-slack-emoji-typing.md`) — `:smile:` 😄, `:thumbsup:` 👍, atd. Tap na řádku copy shortcode do clipboard.

Pomáhá uživateli zapamatovat si codes a ujistit se, co kde je.

## Scope (až přijde čas)

- `Features/EmojiCodes/` framework.
- `EmojiCodesView` — `List` všech codes (~200 řádků), search bar nahoře.
- Tap na řádek → `UIPasteboard.general.string = ":code:"` + toast/haptic potvrzení.
- Link v `SettingsView` → „Emoji codes reference".

## Závislosti

Future task `future-slack-emoji-typing.md` (sdílí mapping table).

## Proč ne v v1.0

Závisí na slack emoji feature.
