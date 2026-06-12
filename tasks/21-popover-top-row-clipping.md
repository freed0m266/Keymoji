# 21 — Top-row long-press popover clipping

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium (UX edge)

## Souhrn

Při long-press na klávesy v top row klávesnice (number row pokud zapnutý, jinak QWERTY row), popover renderovaný `-52 pt` nad klávesou skončí mimo `UIInputView` bounds a iOS ho ořeže. Diakritika je tedy částečně neviditelná.

Apple iOS toto řeší rozšířením `inputView` o oblast popoveru nahoru (transparentní), nebo flipnutím popoveru pod klávesu když nahoře není místo.

**Pozn.:** Po dokončení tasku 25 (key preview bublina) trpí stejným clippingem i preview popup — jeho vertikální offset (~92 pt) je dokonce větší než long-press popoveru (52 pt). Tj. fix musí pokrývat oba overlay typy.

**Pozn. (task 61):** [Task 61](61-constant-height-top-region.md) (konstantní výška + vždy-rezervovaný `topRegion`) tenhle clipping **na default nastavení (number row ON) vyřeší úplně** — QWERTY top row má nově nad sebou `48 (number row) + 42 (region) = 90 pt ≥ 56 pt`. Zbývá řešit už **jen no-number-row top row** (uživatel si number row vypnul, nebo landscape): region 42 pt < popover 56 pt → reziduum ~14 pt. Tj. po tasku 61 je scope tohoto tasku užší — plný fix potřebuje pořád resize `inputView` (a kvůli preview bublině ~92 pt tak jako tak).

## Scope (až přijde čas)

Tři možné cesty:

- **(a) Resize inputView**: `KeyboardViewController.inputView.frame` extendovat o ~95 pt nahoru, transparentní oblast pro popover a preview bublinu. Nejpřesnější Apple-like řešení, ale komplikuje layout. **Výhoda:** overlay kód v `KeyView` se vůbec nemění — fix žije na jednom místě a pokrývá oba overlay typy zdarma.
- **(b) Flip popover dolů na top row**: detekovat „top row" v `KeyRowView` (`isFirstRowAfterNumberRow` flag) a v `KeyView` `.offset(y: +keyHeight + 12)` místo `-popoverHeight - 12`. UX je trochu jiné než Apple a musí se aplikovat zvlášť na long-press popover i preview bublinu (= dvojí propagace `placement` parametru přes `KeyRowView` → `KeyView`).
- **(c) Reserved padding**: vždy přidat ~95 pt nahoru do `KeyboardView` a oba overlay typy renderovat do něj. Visible space cost.

**Doporučení (a)** — overlay kód z tasků 07 a 25 zůstává netknutý, fix je centralizovaný v `KeyboardViewController`. (Před taskem 25 dávalo víc smysl (b), ale s existencí dvou overlay typů se kalkulace překlopila — duplikace `placement` logiky není worth it.)

## Závislosti

Task 07 hotový.

## Proč ne v v1.0

Codex P2 finding při review tasku 07. Pragmatika: top row je menšina dlouhých stisků (uživatel častěji long-pressuje `a`/`s`/`d` než `q`/`w`/`e`), a alternates pro number row jsou single-alternate shortcut (popover se ani neukáže). Akceptovatelná v1.0 limitace.
