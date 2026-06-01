# 46 — Odlišný zvuk mezerníku a delete (parita s nativní klávesnicí)

**Status:** Todo

**Priorita:** v1.1 · **Úsilí:** S–M · **Dopad:** Low–Medium (jemný detail, ale znatelný „native feel")

## Cíl

Nativní iOS klávesnice přehrává **jiný zvuk pro mezerník i pro delete** než pro běžné
znakové klávesy — mezerník/modifikátory mají hlubší, „dutější" cvak, delete má vlastní zvuk,
znaky mají vyšší „tok". Keybo dnes hraje **jeden a tentýž** click pro všechny klávesy. Cílem je,
aby mezerník i delete hrály stejné odlišené zvuky jako nativní klávesnice, zatímco ostatní
klávesy zůstanou na současném znakovém clicku.

Po dokončení: stisk mezerníku i delete zní stejně jako na nativní Apple klávesnici (odlišně od
písmen i od sebe navzájem), ostatní klávesy beze změny.

## Kontext

- Dnešní zvuk je jeden globální `UIDevice.current.playInputClick()` wrapper:
  [`UIKitClickSound.swift`](../KeyboardExtension/Sources/UIKitClickSound.swift) — `play()` nebere
  žádný parametr, hraje vždy stejný systémový click.
- Protokol je rovněž bezparametrový:
  [`KeyClickSounding.swift`](../KeyboardCore/Sources/Public/KeyClickSounding.swift) — `func play()`.
- Volá se z `KeyView` na touch-down přes closure řetězec
  `onKeyClick` → … → [`KeyboardViewController.swift:414`](../KeyboardExtension/Sources/KeyboardViewController.swift:414)
  (`onKeyClick: { self?.clickSound.play() }`). Call-sites v
  [`KeyView.swift:170,342,356`](../KeyboardUI/Sources/Views/KeyView.swift:170).
- Typ klávesy je v scope `KeyView` dostupný: `Key.action` (`.space`, `.backspace`, `.deleteWord`,
  `.insertText`, …) a `Key.role` (`.character` / `.system`) — viz
  [`Key.swift:58-84`](../KeyboardCore/Sources/Models/Key.swift:58). Mezerník = `action == .space`,
  delete = `action == .backspace` (i synteticky emitovaný `.deleteWord` při word-delete repeat,
  viz [`KeyView.swift:345`](../KeyboardUI/Sources/Views/KeyView.swift:345)).

## Klíčová technická překážka

`UIDevice.current.playInputClick()` **neumí vybrat zvuk** — vždy hraje jeden systémový click a
nebere parametry. Odlišný zvuk per klávesa proto vyžaduje opuštění `playInputClick()` ve prospěch
`AudioServicesPlaySystemSound(_:)` s konkrétními keyboard sound IDs.

Známé systémové keyboard sound IDs (k **ověření na reálném zařízení**, nejsou veřejně dokumentované):
- `1104` — Tock (standardní znaková klávesa)
- `1155` — delete / backspace
- `1156` — modifier / mezerník (hlubší cvak)

**Trade-off (záměrně zvážit, ne ignorovat):** task [41](41-click-sound-volume-bug.md) a komentáře v
[`KeyClickSounding.swift`](../KeyboardCore/Sources/Public/KeyClickSounding.swift) zdůrazňují, že
`playInputClick()` je idiomatická Apple cesta, kterou systém **gateuje** dle „Keyboard Clicks"
v Settings → Sounds & Haptics (+ Allow Full Access). `AudioServicesPlaySystemSound` tuhle bránu
**obchází** — hraje i když má uživatel Keyboard Clicks vypnuté, a jede přes media/ringer volume
(potenciální regrese hlasitosti z tasku 41). Před přechodem je proto nutné ověřit:
1. Zda `AudioServicesPlaySystemSound` s keyboard IDs respektuje „Keyboard Clicks" toggle (pravděpodobně **ne**).
2. Hlasitostní profil vs. `playInputClick()` (regrese tasku 41?).

Pokud `AudioServicesPlaySystemSound` brání respekt systémového toggle, je potřeba si ho hlídat
sami — číst stav „Keyboard Clicks" nelze přímo, takže fallback je: gate čistě naším app-side
toggle (`AppGroupStore`) + respekt Allow Full Access, a v tasku poznamenat, že systémový
„Keyboard Clicks" toggle už neplatí (degradace vůči nativní paritě — zvážit, zda je odlišný zvuk
mezerníku tu cenu hoden).

## Scope

1. **Spike / ověření na zařízení (blokující rozhodnutí).**
   - Na reálném zařízení porovnat `AudioServicesPlaySystemSound(1104/1155/1156)` se zvukem nativní
     klávesnice (písmeno vs. mezerník vs. delete). Zapsat, které ID odpovídá mezerníku a které delete.
   - Ověřit chování při vypnutém „Keyboard Clicks" v Settings → Sounds & Haptics.
   - Ověřit hlasitost vs. `playInputClick()` (regrese tasku 41).
   - **Výstup:** rozhodnutí, zda jdeme cestou `AudioServicesPlaySystemSound` (a s jakými gate
     pravidly), nebo zda je ztráta respektu systémového toggle nepřijatelná a task se zaparkuje.

