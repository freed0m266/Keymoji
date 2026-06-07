# 53 — Probliknutí klávesnice na max výšku při přepnutí

**Status:** Todo

**Priorita:** v1.2 · **Úsilí:** S–M · **Dopad:** Medium

## Cíl

Při přepínání mezi Keymoji a nativní klávesnicí (globe / výběr klávesnic) **na pár milisekund problikne
Keymoji na maximální výšce**, než se srovná na výšku, kterou opravdu potřebuje (viz screenshot v
grill-me session — klávesnice vyplní skoro celý spodek obrazovky). Vypadá to rozbitě. **Zjistit příčinu
a opravit**, aby se klávesnice objevila rovnou ve správné výšce bez záblesku.

> Toto je **investigativní** task — root cause není potvrzená, jen hypotézy níže. První krok je
> reprodukce + diagnóza, teprve pak fix.

## Kontext

### Jak se výška dnes nastavuje

- **`KeymojiInputView`** se vytváří v `loadView()` s `inputViewStyle: .keyboard`
  ([KeyboardViewController.swift:61-63](KeyboardExtension/Sources/KeyboardViewController.swift:61)).
- **Height constraint se instaluje až ve `viewDidLoad`** přes `installKeyboardHeightConstraint()`
  ([:70](KeyboardExtension/Sources/KeyboardViewController.swift:70), [:392-400](KeyboardExtension/Sources/KeyboardViewController.swift:392)):

```swift
let constraint = view.heightAnchor.constraint(equalToConstant: desiredKeyboardHeight())
// `.required - 1`: vysoká, ale ne required, aby ji systém mohl přebít při dismiss animacích.
constraint.priority = UILayoutPriority(rawValue: UILayoutPriority.required.rawValue - 1)
constraint.isActive = true
```

- `desiredKeyboardHeight()` čte `state` (showNumberRow, page, showsSuggestionBar)
  ([:411-420](KeyboardExtension/Sources/KeyboardViewController.swift:411)).
- **`viewWillAppear`** ([:108-118](KeyboardExtension/Sources/KeyboardViewController.swift:108)) volá
  `refreshFromStore()` + spol. → může změnit `state` → `rebuild()` → `updateKeyboardHeightConstraint()`
  ([:402-409](KeyboardExtension/Sources/KeyboardViewController.swift:402)), který přepíše `constraint.constant`
  a zavolá `setNeedsLayout()`.
- **`viewDidLayoutSubviews`** ([:129-139](KeyboardExtension/Sources/KeyboardViewController.swift:129)) čte
  `view.bounds.width` a při změně dělá další `rebuild()`.

### Hypotézy příčiny (ověřit, ne brát jako fakt)

1. **Constraint se aktivuje moc pozdě.** Mezi vytvořením input view (`loadView`) a `viewDidLoad`/první
   layout pass iOS zobrazí input view ve **své default (vysoké) výšce**, než náš constraint vyhraje.
   Při *přepínání* klávesnic systém input view recykluje a během přechodové animace mu dá plnou výšku.
2. **Hosting controller self-sizing.** SwiftUI hosting controller (`UIHostingController<KeyboardRoot>`)
   může hlásit velkou `intrinsicContentSize`/sizing, dokud se `KeyboardView.frame(height:)` neustálí —
   na okamžik přetlačí náš constraint.
3. **Priorita `required - 1`** dovolí systému během přechodu prosadit vlastní (max) výšku; možná chce
   vyšší prioritu nebo druhý constraint.
4. **Constraint.constant je při instalaci špatný.** Ve `viewDidLoad` ještě nemusí být `state` načtený ze
   store → `desiredKeyboardHeight()` vrátí default, který se pak ve `viewWillAppear` opraví → viditelný
   skok. (Záblesk je ale na **max** výšku, vyšší než jakýkoli náš default → spíš hypotéza 1/2 než tahle.)

### Souvislost s taskem 52

Task [52](52-key-sizing-bottom-up-refactor.md) přepisuje **jak se výška počítá** (`KeyboardMetrics`) a
**jak se constraint nastavuje** (`desiredKeyboardHeight` přes sdílenou funkci). Tenhle task řeší
**časování a prioritu** téhož constraintu. Jsou nezávislé, ale dělají-li se po sobě, je rozumné **52
napřed** (ustálí výpočet), pak 53 na čistém základu. Pokud se dělá 53 první, počítat s tím, že 52 ten
kód ještě sáhne.

## Scope

### 1. Reprodukce + diagnóza (nejdřív)

