#!/usr/bin/env bash
#
# Regenerate `KeyboardCore/Resources/EmojiData.json` from upstream snapshots.
# Run by hand when bumping Unicode coverage or refreshing keyword annotations.
#
# Two upstream sources are merged:
#
#   1. muan/unicode-emoji-json @ UNICODE_TAG — canonical glyph + name + group.
#   2. muan/emojilib            @ EMOJILIB_TAG — keyword annotations per glyph.
#
# (unicode-emoji-json v0.9.0 dropped the `keywords` field; emojilib remains the
# de-facto keyword source. Both repos use compatible glyph keys.)
#
# Output layout (minimised, one entry per single-base-codepoint emoji):
#
#   [
#     {"g": "😀", "n": "grinning face", "k": ["face","smile","happy"], "c": "smileys"},
#     ...
#   ]
#
#   g = glyph (with U+FE0F variation selector preserved when upstream supplies one)
#   n = canonical CLDR short name (lowercased)
#   k = emojilib keyword list (lowercased, deduped, name token already stripped from upstream)
#   c = EmojiCategory raw value
#
# Filter rules:
#   - accept single base codepoint (one scalar, optionally followed by VS-16 / U+FE0F).
#   - accept keycap sequences (digit/# + VS-16 + U+20E3) — they're well-known glyphs that
#     users expect to surface when typing the matching digit into emoji search.
#   - skip ZWJ sequences and regional indicator pairs (flags stay hand-curated below in
#     `EmojiCatalog.flags`, never sourced from this dataset).

set -euo pipefail

# Pinned versions — bump intentionally when refreshing.
readonly UNICODE_TAG="v0.9.0"
readonly EMOJILIB_TAG="v3.0.12"

readonly UNICODE_URL="https://raw.githubusercontent.com/muan/unicode-emoji-json/${UNICODE_TAG}/data-by-emoji.json"
readonly EMOJILIB_URL="https://raw.githubusercontent.com/muan/emojilib/${EMOJILIB_TAG}/dist/emoji-en-US.json"

readonly REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly OUTPUT_FILE="${REPO_ROOT}/KeyboardCore/Resources/EmojiData.json"
readonly TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

readonly UNICODE_FILE="${TMP_DIR}/unicode-emoji-json.json"
readonly EMOJILIB_FILE="${TMP_DIR}/emojilib.json"

echo "Fetching ${UNICODE_URL}..."
curl --silent --show-error --fail --location "${UNICODE_URL}" -o "${UNICODE_FILE}"

echo "Fetching ${EMOJILIB_URL}..."
curl --silent --show-error --fail --location "${EMOJILIB_URL}" -o "${EMOJILIB_FILE}"

echo "Filtering and reshaping..."
# Upstream `group` values → our EmojiCategory raw values.
# `flags` is intentionally absent here — flags are hand-curated in EmojiCatalog.flags
# and never sourced from this dataset.
jq --compact-output --slurpfile keywords "${EMOJILIB_FILE}" '
  def category_for(group):
    {
      "Smileys & Emotion":           "smileys",
      "People & Body":               "people",
      "Animals & Nature":            "animals",
      "Food & Drink":                "food",
      "Activities":                  "activity",
      "Travel & Places":             "travel",
      "Objects":                     "objects",
      "Symbols":                     "symbols"
    }[group] // empty;

  # Strip the optional VS-16 (U+FE0F = 65039), then accept either:
  #   1. exactly one remaining scalar (single base codepoint), or
  #   2. base scalar + combining-enclosing-keycap (U+20E3 = 8419), i.e. the 12 keycap
  #      sequences `0..9 # *` paired with the keycap modifier.
  def is_single_base_or_keycap(glyph):
    (glyph | explode | map(select(. != 65039))) as $cp
    | ($cp | length) == 1
      or (($cp | length) == 2 and $cp[1] == 8419);

  ($keywords[0]) as $kw
  | to_entries
  | map(
      .value as $v
      | category_for($v.group) as $cat
      | select($cat != null)
      | select(is_single_base_or_keycap(.key))
      | (
          ($kw[.key] // [])
          # First entry in emojilib is the slug — drop it so `k` is pure keywords.
          | (if length > 0 then .[1:] else . end)
          | map(ascii_downcase)
          | unique
        ) as $tokens
      | {
          g: .key,
          n: ($v.name | ascii_downcase),
          k: $tokens,
          c: $cat
        }
    )
' "${UNICODE_FILE}" > "${OUTPUT_FILE}"

count="$(jq 'length' "${OUTPUT_FILE}")"
with_keywords="$(jq '[.[] | select(.k | length > 0)] | length' "${OUTPUT_FILE}")"
echo "Wrote ${count} entries to ${OUTPUT_FILE} (${with_keywords} with keyword annotations)"
