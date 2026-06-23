# 75 — Trackpad-on-space: aktivace časem (350 ms hold) + prázdné klávesy (native parita)

**Status:** Spec — připraveno z grill session 2026-06-23 (`/grill-with-docs`). Implementace v další session.

**Priorita:** v1.1 (UX/UI refinement, native parita) · **Úsilí:** M · **Dopad:** Medium-High (každodenní gesto — space-hold scrubbing; přiblížení loved native featury tak, aby působila nativně)

**Závisí na:** task 23 (trackpad existuje) + task 69 (2D scrubbing) — oboje Done. Žádné nové dependencies, žádné nové API, žádná změna modelů.

## Kontext

Trackpad na long-press space (cursor scrubbing) dnes neodpovídá native iOS klávesnici ve dvou bodech (potvrzeno screenshoty z beta zařízení):

| | Native iOS keyboard | Keymoji dnes |
|---|---|---|
| **Aktivace** | Podržím prst na space → po **350 ms** přijde haptic + symboly zmizí + klávesy lehce změní odstín + trackpad aktivní. **Bez nutnosti tahu.** | Reaguje **jen na drag**: po 300 ms se trackpad jen *„armed"* (nic vidět), teprve tah ≥ 6 pt ho zapne. |
| **Vizuál** | Glyfy kláves **zmizí úplně** (prázdné klávesy), těla kláves zůstanou, pozadí lehce změní odstín. | Celá klávesnice (i s pozadími kláves **i horním stripem**) zfaduje na `opacity 0.45` — symboly jen zeslábnou, nezmizí. |

Mechanismus dnes ([`KeyView.swift`](../KeyboardUI/Sources/Views/KeyView.swift)): touch-down na space spustí `startTrackpadArmTimer()` (`:305`), který po `trackpadArmDelay` (300 ms, `:77`) nastaví `isTrackpadArmed`. Aktivace (`isTrackpadActive`) přijde až ve `handleSpaceDrag` (`:314`) po překročení `trackpadActivationDistance` (6 pt, `:80`). Teprve tehdy se volá `onTrackpadModeChanged(true)` → v [`KeyboardView.swift`](../KeyboardUI/Sources/Views/KeyboardView.swift) `handleTrackpadModeChanged` (`:271`) zapne haptic + nastaví `isInTrackpadMode`, který řídí celoklávesnicový `.opacity(0.45)` (`:131`).

**Native cursor API se nemění** — pořád jen `adjustTextPosition(byCharacterOffset:)`, žádné nové 2D API (viz [keyboard-extension-cursor-api memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keyboard-extension-cursor-api.md)). Tenhle task se kurzorové matematiky (task 69) **vůbec nedotýká** — mění jen *kdy* se trackpad aktivuje a *jak* vypadá.

## Cíl

Trackpad se přiblíží native chování ve dvou bodech, jeden commit / jedna PR (oboje v `KeyView.swift` + `KeyboardView.swift` + `KeyRowView.swift`, sdílí původ = stejné gesto):

1. **Aktivace čistě časem.** Podržení space ≥ 350 ms aktivuje trackpad samo, bez nutnosti tahu.
2. **Prázdné klávesy.** Glyfy všech kláves zmizí, těla zůstanou + jemná změna odstínu; horní strip jemně ustoupí. Zrušit celoklávesnicový fade 0.45.

## Rozhodnutí (zafixovaná z grill session 2026-06-23)

### Aktivace

