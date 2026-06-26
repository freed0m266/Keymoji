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
		autocapitalizationType: AutocapitalizationType,
		enabled: Bool
	) -> Bool {
		// Master toggle off → never promote, regardless of context or field trait (task 85).
		guard enabled else { return false }

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

	/// Applies (or reverts) the auto-cap page promotion to `state`, mirroring exactly what
	/// `KeyboardViewController.refreshAutoCapitalization` needs minus the UIKit glue (proxy reads,
	/// `rebuild()`). Pure and `KeyboardState`-only, so the period-vs-symbols pipeline can be exercised
	/// end-to-end in tests without a real text proxy (task 85). Returns `true` when `state.page` changed.
	///
	/// - Never touches a numeric page — auto-cap only ever flips `letters(.lower)` ↔ `letters(.upper)`
	///   (task 59). Numeric fields report `.none` autocap anyway, but the guard makes it explicit and
	///   independent of `textDidChange` ordering.
	/// - On a non-trigger context it reverts a *prior* auto-promotion (`autoCapitalized`) back to lower,
	///   but leaves a manual shift (`autoCapitalized == false`) untouched.
	@discardableResult
	public static func applyAutoCapitalization(
		to state: inout KeyboardState,
		documentContextBeforeInput: String?,
		autocapitalizationType: AutocapitalizationType,
		enabled: Bool
	) -> Bool {
		guard !state.page.isNumeric else { return false }

		let shouldCap = shouldCapitalize(
			documentContextBeforeInput: documentContextBeforeInput,
			autocapitalizationType: autocapitalizationType,
			enabled: enabled
		)

		if shouldCap {
			if case .letters(.lower) = state.page {
				state.page = .letters(.upper)
				state.autoCapitalized = true
				return true
			}
		} else if state.autoCapitalized {
			state.autoCapitalized = false
			if case .letters(.upper) = state.page {
				state.page = .letters(.lower)
				return true
			}
		}
		return false
	}
}
