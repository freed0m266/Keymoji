# Keymoji

A custom iOS emoji-completion keyboard. This glossary fixes the vocabulary for the keyboard's
input behaviour and settings so code, UI copy, and discussion stay aligned.

## Language

**Accent set**:
The per-language collection of diacritic letters offered when a base letter key is long-pressed
(e.g. the Czech set surfaces `č š ž …` under `c s z`). Primarily a long-press alternates picker; it
also *selects* the language Keymoji's word-completion dictionary is queried in whenever it names one
(see *Completion language*). It does **not** affect the keyboard layout or the system
keyboard-switcher label. Modelled by `LetterAlternateSet`.
_Avoid_: keyboard language, locale, input language.

**Keyboard layout**:
The physical key arrangement, `qwerty` or `qwertz`. Independent of the accent set.

**Primary language**:
The static `PrimaryLanguage` declared in the keyboard extension's Info.plist (`mul` today). Drives
**only** the label iOS shows in the system keyboard switcher (the globe menu); fixed at build time, it
cannot react to in-app settings. Echoed at runtime by `state.currentLanguage`
(`textInputMode?.primaryLanguage`), but for a custom keyboard iOS exposes through it neither the
focused field's language nor the device language — so it carries no useful locale signal and does
**not** drive completions (see *Completion language*).

**Completion language**:
The single language Keymoji queries the system dictionary (`UITextChecker`) in for word completions.
Resolved by a fallback chain: the *Accent set*'s language when it names one (i.e. not *All*) → else the
device's preferred language (`Locale.preferredLanguages`) → else English. Exactly one language is
queried — there is no permanent English co-base — and an unsupported code resolves to English
downstream. Orthogonal to *learned words*, which are language-agnostic and surface regardless of this
choice.
_Avoid_: keyboard language, input language, system language (the chain only *falls back* to it when the accent set is *All*).

**Learned word**:
A word Keymoji has observed the user type and persists (capped pool) to offer as a future
completion. Stored lowercased in the app-group container; PII-adjacent. *Learned* is not *offered*: a
word is stored from its first sighting but only surfaced as a suggestion — and only listed in the
learned-words editor — once it has been seen at least a fixed minimum number of times, applied
uniformly to prose words and email addresses alike (no per-kind exemption). Sub-threshold singletons
stay stored but invisible; *Clear all* is the only way to purge them.

**Number row**:
The optional digit row `1234567890` shown above the letters, gated by the user's "Always show
number row" setting. A Keymoji addition, not a native iOS element. Never shown in landscape or in
emoji-search. Digits carry no long-press shortcut (task 69 dropped the old `1→!` … `0→)` alternates);
the shifted symbols live on the *symbols page*.
_Avoid_: digit row, numbers bar.

**Symbols page**:
The non-letter key page reached via the `123` key. Has two sub-pages — the *primary symbol page*
(`123`) and the *alternate symbol page* (`#+=`) — switched by an in-row toggle.
_Avoid_: symbol keyboard, punctuation page.

**Primary symbol page**:
First sub-page of the *symbols page* (`123` toggle). Carries digits when no *number row* is visible
in that context; otherwise carries the bracket/math row. Mirrors the native iOS `123` page when
digits are present.
_Avoid_: symbols 1, page one.

**Alternate symbol page**:
Second sub-page of the *symbols page* (`#+=` toggle). Carries the less-common symbols.
_Avoid_: symbols 2, extra symbols.

## Input gestures

**Trackpad mode**:
The cursor-scrubbing state entered by holding the *space* key: the keyboard stops acting as keys and
the surface becomes a cursor pad. Entry is a **timed hold alone** (~350 ms, no drag required); on entry
a distinct haptic fires, every key's glyph vanishes (the key bodies stay, slightly shaded) and the
suggestion bar recedes. Finger movement then scrubs the text cursor — horizontal by character, vertical
by line. Exits on release; releasing without having moved types **nothing** (no space). Backed by
`isTrackpadActive` and the `onTrackpadModeChanged` callback.
_Avoid_: cursor mode, scrub mode, swipe-to-move, space-drag.

## Lifecycle

**What's New version**:
A monotonic integer marking the app's current *announcement content* — bumped by hand whenever new
What's-New copy is written, deliberately decoupled from the marketing/app version (a bugfix release
can ship without a bump; two announcements can land in one release). The last value a device has seen
is persisted (app-group). The What's-New screen shows once when the stored value trails the current
one, then the stored value catches up. A fresh install **seeds** the stored value to the current one
(seed-on-absence), so What's New surfaces only on a later *update*, never on first install. Distinct
from the marketing version shown in About.
_Avoid_: app version (it isn't), build number, schema/data version (that's migrations — a separate concern).

## Monetization

**Keymoji Plus**:
The non-consumable in-app purchase entitlement (`com.freedommartin.keymoji.plus`, $3.99 / 99 Kč). Source of
truth `AppGroupStore.isPlus`, paid-only, permanent once owned. Does **not** include trial activations — those
live alongside as the *Plus trial expiry*.
_Avoid_: Premium, Pro, subscription.

**Welcome Plus trial**:
An **opt-in** 30-day Plus grant offered during onboarding (and in Settings until consumed). One-shot per
device; recorded in Keychain. Activating it sets the *Plus trial expiry*.
_Avoid_: Free trial (subscription-flavoured), preview, intro period.

**Plus trial expiry**:
A single `Date?` (`AppGroupStore.promoPlusExpiresAt`, mirrored from Keychain), set by the *Welcome Plus
trial* to `now + 30d`.
_Avoid_: Trial end, expiration date (overloaded), grant deadline.

**Effective Plus**:
The unified entitlement used at every gate (favorites limit, frequency sort, paging, paywall headlines):
`paid OR (promoPlusExpiresAt != nil && now < promoPlusExpiresAt)`. `AppGroupStore.isPlus` deliberately stays
paid-only so the StoreKit truth source stays clean.
_Avoid_: Has Plus (ambiguous), entitled.
