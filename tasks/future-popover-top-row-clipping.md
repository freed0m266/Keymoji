# Future — Top-row long-press popover clipping

**Status:** Stub

**Priorita:** v1.1+ · **Úsilí:** M · **Dopad:** Medium (UX edge)

## Souhrn

Při long-press na klávesy v top row klávesnice (number row pokud zapnutý, jinak QWERTY row), popover renderovaný `-52 pt` nad klávesou skončí mimo `UIInputView` bounds a iOS ho ořeže. Diakritika je tedy částečně neviditelná.

Apple iOS toto řeší rozšířením `inputView` o oblast popoveru nahoru (transparentní), nebo flipnutím popoveru pod klávesu když nahoře není místo.

## Scope (až přijde čas)

Tři možné cesty:

- **(a) Resize inputView**: `KeyboardViewController.inputView.frame` extendovat o ~60 pt nahoru, transparentní oblast pro popover. Nejpřesnější Apple-like řešení, ale komplikuje layout.
- **(b) Flip popover dolů na top row**: detekovat „top row" v `KeyRowView` (`isFirstRowAfterNumberRow` flag) a v `KeyView` `.offset(y: +keyHeight + 12)` místo `-popoverHeight - 12`. UX je trochu jiné než Apple, ale jednodušší.
- **(c) Reserved padding**: vždy přidat 60 pt nahoru do `KeyboardView` a popover renderovat do něj. Visible space cost.

**Doporučení (b)** — minimální komplikace + zachovává viditelnost. Pokud someday user feedback ukáže, že chce Apple-like „above" pro top row, je to upgrade na (a).

## Závislosti

Task 07 hotový.

## Proč ne v v1.0

Codex P2 finding při review tasku 07. Pragmatika: top row je menšina dlouhých stisků (uživatel častěji long-pressuje `a`/`s`/`d` než `q`/`w`/`e`), a alternates pro number row jsou single-alternate shortcut (popover se ani neukáže). Akceptovatelná v1.0 limitace.
