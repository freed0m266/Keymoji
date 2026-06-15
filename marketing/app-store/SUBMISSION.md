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

- [ ] **Name / Subtitle / Keywords / Promotional text / Description** — pushed by
      `fastlane ios upload_metadata` (mirrors the listing file), or paste from it.
- [ ] **Primary category:** Utilities · **Secondary:** Productivity
- [ ] **Support URL:** `https://martinfreedom.com`
- [ ] **Marketing URL** (optional): `https://martinfreedom.com/keymoji`
- [ ] **Privacy Policy URL:** `https://martinfreedom.com/keymoji/privacy.html`
- [ ] Localizations: **English**.

## In-App Purchase — Keymoji Plus (task 63)

One non-consumable unlock. **Must be created in ASC before the build can be reviewed.**

- [ ] Create In-App Purchase **`com.freedommartin.keymoji.plus`**
      - Type: **Non-Consumable**
      - Reference name: **Keymoji Plus**
      - Price: **$3.99 (Tier 4)** / 99 Kč
      - Localized **Display Name**: "Keymoji Plus"
      - Localized **Description**: "Unlock unlimited favorite emoji, multiple favorite
        pages, and auto-sort by most-used. One-time purchase, no subscription."
        (ASC rejects emoji in IAP metadata — keep it text-only, like the app Description.)
- [ ] Attach the IAP to the version and submit it **with** the build (first review of a
      new IAP must accompany an app submission).
- [ ] Local simulator testing uses `Keymoji/Resources/Keymoji.storekit` (wired into the
      Keymoji run scheme) — ASC product not required for that.
- [ ] Sandbox-test buy + **Restore** on device before submitting (Restore is mandatory
      for non-consumables; the paywall already exposes it).

## App Privacy ("nutrition label")

Keymoji collects nothing — set every section to **Data Not Collected**.

- [ ] "Data Collection" → **No, we do not collect data from this app.**
- [ ] **StoreKit / IAP does not change this.** The purchase/restore network call is Apple's,
      not ours — we run no server and receive no data. Purchases are not linked to the user by
      us and are not used for tracking. Keep **Data Not Collected**; only declare a "Purchases"
      data type if ASC's questionnaire forces it (then: not linked, not used for tracking).
- [ ] This must match [`../privacy-policy.html`](../privacy-policy.html) **exactly**. The
      absolute "no network requests at all" wording was softened (task 63) to disclose Apple's
      purchase check — re-upload the current `privacy-policy.html` to
      `https://martinfreedom.com/keymoji/privacy.html` so the hosted page matches.
- [ ] **Listing copy follow-up:** the IAP-reconciled Description in [`listing-en.md`](listing-en.md)
      must be re-mirrored into `fastlane/metadata/en-GB/`, then run [`check-lengths.sh`](check-lengths.sh)
      and `fastlane ios upload_metadata`. Promo text ("zero tracking") is unchanged — still true.

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
