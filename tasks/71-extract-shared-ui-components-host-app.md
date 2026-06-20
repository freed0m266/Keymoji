# 71 — Refactor: extrahovat sdílené UI komponenty z host-app views do KeymojiUI

**Status:** Spec — připraveno z grill session 2026-06-20 (`/grill-with-docs`). Implementace v další session.

**Priorita:** Tech debt · **Úsilí:** M · **Dopad:** None (čistý refactor, žádná uživatelská změna)

**Souvisí s:** [33 — Feature module + VM refactor](33-feature-modules-and-vm-refactor.md) (předchozí čistý refactor, stejný „logika/UX se nemění" princip), **task 72** (sesterský refactor UI klávesnicové extension — `KeyboardUI` — vyčleněný do vlastního tasku, protože `KeyboardUI` je extension-only a nemůže importovat `KeymojiUI`).

## Souhrn

Host-app feature views (`Features/*/Sources/*View.swift`, importují `KeymojiUI`) obsahují hodně opakujícího se SwiftUI kódu — stejná emoji buňka ve dvou modulech, stejný hero text styl na ~10 místech, stejná chevron disclosure row, stejná upsell card row dvakrát v jednom souboru. Task to extrahuje do **sdílených `public` komponent a modifierů v `KeymojiUI`** a přepojí call sites.

**Žádná změna logiky ani UI.** Pouze přesun opakujícího se view kódu do znovupoužitelných primitiv. Žádné nové stringy, žádné L10n renamy, žádné API změny ViewModelů.

## Železná pravidla (zafixovaná z grill session 2026-06-20)

1. **Pixel-perfect preservation.** Komponenta musí reprodukovat **každý** call site byte-for-byte. Tam, kde se dnešní call sites liší v drobnosti (glyph 30 vs 28 pt, chevron weight `.bold` vs `.semibold`), se ten rozdíl stává **parametrem** komponenty — **nikdy** se vzhled nesjednocuje. Sjednotit nekonzistenci = změna UI = mimo scope (případně samostatný design task).
2. **Pokud by komponenta byla skoro jen samé parametry** bez reálné sdílené hodnoty, **neextrahuje se** — nechá se duplikovaná a doplní se poznámka proč (viz [Co se NEextrahuje](#co-se-neextrahuje-záměrně)).
3. **Soubory samotných obrazovek zůstávají netknuté jako soubory.** Žádný `*View+Sections.swift` / `*View+Steps.swift` split. Jediná změna uvnitř screen views: inline snippet → volání nové komponenty. (Přehlednost „více souborů" přichází z nových komponentových souborů v `KeymojiUI`, ne z krájení obrazovek.)
4. **Regrese se hlídá existujícími feature snapshoty** — žádný nový `KeymojiUI` test target. Důkaz nulové UI změny = všechny feature snapshot suites projdou **beze změny obrázků**.

## Co se extrahuje (firm set)

Všechny nové komponenty jsou `public struct ... : View` s `public init`, žijí v `KeymojiUI/Sources/Views/` vedle [PrimaryButton.swift](../KeymojiUI/Sources/Views/PrimaryButton.swift) / [SecondaryButton.swift](../KeymojiUI/Sources/Views/SecondaryButton.swift). Modifiery jdou do [View+Extensions.swift](../KeymojiUI/Sources/Extensions/View+Extensions.swift) (nebo sourozeneckého `View+TextStyles.swift`). Každá komponenta dostane `#Preview` (dev-only, ne snapshot target).

| # | Komponenta | Reprodukuje (call sites) | Parametry (rozdíly mezi sites) |
|---|---|---|---|
| 1 | **`EmojiSelectableCell`** | `OnboardingView.favoriteCell` ([:276-307](../Features/Onboarding/Sources/OnboardingView.swift:276)) + `EmojiCatalogPickerView.cell` ([:102-130](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift:102)) | `glyphSize` (**30** Onboarding vs **28** Picker) |
| 2 | **`GlassEmojiBadge`** | `OnboardingView` ⭐️ ([:165-168](../Features/Onboarding/Sources/OnboardingView.swift:165)) + `PaywallView.header` ✨ ([:85-88](../Features/Paywall/Sources/PaywallView.swift:85)) | `emoji`, `fontSize` (48/52), `tileSize` (94/96) |
| 3 | **`ChevronDisclosureRow`** | `AboutView.chevronRow` ([:85-98](../Features/About/Sources/AboutView.swift:85)) + `SettingsView.plusRowChevronLabel` ([:117-127](../Features/Settings/Sources/SettingsView.swift:117)) | `chevronWeight` (**`.semibold`** About vs **`.bold`** Settings) |
| 4 | **`UpsellCardRow`** | `FavoriteEmojisEditorView.lossAversionBanner` ([:163-186](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift:163)) + `.upsellRow` ([:188-211](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift:188)) | `title`, `caption`, `onTap` (ikona vždy `.starCircleFill`) |
| 5 | **Hero text modifiery** | viz [Scope §5](#5-hero-text-modifiery--viewextensions) — Onboarding kroky + Paywall | — (jen modifier chain) |
| 6 | **`Icon.heroIcon()`** | `OnboardingView` 3 kroky ([:61](../Features/Onboarding/Sources/OnboardingView.swift:61), [:92](../Features/Onboarding/Sources/OnboardingView.swift:92), [:127](../Features/Onboarding/Sources/OnboardingView.swift:127)) | `size` (default 90) |

## Co se NEextrahuje (záměrně)

Necháno duplikované, protože sdílená komponenta by byla skoro jen parametry (pravidlo 2):

- **Bottom toast capsule** — `SettingsView.welcomeToastView` ([:142-153](../Features/Settings/Sources/SettingsView.swift:142), `.regularMaterial`, `subheadline`) vs `EmojiCodesView.toast` ([:84-94](../Features/EmojiCodes/Sources/EmojiCodesView.swift:84), `Color.black.opacity(0.85)`, `callout.weight(.medium)`, bílý text). Liší se fill, font i barva textu — komponenta by byla samé parametry. (Navíc různý sémantický smysl: Welcome-trial potvrzení vs copy-confirm.)
- **Leading-emoji list row** — `FavoriteEmojisEditorView.row` ([:213-237](../Features/FavoriteEmojisEditor/Sources/FavoriteEmojisEditorView.swift:213)) vs `EmojiCodesView.row` ([:64-78](../Features/EmojiCodes/Sources/EmojiCodesView.swift:64)). Sdílí jen 3 řádky leading emoji (`Text(emoji).font(.system(size: 28)).frame(width: 40, alignment: .center)`), pak se rozchází (name/shortcode vs shortcode + copy ikona). Extrakce by ušetřila ~nic a přidala indirection.
- **Benefit / highlight icon-row** — `PaywallView.benefitRow` ([:110-121](../Features/Paywall/Sources/PaywallView.swift:110), icon + text) vs `OnboardingView.highlightRow` ([:359-376](../Features/Onboarding/Sources/OnboardingView.swift:359), icon + title + description). Strukturálně odlišné (highlightRow má dvouřádkový VStack) — sloučení by přidalo větvení.

## Scope

### 1. `EmojiSelectableCell` (nový `KeymojiUI/Sources/Views/EmojiSelectableCell.swift`)

Toggleovatelná emoji buňka: selected pozadí + checkmark badge top-trailing + dim/disable + a11y. Obě dnešní implementace jsou identické až na `glyphSize`.

```swift
public struct EmojiSelectableCell: View {
    let glyph: String
    let isSelected: Bool
    let isDimmed: Bool
    let glyphSize: CGFloat
    let onTap: () -> Void

    public init(glyph: String, isSelected: Bool, isDimmed: Bool, glyphSize: CGFloat, onTap: @escaping () -> Void) { ... }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Text(glyph)
                    .font(.system(size: glyphSize))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                if isSelected {
                    Icon.checkmarkCircleFill
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor, Color(.systemBackground))
                        .padding(2)
                }
            }
            .contentShape(.rect)
            .opacity(isDimmed ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDimmed)
        .accessibilityLabel(glyph)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
```

- Výška buňky **52** je v obou call sites stejná → konstanta v komponentě (ne parametr).
- Picker dnes používá `Image(systemName: "checkmark.circle.fill")`; komponenta sjednocuje na `Icon.checkmarkCircleFill` (design-system wrapper) — renderuje **identický** SF Symbol (`Icon.body` == `Image(systemName:)`). Ověřit snapshotem Pickeru.

Call site změny:
- **`OnboardingView.favoriteCell`** → smazat privátní `func favoriteCell`, v gridu ([:184](../Features/Onboarding/Sources/OnboardingView.swift:184)) volat:
  ```swift
  EmojiSelectableCell(
      glyph: glyph,
      isSelected: viewModel.selectedFavorites.contains(glyph),
      isDimmed: !viewModel.selectedFavorites.contains(glyph) && !viewModel.canSelectMoreFavorites,
      glyphSize: 30,
      onTap: { viewModel.toggleFavorite(glyph) }
  )
  ```
- **`EmojiCatalogPickerView.cell`** → smazat privátní `func cell`, ve gridu ([:55](../Features/EmojiCatalogPicker/Sources/EmojiCatalogPickerView.swift:55)) volat:
  ```swift
  EmojiSelectableCell(
      glyph: emoji.glyph,
      isSelected: selectedEmojis.contains(emoji.glyph),
      isDimmed: isBeyondLimit(isSelected: selectedEmojis.contains(emoji.glyph)),
      glyphSize: Self.glyphSize,   // = 28
      onTap: { onToggle(emoji.glyph) }
  )
  ```
  - **Přidat `import KeymojiUI`** do `EmojiCatalogPickerView.swift` (Tuist dep `design` už [v manifestu je](../Tuist/ProjectDescriptionHelpers/Targets/Features/EmojiCatalogPicker.swift)).
  - Lokální `isBeyondLimit(isSelected:)` zůstává (volá se pro `isDimmed`). Konstanty `glyphSize`/`cellHeight` — `glyphSize` se předává dál; `cellHeight` po extrakci nepoužitá → smazat.

### 2. `GlassEmojiBadge` (nový `KeymojiUI/Sources/Views/GlassEmojiBadge.swift`)

Emoji v glass „tile" hero. Pozn.: Liquid Glass se snapshotuje jen v host-app kontextu — feature suites to hostují správně (viz [Feature.swift `BUNDLE_LOADER` komentář](../Tuist/ProjectDescriptionHelpers/Targets/Feature.swift)).

```swift
public struct GlassEmojiBadge: View {
    let emoji: String
    let fontSize: CGFloat
    let tileSize: CGFloat
    public init(emoji: String, fontSize: CGFloat, tileSize: CGFloat) { ... }
    public var body: some View {
        Text(emoji)
            .font(.system(size: fontSize))
            .frame(width: tileSize, height: tileSize)
            .glassEffect()
    }
}
```

Call sites:
- `OnboardingView` pickFavorites ([:165](../Features/Onboarding/Sources/OnboardingView.swift:165)) → `GlassEmojiBadge(emoji: "⭐️", fontSize: 48, tileSize: 94)`.
- `PaywallView.header` ([:85](../Features/Paywall/Sources/PaywallView.swift:85)) → `GlassEmojiBadge(emoji: "✨", fontSize: 52, tileSize: 96)`.
- **Nepřevádět** `PaywallView.successState` 🎉 ([:202-203](../Features/Paywall/Sources/PaywallView.swift:202)) — to je holé `Text("🎉").font(.system(size: 72))` **bez** glass tile.

### 3. `ChevronDisclosureRow` (nový `KeymojiUI/Sources/Views/ChevronDisclosureRow.swift`)

Label část disclosure řádku (text vlevo + chevron vpravo). Používá se uvnitř `Button` na obou call sites.

```swift
public struct ChevronDisclosureRow: View {
    let title: String
    let chevronWeight: Font.Weight
    public init(title: String, chevronWeight: Font.Weight = .semibold) { ... }
    public var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Icon.chevronRight
                .font(.footnote.weight(chevronWeight))
                .foregroundStyle(.tertiary)
        }
    }
}
```

Call sites:
- **`AboutView.chevronRow`** → smazat privátní `func chevronRow`, v `legalSection` ([:72-77](../Features/About/Sources/AboutView.swift:72)) obalit přímo: `Button(action: { viewModel.openPrivacyPolicy() }) { ChevronDisclosureRow(title: Texts.privacyPolicyLink) }` (weight default `.semibold`).
  - ⚠️ About dnes mezi text a chevron dává `Spacer()`; komponenta používá `frame(maxWidth: .infinity, alignment: .leading)` na Textu. Layout je identický (oba roztáhnou na plnou šířku). **Ověřit `AboutSnapshots`.**
- **`SettingsView.plusRowChevronLabel`** → nahradit tělo funkce `ChevronDisclosureRow(title: text, chevronWeight: .bold)`. Settings dnes používá `.maxWidthLeading()` (BaseKitX) == `frame(maxWidth: .infinity, alignment: .leading)`, takže pixel-identické. (Lze i smazat helper a volat komponentu přímo na obou call sites `plusRowChevronLabel(...)` — [:88](../Features/Settings/Sources/SettingsView.swift:88), [:100](../Features/Settings/Sources/SettingsView.swift:100).)

### 4. `UpsellCardRow` (nový `KeymojiUI/Sources/Views/UpsellCardRow.swift`)

Dvě skoro identické upsell karty v jednom souboru (loss-aversion banner + over-limit upsell).

```swift
public struct UpsellCardRow: View {
    let title: String
    let caption: String
    let icon: Icon
    let onTap: () -> Void
    public init(title: String, caption: String, icon: Icon = .starCircleFill, onTap: @escaping () -> Void) { ... }
    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Icon.chevronRight
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
```

- Pozn.: `icon.font(.system(size: 26))` zrcadlí dnešní `Icon.starCircleFill.font(.system(size: 26))` (font-based sizing na `Icon`, **ne** `Icon.size(_:)`).

Call sites (`FavoriteEmojisEditorView`, už importuje `KeymojiUI`):
- `lossAversionBanner` → `UpsellCardRow(title: Texts.LossAversion.title, caption: Texts.LossAversion.body(viewModel.lossAversionExtraCount), onTap: { viewModel.requestPaywall(.afterTrial) })`.
- `upsellRow` → `UpsellCardRow(title: Texts.limitTitle, caption: Texts.limitCaption(viewModel.favorites.count, viewModel.freeFavoritesLimit), onTap: { viewModel.requestPaywall(.favoritesLimit) })`.

### 5. Hero text modifiery (`View+Extensions.swift`)

Tři centrované text styly. Modifier **nezahrnuje** `.padding(...)` — to si call site drží sám (paddingy se mezi sites liší).

```swift
public extension View {
    func heroTitle() -> some View {
        font(.title2.weight(.bold)).multilineTextAlignment(.center)
    }
    func heroDescription() -> some View {
        font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    func heroFootnote() -> some View {
        font(.footnote).foregroundStyle(.tertiary).multilineTextAlignment(.center)
    }
}
```

Převést **jen** call sites, jejichž modifier chain odpovídá **přesně**:
- `heroTitle()`: Onboarding Step1/Step2/Step3 title ([:65](../Features/Onboarding/Sources/OnboardingView.swift:65), [:96](../Features/Onboarding/Sources/OnboardingView.swift:96), [:131](../Features/Onboarding/Sources/OnboardingView.swift:131)), Favorites title ([:170](../Features/Onboarding/Sources/OnboardingView.swift:170)), Paywall `headline` ([:90](../Features/Paywall/Sources/PaywallView.swift:90)).
- `heroDescription()`: Onboarding Step1/2/3 description, Favorites description, Paywall header subtitle ([:94](../Features/Paywall/Sources/PaywallView.swift:94)), Paywall success body ([:207](../Features/Paywall/Sources/PaywallView.swift:207)).
- `heroFootnote()`: Onboarding Step3 footer ([:148](../Features/Onboarding/Sources/OnboardingView.swift:148)), Favorites footer ([:204](../Features/Onboarding/Sources/OnboardingView.swift:204)), Tour footer ([:336](../Features/Onboarding/Sources/OnboardingView.swift:336)).

**Nepřevádět** (chain se liší — jinak by to byla změna UI):
- `PaywallView.successState` title ([:204-205](../Features/Paywall/Sources/PaywallView.swift:204)) — je `.title` (ne `.title2`).
- `PaywallView.reassurance` ([:123-134](../Features/Paywall/Sources/PaywallView.swift:123)) — alignment řeší rodičovský VStack, první řádek má `.weight(.medium)`; per-Text chain neodpovídá. Nechat inline.

### 6. `Icon.heroIcon()` (rozšířit `KeymojiUI/Sources/Icons/Icon.swift`)

```swift
public extension Icon {
    func heroIcon(size: CGFloat = 90) -> some View {
        self.size(size).foregroundStyle(.tint)
    }
}
```

Call sites (Onboarding): `Icon.keyboardBadgeEye.heroIcon()` ([:61](../Features/Onboarding/Sources/OnboardingView.swift:61)), `Icon.lockShield.heroIcon()` ([:92](../Features/Onboarding/Sources/OnboardingView.swift:92)), `Icon.globe.heroIcon()` ([:127](../Features/Onboarding/Sources/OnboardingView.swift:127)).

### 7. README

Přidat task 71 do [tasks/README.md](README.md) do sekce **Tech debt / Refactoring** vedle tasku 33.

## Hotovo když

**Komponenty:**
- Nové soubory: `KeymojiUI/Sources/Views/{EmojiSelectableCell,GlassEmojiBadge,ChevronDisclosureRow,UpsellCardRow}.swift`, hero modifiery ve `View+Extensions.swift`, `Icon.heroIcon()` v `Icon.swift`. Všechny `public` + `#Preview`.
- `EmojiCatalogPickerView.swift` má `import KeymojiUI`.

**Call sites přepojené & duplicita pryč:**
- `grep -n "func favoriteCell\|func cell" Features/Onboarding Features/EmojiCatalogPicker` → pryč (sloučeno do `EmojiSelectableCell`).
- `lossAversionBanner` i `upsellRow` používají `UpsellCardRow`.
- `chevronRow` / `plusRowChevronLabel` používají `ChevronDisclosureRow`.
- Onboarding/Paywall glass hero používá `GlassEmojiBadge`; Onboarding 3 ikony `Icon.heroIcon()`; hero texty `heroTitle/Description/Footnote()`.

**Důkaz nulové UI změny (klíčové):**
- **Všechny** existující feature snapshot suites projdou **beze změny obrázků**: `Settings`, `Onboarding`, `Paywall`, `FavoriteEmojisEditor`, `EmojiCatalogPicker`, `About`, `EmojiCodes`, `LearnedWordsEditor`. Žádný re-record.
- `tuist generate` bez warningu, Xcode build zelený (na [Keymoji.xcworkspace](../README.md), iPhone 17 / iOS 26.2 sim — viz [keymoji-build-uses-workspace memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keymoji-build-uses-workspace.md)).
- Manuální smoke test: onboarding flow (5 kroků), paywall (3 stavy), favorites editor (upsell + loss-aversion), About legal řádky, Settings Plus řádek — vizuálně identické.

## Mimo scope

- **Keyboard extension UI (`KeyboardUI`)** — vlastní task 72 (extension-only, nemůže importovat `KeymojiUI`).
- **Splitnout soubory obrazovek** (`OnboardingView`, `SettingsView`, `FavoriteEmojisEditorView`) na `+Sections`/`+Steps`. Záměrně ne — soubory zůstávají, jen se z nich volají komponenty.
- **Sjednocovat vizuální nekonzistence** (chevron weight, toast styl, glyph size). Zůstávají jako parametry / duplikáty — to je samostatný design task, ne tento refactor.
- **Extrahovat „leave" set** (toast, leading-emoji list row, benefit/highlight row) — viz [Co se NEextrahuje](#co-se-neextrahuje-záměrně).
- **L10n / stringy / ViewModely / logika** — beze změny.
- **`KeymojiUI` snapshot test target** — neděláme; regresi hlídají feature suites.
- **Debug menu** (`DebugMenuView`, DEBUG-only) — neřešit.
- **`CONTEXT.md`** — žádná aktualizace; tyhle komponenty jsou implementační detail, ne doménový slovník.

## Codex review

**Ano** — task se dotýká ~7 view souborů a přepojuje desítky call sites s tvrdým „pixel-perfect" požadavkem. Failure modes (subtilní pohyb paddingu/alignmentu při převodu na komponentu, záměna `.title`/`.title2`, redundantní modifier měnící layout) jsou přesně to, co snapshot diff i druhý pár očí chytí.

## Reference

- [33 — Feature module + VM refactor](33-feature-modules-and-vm-refactor.md) — předchozí „logika se nemění" refactor, vzor struktury tasku.
- [KeymojiUI/Sources/Views/PrimaryButton.swift](../KeymojiUI/Sources/Views/PrimaryButton.swift) — vzor `public` komponenty (init, `#Preview`).
- [KeymojiUI/Sources/Extensions/View+Extensions.swift](../KeymojiUI/Sources/Extensions/View+Extensions.swift) — vzor `public` view modifieru.
- [KeymojiUI/Sources/Icons/Icon.swift](../KeymojiUI/Sources/Icons/Icon.swift) — `Icon.size(_:)`, sem přidat `heroIcon()`.
