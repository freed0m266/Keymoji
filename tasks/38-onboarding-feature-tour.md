# 38 — Onboarding feature tour: zmínit všechny zásadní funkce

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** M · **Dopad:** Medium (discovery zásadních fíčur, retention)

## Cíl

Rozšířit onboarding flow tak, aby po dokončení tří aktivačních kroků (přidat klávesnici, povolit Full Access, vybrat Keybo) uživatel uviděl krátký **feature tour** se všemi zásadními funkcionalitami, které Keybo má a které Apple stock klávesnice neumí nebo dělá jinak. Cílem je discovery — uživatel jinak fíčury sám nenajde, protože nejsou viditelné z layoutu (long-press, double-tap, Slack typing, trackpad mode atd.).

Zdroj pravdy o tom, co je „zásadní funkce", je [tasks/README.md](README.md). Před implementací projít aktuální stav a vybrat položky, které jsou (a) **Done**, (b) **user-facing** (uživatel je při psaní reálně potká) a (c) **non-obvious** (neuhádne je z UI).

## Kontext

- Onboarding dnes končí krokem 3 (Select Keybo). Po `didFinishOnboarding()` se schová a uživatel padá do main Settings screenu. Nikde se nedozví, že existují fíčury jako Slack-style `:smile:` typing, trackpad-on-space, double-tap-space dismiss nebo emoji favorites.
- Settings screen některé fíčury vystavuje jako toggle (sound, haptic, appearance, double-tap space action), ale to je „configuration view", ne „discovery". Uživatel který nikdy nesjede do Settings o nich neví.
- Existující onboarding bydlí v [Features/Onboarding/](Features/Onboarding/Sources/), 3-step `TabView` s `.page` style, `OnboardingStep` enum [Features/Onboarding/Sources/OnboardingStep.swift](Features/Onboarding/Sources/OnboardingStep.swift), strings v [KeyboResources/Resources/en.lproj/Localizable.strings](KeyboResources/Resources/en.lproj/Localizable.strings) pod prefixem `onboarding.*`.
- „Setup instructions" v hlavním Settings (task 11, scope #8) musí onboarding znovu spustit — po této změně musí proto umět i přeskočit feature tour, nebo ho ukázat zvlášť jako vlastní row.

## Scope

### 1. Projít [README.md](README.md) a vyrobit kanonický seznam „zásadních funkcí"

Před psaním copy projít `tasks/README.md` shora dolů. Pro každý task, který má status **Done** (zkontrolovat hlavičku jednotlivých task souborů), rozhodnout:

- **Patří do feature tour, pokud:** je viditelný uživateli při psaní, není odvoditelný z layoutu klávesnice a odlišuje Keybo od Apple stock.
- **Nepatří do feature tour, pokud:** je to interní implementace (scaffolding, refactor, modul split), bugfix/polish bez user-facing dopadu, nebo pre-App-Store hygiena (app icon).

Tento výběr **udělat při implementaci tasku** (ne v něm dopředu fixovat seznam — README se hýbe). Aktuální kandidáti (k 2026-05-28, jen jako vodítko, ne závazný seznam):

| Feature | Source task | Proč user-facing & non-obvious |
| --- | --- | --- |
| Long-press popover s diakritikou | [07](07-long-press-popover.md) | Bez vysvětlení uživatel nezkusí podržet `a` pro `á/à/â/ä/…` |
| Quick emoji key + system emoji picker | [17](17-emoji-key.md) | Vlastní klávesa na bottom row |
| Favorite emojis | [18](18-favorite-emojis.md), [32](32-favorites-show-shortcodes.md) | Customizace v Settings |
| Slack-style emoji typing (`:smile:` → 😄) | [19](19-slack-emoji-typing.md) | Killer feature, nikdo netuší dokud mu to neřekneme |
| Emoji codes reference | [20](20-emoji-codes-reference.md) | „Najdi si shortcode" screen v Settings |
| Trackpad mode (long-press space) | [23](23-trackpad-on-space.md) | Apple to umí taky, ale uživatel zvyklý ze SwiftKey nemusí vědět že to máme |
| Delete word-by-word (long hold) | [24](24-delete-word-by-word.md) | Speed-up oproti stock |
| Double-tap space → tečka / dismiss / nic | [36](36-space-double-tap-action.md) | Konfigurovatelné, dismiss je SwiftKey-only fíčura |
| Light/dark mode override | [16](16-light-dark-override.md) | Independent na systému |
| Haptic + key click sound toggle | [08](08-haptics-and-sound.md), [26](26-sound-feedback.md), [31](31-haptic-feedback-for-every-key.md) | Konfigurace v Settings |

