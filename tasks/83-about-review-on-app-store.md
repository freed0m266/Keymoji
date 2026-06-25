# 83 — About: „Review on App Store" řádek + icon restyle

**Status:** Todo — připraveno z grill session 2026-06-25.

**Priorita:** v1.x (App Store readiness — chybí CTA na recenzi) · **Úsilí:** XS (jeden řádek + URL + ikony, snapshot update) · **Dopad:** Low/Medium (recenze = ASO + social proof).

**Souvisí s:** [13 — About screen](13-about-and-privacy.md), [47 — App Store listing](47-app-store-listing.md). Dotýká se [`AboutView`](../Features/About/Sources/AboutView.swift), [`AboutViewModel`](../Features/About/Sources/AboutViewModel.swift), [`KeymojiURLs`](../KeymojiCore/Sources/Shared/KeymojiURLs.swift), [`ListButton`](../KeymojiUI/Sources/Views/ListButton.swift), [`Icon`](../KeymojiUI/Sources/Icons/Icon.swift), `L10n.About`.

## Kontext / proč

About má dnes jen `legalSection` se dvěma `ListButton` řádky bez ikon (*Full privacy policy*, *Contact support* — [AboutView.swift:70-83](../Features/About/Sources/AboutView.swift)). Chybí výzva k recenzi (důležité pro ASO i důvěru). Design reference (screenshot z cizí appky, 385 Sparks) ukazuje iOS-Settings styl s barevnými kruhovými dlaždicemi — ten **nepřebíráme**: Keymoji jede monochrom tint ikony (`ListButton` vykresluje `icon` přes `.tint`, [ListButton.swift:32-34](../KeymojiUI/Sources/Views/ListButton.swift)). `ListButton` ikony i caption už umí, jen je About nevolá.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Mechanismus recenze** | Přímý write-review odkaz `https://apps.apple.com/app/id6776134522?action=write-review`. **Ne** `SKStoreReviewController.requestReview` (Apple zakazuje vázat ho na tlačítko + rate-limit). |
| **Vzhled** | Varianta **C**: monochrom tint ikony na všech třech řádcích. Žádné barevné dlaždice ze screenshotu (drží Keymoji design systém, nezavádí novou komponentu). |
| **Struktura** | Dvě sekce: **Support / Feedback** (`⭐ star.fill` Review on App Store · `✉️ envelope.fill` Contact support) + **Legal** (`🛡 lock.shield` Full privacy policy + stávající copyright footer). |

## Scope

- [`KeymojiURLs`](../KeymojiCore/Sources/Shared/KeymojiURLs.swift): `static let appStoreReview = "https://apps.apple.com/app/id6776134522?action=write-review"`.
- [`AboutViewModel`](../Features/About/Sources/AboutViewModel.swift): `func openAppStoreReview()` (otevře `KeymojiURLs.appStoreReview` přes `UIApplication.shared.open`, stejný pattern jako `openPrivacyPolicy`). Přidat do `AboutViewModeling` protokolu + do `AboutViewModelMock`.
- [`AboutView`](../Features/About/Sources/AboutView.swift): rozdělit `legalSection` → `supportSection` (Review + Contact support) + `legalSection` (Full privacy policy, copyright footer). Doplnit `icon:` k `ListButton` voláním (`.starFill`, `Icon("envelope.fill")`, `.lockShield`).
- `Icon`: volitelně `static var envelopeFill: Icon = "envelope.fill"` (nebo literálem `Icon("envelope.fill")`).
- `L10n.About`: nový string `reviewOnAppStore`, header pro support sekci. (`star.fill`/`lock.shield` v `Icon` už jsou.)
- Snapshot: aktualizovat [`AboutSnapshots`](../Features/About/Tests/AboutSnapshots.swift) (re-record — memory *keymoji-snapshot-rerecord*).

## Non-goals

- `SKStoreReview` in-app prompt (ani jako doplněk).
- Barevné kruhové icon dlaždice ze screenshotu.
- Změna **defaultu** `ListButton` (mění se jen volání s `icon:`, ne komponenta — používá ji i Settings plusSection).

## Akceptační kritéria

- Tap na *Review on App Store* otevře App Store write-review composer (reálně až po App Store release; do té doby odkaz neotevře nic — to je OK).
- Tři řádky, každý s monochrom tint ikonou + chevronem; rozdělené do dvou sekcí dle Rozhodnutí.
- Snapshot dark prochází (re-recordnutý).

## Jak testovat (next session)

- Build/snapshoty přes **`Keymoji.xcworkspace`**, iPhone 17 / iOS 26.2 (memory *keymoji-build-uses-workspace*).
- Žádné nové `.swift` soubory (jen úpravy) → `tuist generate` netřeba, ale neuškodí.
- Pozn.: odkaz se ověří funkčně až po veřejném releasu (App ID 6776134522, memory *keymoji-app-store-connect*).
