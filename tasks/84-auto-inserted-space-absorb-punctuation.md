# 84 — Auto-inserted space pohlcená následující interpunkcí

**Status:** Todo — připraveno z grill session 2026-06-25.

**Priorita:** v1.x (typing polish, Apple-like) · **Úsilí:** S (jeden stavový příznak + větev v insertu + testy) · **Dopad:** Medium (plynulejší psaní s návrhy, žádné `„slovo ."`).

**Souvisí s:** [40 — word completion suggestions](40-word-completion-suggestions.md), [74 — kvalita učení](74-learning-quality-numbers-emails.md). Glosář **Auto-inserted space** v [`CONTEXT.md`](../CONTEXT.md). Dotýká se [`InputDispatcher`](../KeyboardCore/Sources/Logic/InputDispatcher.swift), [`KeyboardState`](../KeyboardCore/Sources/Models/KeyboardState.swift).

## Kontext / proč

Při přijetí návrhu se za slovo vkládá mezera (`replacementText + " "`, [InputDispatcher.swift:152](../KeyboardCore/Sources/Logic/InputDispatcher.swift)). Když pak uživatel napíše interpunkci, vznikne `„slovo ."` s nechtěnou mezerou. Apple tuhle auto-mezeru před interpunkcí maže. Stav `lastInsertWasSpace` dnes **nerozlišuje** auto-mezeru od ručně psané — proto se nedá selektivně mazat jen ta auto.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Spouštěč** | Jen mezera **z přijetí návrhu** (`.suggestionAccept` s `appendsSpace == true`). **Ne** ručně psaná mezera. **Ne** `". "` z double-tapu (ta uvozuje další slovo; pohlcení by dalo nesmysl `".,"`). |
| **Znaky** | `.` `,` `?` `!` (shodné s `learningBoundaries`, [:324](../KeyboardCore/Sources/Logic/InputDispatcher.swift)). `;` `:` `)` apod. ne. |
| **Mechanismus** | Nový příznak `KeyboardState.lastSpaceWasAuto`. Set `true` jen v `.suggestionAccept` (když appendsSpace). Při insertu znaku z množiny, pokud `lastSpaceWasAuto` && kontext končí `" "` → `proxy.deleteBackward()` před vložením znaku. |
| **Re-learn guard (tvrdá podmínka)** | Vložení interpunkce v pohlcovacím případě **nesmí** spustit učící hook — slovo už bylo započítané při accept ([:165](../KeyboardCore/Sources/Logic/InputDispatcher.swift)). Bez toho double-count: po smazání mezery je kontext `„slovo."` a guard v `learnIfWordBoundary` ([:350](../KeyboardCore/Sources/Logic/InputDispatcher.swift)) už mezeru nevidí → slovo by se naučilo podruhé. |
| **Toggle** | Žádný. Vždy zapnuto — de facto navázané na Suggestions (příznak se nastaví jen při accept). |

## Scope

- [`KeyboardState`](../KeyboardCore/Sources/Models/KeyboardState.swift): `public var lastSpaceWasAuto: Bool` (init default `false`). Reset na `false` všude, kde se dnes resetuje `lastInsertWasSpace` (backspace, deleteWord, return, switchPage, cursor*).
- [`InputDispatcher`](../KeyboardCore/Sources/Logic/InputDispatcher.swift):
  - `.suggestionAccept`: `state.lastSpaceWasAuto = appendsSpace` (vedle `lastInsertWasSpace`).
  - `.insertText` / `.insertRawText`: na začátku, pokud `state.lastSpaceWasAuto`, `text ∈ {".",",","?","!"}` a `proxy.documentContextBeforeInput` končí `" "` → `proxy.deleteBackward()`; pak normální insert; **pro tenhle případ NEvolat `learnIfWordBoundary`** (nebo zaručit, že se znovu nezapočítá). Po každém insertu `lastSpaceWasAuto = false`.
  - `updateSpaceTracking`: nastavit `lastSpaceWasAuto = false`, když vložený text není auto-mezera.

## Non-goals

- Ručně psané mezery (zůstávají netknuté).
- `". "` z double-tapu mezerníku.
- `;` `:` `)` a další znaky; žádný toggle.
- Změna chování v e-mail polích (tam accept mezeru nepřidává → příznak `false` → feature se neuplatní).

## Akceptační kritéria

- Accept `„hello"` → `„hello "`; napíšu `.` → `„hello."` (mezera pryč). Slovo započítané **1×** (ne 2×).
- Accept `„hello"`; napíšu písmeno → `„hello X"` (mezera zůstává — normální).
- **Ruční** mezera (`„hello"` + mezerník) → `.` → `„hello ."` (mezera **zůstává** — A scope).
- `". "` z double-tapu + `,` → `". ,"` se **nepohltí** (mezera zůstává).
- E-mail pole: accept bez mezery → feature 2 se neuplatní (žádná regrese).

## Regresní síť

**Existující — musí projít beze změny:** [`InputDispatcherSuggestionTests`](../KeyboardCore/Tests/Suggestions/InputDispatcherSuggestionTests.swift), učení/count ([`PersonalRecentsStoreTests`](../KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift)), double-tap-space `". "` ([`InputDispatcherTests`](../KeyboardCore/Tests/InputDispatcherTests.swift)).

**Nové:** pohlcení mezery pro všechny 4 znaky; no-double-count po pohlcení; ruční mezera netknutá; `". "` netknutá.

## Jak testovat (next session)

- Build/testy přes **`Keymoji.xcworkspace`**, iPhone 17 / iOS 26.2.
- Manuálně: se zapnutými Suggestions přijmi návrh a napiš `.`/`,`/`?`/`!`; pak otevři editor naučených slov a ověř, že count nevyskočil o 2.
- Bez nových `.swift` souborů → `tuist generate` netřeba.
