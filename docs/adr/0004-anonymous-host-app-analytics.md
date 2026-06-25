# Anonymous host-app analytics with a precise (not absolute) privacy claim

Keymoji shipped an **absolute** privacy promise — in-app *„no network access, no analytics, and no
third-party SDKs — nothing you type is ever sent off your iPhone"* ([Localizable.strings:180](../../KeymojiResources/Resources/en.lproj/Localizable.strings)),
a planned App Store **„Data Not Collected"** label, and a *„zero tracking"* promo line. The roadmap also
listed *„analytics, telemetry"* as a deliberate non-goal. But to know **which settings users adopt** and
**who the audience is** (so updates can be prioritised), aggregate data is needed, and that is impossible
on-device — own-device stats carry no signal. The goal genuinely requires sending data off the phone.

Decision ([task 86](../../tasks/86-anonymous-host-app-analytics-telemetrydeck.md)): adopt **TelemetryDeck**
for **anonymous, host-app-only** analytics, and **reword the claim to be precise rather than absolute**.
Three hard boundaries keep the strongest part of the promise literally true:

1. **Host app only.** The keyboard extension never links the SDK and never makes a network call — *„nothing
   you type is ever sent off your iPhone"* stays literally true. The host app reads settings from the App
   Group and emits them itself.
2. **Never any content.** No keystrokes, learned words, favourites, or search queries — only *settings
   states* and lifecycle/funnel events.
3. **Anonymous only.** TelemetryDeck's on-device double-hashed anonymous ID; no PII, no IDFA → no ATT prompt.

Collection is **opt-out, default on**. What changes in the wording: *„no analytics"* → „anonymous usage
statistics (opt-out, never content)", and *„no third-party SDKs"* is dropped/qualified (the SDK lives only
in the host app). *„zero tracking"* **stays valid** — TelemetryDeck does no cross-app tracking, which is what
Apple's „tracking" means. Architecturally, the `AnalyticsServicing` protocol may live in KeymojiCore (clean,
SDK-free), but the `TelemetryDeckAnalyticsService` implementation must live in a host-app-only target —
KeymojiCore is linked into the extension (`APPLICATION_EXTENSION_API_ONLY = YES`), so the SDK must not reach it.

Decided **before first public submission** (`PREPARE_FOR_SUBMISSION`), the cheapest possible moment: no user
was ever promised the absolute claim, so there is no trust to retroactively spend.

## Considered alternatives

- **Hold the absolute claim, no analytics.** Keeps „we collect nothing" literally true — a strong asset for
  a *keyboard* (users rightly fear keyloggers). Rejected: every product decision stays blind; the stated
  goal can't be met at all.
- **Firebase / Mixpanel (full product analytics).** More power. Rejected: breaks the whole positioning,
  worsens the App Store privacy label, and a Google/Mixpanel SDK is exactly the third-party-tracking SDK the
  app brags about *not* having.

## Consequences

- App Store privacy label moves from „Data Not Collected" to **„Usage Data (Product Interaction) — Not Linked
  to You — Not Used for Tracking"**; the in-app statement, `marketing/privacy-policy.html` (en + cs, re-uploaded),
  `listing-en.md`, `SUBMISSION.md`, and the roadmap non-goal are all reconciled within task 86.
- The label/policy must match real behaviour before submit — boundary 2 (never content) is enforced in code
  review, not just docs.
