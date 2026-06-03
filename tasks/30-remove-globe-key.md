# 30 — Odstranit globe key z bottom row

**Status:** Done — 2026-05-26

**Priorita:** v1.1 · **Úsilí:** S · **Dopad:** Low (čistka UI a kódu)

## Souhrn

Bottom row aktuálně obsahuje globe key (`SystemSymbol.globe`, `KeyAction.nextKeyboard`), který přepíná na další systémovou klávesnici. Pro osobní použití (Keymoji nahrazuje SwiftKey jako *jedinou* klávesnici) nemá smysl — uživatel mezi klávesnicemi necyklí. Odstranit ho z UI i z modelu, včetně doprovodné logiky a testů.

Bottom row pak bude užší o jednu klávesu, což dá zbylým klávesám (zejména space) o něco více místa — to je vítaný side-effect, ne primární motivace.

## Scope

1. **`LayoutBuilder.swift`** ([KeyboardCore/Sources/Logic/LayoutBuilder.swift:281](KeyboardCore/Sources/Logic/LayoutBuilder.swift:281) a [:342](KeyboardCore/Sources/Logic/LayoutBuilder.swift:342))
   - Smazat `globe` klíče v `makeStandardBottomRow` a `makeEmojiBottomRow`.
   - Upravit `keys: [...]` array (vypadne 1 prvek v obou řádcích).
   - Smazat / přepsat komentáře, které globe zmiňují (řádky 289, 330).

2. **`Key.swift`** ([KeyboardCore/Sources/Models/Key.swift](KeyboardCore/Sources/Models/Key.swift))
   - Smazat `SystemSymbol.globe` case a jeho mapping v `systemName`.
   - Smazat `KeyAction.nextKeyboard` case.
   - Aktualizovat doc-comment u `SystemSymbol` ("shift, delete, return, globe" → bez "globe") a u `KeyRole.system` (řádek 81).

3. **`InputDispatcher.swift`** ([KeyboardCore/Sources/Logic/InputDispatcher.swift:71](KeyboardCore/Sources/Logic/InputDispatcher.swift:71))
   - Smazat `case .nextKeyboard:` větev. `KeyAction` přestane být enum s tímto casem, takže switch musí přestat být exhaustive bez něj — žádný `@unknown default` workaround.

4. **`KeyboardControlling.swift`** ([KeyboardCore/Sources/Public/KeyboardControlling.swift](KeyboardCore/Sources/Public/KeyboardControlling.swift))
   - Pokud `advanceToNextInputMode()` v protokolu už nikdo nevolá, smazat ho. (Default implementace je `UIInputViewController`, takže odstranění z protokolu nic nerozbije.)

5. **`KeyView.swift`** ([KeyboardUI/Sources/Views/KeyView.swift](KeyboardUI/Sources/Views/KeyView.swift))
   - Smazat `.nextKeyboard` branch v `firesKeyTapFeedback` (řádek 187) a v `accessibilityLabel` (řádek 481).
   - Aktualizovat komentář o "globe" v `firesKeyTapFeedback` (řádek 166).

6. **Testy**
   - `LayoutBuilderTests.swift` ([KeyboardCore/Tests/LayoutBuilderTests.swift:236](KeyboardCore/Tests/LayoutBuilderTests.swift:236) a dál) — snížit očekávaný `row.keys.count` (z 6 na 5 v letters/symbols, z 4 na 3 v emojis), odstranit assertion na `row.keys[1].action == .nextKeyboard`, přečíslovat zbylé indexy. Přejmenovat `testEmojiPage_bottomRow_hasABCGlobeSpaceDelete` na `…hasABCSpaceDelete`.
   - `InputDispatcherTests.swift` ([KeyboardCore/Tests/InputDispatcherTests.swift:439](KeyboardCore/Tests/InputDispatcherTests.swift:439)) — smazat `testNextKeyboard_callsController` a `advanceCount` / `advanceToNextInputMode()` z `MockController` (řádek 522).
   - Pokud existují snapshot testy bottom row, zaktualizovat snapshots.

7. **Onboarding — *nechat beze změny***
   - [SelectKeyboardStepView.swift](Features/Onboarding/Sources/SelectKeyboardStepView.swift) ukazuje globe ikonu a [OnboardingStep.swift:17](Features/Onboarding/Sources/OnboardingStep.swift:17) zmiňuje "tap the globe key". To se vztahuje k **systémovému** globe v jiných klávesnicích (uživatel přes něj přepne *na* Keymoji), ne k naší klávese. Onboarding zůstává.

## Důsledky pro uživatele

- **Přepnutí na jinou klávesnici z Keymoji:** iOS samo zobrazí globe v *jiných* klávesnicích, takže přepnout *zpátky* půjde. Z Keymoji *ven* (na jinou kbd v rámci téhož inputu) přímá cesta nezůstane — Apple nemá veřejné API pro long-press globe menu mimo vlastní `UIInputViewController.handleInputModeList(from:with:)`, a to je provázané s globe gestem.
- Vzhledem k tomu, že Keymoji má být **jediná** nainstalovaná custom klávesnice (use case = nahradit SwiftKey), tento scénář v praxi nenastane. Pokud bys měl/a v budoucnu více klávesnic, vrátíš globe v separátním tasku.

## App Store risk

Apple HIG doporučuje globe key pro custom klávesnice, ale není to formální requirement (review v posledních letech aplikace bez globe propouští, pokud má klávesnice jiný způsob, jak uživatel může pokračovat — což emoji page + standardní iOS UI splňují). Pokud by review aplikaci kvůli tomu odmítl, vrátit globe je jednodušší než rebranding — minor rollback.

## Závislosti

Žádné — orthogonal vůči ostatním v1.1 taskům.

## Mimo scope

- Změna pozic / weight ostatních kláves v bottom row nad rámec přirozeného přerozdělení šířky (které řeší existující weight logika v `KeyboardView`). Pokud po odstranění globe vznikne UX issue (např. space je teď „moc široký" a dot key se ztrácí), řešit v separátním polish tasku.
- Skrytí globe podmíněně (např. „jen když je nainstalována pouze jedna klávesnice"). Šlo by to přes `needsInputModeSwitchKey`, ale komplikuje to layout (řádek mění počet kláves runtime). Pro v1 keep simple: globe není.

## Hotovo když

- `tuist generate` + build projde bez warning.
- Všechny testy v `KeyboardCore` zelené.
- Manuální test: na zařízení s nainstalovanou Keymoji klávesnicí spustit iMessage, vyvolat Keymoji — globe key se nezobrazuje na žádné stránce (letters / symbols / symbols-alt / emojis). Ostatní klávesy fungují normálně.
- `grep -r "globe\|nextKeyboard" KeyboardCore KeyboardUI KeyboardExtension` vrátí *jen* legitimate hits v onboardingu (kde se mluví o systémové globe v jiných klávesnicích).

## Reference

- [KeyboardCore/Sources/Logic/LayoutBuilder.swift](KeyboardCore/Sources/Logic/LayoutBuilder.swift) — definice bottom row
- [KeyboardCore/Sources/Models/Key.swift](KeyboardCore/Sources/Models/Key.swift) — `SystemSymbol`, `KeyAction`
- [KeyboardCore/Sources/Logic/InputDispatcher.swift](KeyboardCore/Sources/Logic/InputDispatcher.swift) — dispatch logika
