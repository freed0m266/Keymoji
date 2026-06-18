# 65 — Accent-aware doplňování, caps lock z prázdného pole & limity

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** M · **Dopad:** Medium (kvalita psaní pro bilingvní uživatele + dvě UX vady)

## Cíl

Pět souvisejících úprav klávesnice a nastavení:

1. **Limit „Learned words" 500 → 1000.**
2. **Caps lock z prázdného pole.** Dvojí poklep na shift v *prázdném* poli dnes caps lock nezapne
   (v neprázdném ano). Sjednotit na iOS pravidlo „dva taby do 400 ms = caps lock".
3. **Accent přidá jazyk do doplňování.** Ke stávající bázi (`currentLanguage` = `PrimaryLanguage`
   extension) se **přidá** jazyk zvoleného **accent setu**; oba slovníky `UITextChecker` se slijí.
   Aditivní — báze pole/PrimaryLanguage se nezahazuje.
4. **Label v systémovém přepínači** klávesnic → „Multiple languages" (místo „English").
5. **Název accentu v Nastavení** se zobrazí v jazyce UI appky (angl. „Czech") místo endonymu „Čeština".
6. **`longPressDelay` 450 → 350 ms** (parita s Apple).

Po dokončení: v prázdném poli dvojklik na shift zapne caps lock; s accentem Čeština nabízí klávesnice
i česká doplnění; přepínač klávesnic ukazuje „Multiple languages"; v Nastavení svítí „Czech".

## Kontext / klíčová zjištění z průzkumu kódu

### Item 2 — caps lock (jádro)

- **Příčina je v auto-cap cestě.** `refreshAutoCapitalization`
  ([KeyboardViewController.swift:744](../KeyboardExtension/Sources/KeyboardViewController.swift:744))
  v prázdném poli nastaví `state.page = .letters(.upper)` a `autoCapitalized = true`, ale **nenastaví
  `lastShiftTapAt`**.
- **`ShiftStateMachine` o `autoCapitalized` neví** a větev `.lower`
  ([ShiftStateMachine.swift:73](../KeyboardCore/Sources/Logic/ShiftStateMachine.swift:73)) **nekontroluje
  double-tap**. Trace v prázdném poli: tap1 `.upper`(bez historie)→`.lower` (uloží t0); tap2 `.lower`→`.upper`
  → caps lock se nikdy nespustí. V neprázdném poli se startuje z `.lower`, takže tap1→`.upper`(t0),
  tap2→`.capsLock` funguje.
- **Stávající testy se symbolem, ne s konkrétními stavy** ([ShiftStateMachineTests.swift](../KeyboardCore/Tests/ShiftStateMachineTests.swift))
  — symetrická úprava je nerozbije, jen přidáme nové.

### Item 3 — accent jako jazyk doplňování (největší část)

- **Báze zůstává `currentLanguage`; accent se přidá navrch.** `refreshLanguage`
  ([KeyboardViewController.swift:306](../KeyboardExtension/Sources/KeyboardViewController.swift:306)) čte
  `textInputMode?.primaryLanguage` → `state.currentLanguage` → `SuggestionContext.primaryLanguage`
  ([:557](../KeyboardExtension/Sources/KeyboardViewController.swift:557)) → `language` arg pro `UITextChecker`
  ([WordCompletionProvider.swift:82](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:82)).
  **Tohle chování zachováváme** a jen k němu přidáváme jazyk accentu. **Pozor — technický fakt:** u custom
  klávesnice `textInputMode?.primaryLanguage` **nevrací jazyk pole**, ale `PrimaryLanguage` extension (iOS
  jazyk pole 3. straně nedává). „Jazyk pole" a „statický PrimaryLanguage" jsou tedy **týž signál** (dnes
  `en-US`, po item 4 `mul`). `currentLanguage` proto **nemažeme** — zůstane bází a je future-proof, kdyby
  iOS jazyk pole někdy vystavil.
- **Mapování accent → jazyk už existuje.** `LetterAlternateSet.byLanguage`
  ([LetterAlternateSet.swift:41](../KeymojiCore/Sources/Shared/LetterAlternateSet.swift:41)):
  `czech→cs, slovak→sk, german→de, polish→pl, french→fr, spanish→es`. `state.letterAlternateSet` je
  v controlleru živý (refresh ve `viewWillAppear` + Darwin notifikace).
- **Dostupnost slovníku máme zadarmo.** `UITextCheckerAdapter.resolveLanguage`
  ([SuggestionProviderAdapters.swift:34](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift:34))
  už dnes fallbackuje `přesný tag → základní jazyk → angličtina → cokoliv` přes `UITextChecker.availableLanguages`.
  Takže požadavek na `cs` na zařízení bez českého slovníku **sám spadne na angličtinu** — přesně decision D3.
  Žádný nový availability kód.
- **Merge umí víc zdrojů.** `WordCompletionProvider` slévá recents + checker + lexikon přes
  `consider(word, score)` s case-insensitive dedup (max skóre vyhrává). Druhý jazyk = druhé volání checkeru
  ve stejné smyčce.
- **Výkon.** Checker je synchronní in-memory prefix lookup, volaný na každý stisk už dnes. Aditivní varianta
  = max 2 volání (báze + accent), accent=`all` jen 1. Zdvojení levné operace → zanedbatelné, žádné async/I/O.
  Jazyky se před voláním **dedupnou** (raw tagy), ať se stejný slovník nevolá 2×.

### Item 4 — label přepínače

- **Statický plist.** `"PrimaryLanguage": "en-US"`
  ([KeyboardExtension.swift:18](../Tuist/ProjectDescriptionHelpers/Targets/KeyboardExtension.swift:18)) řídí
  text v systémovém přepínači. Je compile-time, **nejde měnit za běhu** dle in-app nastavení. `"mul"` (ISO kód
  „multiple languages") iOS renderuje jako „Multiple languages" (viz SwiftKey). `PrimaryLanguage` sice pořád
  teče do doplňování jako báze (přes `currentLanguage`), ale `resolveLanguage` v adapteru přemapuje `"mul"`
  na angličtinu, takže změna na `"mul"` doplňování nerozbije (báze zůstane anglická, accent se přidá navrch).

### Item 5 — název accentu v Nastavení

- **Dnes endonymy, schválně.** `label(for set:)`
  ([SettingsView.swift:225](../Features/Settings/Sources/SettingsView.swift:225)) vrací natvrdo „Čeština",
  „Deutsch", … Komentář ([:223](../Features/Settings/Sources/SettingsView.swift:223)) to zdůvodňuje
  vícejazyčným UI. Appka je ale **čistě anglická** (jen `KeymojiResources/Resources/en.lproj`,
  `developmentRegion: "en"` v [Project.swift:21](../Project.swift:21)), takže exonym „Czech" je pro uživatele
  srozumitelnější. Tohle rozhodnutí **obracíme**; komentář se přepíše.
- **Past `Locale.current`.** Na českém telefonu je `Locale.current = cs_CZ` → `localizedString(forLanguageCode: "cs")`
  vrátí zase „čeština". Musí se použít **jazyk UI appky**: `Bundle.main.preferredLocalizations.first` (dnes „en").
- `.all` zůstává přes `Texts.Keyboard.LetterAlternateSet.all` (L10n) — je to vlastní koncept, ne jazyk.

### Item 1 & 6 — limity

- `PersonalRecentsStore.capacity = 500`
  ([PersonalRecentsStore.swift:43](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:43)); evikce na
  [:175](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:175) i testy
  ([PersonalRecentsStoreTests.swift:158](../KeyboardCore/Tests/Suggestions/PersonalRecentsStoreTests.swift:158))
  jedou přes **symbol**, ne literál → změna konstanty je bezpečná.
- `longPressDelay = .milliseconds(450)`
  ([KeyView.swift:54](../KeyboardUI/Sources/Views/KeyView.swift:54)) — jediné použití, žádné testy; komentář
  na [:53](../KeyboardUI/Sources/Views/KeyView.swift:53) (dnes obhajuje 450) se přepíše.

## Rozhodnutí (z grillingu)

| Otázka | Rozhodnutí |
|---|---|
| Label přepínače klávesnic | **„Multiple languages"** (`PrimaryLanguage` → `"mul"`). Ověřit na zařízení. |
| Jazyk doplňování | **Aditivní: báze (`currentLanguage`/`PrimaryLanguage`) + jazyk accent setu, slité.** Báze pole se **nezahazuje**; accent se přidá navrch. |
| Accent `all` | **Jen angličtina** (není to konkrétní jazyk; diakritika pořád přes long-press). |
| Chybějící slovník na zařízení | **Tiše jen angličtina** — řeší stávající `resolveLanguage` fallback, žádné UI. |
| Název jazyka v Nastavení | **`Locale` dle UI appky** (`Bundle.main.preferredLocalizations.first`), ne `Locale.current`. Obrací endonym rozhodnutí. |
| Caps lock | **Dva taby do 400 ms = caps lock**, nezávisle na mezistavu (lower i upper). Edge `capsLock→lower` ošetřit vynulováním `lastShiftTapAt`. |
| Limit learned words | **1000.** |
| `longPressDelay` | **350 ms.** |
| Váhování EN vs accent | Každý seznam skórován vlastním ordinálem, dedup drží max skóre. Žádné privilegování jazyka (lze později ladit). |

## Scope

### 1. Accent → jazykový kód (KeyboardCore, pure)

[KeymojiCore/Sources/Shared/LetterAlternateSet.swift](../KeymojiCore/Sources/Shared/LetterAlternateSet.swift)
— nová computed property (znovu použít `byLanguage`). Vrací **jen příspěvek accentu** (jazyk accentu, nebo
`nil` u `.all`); bázi (`currentLanguage`) přidá controller (scope 4):

```swift
/// Jazyk slovníku, který tento accent set přidává do doplňování, nebo `nil` když accent není konkrétní
/// jazyk (`.all`). Báze (jazyk pole / PrimaryLanguage) se přidává zvlášť v controlleru. Dostupnost na
/// zařízení řeší `UITextCheckerAdapter.resolveLanguage` (chybějící → fallback na angličtinu).
public var accentLanguageCode: String? {
	Self.byLanguage.first(where: { $0.value == self })?.key
}
```

### 2. `SuggestionContext` — `primaryLanguage` → `completionLanguages`

[KeyboardCore/Sources/Logic/Suggestions/Suggestion.swift:57](../KeyboardCore/Sources/Logic/Suggestions/Suggestion.swift:57):

- Nahradit `public let primaryLanguage: String?` za `public let completionLanguages: [String]`
  (a stejně v `init`). Smazat komentář o `UITextInputMode.primaryLanguage`.

### 3. `WordCompletionProvider` — smyčka přes jazyky

[KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:58](../KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift:58):

- Smazat `let language = context.primaryLanguage ?? "en"`.
- Sekci (b) obalit smyčkou přes `context.completionLanguages`:

  ```swift
  // (b) UITextChecker completions — jednou na jazyk (EN + accent), slité do merge.
  for language in context.completionLanguages {
  	let checkerHits = textChecker.completions(forPartialWord: prefix, language: language)
  	for (index, word) in checkerHits.enumerated() {
  		let score = 0.9 - 0.5 * Double(index) / Double(max(checkerHits.count - 1, 1))
  		consider(word, score: score)
  	}
  }
  ```

  Dedup v `consider` (klíč = lowercased) drží max skóre, takže slovo z obou jazyků se nezdvojí.

### 4. `KeyboardViewController` — složení seznamu jazyků (báze + accent)

[KeyboardExtension/Sources/KeyboardViewController.swift](../KeyboardExtension/Sources/KeyboardViewController.swift):

- `refreshLanguage()` a `state.currentLanguage` **zůstávají** (báze pole/PrimaryLanguage). **Nic se nemaže.**
- `currentSuggestions()` ([:553](../KeyboardExtension/Sources/KeyboardViewController.swift:553)): složit
  seznam jazyků z báze + accentu (dedup, ať se stejný slovník nevolá 2×) a předat ho místo `primaryLanguage`:

  ```swift
  var languages = [state.currentLanguage ?? "en"]
  if let accent = state.letterAlternateSet.accentLanguageCode, !languages.contains(accent) {
  	languages.append(accent)
  }
  // …
  primaryLanguage → completionLanguages: languages
  ```

  > Pozn.: s `PrimaryLanguage="mul"` je `currentLanguage == "mul"`; `resolveLanguage` ho v adapteru přemapuje
  > na angličtinu, takže báze efektivně zůstává anglická, accent se přidá navrch. Žádné speciální ošetření „mul".

### 5. `PrimaryLanguage` → „mul"

[Tuist/ProjectDescriptionHelpers/Targets/KeyboardExtension.swift:18](../Tuist/ProjectDescriptionHelpers/Targets/KeyboardExtension.swift:18):
`"PrimaryLanguage": "mul"`. Po změně `tuist generate`. Label ověřit na zařízení (scope 9).

### 6. Caps lock — symetrická double-tap detekce

[KeyboardCore/Sources/Logic/ShiftStateMachine.swift](../KeyboardCore/Sources/Logic/ShiftStateMachine.swift),
`nextPageAfterShiftTap` ([:62](../KeyboardCore/Sources/Logic/ShiftStateMachine.swift:62)):

- Větev `.lower` zkontroluje double-tap stejně jako `.upper`:

  ```swift
  case .lower:
  	let isDoubleTap = lastTapAt.map { now.timeIntervalSince($0) < doubleTapWindow } ?? false
  	return isDoubleTap ? .letters(.capsLock) : .letters(.upper)
  ```

- Edge `capsLock → lower`: po opuštění caps locku vynulovat `lastShiftTapAt`, aby rychlý další tap nešel
  zpět do caps locku, ale do jednorázového velkého. V `reduce`
  ([:29](../KeyboardCore/Sources/Logic/ShiftStateMachine.swift:29)) ošetřit: když výsledná stránka po
  shift-tapu je `.lower` a předchozí byla `.capsLock`, nastavit `next.lastShiftTapAt = nil` (místo `now`).

  > Pozn.: prázdné pole jede cestou auto-`.upper` → `.lower` (ne `capsLock→lower`), takže to vynulování
  > fix nerozbije.

- `autoCapitalized` flag ani plumbing do state machine **netřeba** — fix je čistě v pravidle časování.

### 7. Název jazyka v Nastavení

[Features/Settings/Sources/SettingsView.swift:225](../Features/Settings/Sources/SettingsView.swift:225),
`label(for set:)`:

```swift
/// Název jazyka v jazyce UI appky (dnes angličtina → „Czech", „Slovak", …). Záměrně NE `Locale.current`
/// (na cs zařízení by vrátil endonym „čeština"); bereme jazyk UI appky z `preferredLocalizations`.
private func label(for set: LetterAlternateSet) -> String {
	if set == .all { return Texts.Keyboard.LetterAlternateSet.all }
	let uiLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
	let code = set.accentLanguageCode ?? "en"   // konkrétní jazyk accentu (.all je odchycen výš)
	return uiLocale.localizedString(forLanguageCode: code)?.capitalizedFirstLetter() ?? code
}
```

- Přepsat zavádějící komentář o endonymech ([:223](../Features/Settings/Sources/SettingsView.swift:223)).
- Ověřit, že `accentLanguageCode` sedí pro všech 6 jazyků.

### 8. Limity

- [PersonalRecentsStore.swift:43](../KeyboardCore/Sources/Storage/PersonalRecentsStore.swift:43):
  `public static let capacity = 1000`. Aktualizovat komentář, pokud zmiňuje 500.
- [KeyView.swift:54](../KeyboardUI/Sources/Views/KeyView.swift:54): `.milliseconds(350)`; komentář na
  [:53](../KeyboardUI/Sources/Views/KeyView.swift:53) přepsat (350 = parita s Apple).

### 9. Testy

- **`ShiftStateMachineTests`** (nové):
  - Prázdné pole: z `State(page: .letters(.upper), lastShiftTapAt: nil)` tap → `.lower` (uloží t0); druhý
    tap do okna → `.capsLock`. (Integrace přes `apply` na `KeyboardState`, jako `testDoubleTapSequence…`.)
  - `capsLock → lower`: po single tapu je `lastShiftTapAt == nil` a následný rychlý tap → `.upper`
    (ne `.capsLock`).
  - Regrese: stávající testy (`testUpper_…`, `testLower_shiftTapped_goesToUpper`,
    `testDoubleTapSequence_lowerToUpperToCapsLock`) zůstávají zelené beze změny.
- **`WordCompletionProviderTests`**: s `completionLanguages: ["en", "cs"]` a fake `TextChecking`, který
  vrací různé kandidáty pro `en` vs `cs`, ověřit, že merge obsahuje obojí a dedup drží max skóre; s
  `["en"]` (accent `.all`) jen anglické.
- **`LetterAlternateSet` test** (nový nebo do existujícího): `accentLanguageCode` = `"<code>"` pro každý
  konkrétní jazyk (cs/sk/de/pl/fr/es) a `nil` pro `.all`.
- **Composition test** (controller-side, je-li testovatelné): báze `"en"` + accent `.czech` → `["en", "cs"]`;
  báze `"en"` + accent `.all` → `["en"]` (žádný duplicitní `"en"`).
- **Settings**: pokud existuje test/snapshot pro řádek accentu, refresh (label se mění na „Czech").

### 10. Manuální verify (simulátor + reálné zařízení)

1. **Caps lock:** prázdné pole → dvojklik shift → caps lock (capslock.fill ikona, velká písmena drží).
   Neprázdné pole → pořád funguje. Single tap v prázdném poli → malé (auto-cap se vypne).
2. **Doplňování:** accent Čeština → psaní českého prefixu nabízí česká slova (vyžaduje český slovník na
   zařízení); accent „All" → jen anglická. Bez českého slovníku → tiše anglická (žádný pád).
3. **Přepínač klávesnic** (globe long-press): pod „Keymoji" stojí „Multiple languages". **Reálné zařízení
   / čistý build** — `PrimaryLanguage` se cachuje, po změně případně reinstall.
4. **Nastavení:** accent řádek ukazuje „Czech" (ne „Čeština"); ostatní jazyky „Slovak/German/Polish/French/Spanish".
5. **Limit:** (smoke) learned words se plní bez pádu; eviction až nad 1000.
6. **Long-press:** alternates vyskočí znatelně rychleji (350 ms).

## Mimo scope

- **Per-language keyboard extension targety** (samostatné položky v přepínači). Velká architektonická změna,
  případně vlastní task.
- **Dynamický `PrimaryLanguage` dle accentu** — iOS to neumožňuje (compile-time).
- **Layout/QWERTZ dle accentu, autocorrect, autocap dle jazyka.** Accent řídí jen long-press alternates +
  (nově) jazyk doplňování.
- **UI hláška „slovník není nainstalován".** Vědomě tiše.
- **Lokalizace UI appky do dalších jazyků.** `label(for:)` je na to připravený, ale samotná lokalizace ne.
- **Privilegování accent jazyka nad angličtinou ve skóre.** Zatím rovnocenné.

## Hotovo když

- Dvojklik shift v prázdném i neprázdném poli zapne caps lock; `capsLock→lower` rychlý tap jde do upper.
- `UITextChecker` se volá pro bázi (`currentLanguage`) **i** jazyk accentu (je-li konkrétní a dostupný);
  výsledky slité, bez duplicit; `currentLanguage`/`refreshLanguage` **zachovány** (báze pole/PrimaryLanguage).
- Systémový přepínač ukazuje „Multiple languages"; doplňování tím není dotčeno.
- Nastavení ukazuje název accentu v jazyce UI appky (angl. „Czech").
- `capacity == 1000`, `longPressDelay == 350 ms`; komentáře aktualizované.
- Unit testy (ShiftStateMachine, WordCompletionProvider, LetterAlternateSet) + případné snapshoty zelené.
- Manuální verify (caps lock, doplňování, přepínač, Nastavení, long-press) prošel.

## Rizika

- **`PrimaryLanguage="mul"` a doplňování — ošetřeno.** Když je `currentLanguage == "mul"`, `resolveLanguage`
  ([SuggestionProviderAdapters.swift:34](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift:34)) ho
  v adapteru přemapuje na angličtinu, takže báze zůstane anglická a accent se přidá navrch. „mul" tedy
  doplňování **nezabije**. Přesto v rámci verify (scope 10.2) potvrdit, že anglická doplnění chodí i s „mul".
- **Label přepínače se cachuje.** iOS čte `PrimaryLanguage` při registraci extension; změna se nemusí projevit
  bez reinstallu / restartu. Ověřit na reálném zařízení, ne jen simulátoru. Hodnota „mul" → „Multiple
  languages" je doloženo chováním SwiftKey, ale **potvrdit vizuálně**.
- **Redundantní anglické volání.** Když accent jazyk není na zařízení, `resolveLanguage` ho přemapuje na
  angličtinu → checker se pro angličtinu zavolá 2×. Neškodné (dedup), jen drobný overhead — neřešíme.
- **`capacity` 2× větší PII-pool.** Větší JSON blob v app-group containeru; pořád bounded, mazatelné přes
  „Clear learned words". Bez akce, jen poznámka.

## Reference

- [CONTEXT.md](../CONTEXT.md) — glosář: *Accent set*, *Primary language*, *Learned word*.
- [tasks/59-auto-numberpad-for-numeric-fields.md](59-auto-numberpad-for-numeric-fields.md) — vzor stylu tasku.
- [KeymojiCore/Sources/Shared/LetterAlternateSet.swift](../KeymojiCore/Sources/Shared/LetterAlternateSet.swift) — accent → jazyk.
- [KeyboardExtension/Sources/SuggestionProviderAdapters.swift](../KeyboardExtension/Sources/SuggestionProviderAdapters.swift) — `resolveLanguage` fallback.
- Apple App Extension Programming Guide — Custom Keyboard (`PrimaryLanguage`, forced-system pravidla).

## Codex review

**Ano** — dotýká se suggestion pipeline (`SuggestionContext` kontrakt napříč KeyboardCore/Extension) a
`ShiftStateMachine` (stavová logika s edge case). Spustit `codex review --uncommitted` před closing commitem.
