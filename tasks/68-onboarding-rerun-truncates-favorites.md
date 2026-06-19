# 68 — Re-run onboardingu ořezává existující favorites na free cap (data loss)

**Status:** Todo

**Priorita:** v1.x · **Úsilí:** S · **Dopad:** High (data loss — downgradnutý free user přijde o favorites, které mu [task 64](64-hesoyam-promo-trial.md) slibuje zachovat)

**Souvisí s:** [64 — Welcome trial + HESOYAM](64-hesoyam-promo-trial.md) (Scope 12 slibuje, že se favorites po downgradu **neztratí**), [62 — Onboarding pick favorites](62-onboarding-pick-favorites.md), [11 — Host app onboarding](11-host-app-onboarding.md).

## Bug

`OnboardingViewModel.persistFavoritesIfPickerWasShown()` ukládá favorites takhle:

```swift
dependencies.preferences.persistOnboardingFavorites(Array(resolved.prefix(favoritesLimit)))
```

`selectedFavorites` je v initu předvyplněný stávajícími favorites (`dependencies.preferences.currentFavorites`). Když **free user** (effectiveIsPlus false → `favoritesLimit == 6`) znovu pustí onboarding (Settings → „Setup instructions", startuje na `.addKeyboard`, což je ≤ `pickFavorites`) a krok dokončí, uloží se **jen prvních 6** a **zbytek se smaže**.

## Proč je to reálně dosažitelné (a proč až teď)

Před taskem 64 free user nikdy nemohl mít >6 favorites (cap se vynucoval při přidávání), takže `prefix(6)` byl no-op. **Task 64 ten předpoklad rozbil**: po expiraci promo trialu se favorites nad cap **zachovají** (Scope 12 „favorites se nemažou, jen se nezobrazují nad limit"). Takový downgradnutý free user má >6 uložených favorites — a re-run onboardingu mu je ořeže. Tedy přesně ten uživatel, kterému 64 slibuje opak.

## Reprodukce

1. Mít >6 favorites jako **free** user (po expiraci promo trialu; nebo přes [debug menu task 67](67-debug-menu-simulate-free-user.md): force-free + favorites > 6).
2. Settings → „Setup instructions" → projít na krok „Pick favorites" → **Continue**.
3. Uložené favorites se ořežou na 6, zbytek je pryč.

## Příčina

Cap na *write* (`prefix(favoritesLimit)`) je tam záměrně pro **první** run: curated fallback má 12 a free user smí udržet jen 6, takže se nemá uložit víc, než klávesnice ukáže. U **re-runu**, kdy už uživatel vlastní favorites má, je ten ořez destruktivní.

## Návrh řešení (doladit v implementaci)

Persist nikdy nesmí **mazat** data — clamp je čistě view concern (`FavoritesEntitlement.visibleFavorites` už nad limit clampuje při zobrazení, nedestruktivně). Preferovaný směr:

- **(c) Nepřefixovávat při persistu.** Ukládat plný `selectedFavorites`; cap řešit jen při (i) selekci (`canSelectMoreFavorites`) a (ii) displeji (`visibleFavorites` clamp). Tím persist nikdy neztratí data a drží se invariant z 63/64, že downgrade favorites zachovává.
- Alternativy, kdyby (c) rozbila první-run UX: (a) cap aplikovat jen na **fallback** (prázdná selekce → curated default ořež), ne na uživatelem pre-fillnutou/upravenou selekci; (b) při re-runu (`currentFavorites` neprázdné) zachovat plný stored set.

Zvážit, jestli při prvním runu free usera nechceme i tak nějaký rozumný strop na curated default (ať klávesnice nemusí clampovat hned po onboardingu) — ale to řešit bez mazání existujících dat.

## Hotovo když

- Free user s >6 favorites projde re-run onboardingu a dokončí → **všechny** favorites zachované (žádný ořez).
- První run s prázdnou selekcí pořád uloží smysluplný default.
- VM test: re-run s `currentFavorites.count > freeFavoritesLimit` + free → persist zachová celý set (nic se neořízne).

## Codex review

**Ano** — data-loss path; ověřit, že fix nerozbije první-run fallback ani Plus chování.