| Téma | Rozhodnutí |
|---|---|
| **Trigger** | **Čistě časem.** Po 350 ms hold se trackpad aktivuje sám. Tah před vypršením času nedělá nic (žádná předčasná aktivace). |
| **Práh tahu** | `trackpadActivationDistance` (6 pt dead-zone) se **ruší** — aktivace už není podmíněná tahem. |
| **Stavový automat** | `isTrackpadArmed` se **ruší**. Timer nastaví `isTrackpadActive = true` přímo a volá `onTrackpadModeChanged(true)` (haptic + vizuál). „Armed" vs „active" se slévá do jednoho stavu. |
| **Delay** | `trackpadArmDelay`: **300 → 350 ms** (= existující `longPressDelay`, parita s Apple long-press). |
| **Anchor při aktivaci** | Kurzorový anchor = poloha prstu v momentě aktivace. Před aktivací `trackpadAnchorX/Y` **trackuje prst** (overwrite každý frame v `onChanged`, dokud `!isTrackpadActive`). U stacionárního prstu = touch-down poloha. Po aktivaci anchor posouvá kvantovaně `handleSpaceDrag` jako dnes → žádný skok kurzoru při zapnutí. |
| **Release bez pohybu** | **Napíše nic.** Po 350 ms je trackpad aktivní → release spadne do `wasTrackpadActive` větve (`handleTouchUp:288`), `.space` tap se potlačí. Native parita. (Změna oproti dnešku, kdy hold+release psal mezeru.) |
| **Haptic** | Existující `trackpadModeEntered` (soft impact 1.0, [`UIKitHaptics.swift:72`](../KeyboardExtension/Sources/UIKitHaptics.swift)) — beze změny, jen se teď spustí v 350 ms místo při tahu. Touch-down space tap haptic (`KeyView:221`) zůstává. |

### Vizuál

| Téma | Rozhodnutí |
|---|---|
| **Celoklávesnicový fade 0.45** | **Zrušit** (`KeyboardView:131`). |
| **Glyfy kláves** | Skrýt **všem** klávesám (písmena, symboly, space label, shift/123/return/emoji) → `content.opacity(isTrackpadActive ? 0 : 1)` v `KeyView:137`, s `.animation(.easeOut(0.15))`. |
| **Pozadí kláves** | Zůstanou viditelná + **jemná změna odstínu** (trackpad varianta v `keyBackgroundColor`, `KeyView:261`). Přesný odstín doladit okem proti native v dark/light na zařízení (dark: klávesy mírně světlejší/našedlé). |
| **Horní strip** (emoji oblíbené / našeptávač) | **Jemně ustoupí** — vlastní dim na `topRegion` (`KeyboardView:142`), nezávisle na klávesách. Obsah stripu nemizí, jen recede. |
| **Datový tok flagu** | `isInTrackpadMode` už žije v `KeyboardView` (`:42`). Prodrillovat **dolů** jako `isTrackpadActive: Bool` přes `KeyRowView` → `KeyView`. (Dnes flag tekl jen nahoru callbackem; pro skrytí glyfů ho potřebuje znát každá klávesa.) |

## Scope

### 1. `KeyView.swift` — aktivace časem

- **Smazat** `@State isTrackpadArmed` (`:44`) a konstantu `trackpadActivationDistance` (`:80`) — dead code po této změně.
- `trackpadArmDelay` (`:77`): `300 → 350` ms. Aktualizovat komentář (teď = `longPressDelay`).
- `startTrackpadArmTimer()` (`:305-312`): po `Task.sleep` a guardu `isPressed` místo `isTrackpadArmed = true` udělat plnou aktivaci:
  ```swift
  guard !Task.isCancelled, isPressed else { return }
  isTrackpadActive = true
  onTrackpadModeChanged(true)
  ```
  (Anchory už trackují prst — viz níže. Přejmenovat metodu na `startTrackpadActivationTimer()` ať jméno nelže.)
- `combinedGesture.onChanged` (`:180-190`): pro space key dokud `!isTrackpadActive` nechat anchory sledovat prst — **před** voláním `handleSpaceDrag`:
  ```swift
  if isSpaceKey {
      if !isTrackpadActive {
          trackpadAnchorX = value.location.x
          trackpadAnchorY = value.location.y
      }
      handleSpaceDrag(at: value.location)
  }
  ```
- `handleSpaceDrag(at:)` (`:314-360`): smazat celý aktivační blok (`:315` guard `isTrackpadArmed` + dead-zone `:317-337`). Nově:
  ```swift
  guard isTrackpadActive else { return }
  // per-frame dominant-axis emit — beze změny (:339-359)
  ```
