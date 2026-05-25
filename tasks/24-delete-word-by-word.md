# 24 — Delete word-by-word (long hold)

**Status:** Done — 2026-05-25

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Medium

## Souhrn

V1.0 (task 09): delete hold = char-by-char repeat. Apple navíc po ~2 sekundách držení přepne na word-by-word delete (mažou se celá slova). Velmi handy pro mazání chybných sentence.

## Scope (až přijde čas)

- Po 2000 ms hold na delete (od task 09 repeat start) přepnout repeat mode na word-delete.
- Word boundary detection: regex na `\b` nebo manuální scan `documentContextBeforeInput` od konce (poslední non-whitespace sequence).
- Repeat rate na word delete: pomalejší než char (každých ~200 ms).
- Visual feedback: optional přesvícení klávesy do oranžové (jako Apple).

## Závislosti

Task 09 hotový.

## Proč ne v v1.0

Polish layer nad existing repeat behavior. Tasku 09 stačilo char-by-char pro „basic usable".
