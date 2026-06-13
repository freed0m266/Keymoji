# 62 — Onboarding: výběr oblíbených emoji (s garantovaným ne-prázdným fallbackem)

**Status:** Done — 2026-06-13

**Status (původní):** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium (cold-start — favorites bar má hned smysluplný obsah místo prázdna; lepší první dojem)

## Cíl

Přidat do onboardingu **nový krok**, kde si uživatel z malé kurátorované nabídky naťuká své oblíbené
emoji. Krok jde **přeskočit**. Na konci onboardingu ale `favoriteEmojis` **nikdy nesmí být prázdné** —
když uživatel nic nevybere (skip, nebo prostě Continue bez výběru), dosadí se **fixní set 12 emoji**
(žádný random).

Po dokončení: projdu onboarding → na novém kroku ťuknu pár emoji → po „Start typing" mám ty emoji
ve favorites baru nad klávesnicí. Když krok přeskočím → mám tam předdefinovaných 12.

## Kontext / klíčová zjištění z průzkumu kódu

- **Onboarding je 4-krokový `TabView`.** Pořadí `addKeyboard → allowFullAccess → selectKeyboard →
  featureTour` v [OnboardingStep.swift](../Features/Onboarding/Sources/OnboardingStep.swift); render
  v [OnboardingView.swift](../Features/Onboarding/Sources/OnboardingView.swift). Kroky 1–3 jsou „odskoč
  do iOS Settings", krok 4 je pasivní feature tour. Tour končí tlačítkem „Start typing", které volá
  `viewModel.didFinishOnboarding()` + `onFinish()` ([OnboardingView.swift:182](../Features/Onboarding/Sources/OnboardingView.swift:182)).

- **Finish chokepoint už existuje.** `didFinishOnboarding()`
  ([OnboardingViewModel.swift:58](../Features/Onboarding/Sources/OnboardingViewModel.swift:58)) dnes jen
  volá `dependencies.preferences.markOnboardingComplete()`. Sem přidáme zápis favorites — **jediné místo**,
  kde se invariant vynutí.

- **Favorites store je hotový.** `AppGroupStore.favoriteEmojis: [String]` (uspořádané glyphy, default
  **prázdné**). Editor v Settings zapisuje live + postuje `SettingsChangeNotifier.post(.favoriteEmojis)`
  ([FavoriteEmojisEditorViewModel.swift:95](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorViewModel.swift:95)).
  `favoritesSortMode` default `.manual` → **pořadí v poli = pořadí v baru**. Favorites bar nad klávesnicí
  je hotový (tasky 44/49/51), tady ho **neřešíme**.

- **DI seam = `OnboardingPreferencesProviding`.** Protokol
  ([OnboardingDependencies.swift:11](../Features/Onboarding/Sources/OnboardingDependencies.swift:11)) dnes
  má `isOnboardingComplete` + `markOnboardingComplete()`, impl drží `AppGroupStore`. Rozšíříme ho o čtení
  a zápis favorites → VM zůstane testovatelná přes mock, UIKit/notifier zůstane mimo VM.

- **Reusable picker se sem nehodí.** [EmojiCatalogPickerView](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift)
  je kategorizovaný nad celým `EmojiCatalog.staticCategories` — overkill na 12 kurátorovaných. Postavíme
  **malý bespoke grid** přímo v Onboarding featuře (vizuál buňky okopíruje
  [EmojiCatalogPickerView.swift:83](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift:83):
  accent fill + `checkmark.circle.fill`).

- **Onboarding target dnes nezná `KeyboardCore`.** Deps jsou `core/design/resources`
  ([Tuist/.../Features/Onboarding.swift](../Tuist/ProjectDescriptionHelpers/Targets/Features/Onboarding.swift)).
  Konstantu 12 emoji dáme do `KeyboardCore` (vedle `EmojiCatalog`) → přidat dep (vzor:
  [FavoriteEmojisEditor.swift](../Tuist/ProjectDescriptionHelpers/Targets/Features/FavoriteEmojisEditor.swift)
  už `keyboardCore` má).

### Rozhodnutí (z grillingu)

