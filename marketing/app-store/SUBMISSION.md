# App Store Connect — submission checklist

Manual steps for the first Keymoji submission. The text fields live in
[`listing-en.md`](listing-en.md). Run [`check-lengths.sh`](check-lengths.sh)
before pasting to confirm every field still fits its character limit.

## Before you start

- [ ] Real app icon shipped (task 28) — ASC and screenshots both need it.
- [ ] Privacy policy live at `https://martinfreedom.com/keymoji/privacy.html` (upload the
      current [`../privacy-policy.html`](../privacy-policy.html) — the in-app
      `KeymojiURLs.privacyPolicy` already points here).
- [ ] UI is final for screenshots (tasks 35 redesign, 40 suggestions, 18/32 favorites).

## App information

- [ ] **Name / Subtitle / Keywords / Promotional text / Description** — paste from the
      listing file.
- [ ] **Primary category:** Utilities · **Secondary:** Productivity
- [ ] **Support URL:** `https://github.com/freed0m266/Keymoji`
- [ ] **Marketing URL** (optional): `https://martinfreedom.com/keymoji`
- [ ] **Privacy Policy URL:** `https://martinfreedom.com/keymoji/privacy.html`
- [ ] Localizations: **English**.

## App Privacy ("nutrition label")

Keymoji collects nothing — set every section to **Data Not Collected**.

- [ ] "Data Collection" → **No, we do not collect data from this app.**
- [ ] This must match [`../privacy-policy.html`](../privacy-policy.html) **exactly**.
      If any networked SDK is ever added, this label becomes false and is an App
      Store violation — see the privacy non-goal in `tasks/README.md`.

## Screenshots

Required device sizes: **6.9" (iPhone 16 Pro Max)** and **6.5" (iPhone 11 Pro Max
/ XS Max class)**. Capture from the simulator; store source PNGs under
`marketing/app-store/screenshots/`.

1. [ ] Keyboard in action (typing a message) — hero shot, native parity (task 35)
2. [ ] Emoji mode + favorites / shortcodes (tasks 17, 18, 32)
3. [ ] Word completion suggestion bar (task 40)
4. [ ] Host app Settings — haptics, sound, QWERTY/QWERTZ, light/dark toggles
5. [ ] Onboarding "Allow Full Access for haptics & sound" screen (tasks 11, 38)
6. [ ] (optional) About screen with the privacy statement (task 13)

## Review notes (App Review Information)

Recommended note to pre-empt the custom-keyboard Full Access question:

> Keymoji requests "Allow Full Access" solely to use the haptic feedback and key
> click sound APIs, which iOS gates behind Full Access for keyboard extensions.
> The app contains no networking code, makes no network requests, and collects
> no data. Full Access is optional — all typing features work without it.

## Final gate

- [ ] `check-lengths.sh` passes.
- [ ] Privacy label, privacy policy, and listing copy all tell the same Full Access
      story (haptics + key click sounds — **not** data, **not** the shared container,
      which is gated by the App Group entitlement rather than Full Access).
- [ ] Screenshots uploaded for both sizes.