- Reprodukovat na zařízení: přepnout z nativní klávesnice na Keymoji (globe long-press / výběr) a
  sledovat záblesk. Zkusit i cold start vs warm switch.
- Instrumentovat výšku v čase: zalogovat (nebo přes Xcode View Debugger / `CADisplayLink`) `view.bounds.height`
  a `constraint.constant` v `loadView` / `viewDidLoad` / `viewWillAppear` / `viewDidLayoutSubviews` /
  `viewDidAppear`. Zjistit, **kdy** je výška maximální a **co** ji v ten okamžik drží (náš constraint vs
  systém vs hosting controller).
- Potvrdit/vyvrátit hypotézy 1–4 výše. Diagnóza rozhodne o fixu — možnosti níže jsou *kandidáti*.

### 2. Kandidátní fixy (vybrat podle diagnózy)

- **Instalovat constraint dřív** — v `loadView()` hned po vytvoření `view`, nebo v `updateViewConstraints()`,
  ať existuje před prvním layout passem (hypotéza 1).
- **Pinovat hosting controller view** na input view se správnými prioritami / `setContentHugging` +
  `setContentCompressionResistance`, aby SwiftUI obsah nediktoval dočasně velkou výšku (hypotéza 2).
- **Zvýšit prioritu** height constraintu (nebo přidat druhý `required` constraint na konečnou výšku a
  nechat `required-1` jen pro animace) — opatrně, aby nevznikly auto-layout výjimky při swipe-down dismiss
  (existující komentář u priority). Křížově ověřit s taskem [29](29-swipe-down-dismiss-jank.md).
- **Nastavit `constraint.constant` na správnou hodnotu co nejdřív** (po načtení store, ideálně před
  prvním viditelným snímkem), ať nedojde k default→správná skoku (hypotéza 4).
- Zvážit `inputView?.allowsSelfSizing` chování a `translatesAutoresizingMaskIntoConstraints` na obou
  view (input view i hosting controller view).

### 3. Ověření

- Žádný viditelný záblesk při přepnutí ani při cold startu — klávesnice najede rovnou na cílovou výšku.
- Swipe-down dismiss ([29](29-swipe-down-dismiss-jank.md)) pořád plynulý, **žádné auto-layout výjimky**
  v konzoli.
- Přepínání letters ↔ symbols (jiná total výška, task 52) bez záblesku.
- Otestovat na víc velikostech zařízení (malý / velký iPhone), protože „max výška" je relativní k displeji.

## Mimo scope

- **Refaktor výpočtu výšky / jedna konstanta** → task [52](52-key-sizing-bottom-up-refactor.md).
- **Animace přechodu mezi klávesnicemi** nad rámec odstranění záblesku — neladit systémovou transition.
- **Swipe-down dismiss jank** sám o sobě (task 29) — jen neregresovat.

## Hotovo když

- Při přepnutí z nativní klávesnice na Keymoji (i při cold startu) se **neobjeví žádný záblesk** na
  maximální výšce — klávesnice najede rovnou ve správné výšce.
- Příčina je v tasku **doložená** (ne jen „zmizelo to") — víme, proč to bylo a proč fix funguje.
- Žádné nové auto-layout výjimky; swipe-down dismiss zůstává plynulý.
- Ověřeno na malém i velkém iPhonu.

## Rizika

- **Auto-layout výjimky.** Zvýšení priority nebo druhý constraint může kolidovat se systémovou
  height-animací (swipe-down) → konzole plná `Unable to simultaneously satisfy constraints`. Existující
  `required - 1` byla zvolená právě proto — měnit obezřetně.
- **Těžká reprodukce.** Záblesk trvá pár ms a může být citlivý na warm/cold stav, rychlost přepnutí,
  zařízení. Bez spolehlivé reprodukce hrozí „opravím něco, co nebyl root cause". Proto diagnóza první.
- **Závislost na 52.** Pokud se 52 udělá potom, sáhne to do `desiredKeyboardHeight` / instalace
  constraintu a může fix rozhodit — koordinovat pořadí.

## Reference

- [52 — Refaktor výšky/šířky kláves (zdola nahoru)](52-key-sizing-bottom-up-refactor.md) — sdílený height
  constraint, dělat ideálně napřed.
- [29 — Plynulý swipe-down dismiss klávesnice](29-swipe-down-dismiss-jank.md) — proč je priorita
  `required - 1`; neregresovat.
- Apple Custom Keyboard Programming Guide: <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Keyboard.html>