| Otázka | Rozhodnutí |
|---|---|
| Co krok ukáže | **Kurátorovaný „starter" grid** (12 emoji). Plný katalog se needituje — zůstává v Settings. |
| Startovní stav | **Opt-in** (prázdný výběr, uživatel ťuká a přidává). Ne opt-out předvybrané. |
| Shown set vs. fallback | **Jeden set, jeden zdroj pravdy.** `EmojiCatalog.defaultFavorites` je grid i fallback. |
| Fixní vs. random | **Fixní.** Žádný random — kvůli predikovatelnosti a snapshotům. |
| Obsah (12, pořadí) | `❤️ 😂 👍 🙏 😍 🔥 🎉 😭 🥰 😎 👌 ✨`. Pořadí = pořadí v baru (manual sort). |
| Lokalizace setu | **Jeden globální** set pro všechny. Region-tuning (vlajky) = případný future task. |
| Skip affordance | Primary „Continue" (vždy aktivní) + Secondary „Skip for now". Continue ani Skip **nedisablujeme**. |
| Kde se vynutí ne-prázdno | **Jeden chokepoint:** `didFinishOnboarding()`. `selected.isEmpty ? defaults12 : selected`. |
| Kde žije výběr / kdy zápis | Výběr drží `OnboardingViewModel` (lokální stav). **Jeden zápis na finiši**, ne live. |
| Placement v sekvenci | **Před tour:** `selectKeyboard → pickFavorites → featureTour`. Tour zůstává finišerem. |
| Re-run onboardingu | Init `selectedFavorites = store.favoriteEmojis` → vracející se uživatel má svoje předzaškrtnuté. |
| Migrace hotových uživatelů | **Žádná.** Garance jen ve flow; app je pre-release → moot. Globální backfill = samostatný task. |
| Grid impl | **Bespoke** v Onboarding featuře (ne reuse `EmojiCatalogPickerView`). |
| Konstanta 12 | V **`KeyboardCore`** vedle `EmojiCatalog` + konzistenční unit test (⊆ katalogu podle glyphu). |
| Ikona / copy | Ikona `star`; copy viz scope 8. Fallback je **tichý** (neavízujeme „vyber aspoň jeden"). |
| Codex review | **Ano** (persistence invariant + finish flow + nový `OnboardingStep` case). |

## Scope

### 1. `OnboardingStep` — nový case

[Features/Onboarding/Sources/OnboardingStep.swift](../Features/Onboarding/Sources/OnboardingStep.swift) —
vložit `pickFavorites` **mezi** `selectKeyboard` a `featureTour` (deklarační pořadí = pořadí v `TabView`
i v dot indikátoru, který iteruje `allCases`):

```swift
public enum OnboardingStep: Int, CaseIterable, Identifiable {
	case addKeyboard
	case allowFullAccess
	case selectKeyboard
	case pickFavorites      // ← nový: in-app výběr oblíbených emoji
	case featureTour
	public var id: Int { rawValue }
}
```

Pozn.: `rawValue` se posune (`featureTour` 3→4), ale používá se jen jako `id` a pro pořadí teček — nikde
se neperzistuje, takže posun je neškodný.

### 2. `EmojiCatalog.defaultFavorites` — konstanta v KeyboardCore

Nová konstanta vedle existujícího katalogu (přesné glyphy **vč. variation selectorů** — viz Rizika):

```swift
public extension EmojiCatalog {
	/// Tichý fallback pro onboarding: zapíše se do `favoriteEmojis`, když uživatel krok přeskočí
	/// nebo nic nevybere. Zároveň je to nabídka zobrazená v onboarding gridu (jeden zdroj pravdy).
	/// Pořadí = pořadí ve favorites baru (manual sort). Globální, locale-agnostické.
	static let defaultFavorites: [String] = [
		"❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "😭", "🥰", "😎", "👌", "✨"
	]
}
```

### 3. Tuist dependency

[Tuist/.../Features/Onboarding.swift](../Tuist/ProjectDescriptionHelpers/Targets/Features/Onboarding.swift)
— přidat `KeyboardCore` (kvůli `EmojiCatalog.defaultFavorites`):

```swift
public let onboarding = Feature(
	name: "Onboarding",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: keyboardCore.name)   // ← nový
	]
)
```

Po změně `tuist generate`.

### 4. `OnboardingPreferencesProviding` — čtení + zápis favorites

[Features/Onboarding/Sources/OnboardingDependencies.swift](../Features/Onboarding/Sources/OnboardingDependencies.swift) —
rozšířit protokol a impl. Rozhodnutí selection-vs-fallback **nezůstává tady** (je ve VM, scope 5) — impl
jen zapíše, co dostane, a postne notifier:

```swift
public protocol OnboardingPreferencesProviding: Sendable {
	var isOnboardingComplete: Bool { get }
	var currentFavorites: [String] { get }                  // ← pro pre-fill při re-runu
	func markOnboardingComplete()
	func persistOnboardingFavorites(_ favorites: [String])  // ← finální zápis + notify
}

public struct OnboardingPreferences: OnboardingPreferencesProviding {
	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier

	public init(store: AppGroupStore = .shared, notifier: SettingsChangeNotifier = .shared) {
		self.store = store
		self.notifier = notifier
	}

	public var isOnboardingComplete: Bool { store.onboardingComplete }
	public var currentFavorites: [String] { store.favoriteEmojis }

	public func markOnboardingComplete() { store.onboardingComplete = true }

	public func persistOnboardingFavorites(_ favorites: [String]) {
		store.favoriteEmojis = favorites
		notifier.post(.favoriteEmojis)   // keyboard přidaná už v kroku 1 se refreshne; jinak no-op
	}
}
```

### 5. `OnboardingViewModeling` / `OnboardingViewModel` — stav výběru + finish logika

[Features/Onboarding/Sources/OnboardingViewModel.swift](../Features/Onboarding/Sources/OnboardingViewModel.swift):

- **Protokol** — přidat:

  ```swift
  var selectedFavorites: [String] { get }
  func toggleFavorite(_ glyph: String)
  ```

- **Impl** — `import KeyboardCore`; uspořádaný `selectedFavorites` (toggle = append/remove → tap pořadí =
  manual pořadí); init pre-fill ze storu; rozhodnutí selection-vs-fallback v `didFinishOnboarding`:

  ```swift
  private(set) var selectedFavorites: [String]

  init(dependencies: OnboardingDependencies, initialStep: OnboardingStep) {
  	self.dependencies = dependencies
  	self.currentStep = initialStep
  	self.selectedFavorites = dependencies.preferences.currentFavorites   // prázdné u nového, předvyplněné u re-runu
  	super.init()
  	refreshKeyboardStatus()
  }

  func toggleFavorite(_ glyph: String) {
  	if let idx = selectedFavorites.firstIndex(of: glyph) {
  		selectedFavorites.remove(at: idx)
  	} else {
  		selectedFavorites.append(glyph)
  	}
  }

  func didFinishOnboarding() {
  	let final = selectedFavorites.isEmpty ? EmojiCatalog.defaultFavorites : selectedFavorites
  	dependencies.preferences.persistOnboardingFavorites(final)
  	dependencies.preferences.markOnboardingComplete()
  }
  ```

  Pozn.: rozhodnutí `isEmpty ? defaults : selected` je ve VM schválně — je to čistá logika testovatelná
  přes mock, který zaznamená předané pole (scope 9). Skip ani Continue tu nic nezapisují (scope 6).

### 6. `OnboardingView` — nový krok + drátování

[Features/Onboarding/Sources/OnboardingView.swift](../Features/Onboarding/Sources/OnboardingView.swift):

- **`selectKeyboardStep`** tlačítko ([:140](../Features/Onboarding/Sources/OnboardingView.swift:140)) —
  přesměrovat z `.featureTour` na `.pickFavorites`.

- **Nový `pickFavoritesStep`** vložit do `TabView` mezi select a tour, `.tag(OnboardingStep.pickFavorites)`.
  Struktura ladí s ostatními kroky (ikona + title + description nahoře, akce dole). Continue i Skip jen
  **navigují** na `.featureTour` (zápis je až na finiši přes tour „Start typing"):

  ```swift
  private var pickFavoritesStep: some View {
  	VStack(spacing: 24) {
  		Icon.star.size(90).foregroundStyle(.tint)
  		Text(Texts.Favorites.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
  		Text(Texts.Favorites.description)
  			.font(.callout).foregroundStyle(.secondary)
  			.multilineTextAlignment(.center).padding(.horizontal, 24)

  		favoritesGrid

  		Spacer()

  		VStack(spacing: 16) {
  			PrimaryButton(Texts.Favorites.cta) { viewModel.currentStep = .featureTour }
  			SecondaryButton(Texts.Favorites.skip) { viewModel.currentStep = .featureTour }
  			Text(Texts.Favorites.footer)
  				.font(.footnote).foregroundStyle(.tertiary).multilineTextAlignment(.center)
  		}
  		.padding(.horizontal, 32)
  	}
  	.padding(.top, 64)
  }
  ```

- **`favoritesGrid`** — bespoke `LazyVGrid` nad `EmojiCatalog.defaultFavorites`; buňka = glyph + accent
  fill + `checkmark.circle.fill` pro `selectedFavorites.contains(glyph)`; tap → `viewModel.toggleFavorite(glyph)`.
  Accessibility: `.isSelected` trait jako v [EmojiCatalogPickerView.swift:108](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift:108).
  12 buněk se musí vejít i na iPhone SE (320pt) — adaptivní sloupce, žádný horizontální scroll.

- **`Texts`** alias rozšířit / použít `L10n.Onboarding.Favorites` (scope 8).

- **Previews** — přidat `#Preview("Step — Pick favorites")` (prázdný výběr) + variantu s pár vybranými.

### 7. `OnboardingViewModelMock`

[Features/Onboarding/Testing/OnboardingViewModelMock.swift](../Features/Onboarding/Testing/OnboardingViewModelMock.swift) —
doplnit `selectedFavorites` + `toggleFavorite` (ať jdou dělat previews/snapshoty s předvybranými) a init
param pro počáteční výběr:

```swift
public var selectedFavorites: [String]
public init(currentStep: OnboardingStep = .addKeyboard,
            isKeyboardActivated: Bool = false,
            selectedFavorites: [String] = []) { … }
public func toggleFavorite(_ glyph: String) { /* append/remove */ }
```

### 8. Lokalizace

[KeymojiResources/.../en.lproj/Localizable.strings](../KeymojiResources/Resources/en.lproj/Localizable.strings)
— nové klíče (po přidání `tuist generate` přegeneruje `L10n.Onboarding.Favorites`):

```
"onboarding.favorites.title" = "Pick your favorite emoji";
"onboarding.favorites.description" = "Tap the ones you reach for most — they'll sit right above your keyboard, ready to drop in.";
"onboarding.favorites.cta" = "Continue";
"onboarding.favorites.skip" = "Skip for now";
"onboarding.favorites.footer" = "You can change these any time in Settings.";
```

Vědomě **netvrdíme** „vyber aspoň jeden" — fallback je tichý.

### 9. Unit testy (Onboarding Tests)

Mock `OnboardingPreferencesProviding`, který zaznamenává předané pole do `persistOnboardingFavorites`:

- **prázdný výběr → `didFinishOnboarding()` →** mock dostal přesně `EmojiCatalog.defaultFavorites` (12, ve správném pořadí).
- **neprázdný výběr → finish →** mock dostal přesně vybrané glyphy **v tap pořadí**.
- **`toggleFavorite`** přidá/odebere a drží pořadí (přidání na konec; re-toggle odebere).
- **init pre-fill:** `currentFavorites = ["🚀","🐶"]` → `selectedFavorites == ["🚀","🐶"]` (re-run).
- **finish volá i `markOnboardingComplete()`** (pořadí nerozhoduje, ale obojí musí proběhnout).

**Konzistenční test (KeyboardCore Tests):** každý glyph z `EmojiCatalog.defaultFavorites` existuje
v `EmojiCatalog.all` (match podle `glyph`). Chytne variation-selector / překlep.

### 10. Snapshot testy (`OnboardingSnapshots`)

[Features/Onboarding/Tests/OnboardingSnapshots.swift](../Features/Onboarding/Tests/OnboardingSnapshots.swift):

- `testStep_pickFavorites_dark` (prázdný výběr).
- `testStep_pickFavorites_someSelected_dark` (`selectedFavorites: ["❤️","🔥","🎉"]` → checkmarky).
- `testStep_pickFavorites_iPhoneSE` (grid musí sednout na 320pt bez ořezu / scrollu).

Postup standardní: `record: true` → vizuální kontrola → `record: false` → green.

### 11. Manuální verify

1. Čistá instalace → projít onboarding → na novém kroku ťuknout 3 emoji → „Start typing" → otevřít
   klávesnici → favorites bar má ty 3 ve vybraném pořadí.
2. Čistá instalace → na kroku dát **Skip** (nic nevybráno) → dokončit → bar má předdefinovaných 12.
3. Čistá instalace → nic neťuknout, dát **Continue** → dokončit → bar má 12 (stejné jako Skip).
4. Re-run onboardingu ze Settings s existujícími favorites → krok má je předzaškrtnuté → změnit → finish
   zapíše změnu.
5. iPhone SE: grid 12 emoji se vejde, nic se neořízne.

## Mimo scope

- **Plný katalog v onboardingu.** Výběr mimo těch 12 se dělá v Settings (Favorite emojis editor).
- **Favorites bar rendering / paging / sort.** Hotovo v taskách 44/49/51.
- **Migrace existujících `onboardingComplete == true` uživatelů** s prázdnými favorites (žádný backfill).
- **Region/locale-tuning setu** (např. 🇨🇿 default pro CZ) — případný samostatný task.
- **Min/max počet výběru.** Žádný limit; grid nabízí 12, vybrat lze 0–12.
- **Avízování fallbacku v UI** („vyber aspoň jeden" / „dosadíme za tebe") — fallback je tichý.

## Hotovo když

- `OnboardingStep` má `.pickFavorites` mezi `selectKeyboard` a `featureTour`; tečka v indikátoru přibyla automaticky.
- Nový krok ukazuje bespoke grid 12 emoji (`EmojiCatalog.defaultFavorites`), tap toggluje, checkmark drží stav.
- `selectKeyboard` vede na `pickFavorites`, ten (Continue i Skip) na `featureTour`; tour zůstává finišerem.
- `didFinishOnboarding()` zapíše `selected.isEmpty ? defaults12 : selected` přes `persistOnboardingFavorites`
  (+ notify) a pak `markOnboardingComplete()` — **favorites po onboardingu nikdy nejsou prázdné**.
- Re-run předvyplní `selectedFavorites` ze storu.
- Onboarding target má `KeyboardCore` dep; `EmojiCatalog.defaultFavorites` existuje; konzistenční test zelený.
- Unit testy (finish selection/fallback/pořadí, toggle, pre-fill) + nové/refreshnuté snapshoty zelené.
- Manuální verify (3 vybrané / skip→12 / continue→12 / re-run / iPhone SE) sedí.

## Rizika

- **Variation-selector mismatch.** Favorites se matchují přes glyph string. `❤️` (U+2764 U+FE0F) zapsané
  jinak než má `EmojiCatalog` by se v gridu „nenašlo" (checkmark by neseděl) a v baru by mohlo renderovat
  jinak. **Mitigace:** konstanta sdílená pro grid i fallback (jeden zdroj) + konzistenční unit test
  (scope 9) ⊆ katalogu.
- **Exhaustivní `switch` nad `OnboardingStep`.** Nový case může rozbít build. Plocha je malá (view používá
  tagy, VM explicitní přechody), ale ověřit:
  `grep -rn "case .addKeyboard\|case .selectKeyboard\|case .featureTour\|switch.*currentStep" --include="*.swift" Features/Onboarding Keymoji`.
- **iPhone SE layout.** 12 buněk + ikona + 2 tlačítka + footer na 320×568 je těsné. Grid musí být adaptivní
  a nesmí tlačit tlačítka mimo obrazovku — pokrýt SE snapshotem (scope 10), případně zmenšit ikonu/spacing
  na malém displeji.
- **Re-run a „odškrtání všeho".** Vracející se uživatel odškrtá vše → finish dosadí 12 (invariant nad
  očekáváním). Vědomé a žádoucí: favorites prostě nikdy nezůstanou prázdné. Žádná akce, jen poznámka.
- **Notify bez konzumenta.** Během onboardingu klávesnice typicky není aktivní → `notifier.post` je no-op.
  Neškodné; necháváme kvůli edge-case, kdy ji uživatel přidal už v kroku 1.

## Reference

- [tasks/11-host-app-onboarding.md](11-host-app-onboarding.md) — vznik onboarding flow + `@State` VM v RootView
- [tasks/38-onboarding-feature-tour.md](38-onboarding-feature-tour.md) — krok 4 (tour), vzor pro nový krok
- [tasks/18-favorite-emojis.md](18-favorite-emojis.md) — favorites editor + `AppGroupStore.favoriteEmojis`
- [tasks/44-favorite-emojis-in-suggestion-bar.md](44-favorite-emojis-in-suggestion-bar.md), [49](49-favorites-bar-tabview-paging.md), [51](51-favorites-bar-sort-by-frequency.md) — favorites bar (mimo scope, ale konzument)
- [Features/Onboarding/Sources/OnboardingView.swift](../Features/Onboarding/Sources/OnboardingView.swift) — Primary+Secondary vzor (krok 2)
- [Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift) — vzor buňky gridu (accent fill + checkmark)
- [KeyboardCore/Sources/Models/EmojiCatalog.swift](../KeyboardCore/Sources/Models/EmojiCatalog.swift) — kam přidat `defaultFavorites`

## Codex review

**Ano** — dotýká se persistence invariantu `favoriteEmojis` (nový writer mimo editor), onboarding completion
path a přidává case do `OnboardingStep`. Menší plocha než task 59, ale finish flow + tichý zápis defaultů
stojí za `codex review --uncommitted` před closing commitem.