**Cílit na ~5–7 položek, ne 10+.** Onboarding nesmí být wall of text. Pokud je kandidátů víc, sloučit příbuzné (např. „Haptika a zvuk se dají vypnout v Settings" jako jedna položka).

### 2. Datový model — `FeatureHighlight`

Nový soubor `Features/Onboarding/Sources/FeatureHighlight.swift`:

```swift
import Foundation

/// One item shown in the post-activation feature tour.
public struct FeatureHighlight: Sendable, Hashable, Identifiable {
    public let id: String
    public let symbol: String      // SF Symbol name
    public let title: String       // localized
    public let description: String // localized, 1–2 sentences

    public init(id: String, symbol: String, title: String, description: String) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.description = description
    }
}
```

Statický seznam highlightů držet v `FeatureHighlight.all` (computed `[FeatureHighlight]`) ve stejném souboru. Stringy přes `L10n.Onboarding.Tour.*`.

### 3. Rozšíření `OnboardingStep` enum

Přidat nový case `.featureTour` do [Features/Onboarding/Sources/OnboardingStep.swift](Features/Onboarding/Sources/OnboardingStep.swift):

```swift
public enum OnboardingStep: Sendable, Hashable, CaseIterable {
    case addKeyboard
    case allowFullAccess
    case selectKeyboard
    case featureTour
}
```

Pořadí v `allCases` (Swift autoderives podle declarations) určuje pořadí v `TabView` — `featureTour` musí být **poslední**.

### 4. `FeatureTourStepView`

Nový soubor `Features/Onboarding/Sources/FeatureTourStepView.swift`:

```swift
struct FeatureTourStepView<ViewModel: OnboardingViewModeling>: View {
    @State var viewModel: ViewModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Headline: "What Keybo can do"
            // ScrollView se seznamem FeatureHighlight řádků (Icon + title + description)
            // Primary CTA: "Start typing" → onFinish()
            // Secondary CTA: "Show this again later in Settings"
        }
    }
}
```

Layout per highlight row: SF Symbol vlevo (size ~28), nadpis bold, popisek `.subheadline.foregroundStyle(.secondary)`. Vertikální `ScrollView` — na iPhone SE se 7 položek nevejde, scroll je expected.

### 5. `OnboardingView` integrace

V [Features/Onboarding/Sources/OnboardingView.swift](Features/Onboarding/Sources/OnboardingView.swift) přidat čtvrtý tag do `TabView`:

```swift
FeatureTourStepView(viewModel: viewModel, onFinish: onFinish)
    .tag(OnboardingStep.featureTour)
```

`SelectKeyboardStepView.onFinish` přesměrovat — `Done` tlačítko místo `onFinish()` přepne na `currentStep = .featureTour`. Skutečné `onFinish()` (= zavřít onboarding + `didFinishOnboarding()`) volá až tlačítko v `FeatureTourStepView`.

### 6. `OnboardingViewModel` — žádná logika navíc

Tour je čistě presentational — žádný state machine, žádné detekce. `currentStep` už enum case zvládne, persistence onboarding completion zůstává na `didFinishOnboarding()` v posledním kroku (= tour CTA).

Edge case: pokud uživatel onboarding restartuje ze Settings („Setup instructions"), zobrazí se mu opět všechny 4 kroky včetně tour. Zvážit přidat parametr `OnboardingView(initialStep:)` aby šlo z Settings spustit přímo `featureTour` jako samostatný „What's in Keybo" prohlížeč. **Doporučení:** udělat to — v Settings dvě řádky:
- „Setup instructions" → `OnboardingView(initialStep: .addKeyboard)`
- „What Keybo can do" → `OnboardingView(initialStep: .featureTour)`

### 7. Lokalizace

Do `KeyboResources/Resources/en.lproj/Localizable.strings` přidat sekci:

```strings
"onboarding.tour.title" = "What Keybo can do";
"onboarding.tour.subtitle" = "A few things stock keyboards don't.";
"onboarding.tour.cta" = "Start typing";

"onboarding.tour.diacritics.title" = "Hold a letter for accents";
"onboarding.tour.diacritics.description" = "Press and hold any letter to pick from variants like á, ä, â.";

"onboarding.tour.slack.title" = "Type emoji by name";
"onboarding.tour.slack.description" = ":smile: turns into 😄 the moment you hit space. Customize your shortcodes in Settings.";

// ... další podle finálního seznamu z kroku 1
```

Po `tuist generate` se vygeneruje `L10n.Onboarding.Tour.Slack.title` atd. Použít.

### 8. Snapshot testy

Do [Features/Onboarding/Tests/](Features/Onboarding/Tests/) přidat nové snapshoty:

- `testOnboarding_featureTour_dark` (default content)
- `testOnboarding_featureTour_light`
- Případně `testOnboarding_featureTour_iPhoneSE` (overflow check — ScrollView funguje)

Existující `OnboardingViewModelMock` rozšířit o `currentStep: .featureTour` v initu.

### 9. Settings screen — nová row

V [Features/Settings/Sources/SettingsView.swift](Features/Settings/Sources/SettingsView.swift) přidat do existující „Help" / „About" sekce (jakkoli se aktuálně jmenuje) druhou row „What Keybo can do" který otevírá `OnboardingView(initialStep: .featureTour)` v sheetu. Vedle stávající „Setup instructions".

## Mimo scope

- **Animace / video / GIFy fíčur.** Static layout (SF Symbol + text) stačí pro v1.1. Custom animace = vlastní task.
- **Interaktivní onboarding** (zkus si long-press tady v appce). Nedělat — uživatel je v iOS Settings appce když to čte, custom interactive widget = overengineering.
- **Localizace mimo en.** Budoucí task pokud přijde druhý jazyk.
- **A/B testing pořadí highlightů** nebo measurement které mají highest engagement. Privacy claim = žádné telemetry.
- **„Don't show this again" toggle uvnitř tour.** Tour se ukáže max 2× — jednou v onboardingu, potom jen na explicit request ze Settings. Nepotřebuje opt-out.

## Hotovo když

- Po dokončení Step 3 (Done) onboarding NEZmizí, ale přepne na nový čtvrtý krok `featureTour`.
- Tour zobrazuje 5–7 položek dle výběru z kroku 1 scope.
- Každá položka má SF Symbol + lokalizovaný nadpis + popisek.
- ScrollView funguje na iPhone SE (overflow nezahazuje obsah).
- CTA „Start typing" zavolá `didFinishOnboarding()` a zavře onboarding.
- Settings screen má row „What Keybo can do" která otevírá tour samostatně (sheet, `initialStep: .featureTour`).
- Snapshot testy green (dark + light + SE width).
- Manuální test: full first-run flow projít, ověřit že tour je čitelný a CTA odešle do Settings.
- README.md v `tasks/` nebyl rozšířen — taskový seznam zůstává jako úložiště plánů, ne user-facing dokumentace.

## Rizika

- **Maintenance overhead** — pokud přibyde fíčura, někdo musí ručně rozšířit `FeatureHighlight.all` a strings. Mitigation: do checklistu při closing každého user-facing tasku přidat „zvážit zda zmínit v onboarding tour".
- **Wall-of-text** — pokud výběr v kroku 1 nezvládne self-discipline, tour se rozroste na 12 položek a nikdo to nepřečte. Mitigation: hard cap 7 položek, nadbytek shrnout („+ víc v Settings").
- **Onboarding restart** — pokud user dá Setup instructions ze Settings, neměl by být donucen znovu projít tour (kterou už viděl). Proto `initialStep:` parametr — Setup instructions otevírá `.addKeyboard`, „What Keybo can do" otevírá `.featureTour`. Dva entry pointy ze Settings.

## Reference

- Onboarding feature: [Features/Onboarding/Sources/](Features/Onboarding/Sources/)
- Existující strings: [KeyboResources/Resources/en.lproj/Localizable.strings](KeyboResources/Resources/en.lproj/Localizable.strings)
- Settings screen kam přidat row: [Features/Settings/Sources/SettingsView.swift](Features/Settings/Sources/SettingsView.swift)
- Zdroj kanonického seznamu fíčur: [tasks/README.md](README.md)

## Codex review

**Ano** — task se dotýká user-facing copy, navigation flow a persistence. Codex review chytí přehlédnuté lokalizační klíče, dead step navigation, missing snapshot variants.