- `handleTouchUp` (`:266-298`): beze změny — `wasTrackpadActive` větev (`:288`) už dnes potlačuje `.space`. Po této změně se trefí i u stacionárního hold+release (release bez pohybu = nic). Ověřit, že `isTrackpadActive` reset (`:280`) zůstává.
- `handleTouchDown` (`:203`): anchory na touch-down poloze (`:215-216`) zůstávají — slouží jako fallback pro stacionární prst.

### 2. `KeyView.swift` — prázdné klávesy

- Přidat `let isTrackpadActive: Bool` do KeyView properties.
- `body` (`:137`): na `content` přidat `.opacity(isTrackpadActive ? 0 : 1)` + `.animation(.easeOut(duration: 0.15), value: isTrackpadActive)`. (Pozadí `RoundedRectangle` `:134` zůstává viditelné.)
- `keyBackgroundColor` (`:261-264`): přidat trackpad odstín větev:
  ```swift
  if isTrackpadActive { return style.trackpadBackgroundColor } // jemně odlišný od normal
  if isWordDeleting { return Color.orange.opacity(0.6) }
  return isPressed ? style.pressedBackgroundColor : style.backgroundColor
  ```
  (Pokud `KeyStyle` token nemá, doplnit `trackpadBackgroundColor` jako jemnou variantu `backgroundColor` — viz styling pozn.)

### 3. `KeyRowView.swift` — propagace flagu (⚠️ Equatable)

- Přidat `let isTrackpadActive: Bool`.
- **Kritické:** přidat ho do `static func ==` (`:27-32`):
  ```swift
  && lhs.isTrackpadActive == rhs.isTrackpadActive
  ```
  Jinak short-circuit (task 73) přeskočí re-render a klávesy se **nepřepnou** na blank. Aktualizovat doc komentář (`:6-9`), že render je teď funkcí i `isTrackpadActive`.
- Předat `isTrackpadActive: isTrackpadActive` do `KeyView(...)` (`:41-57`).
- Aktualizovat preview (`:134-145`) novým argumentem (`isTrackpadActive: false`).

### 4. `KeyboardView.swift` — zrušit fade, dim stripu, předat flag

- **Smazat** `.opacity(isInTrackpadMode ? 0.45 : 1.0)` (`:131`). `.animation(.easeOut(0.15), value: isInTrackpadMode)` (`:132`) může zůstat (řídí teď dim stripu) — nebo přesunout na strip.
- `topRegion` (`:142-160`): přidat jemný dim při trackpad módu, např. `.opacity(isInTrackpadMode ? 0.4 : 1.0)` na obsah `topRegion` (ne na height container — výška se nesmí hnout, task 61).
- `defaultKeyboard` (`:248-261`): předat `isTrackpadActive: isInTrackpadMode` do `KeyRowView(...)`.
- `handleTrackpadModeChanged` (`:271-274`): beze změny (pořád nastaví `isInTrackpadMode` + haptic).
- **Symbols page taky (potvrzeno).** `defaultKeyboard` je non-emoji větev (`body:123-124`) → renderuje letters **i** symbols page; rozliší je `page` na `KeyRowView`. Předáním flagu zde jsou pokryté **obě**. Trackpad je v `KeyView` vázaný na `isSpaceKey` (action `.space`), který je na obou stránkách, takže gesto na symbols-page space už jede dnes — tahle změna jen zajistí, že tam i **zblanknou glyfy**. Emoji / emoji-search keyboard (`emojiKeyboard`, `emojiSearchKeyboard`, `body:119-122`) mají vlastní strukturu bez letter-grid space → netýká se jich, žádný `isTrackpadActive` argument tam není.

### 5. `KeyStyle` (styling)

- Doplnit `trackpadBackgroundColor` token (jemně odlišný od `backgroundColor`). Dark: lehce světlejší/našedlý. Light: lehce tmavší. Doladit okem proti native screenshotu.

### 6. Snapshot test

