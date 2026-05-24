import Foundation

/// Sendable mirror of `UITextAutocapitalizationType`. v1.0 only acts on `.sentences`.
public enum AutocapitalizationType: Sendable, Equatable {
	case none
	case words
	case sentences
	case allCharacters
}

/// Pure function that decides whether the next typed character should be uppercased,
/// based on what's already in the document and what the host app requested.
///
/// v1.0 triggers: start of document, after `. `, `? `, `! `, or `\n\n` (paragraph break).
/// No heuristics for `Mr.`, ellipsis, etc.
public enum AutoCapitalizer {

	public static func shouldCapitalize(
		documentContextBeforeInput: String?,
		autocapitalizationType: AutocapitalizationType
	) -> Bool {
		// v1.0 honors only `.sentences` — everything else is a no-op.
		guard autocapitalizationType == .sentences else { return false }

		let context = documentContextBeforeInput ?? ""

		// Beginning of document — everything before the cursor is whitespace/empty.
		if context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return true
		}

		// After a sentence terminator + single space.
		if context.hasSuffix(". ") || context.hasSuffix("? ") || context.hasSuffix("! ") {
			return true
		}

		// New paragraph (two consecutive newlines).
		if context.hasSuffix("\n\n") {
			return true
		}

		return false
	}
}
