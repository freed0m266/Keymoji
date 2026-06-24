# Single completion language driven by the Accent set

iOS gives a custom keyboard **no** signal about the focused field's language or the device language — the
only language it exposes is the static `PrimaryLanguage` from the extension's Info.plist, which is `mul`
today and the adapter resolves to English. The previous model ([task 65](../../tasks/65-accent-aware-completions-capslock-limits.md))
therefore queried the system dictionary (`UITextChecker`) in an **English base + the Accent set's language,
additively** — so a user with e.g. a Czech accent set got English and Czech completions as equal peers and
saw English crowding their bar even though they'd picked Czech.

We **decide** to query the system dictionary in **exactly one language**, resolved by a fallback chain:
the Accent set's language when it names one (not *All*) → else the device's preferred language
(`Locale.preferredLanguages`) → else English. There is **no permanent English co-base**, and `state.currentLanguage`
(the `mul` Primary-language echo) no longer feeds completions. Implemented in
[task 78](../../tasks/78-completion-language-from-accent-set.md); glossary term *Completion language* in
[`CONTEXT.md`](../../CONTEXT.md).

## Considered alternatives

- **Keep the additive model (status quo).** Rejected — it's the source of the English-heavy bar; reordering
  the language list can't fix it because scores depend on a word's ordinal *within* its language, not on the
  list position.
- **Accent primary + English secondary (biased additive).** Keep querying both but weight the accent language
  so it wins. Rejected — it isn't "one language", needs a tuned scoring knob (more complexity), and English
  still occasionally leaks into an accent user's bar. The single-language chain solves the pain at the root.

## Consequences

- **An accent user loses English *dictionary* completions.** Softened, and the reason this is acceptable:
  *learned words* (personal recents) are **language-agnostic**, so English words the user actually types (≥2×)
  still surface. Only first-time dictionary completions of never-typed English words are lost — and those get
  learned on first use.
- **Accent = All now follows the device language** (`Locale.preferredLanguages`) instead of hardcoded English —
  a strict improvement for non-English users who keep the *All* set. English remains the final fallback when no
  device language is resolvable, and the adapter still maps any unsupported code to English.
- Reverses the *additive* half of task 65; the caps-lock / eligibility limits from task 65 are unchanged.
