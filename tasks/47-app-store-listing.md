# 47 — App Store listing & ASO

**Status:** Done — 2026-06-02 (listing copy EN+CZ + submission checklist prepared in `marketing/app-store/`; screenshots + App Store Connect upload still manual)

**Priorita:** Pre-App-Store (souběžně s task 28) · **Úsilí:** S · **Dopad:** High (acquisition)

## Cíl

Mít připravený App Store listing, screenshoty a klíčová slova před první submission. Keymoji je privacy-first klávesnice — to je hlavní marketingový hook a musí prosakovat celým listingem.

## Kontext

- App Store Connect submission vyžaduje vyplněné metadata, screenshoty pro každou podporovanou velikost a privacy policy URL (z task 13).
- Keymoji je **English-only** UI (viz README „Mimo scope") — listing děláme **EN primary**, CZ jako sekundární locale (Martin je CZ, ale klávesnice cílí globálně).
- Privacy claim „nesbíráme nic" je doslova pravda (žádný analytics/crash reporting) — můžeme ho použít jako headline bez review rizika.

## Scope

- **Název (max 30 znaků):** „Keymoji – Private Keyboard" (zkontrolovat délku).
- **Subtitle (max 30 znaků):** EN „No tracking. Just typing." / CZ „Klávesnice, co nešpehuje".
- **Keywords (max 100 znaků, comma-separated, bez mezer kvůli úspoře):**
  EN: `keyboard,private,privacy,emoji,haptic,typing,qwerty,qwertz,no tracking,offline,custom,fast`
  CZ: `klávesnice,soukromí,emoji,haptika,psaní,qwertz,offline,bez sledování,vlastní,rychlá`
- **Screenshoty (5–6 ks, EN + CZ, iPhone 6.9" + 6.5" required sizes):**
  1. Klávesnice v akci (psaní zprávy) — hero shot s viditelnou nativní paritou (task 35).
  2. Emoji režim + favorites / shortcodes (task 17, 18, 32).
  3. Word completion suggestion bar (task 40).
  4. Host app Settings — viditelné toggly (haptika, zvuk, QWERTY/QWERTZ, light/dark override).
  5. Onboarding / „Allow Full Access for haptics & sound" obrazovka (task 11, 38) — proaktivně vysvětlit Full Access.
  6. (volitelně) About screen s privacy statementem (task 13) — posílit privacy claim.
- **Popis (description):** highlight 4–5 klíčových výhod jako bullet list:
  - 100% on-device, žádné sledování, žádný analytics, žádný network access.
  - Full Access slouží **jen** pro haptiku a zvuky kláves — vysvětlit, proč o něj iOS žádá (iOS sandbox blokuje haptiku i `playInputClick`/`AudioServicesPlaySystemSound` bez Full Access). Suggestions, nastavení i emoji fungují i bez něj.
  - Emoji search + favorites + Slack-style `:shortcodes:`.
  - QWERTY / QWERTZ přepínání, light/dark override.
  - Haptika a zvuk feedback, plně laditelné.
- **Promotional text (170 znaků, měnitelné bez review):** krátký aktuální hook.
- **Privacy policy URL** → `Constants.URLs.privacyPolicy` (task 13), musí být live před submission.
- **Support URL** → osobní web / GitHub repo (task 13 `sourceCode`).
- **App Privacy „Nutrition Label" v App Store Connect:** vyplnit jako **„Data Not Collected"** — žádná kategorie. Musí matchovat privacy policy doslova.
- **Category:** Primary „Utilities", Secondary „Productivity".
- Lokalizovaná metadata: **EN primary**, CZ secondary minimum.

## Závislosti

- Task 13 (privacy policy HTML + Constants URLs) — Done.
- Task 28 (real app icon) — ikona musí být hotová, screenshoty i ASC listing ji potřebují.
- Vizuální tasky (35 redesign, 40 suggestions, 18/32 favorites) ideálně Done, aby screenshoty ukazovaly finální UI.

## Kde žijí artefakty

- Screenshoty + listing copy do `marketing/` (vedle `privacy-policy.html`) — **mimo app bundle**, není to runtime resource. Např. `marketing/app-store/`.
- Samotná ASC submission je manuální krok (ne v repo).

## Mimo scope

- App Store Connect API / fastlane automatizace uploadu — manuální submission v1.0 stačí (WidgetCoin to řeší samostatným taskem 19, pro Keymoji zatím přehnané).
- App Preview video. Future polish.
- Více locale než EN + CZ.
- Paid tier / IAP screenshoty — Keymoji je free, žádný paywall.

## Hotovo když

- App Store Connect submission má vyplněné všechny fieldy (název, subtitle, keywords, description, promotional text, support + privacy URL, kategorie) pro **EN i CZ** locale.
- Screenshoty pro required velikosti nahrané pro obě locale.
- App Privacy label nastaven na „Data Not Collected" a matchuje privacy policy.
- Listing copy verzovaná v `marketing/app-store/`.

## Rizika

- **Full Access vysvětlení** — App Store review je u custom keyboardů citlivý na „Allow Full Access". Description i screenshot 5 musí jasně říct, že Full Access je **jen** pro haptiku a zvuky kláves, ne pro data. Nesoulad s privacy labelem = rejection.
- **Nesoulad s privacy policy (task 13)** — `marketing/privacy-policy.html` aktuálně tvrdí, že Full Access je pro „haptic feedback" + „reading/writing preferences in a shared container". Obojí je nepřesné: (a) chybí **zvuky** (taky vyžadují Full Access), (b) přístup k shared containeru je gated **App Group entitlementem**, ne Full Accessem. Před submission sjednotit policy text i listing copy na pravdivé znění: „Full Access enables haptic feedback and key click sounds." (Drobná oprava task 13 artefaktu — flag, ne scope tohoto tasku.)
- **Privacy label vs. realita** — pokud do appky kdykoli přibude jakýkoli SDK se síťovým přístupem, label „Data Not Collected" přestane platit a je to App Store violation. Držet privacy claim doslova (viz README non-goal: žádné analytics/telemetry).
- **Název delší než 30 znaků** — „Keymoji – Private Keyboard" zkontrolovat byte count.

## Reference

- `~/Development/WidgetCoin/tasks/15-app-store-listing.md` — vzor tasku.
- `~/Development/WidgetCoin/tasks/marketing/` — vzor pro organizaci marketing artefaktů.
- Task 13 (`tasks/13-about-and-privacy.md`) — privacy policy + Constants URLs.
- Apple App Store Review Guidelines, 5.1.1 Privacy — <https://developer.apple.com/app-store/review/guidelines/#privacy>
- App Store screenshot specs — <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/>

## Codex review

**Skip** — žádná code logika, jen metadata a marketing artefakty.
