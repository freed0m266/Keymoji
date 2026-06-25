import Foundation

/// Tokenization for word completion. Pure, UIKit-free, fully unit-testable.
///
/// The word boundary is **whitespace and newline only** (task 79 / ADR 0003): every other character —
/// letters, digits, `.`, `@`, hyphen, apostrophe and the rest of the punctuation family — is part of
/// the word. So an in-progress address (`sv.mar@e`) stays one token, prefix-matches a stored
/// `sv.mar@email.cz`, and accept deletes exactly that run. The punctuation the old boundary conflated
/// is handled downstream at *learn* time by the normalize/classify step (`wordCore` + `isEmailShaped`),
/// not by shredding the token here.
public enum WordPrefixExtractor {

	/// The word the user is currently composing (the trailing run of word characters before the
	/// cursor), or nil when there is no active prefix to complete.
	///
	/// Returns nil when:
	/// - `before` is nil/empty or ends on whitespace/newline (no in-progress word), or
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

	/// The last *completed* token in `before` — the trailing run of word characters after skipping any
	/// trailing whitespace (the space the user just typed). With the whitespace-only boundary this run
	/// can carry attached punctuation (`ahoj,`, `e.g.`); the learning hook normalizes it with `wordCore`
	/// before classifying. Returns nil when there's no token to harvest (only whitespace).
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

	/// `token` with leading/trailing non-alphanumeric characters stripped, leaving *internal* punctuation
	/// intact (`"ahoj," → "ahoj"`, `"(e.g.)" → "e.g"`, `"sv.mar@email.cz"` unchanged, `"+420…" → "420…"`).
	/// The whitespace-only tokenizer keeps edge punctuation attached to a harvested token; this
	/// normalizes it before the learning hook classifies it (task 79 / ADR 0003). Returns nil when the
	/// token has no alphanumeric content at all (`"..."`, `":"`).
	static func wordCore(of token: String) -> String? {
		let chars = Array(token)
		guard let first = chars.firstIndex(where: isAlphanumeric),
		      let last = chars.lastIndex(where: isAlphanumeric) else { return nil }
		return String(chars[first...last])
	}

	/// True when `token` is shaped like a full email address (`local@domain.tld`, with a ≥2-letter TLD,
	/// ≤100 chars). The store-side gate for learning a prose-typed address as a single `.emailAddress`
	/// token: a token containing `@` is learned only when this holds, so a half-typed `sv.mar@email` or a
	/// TLD-less `foo@bar` is dropped rather than stored as a fragment. Replaces the old `trailingEmail`
	/// reassembly — the whitespace-only tokenizer already delivers the whole address as one token, so
	/// this only has to recognize it (`^…$`), never rebuild it.
	static func isEmailShaped(_ token: String) -> Bool {
		guard token.count <= PersonalRecentsStore.maxEmailLength, let regex = emailRegex else { return false }
		let range = NSRange(token.startIndex..., in: token)
		return regex.firstMatch(in: token, options: [], range: range) != nil
	}

	/// `local@domain.tld` anchored to the *whole* string. Compiled once and shared (`NSRegularExpression`
	/// is immutable and thread-safe).
	private static let emailRegex = try? NSRegularExpression(
		pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
	)

	/// A word character: anything that is **not** whitespace or a newline (task 79 / ADR 0003). The
	/// boundary is purely whitespace now; everything else (`.`, `@`, hyphen, apostrophe, digits, letters,
	/// combining marks) is part of the token.
	static func isWordCharacter(_ character: Character) -> Bool {
		!character.isWhitespace && !character.isNewline
	}

	/// A letter or decimal digit — the "content" characters `wordCore` trims toward.
	private static func isAlphanumeric(_ character: Character) -> Bool {
		character.isLetter || character.isNumber
	}
}
