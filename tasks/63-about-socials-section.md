# 63 — About: sekce „Follow along" se socials (Instagram + Threads) + přerámování supportu

**Status:** Todo

**Priorita:** v1.x (pre-App-Store / polish) · **Úsilí:** S · **Dopad:** Low–Medium (vlastní propagace + jasnější routing: nápady/feedback → sítě, bugy → mail)

## Cíl

Přidat do [AboutView](../Features/About/Sources/AboutView.swift) **novou sekci „Follow along"** s odkazy na
osobní sítě (📸 Instagram, 🧵 Threads), umístěnou **hned pod header**. Sekce slouží k vlastní propagaci a
jako **osobnější, rychlejší kanál na nápady a feedback** („co v appce zlepšit / co přidat").

Zároveň **přerámovat stávající e-mailový řádek** „Contact support" → **„Report a problem"**, aby bylo jasné,
že mail je na **bugy / technické problémy**, kdežto nápady patří na sítě. Rozdělení je **explicitní, ale
lehkou rukou** — žádné zákazy, jen pozitivní rámec (intro u socials + výmluvnější popisek u mailu).

Po dokončení: otevřu About → hned pod logem/verzí je sekce „Follow along" se dvěma řádky; ťuknutí otevře
Instagram/Threads (nativní app, pokud je nainstalovaná, jinak prohlížeč); řádek u mailu se jmenuje
„Report a problem" a pořád otevře čistý `mailto:`.

## Kontext / klíčová zjištění z průzkumu kódu

- **AboutView je `Form` se třemi sekcemi.** `headerSection → privacySection → legalSection`
  ([AboutView.swift:27](../Features/About/Sources/AboutView.swift:27)). `legalSection`
  ([:70](../Features/About/Sources/AboutView.swift:70)) drží dva odkazové řádky (privacy policy +
  „Contact support") přes sdílený `chevronRow(title:action:)`
  ([:85](../Features/About/Sources/AboutView.swift:85)) + copyright ve `footer`.

- **`chevronRow` je přesně to, co recyklujeme.** `Button` → `HStack { Text(title); Spacer(); Icon.chevronRight }`.
  Nové socials řádky půjdou stejným builderem, jen s emoji-prefixovaným titulkem (vzor `"⭐️ …"` prefixu je
  z [SettingsView](../Features/Settings/Sources/SettingsView.swift)). **Žádná nová ikona do KeymojiUI** —
  chevron zůstává i pro externí odkazy (precedens: privacy policy i mail už dnes otevírají externě s chevronem).

- **Otevírání odkazů = `UIApplication.shared.open(url)` přímo ve VM.** `openPrivacyPolicy()` / `openSupportEmail()`
  ([AboutViewModel.swift:31–39](../Features/About/Sources/AboutViewModel.swift:31)) berou string z `KeymojiURLs`.
  Žádný centrální URLOpener service — držíme stejný vzor pro `openInstagram()` / `openThreads()`.

- **URL konstanty žijí v `KeymojiURLs`** ([KeymojiCore/.../KeymojiURLs.swift](../KeymojiCore/Sources/Shared/KeymojiURLs.swift)).
  `KeymojiCore` už je dep About targetu → **žádné Tuist změny**.

- **Lokalizace je flat, anglicky.** About klíče v
  [en.lproj/Localizable.strings:133–140](../KeymojiResources/Resources/en.lproj/Localizable.strings:133)
  (`about.title`, `about.support` = `"Contact support"`, …). Tuist generuje `L10n.About.*`; v AboutView
  alias `typealias Texts = L10n.About` ([AboutView.swift:17](../Features/About/Sources/AboutView.swift:17)).
  App je **English-only** (jediné `en.lproj`) → nové klíče taky jen EN.

- **Mock je triviální.** [AboutViewModelMock](../Features/About/Testing/AboutViewModelMock.swift) má dvě
  no-op metody → doplníme dvě další.

- **Snapshot je jeden:** `testAbout_dark` (393×852, dark)
  ([AboutSnapshots.swift](../Features/About/Tests/AboutSnapshots.swift)). Nová sekce ho změní → re-record.

### Rozhodnutí (z grillingu)

| Otázka | Rozhodnutí |
|---|---|
| Koncept | **Explicitní rozdělení, lehkou rukou.** Socials = nápady/feedback/propagace/osobní; mail = bugy/technické. Pozitivní rámec, žádné zákazy. |
| Platformy | **Jen Instagram + Threads.** Žádné X/TikTok/YouTube. |
| Prezentace řádků | **Emoji prefix** ve stejném stylu jako Settings (`📸 Instagram`, `🧵 Threads`). **Žádná brand loga / assety.** |
| Trailing ikona | **Chevron (recyklace `chevronRow`).** Žádná nová `arrow.up.right` ikona. Konzistence > formální správnost. |
| Formát odkazu | **Obyčejné `https://`.** iOS sám otevře nativní app, pokud je. Žádné `instagram://` deep linky s fallbackem. |
| URL | IG `https://www.instagram.com/zatim_bez_titulu/` · Threads `https://www.threads.com/@zatim_bez_titulu` (doména `.com` dle zadání). |
| Povaha účtu | **Osobní/tvůrčí** (ne brand appky) → copy v první osobě, osobní tón. |
| Umístění | **Hned pod header:** `header → connect → privacy → legal`. Viditelnost pro propagaci. |
| Support řádek | Přejmenovat **„Contact support" → „Report a problem"** (širší než „bug", stále jasně technické). |
| Mailto | **Čistý `mailto:`** beze změny — žádný `?subject=` prefill. `KeymojiURLs.supportEmail` se nemění. |
| Copy / tón | **Propagační.** Header sekce „Follow along"; pitch řádek směruje nápady na sítě (viz scope 4 — pozn. k redundanci). |
| Lokalizace | EN-only, flat klíče `about.*` (jako zbytek). |
| Codex review | **Volitelně** — malá plocha; rename klíče + nové URL stojí za rychlý průlet. |

## Scope

### 1. `KeymojiURLs` — dvě nové konstanty

[KeymojiCore/Sources/Shared/KeymojiURLs.swift](../KeymojiCore/Sources/Shared/KeymojiURLs.swift):

```swift
public enum KeymojiURLs {
	public static let privacyPolicy = "https://martinfreedom.com/keymoji/privacy.html"
	public static let supportEmail = "mailto:martin.svoboda026@gmail.com"   // beze změny
	public static let instagram = "https://www.instagram.com/zatim_bez_titulu/"
	public static let threads = "https://www.threads.com/@zatim_bez_titulu"
}
```

### 2. `AboutViewModeling` / `AboutViewModel` — dvě nové metody

[Features/About/Sources/AboutViewModel.swift](../Features/About/Sources/AboutViewModel.swift) — protokol +
impl, přesně podle vzoru `openSupportEmail()`:

```swift
@MainActor
public protocol AboutViewModeling: Observable, AnyObject {
	var versionString: String { get }
	func openPrivacyPolicy()
	func openSupportEmail()
	func openInstagram()   // ←
	func openThreads()     // ←
}
```

```swift
func openInstagram() {
	guard let url = URL(string: KeymojiURLs.instagram) else { return }
	UIApplication.shared.open(url)
}

func openThreads() {
	guard let url = URL(string: KeymojiURLs.threads) else { return }
	UIApplication.shared.open(url)
}
```

### 3. `AboutView` — nová `connectSection` + rename support řádku

[Features/About/Sources/AboutView.swift](../Features/About/Sources/AboutView.swift):

- **`body`** — vložit `connectSection` **mezi** `headerSection` a `privacySection`:

  ```swift
  Form {
  	headerSection
  	connectSection      // ← nový, hned pod header
  	privacySection
  	legalSection
  }
  ```

- **Nová `connectSection`** — recykluje `chevronRow`, header = title sekce, footer = pitch (viz pozn. níže):

  ```swift
  private var connectSection: some View {
  	Section {
  		chevronRow(title: Texts.instagram) {
  			viewModel.openInstagram()
  		}
  		chevronRow(title: Texts.threads) {
  			viewModel.openThreads()
  		}
  	} header: {
  		Text(Texts.connectHeader)
  	} footer: {
  		Text(Texts.connectFooter)
  	}
  }
  ```

- **`legalSection`** — přejmenovat referenci `Texts.support` → `Texts.reportProblem`
  ([AboutView.swift:75](../Features/About/Sources/AboutView.swift:75)). Header sekce „Legal & support"
  (`Texts.legalHeader`) **zůstává** — pořád sedí (privacy policy = legal, report a problem = support).

- **Accessibility (emoji prefix):** VoiceOver by `"📸 Instagram"` přečetl jako „camera Instagram". Na socials
  řádcích nastavit `.accessibilityLabel(Text("Instagram"))` / `"Threads"` (čistý název bez emoji). Bez
  nového parametru `chevronRow` to lze modifierem na výsledku volání, nebo přidat volitelný `accessibilityLabel:`
  param do `chevronRow` — implementační detail. Stávající řádky (privacy/report) nech beze změny.

### 4. Lokalizace

[KeymojiResources/.../en.lproj/Localizable.strings](../KeymojiResources/Resources/en.lproj/Localizable.strings)
(po přidání `tuist generate` přegeneruje `L10n.About.*`):

```
"about.connectHeader" = "Follow along";
"about.connectFooter" = "Tell me what to build next — I reply faster here.";
"about.instagram" = "📸 Instagram";
"about.threads" = "🧵 Threads";
```

A **změna existujícího klíče** (řádek 140) — přejmenovat klíč i hodnotu:

```
// bylo:  "about.support" = "Contact support";
"about.reportProblem" = "Report a problem";
```

> **Pozn. ke copy (rozhodnutí „Propagační"):** vybraná varianta z grillingu byla header „Follow along" +
> intro „Follow along and tell me what to build next." — „Follow along" se ale opakuje v headeru i pitchi.
> Výše navržené `connectFooter = "Tell me what to build next — I reply faster here."` redundanci odstraňuje
> a drží routing (nápady → sítě). **Finální znění je na Martinovi** — pokud chce přesně původní větu, klidně
> `"Follow along and tell me what to build next."`. Tón: osobní, první osoba.

> **Pozn. k rename klíče:** před změnou ověřit, že `about.support` / `Texts.support` nikde jinde nevisí:
> `grep -rn "about\.support\|Texts\.support\|About\.support" --include="*.swift" .` — průzkum našel jediný
> výskyt v AboutView. Pokud by byl víc, buď přejmenovat všechny, nebo nechat klíč `about.support` a změnit
> jen hodnotu na „Report a problem".

### 5. `AboutViewModelMock`

[Features/About/Testing/AboutViewModelMock.swift](../Features/About/Testing/AboutViewModelMock.swift) —
doplnit dvě no-op metody, ať jdou previews/snapshoty:

```swift
func openInstagram() {}
func openThreads() {}
```

### 6. Snapshot test

[Features/About/Tests/AboutSnapshots.swift](../Features/About/Tests/AboutSnapshots.swift) — nová sekce mění
layout, takže **re-record `testAbout_dark`**. Postup standardní: `record: true` → vizuální kontrola (sekce
„Follow along" sedí hned pod headerem, dva řádky, footer pitch; mail řádek = „Report a problem") →
`record: false` → green. Nový samostatný test netřeba — je to pořád jedna obrazovka.

### 7. Manuální verify

1. Otevřít About → hned pod logem/verzí sekce „Follow along" se dvěma řádky (📸 Instagram, 🧵 Threads) + pitch footer.
2. Ťuk Instagram → s nainstalovanou IG appkou se otevře nativně; bez ní v prohlížeči na `…/zatim_bez_titulu/`.
3. Ťuk Threads → analogicky `https://www.threads.com/@zatim_bez_titulu`.
4. Sekce „Legal & support" → řádek se jmenuje **„Report a problem"** a otevře čistý `mailto:` (předmět prázdný).
5. VoiceOver na socials řádcích čte „Instagram" / „Threads" (ne „camera Instagram").

## Mimo scope

- **Brand loga / asset katalog** pro IG/Threads. Zůstává emoji prefix.
- **Deep linky `instagram://` + fallback logika.** Obyčejné https stačí.
- **Další platformy** (X/Twitter, TikTok, YouTube, web). Případně samostatný task, až budou účty.
- **`?subject=` / `?body=` prefill u mailu.** Mail zůstává čistý `mailto:`.
- **Refactor `UIApplication.shared.open` do URLOpener service.** Držíme stávající přímý vzor.
- **Lokalizace do češtiny** — app je EN-only; mimo scope.
- **Změna `legalHeader` „Legal & support".** Pořád sedí, neměníme.

## Hotovo když

- `KeymojiURLs` má `instagram` + `threads`; `supportEmail` beze změny.
- `AboutViewModeling` má `openInstagram()` + `openThreads()`; impl otevírá přes `UIApplication.shared.open`.
- AboutView má `connectSection` **mezi** header a privacy; recykluje `chevronRow` (chevron, žádná nová ikona);
  řádky `📸 Instagram` / `🧵 Threads` s a11y labelem bez emoji.
- Support řádek se jmenuje „Report a problem" (`Texts.reportProblem`), pořád `mailto:` čistý.
- Nové L10n klíče (`connectHeader`, `connectFooter`, `instagram`, `threads`) + přejmenovaný `reportProblem`;
  `tuist generate` přegeneroval `L10n.About.*` a build je zelený.
- Mock má obě nové no-op metody; preview funguje.
- `testAbout_dark` re-recordnutý a zelený.
- Manuální verify (umístění sekce / otevření IG+Threads / „Report a problem" mailto / VoiceOver) sedí.

## Rizika

- **Rename klíče `about.support`.** Pokud na něj odkazuje víc míst než AboutView, build spadne. Mitigace:
  grep ze scope 4 před změnou; jinak nechat klíč a změnit jen hodnotu.
- **Threads doména `.com` vs `.net`.** Zadáno `threads.com` (Meta na ni redirectuje). Pokud by v budoucnu
  přestala fungovat, změna je jednořádková v `KeymojiURLs`.
- **Emoji prefix a VoiceOver.** Bez `accessibilityLabel` čte VoiceOver název emoji před textem — proto scope 3
  nastavuje čistý label.
- **Salesy dojem nahoře.** Sekce je hned pod headerem na jinak privacy-focused obrazovce. Mitigace: krátký
  pitch (footer), žádný hard-sell; ověřit subjektivně na re-recordnutém snapshotu.

## Reference

- [tasks/13-about-and-privacy.md](13-about-and-privacy.md) — vznik About screenu + `KeymojiURLs` + privacy policy
- [Features/About/Sources/AboutView.swift](../Features/About/Sources/AboutView.swift) — `chevronRow` vzor (recyklace)
- [Features/Settings/Sources/SettingsView.swift](../Features/Settings/Sources/SettingsView.swift) — `"⭐️ …"` emoji-prefix vzor řádku
- [KeymojiCore/Sources/Shared/KeymojiURLs.swift](../KeymojiCore/Sources/Shared/KeymojiURLs.swift) — kam přidat IG/Threads

## Codex review

**Volitelně.** Malá, převážně additivní plocha (dvě VM metody, dvě URL, jedna sekce, string změny). Jediné
„riziko" je rename klíče `about.support` → ověřitelné gripem. Pokud se task spojí s jiným, klidně bez review;
jinak rychlý `codex review --uncommitted` před closing commitem neuškodí.