- `KeyboardViewSnapshots` (nebo row-level): nový snapshot stavu **trackpad aktivní** — `KeyRowView(... isTrackpadActive: true)` → ověří blank klávesy + odstín. Light + dark.
- Existující idle snapshoty musí zůstat nedotčené (`isTrackpadActive: false` default).
- ⚠️ Aktivační timing a release-bez-mezery jsou gesture-driven → snapshot je nezachytí. Ověřit na zařízení (viz Hotovo když).

## Hotovo když

### Aktivace
- Podržím prst na space **bez pohybu** → po ~350 ms přijde haptic „thunk" + klávesy zblanknou → trackpad aktivní. Pohyb prstu pak posouvá kurzor (jako dnes).
- Podržím space ≥ 350 ms a pustím **bez pohybu** → **nenapíše se mezera**, kurzor zůstane.
- Krátký tah na space **před** 350 ms → nic se neaktivuje; na release se napíše mezera (dnešní rychlý space tap zachován).
- Po aktivaci první pohyb prstu **neskočí** kurzorem (anchor = poloha prstu při aktivaci).
- 2D scrubbing (horizontál po znaku, vertikál po řádku, task 69) funguje beze změny.

### Vizuál
- Při aktivaci zmizí glyfy **všech** kláves (vč. space labelu, shift/123/return/emoji); těla kláves zůstanou viditelná + jemně jiný odstín.
- Klávesnice **není** ztmavená na 45 % — blank, ale jasná (jako native screenshot).
- Horní emoji/našeptávač strip jemně ustoupí (dim), obsah nezmizí, výška se nehne.
- Exit (release): glyfy se vrátí s `.easeOut(0.15)`.
- **Symbols page (123):** hold na space na symbolové stránce aktivuje trackpad stejně a zblankne glyfy symbolů (ne jen na letters page).

### Obecně
- Žádné nové permission prompts, žádné nové dependencies, žádná změna `Key.Action`.
- `KeyboardUI` snapshot suite zelená (po přidání trackpad snapshotu). `KeymojiCore` + `Settings` testy zelené.
- Reálné ověření na iPhone 17 / iOS 26.2 sim ([keymoji-build-uses-workspace memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keymoji-build-uses-workspace.md)) — porovnat side-by-side s native klávesnicí v dark i light.
- ⚠️ Nové soubory nejsou — jen edity existujících, takže `tuist generate` netřeba ([keymoji-tuist-new-files-silent-skip memory](../../../../.claude/projects/-Users-martin-Development-Keymoji/memory/keymoji-tuist-new-files-silent-skip.md) se neuplatní).

## Rizika / poznámky

- ⚠️ **Equatable past.** Zapomenout `isTrackpadActive` v `KeyRowView.==` (krok 3) → klávesy se vizuálně nepřepnou (short-circuit z task 73). Hlavní failure mode, hlídat v review.
- ⚠️ **Anchor drift.** Pokud anchor netrackuje prst před aktivací, kurzor při zapnutí poskočí o vzdálenost, o kterou prst během 350 ms hold ujel. Proto overwrite anchorů v `onChanged` dokud `!isTrackpadActive` (krok 1).
- ⚠️ **Změna chování:** dlouhý hold+release na space dnes píše mezeru, nově nic. Zamýšlené (native parita), ale je to user-facing změna — zmínit v changelogu/PR.
- **Odstín** je tuning detail — neexistuje „správná hodnota", doladit okem proti native v obou módech.

## Codex review

**Ano** — task přepisuje aktivační část gesture state machine na hot-path space klávese (`KeyView`) a mění Equatable kontrakt sdílený s perf optimalizací (task 73). Failure modes (chybějící `isTrackpadActive` v `==`, anchor skok při aktivaci, regrese „release píše mezeru") jsou drobné, ale na klávesnici při každém scrubu. Stojí za druhý pár očí. (Konzistentní s task 69.)

## ADR

**Ne.** Zvážen a vynechán: rozhodnutí (čas vs. tah, blank vs. fade, release píše nic) jsou vratná UX/tuning volba a zarovnání na native paritu, ne architektonický trade-off s trvalým dopadem. Nesplňuje „hard to reverse + surprising + genuine trade-off".