2. **Rozšíření soundu o typ klávesy.**
   - Rozšířit `KeyClickSounding` o informaci o klávese, např.
     `func play(for kind: ClickSoundKind)` s malým enumem `enum ClickSoundKind { case character, space, delete }`
     (preferovat malý enum místo prosakování celého `KeyAction` do UI vrstvy).
   - Aktualizovat `NoopClickSound` a `UIKitClickSound`.
   - `KeyView` při volání `onKeyClick` předá typ klávesy (`key.action == .space` → space zvuk,
     `.backspace`/`.deleteWord` → delete zvuk, jinak character).
   - Provázat přes `onKeyClick` closure řetězec (KeyView → KeyRowView → KeyboardView →
     KeyboardRoot → KeyboardViewController). Pozor na všechny call-sites `onKeyClick()`
     (KeyView, SuggestionBarView, EmojiPanelView, EmojiSearchView) — chipy/emoji = character zvuk.

3. **Implementace odlišného zvuku.**
   - `UIKitClickSound.play(for:)`: pro `.space` hrát space ID (≈ `1156`), pro `.delete` hrát
     delete ID (≈ `1155`), jinak zachovat dosavadní chování.
   - **Preferovaný minimální zásah:** pokud spike ukáže, že `playInputClick()` musíme opustit jen
     pro mezerník a delete, hrát je přes `AudioServicesPlaySystemSound(<space/delete ID>)` a
     **ostatní klávesy ponechat na `playInputClick()`** — tím zachováme respekt systémového toggle
     pro drtivou většinu stisků a obětujeme ho jen u mezerníku a delete. (Zvážit konzistenci:
     část kláves respektuje toggle, část ne — možná je čistší všechny cesty sjednotit. Rozhodnout
     v rámci spiku.)

4. **Žádné nové uživatelské toggles.**
   - Cíl je parita s nativní klávesnicí, ne konfigurace. Žádný „space sound" Setting.

## Mimo scope

- Vlastní `.wav` samply zvuků kláves. Cílem je parita s nativními systémovými zvuky, ne branding.
- Odlišný zvuk pro return/shift/page-toggle (nad rámec mezerníku a delete). Pokud spike odhalí
  jejich ID levně, lze přidat jako bonus, ale primární cíl jsou **mezerník a delete**.
- Per-key hlasitost nebo pitch ladění.
- Oprava/změna haptik (task [31](31-haptic-feedback-for-every-key.md)) — nedotčené.

## Závislosti

- Task [26](26-sound-feedback.md) (click sound impl) — done.
- Task [41](41-click-sound-volume-bug.md) (volume bug) — done; **kriticky** ověřit, že přechod na
  `AudioServicesPlaySystemSound` neznovuotevře hlasitostní regresi z tasku 41.

## Hotovo když

- [ ] Spike zapsán: které sound ID = mezerník a které = delete, jak se chovají vůči „Keyboard Clicks" toggle a hlasitosti.
- [ ] Stisk mezerníku i delete zní odlišně od písmen (a navzájem) — side-by-side s nativní klávesnicí potvrzuje paritu.
- [ ] Delete-on-hold repeat (i word-delete eskalace) hraje delete zvuk konzistentně po celou dobu držení.
- [ ] Ostatní klávesy (písmena, čísla, symboly, emoji, suggestion chipy) zní beze změny.
- [ ] App-side click toggle (`AppGroupStore`) stále vypne/zapne veškerý zvuk včetně mezerníku a delete.
- [ ] Žádná regrese hlasitosti z tasku 41 (test scénář: Spotify playback → otevři Keybo → psaní).
- [ ] Hudba host appky není přerušena při psaní.
- [ ] Rozhodnutí o respektu systémového „Keyboard Clicks" toggle je vědomé a zaznamenané v kódu
      (komentář u `UIKitClickSound`).
- [ ] Žádná regrese haptik, popover, delete-repeat.

## Reference

- [`KeyboardExtension/Sources/UIKitClickSound.swift`](../KeyboardExtension/Sources/UIKitClickSound.swift)
- [`KeyboardCore/Sources/Public/KeyClickSounding.swift`](../KeyboardCore/Sources/Public/KeyClickSounding.swift)
- [`KeyboardCore/Sources/Models/Key.swift`](../KeyboardCore/Sources/Models/Key.swift) — `KeyAction`, `KeyRole`.
- [`KeyboardUI/Sources/Views/KeyView.swift`](../KeyboardUI/Sources/Views/KeyView.swift) — `onKeyClick` call-sites.
- [`KeyboardExtension/Sources/KeyboardViewController.swift:414`](../KeyboardExtension/Sources/KeyboardViewController.swift:414) — `clickSound.play()` hook.
- Apple — [`UIDevice.playInputClick()`](https://developer.apple.com/documentation/uikit/uidevice/1620025-playinputclick), [`AudioServicesPlaySystemSound`](https://developer.apple.com/documentation/audiotoolbox/1405202-audioservicesplaysystemsound).
- Task [26](26-sound-feedback.md), [41](41-click-sound-volume-bug.md).
