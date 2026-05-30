import Foundation

/// Tokenization for word completion. Pure, UIKit-free, fully unit-testable.
///
/// Word characters: Unicode letters, digits, the apostrophe (`'`), and Unicode combining marks
/// (so "café", "naïve", "don't", "ipv6" stay whole). Everything else — whitespace, hyphen, the
/// `,.;:?!()[]{}/\@` punctuation family — is a word boundary. Hyphen is *out* by design so
/// "well-known" completes "known", not "well-known".
public enum WordPrefixExtractor {

	/// The word the user is currently composing (the trailing run of word characters before the
	/// cursor), or nil when there is no active prefix to complete.
	///
	/// Returns nil when:
	/// - `before` is nil/empty or ends on a boundary character (no in-progress word), or
	/// - the cursor sits mid-word: `before` ends with a word char *and* `after` begins with one
	///   (completing here would mangle the tail of an existing word, so the bar collapses).
	public static func activeWordPrefix(before: String?, after: String?) -> String? {
		guard let before, !before.isEmpty else { return nil }

		// Mid-word guard: caret wedged between two word characters.
		if let lastBefore = before.last, isWordCharacter(lastBefore),
		   let firstAfter = after?.first, isWordCharacter(firstAfter) {
			return nil
		}

		let chars = Array(before)
		var index = chars.count - 1
		var startOfWord = chars.count
		while index >= 0, isWordCharacter(chars[index]) {
			startOfWord = index
			index -= 1
		}
		guard startOfWord < chars.count else { return nil }
		return String(chars[startOfWord...])
	}

	/// The last *completed* word in `before` — the trailing word run after skipping any trailing
	/// boundary characters (the space or punctuation the user just typed). Used by the learning
	/// hook: after a word-boundary keystroke, this is the word to learn. Returns nil when there's
	/// no word to harvest.
	public static func lastCompletedWord(in before: String?) -> String? {
		guard let before, !before.isEmpty else { return nil }
		let chars = Array(before)
		var index = chars.count - 1
		// Skip the trailing boundary run (e.g. the just-typed " " or ". ").
		while index >= 0, !isWordCharacter(chars[index]) {
			index -= 1
		}
		guard index >= 0 else { return nil }
		let end = index + 1
		var startOfWord = end
		while index >= 0, isWordCharacter(chars[index]) {
			startOfWord = index
			index -= 1
		}
		return String(chars[startOfWord..<end])
	}

	/// A word character: Unicode letter, decimal digit, apostrophe, or combining mark.
	static func isWordCharacter(_ character: Character) -> Bool {
		if character == "'" { return true }
		if character.isLetter || character.isNumber { return true }
		// Standalone combining marks (rare — most arrive composed into a letter, but guard anyway).
		return character.unicodeScalars.allSatisfy { scalar in
			scalar.properties.isDiacritic
				|| CharacterSet.nonBaseCharacters.contains(scalar)
		} && !character.unicodeScalars.isEmpty
	}
}
