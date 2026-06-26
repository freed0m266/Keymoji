# 87 — Plus copy retext (marketing-psychology) + oprava Full Access claimů

**Status:** Done — 2026-06-27 (in-app copy + App Store listing Plus sekce + Full Access reconciliation napříč shipping copy / kód-komentáři / historickými tasky; 16 snapshotů re-recordnuto)

**Priorita:** v1.x (před širším releasem — konverze + App Review přesnost) · **Úsilí:** M (copy + reconciliace + re-record) · **Dopad:** High (konverze Plus + odstranění nepravdivého App Review claimu)

**Souvisí s:** [63 — monetizace Keymoji Plus](63-monetization-keymoji-plus.md) (paywall/limit/trial copy), [64 — welcome trial](64-hesoyam-promo-trial.md) (loss-aversion smyčka), [86 — analytics + privacy reconciliation](86-anonymous-host-app-analytics-telemetrydeck.md) (privacy copy), [47 — App Store listing](47-app-store-listing.md), [13 — About & privacy](13-about-and-privacy.md). Vzešlo z `/marketing-psychology` session.

## Cíl

Dvě věci, které spolu souvisí přes „shipping copy":

1. **Přetextovat Plus copy** tak, aby líp fungovala z pohledu prodeje/marketingu (paywall, welcome trial, favorites limit) **a zároveň zlepšila UX** — copy, která zněla jako zeď, převést na pozvánku; doplnit chybějící anti-subscription signál na rozhodovacích prvcích.
2. **Sjednotit pravdu o „Allow Full Access"** napříč celou appkou: Full Access je potřeba **jen pro haptiku**, ne pro zvuky kláves. Stará (chybná) víra „zvuk vyžaduje Full Access" byla rozsetá v shipping copy, kód-komentářích i task docech.

## Rozhodnutí (zafixovaná z této session)

- **Tón Plus copy zůstává reciprocity-first** (zadání z [task 63](63-monetization-keymoji-plus.md)) — žádné shaming, žádná agresivní urgency. Měníme jen místa, kde copy nechtěně zní jako zeď nebo kde se ztrácí konverzní páka.
- **US angličtina** zůstává (žádná GB normalizace).
- **Full Access = jen haptika.** Key click sound (oba paty: `playInputClick()` pro znaky i `AudioServicesPlaySystemSound` pro space/delete) hraje **bez** Full Access — **ověřeno Martinem na reálném zařízení, iOS 26.** Apple's starší custom-keyboard guide tvrdí opak a ta víra se propsala do kódu i doců; korigujeme na realitu.
- **`paywall.benefitPages`** — zkoušeno „A full page of 9 — swipe for more", nakonec **návrat k „Multiple favorite pages"** (vizuální stránku „pages" stejně časem převezme ilustrace; text se nemusí dřít).

## Co se změnilo

### 1. In-app copy (`KeymojiResources/.../Localizable.strings`)

| klíč | předtím | teď | proč |
|---|---|---|---|
| `paywall.cta` | `Unlock for %@` | `Unlock once — %@` | anti-subscription námitka přímo na rozhodovacím buttonu (spec t63 to chtěl, vypadlo) |
| `paywall.headlineFrequency` | „Auto-sort is a Keymoji Plus feature." | „Your most-used emoji, always first." | zeď → outcome (uživatel sem přišel s vysokou motivací) |
| `settings.favorites.frequencyLockedFooter` | „…**is a Keymoji Plus feature**. Unlock it to…" | „Order favorites by how often you use them — your most-used always first. Unlock with Plus." | benefit první, gate druhý |
| `paywall.headlineSettings` | „Keymoji Plus" | „Make Keymoji yours." | studený vstup potřebuje desire, ne název produktu |
| `paywall.headlineAfterTrial` | „You loved Plus. Get it back." | „Your Plus month is over." | bez presumpce; subtitle nese hodnotu |
| `settings.favorites.lossAversion.title` | „Your Plus trial ended" | „Your Plus month is over" | konzistentní s paywallem |
| `paywall.successCta` | „Done" | „Let's go" | peak-end momentum |
| `onboarding.step2.privacy` | „…**does not access the internet**…" | „…**The keyboard makes no network calls**…" | reconciliace s [task 86](86-anonymous-host-app-analytics-telemetrydeck.md) (díra, kterou 86 v in-app copy minul — jmenoval jen `about.privacyStatement`) |
| `settings.keyboard.hapticFooter` | „Haptic feedback **and key clicks** both require Allow Full Access… Key clicks additionally require…" | „Haptic feedback requires Allow Full Access… **Key click sound works without it.**" | Full Access = jen haptika |

### 2. App Store listing — Plus sekce (chyběla úplně)

`marketing/app-store/listing-en.md` + fastlane `en-GB/description.txt`: přidaná sekce **`FREE FOREVER — PLUS IS OPTIONAL`** (freemium frame = anti-bait-and-switch + „no subscription, ever"). `check-lengths.sh` ✅ (Description 3028/4000).

### 3. Full Access reconciliation (haptics only)

Sjednoceno napříč:
- **Shipping copy:** `hapticFooter` (in-app), listing-en.md + fastlane `en-GB` (sekce „ABOUT ALLOW FULL ACCESS" → jedna věc místo dvou; „off → still silent" → „off → sounds included, jen bez haptiky"), `review_information/notes.txt`, `SUBMISSION.md`, root `README.md`.
- **Kód-komentáře:** `KeyClickSounding.swift`, `UIKitClickSound.swift`, `KeyboardViewController.swift` (odstraněn „requires Full Access" claim; znění čistě present-tense).
- **Historické tasky:** 41 (hypotéza 4 vyloučena), 46 (gate description), 47 (description + Rizika flag) — chybný claim „zvuk vyžaduje Full Access" opraven.

> `about.privacyStatement` (z [task 86](86-anonymous-host-app-analytics-telemetrydeck.md)) měl Full Access claim **správně** už předtím („required only for haptic feedback") — neměněn.

### 4. Snapshoty
15 re-recordnuto (iPhone 17 / iOS 26.2): Paywall ×6, Settings ×6, FavoriteEmojisEditor ×2, Onboarding step2 ×1. Verify green. (Dříve flaky `testPaywall_loadingPrice_dark` byl mezitím odstraněn samostatně — commit `a7bc8d2`, takže Paywall suite je teď bez flaky testu.)

## Mimo scope

- **Ilustrace k „multiple pages"** — budoucí polish (proto text zůstal jednoduchý).
- **Agresivnější konverzní páky** (anchoring „compare" ceny, urgency) — drží se reciprocity-first zadání z [task 63](63-monetization-keymoji-plus.md).
- **GB pravopis** — US angličtina zůstává.
- **`privacy-policy.html`** — Full Access tam už [task 86](86-anonymous-host-app-analytics-telemetrydeck.md) nechal jako „haptics only" konzistentní; tady neměněno.

## Hotovo když

- Plus copy (paywall/trial/favorites) přetextovaná dle marketing-psychology, snapshoty green.
- App Store listing má Plus sekci; `check-lengths.sh` projde.
- Žádné shipping místo / kód-komentář netvrdí, že key click sound vyžaduje Full Access; App Review notes mluví pravdu (Full Access = jen haptika).
- Historické tasky 41/46/47 nenesou chybný claim.

## Reference

- [[keymoji-fullaccess-haptics-only]] — memory: Full Access gateuje jen haptiku (real-device ověřeno).
- `/marketing-psychology` skill — psychologický rámec pro copy rozhodnutí.
