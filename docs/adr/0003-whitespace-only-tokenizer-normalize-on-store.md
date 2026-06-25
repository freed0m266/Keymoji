# Whitespace-only word tokenizer with normalize-on-store

The word-completion tokenizer ([`WordPrefixExtractor`](../../KeyboardCore/Sources/Logic/Suggestions/WordPrefixExtractor.swift))
treated digits-as-word but `.`, `@`, hyphen and the `,.;:?!()[]{}/\` family as **hard word boundaries**.
That made a learned email address impossible to re-offer mid-typing: typing `sv` matches the stored
`sv.mar@email.cz`, but the moment the user types the `.` the active prefix collapses to empty and the chip
vanishes — the user can never get past the first dot of their own address. A second regex path
(`trailingEmail`) already existed precisely to re-assemble an address the tokenizer had shredded into
`gmail`/`com` fragments, which is a smell: the tokenizer was fighting the data.

We **decide** to make the tokenizer boundary **whitespace (and newline) only** — everything else, including
`.`/`@`/digits, is part of the word. So the active prefix is the whole run since the last space
(`sv.mar@e` stays one token, prefix-matches the stored address, and accept deletes exactly the right run for
free). The punctuation handling that the old boundary conflated is split into the three distinct concepts it
always was:

1. **Tokenizer boundary** — whitespace only (drives the completion prefix and the harvested token).
2. **Learning trigger** — still fires on `[" " . , ! ?]` so an end-of-sentence word is learned without a
   trailing space (kept deliberately asymmetric with the tokenizer — see Consequences).
3. **Store shape filter** — on learn, **trim leading/trailing non-alphanumerics**, then classify: a token
   containing `@` is stored only if it matches the email regex (`local@domain.tld`, ≤100 chars), otherwise a
   non-`@` token is stored on the existing prose length rule `[3, 25]`. This absorbs and replaces the old
   `trailingEmail` reassembly.

Implemented in [task 79](../../tasks/79-whitespace-word-tokenizer-email-completion.md).

## Considered alternatives

- **A dedicated email-prefix provider** (dot-inclusive trailing token matched against learned `@`-tokens),
  tokenizer untouched. Rejected — it *adds* a provider and a parallel notion of "word", growing complexity to
  paper over a tokenizer that was splitting data it shouldn't. Simplifying the tokenizer deletes more than it
  adds and fixes the accept-deletion math as a side effect.
- **Collapse everything to whitespace, including the learning trigger.** Rejected — losing `.`/`,`/`!`/`?` as
  learn triggers would stop learning the last word of a message sent without a trailing space (common in
  chat). Keeping the trigger set is free and preserves that behavior.

## Consequences

- **Boundary and learn-trigger are intentionally asymmetric.** A future reader will see "boundary = whitespace
  only" next to "learn triggers still include punctuation" and may want to "fix" the inconsistency — don't.
  The store's edge-trim + email-shape gate is what makes harvesting on a `.`/`,` safe (`ahoj,` → `ahoj`,
  `sv.mar@email.` → dropped as non-email, full address stored only on the closing space).
- **`trailingEmail` is repurposed**, not kept: its regex becomes the store-side email-shape detector; the
  tokenizer no longer needs to re-assemble addresses.
- **Prose tokens can now contain internal punctuation** (`well-known`, `3.14` are single learned tokens). The
  `[3, 25]` length gate and the display-time `minSuggestCount` threshold keep this from polluting suggestions.
- **`@`-token completions bypass smart-capitalization** and insert the stored lowercase form, so an
  auto-capitalized `Sv…` prefix doesn't yield `Sv.mar@email.cz`.
- The hot path gets marginally *cheaper* (`!isWhitespace` vs the letter/digit/diacritic check); the only added
  cost is the email regex at learn time (debounced, off the keystroke path).
- **Store and lookup are deliberately asymmetric for *leading* edge punctuation.** `wordCore` trims edge
  punctuation only at *learn* time, but the lookup prefix (`activeWordPrefix`) keeps it (no punctuation
  special-casing in the tokenizer, by decision above). So a token retyped *with* a leading punctuation char
  isn't re-offered: a `+420…` phone is stored as `420…` but typing `+420…` again yields the prefix `+420…`,
  which prefix-matches nothing (it lands in a different `LearnedWordsIndex` bucket). This retires the task-74
  "offers `+420…` as `420…`" behavior. Accepted as a minor consequence of the simpler model — typing the number
  *without* the `+` still completes, and adding a symmetric lookup-side trim would re-introduce the
  special-casing this ADR removed (and would eat the typed `+` on accept). Trailing edge punctuation is *not*
  asymmetric: it's mid-token while composing, so it stays in the prefix and the accept deletes the exact run.
