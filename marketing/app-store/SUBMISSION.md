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

The app sends anonymous usage statistics via TelemetryDeck (task 86, ADR 0004) — so this is
**no longer "Data Not Collected"**. Declare exactly one data type: anonymised, not linked, untracked.

- [ ] "Data Collection" → **Yes, we collect data from this app.**
- [ ] Data type: **Usage Data → Product Interaction** (which settings are used, app/feature
      lifecycle events, coarse counts). Purpose: **Analytics** (and App Functionality).
      - **Linked to the user? No** — TelemetryDeck uses an on-device double-hashed anonymous ID;
        no account, no IDFA.
      - **Used for tracking? No** — no cross-app / cross-developer tracking, no data brokers, so
        no ATT prompt. Net label: **"Usage Data (Product Interaction) — Not Linked to You — Not
        Used for Tracking"**.
- [ ] **Never declare content.** No typed text, learned words, favourites, or searches leave the
      device (boundary 2, ADR 0004). Every emitted field maps to a settings *state*, a lifecycle
      event, or a coarse bucket — if it can't, it isn't collected.
- [ ] **StoreKit / IAP.** The purchase/restore network call is Apple's, not ours — we run no
      server and receive no purchase data. Only declare a "Purchases" data type if ASC's
      questionnaire forces it (then: not linked, not used for tracking).
- [ ] This must match [`../privacy-policy.html`](../privacy-policy.html) **exactly**. The policy
      now discloses TelemetryDeck, what's collected, and the opt-out — re-upload the current
      `privacy-policy.html` to `https://martinfreedom.com/keymoji/privacy.html` so the hosted page
      matches before submitting.
- [ ] **Listing copy follow-up:** the IAP-reconciled Description in [`listing-en.md`](listing-en.md)
      must be re-mirrored into `fastlane/metadata/en-GB/`, then run [`check-lengths.sh`](check-lengths.sh)
      and `fastlane ios upload_metadata`. Promo text ("zero tracking") is unchanged — still true
      (TelemetryDeck does no cross-app tracking, which is what Apple's "tracking" means).

## Screenshots

Required device sizes: **6.9" (iPhone 16 Pro Max)** and **6.5" (iPhone 11 Pro Max
/ XS Max class)**. Capture from the simulator; store source PNGs under
`marketing/app-store/screenshots/`.

1. [ ] Keyboard in action (typing a message) — hero shot, native parity (task 35)
2. [ ] Emoji mode + favorites / shortcodes (tasks 17, 18, 32)
3. [ ] Word completion suggestion bar (task 40)
4. [ ] Host app Settings — haptics, sound, QWERTY/QWERTZ, light/dark toggles
5. [ ] Onboarding "Allow Full Access for haptics" screen (tasks 11, 38)
6. [ ] (optional) About screen with the privacy statement (task 13)

## Review notes (App Review Information)

Recommended note to pre-empt the custom-keyboard Full Access question:

> Keymoji requests "Allow Full Access" solely to use the haptic feedback API,
> which iOS gates behind Full Access for keyboard extensions.
> The keyboard extension contains no networking code and makes no network requests;
> nothing you type ever leaves the device. The app sends only anonymous, opt-out
> usage statistics (which settings are used — never content) via TelemetryDeck.
> Full Access is optional — all typing features work without it.

## Final gate

- [ ] `check-lengths.sh` passes.
- [ ] Privacy label, privacy policy, and listing copy all tell the same story:
      Full Access is for haptic feedback only (**not** data, **not** the
      shared container, which the App Group entitlement gates), and the only data
      leaving the device is anonymous, opt-out usage statistics — never content.
- [ ] Screenshots uploaded for both sizes.
