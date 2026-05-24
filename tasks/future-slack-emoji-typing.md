# Future — Slack-style emoji typing (`:smile:` → 😄)

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** M · **Dopad:** Medium

## Souhrn

Když uživatel napíše `:smile:` nebo `:thumbsup:`, Keybo to automaticky nahradí za emoji. Inspirace ze Slacku / Discord / GitHubu.

## Scope (až přijde čas)

- `SlackEmojiParser` v `KeyboardCore` — pure logika.
- Trigger: každý character insert kontroluje, jestli `documentContextBeforeInput` končí na `:.+:` pattern. Pokud ano:
  1. Lookup v mapě `["smile": "😄", "thumbsup": "👍", ...]`.
  2. Pokud match: smazat `:foo:` (count chars + 2) backspaces, vložit emoji.
  3. Pokud žádný match: nedělat nic, ponechat `:foo:` jako text.
- Mapping table: ~200 nejpoužívanějších emoji shortcodes. Zdroj: `emoji-data` Unicode data nebo Slack veřejný seznam.
- Volitelně live preview během psaní `:smi` → suggestion popover (typeahead). Komplexnější, v Future-Future.

## Závislosti

Tasky 02, 04 hotové.

## Proč ne v v1.0

Vyžaduje emoji mapping table a tracking. Není to core typing, je to power user feature. Future polish.
