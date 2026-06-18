# Keymoji

A custom iOS emoji-completion keyboard. This glossary fixes the vocabulary for the keyboard's
input behaviour and settings so code, UI copy, and discussion stay aligned.

## Language

**Accent set**:
The per-language collection of diacritic letters offered when a base letter key is long-pressed
(e.g. the Czech set surfaces `č š ž …` under `c s z`). Primarily a long-press alternates picker; it
*additionally* contributes its language to the word-completion dictionary (English base + the
accent's language, merged). It does **not** affect the keyboard layout or the system
keyboard-switcher label. Modelled by `LetterAlternateSet`.
_Avoid_: keyboard language, locale, input language.

**Keyboard layout**:
The physical key arrangement, `qwerty` or `qwertz`. Independent of the accent set.

**Primary language**:
The static `PrimaryLanguage` declared in the keyboard extension's Info.plist. Drives the label iOS
shows in the system keyboard switcher (the globe menu) and is fixed at build time — it cannot react
to in-app settings. At runtime it is echoed by `state.currentLanguage` (`textInputMode?.primaryLanguage`);
for a custom keyboard iOS does **not** expose the focused field's own language, so the two are the same
value, and `currentLanguage` is the base of the completion-dictionary language list (see *Accent set*).

**Learned word**:
A word Keymoji has observed the user type and persists (capped pool) to offer as a future
completion. Stored lowercased in the app-group container; PII-adjacent.

**Number row**:
The optional digit row `1234567890` shown above the letters, gated by the user's "Always show
number row" setting. A Keymoji addition, not a native iOS element. Never shown in landscape or in
emoji-search.
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
