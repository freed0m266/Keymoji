import UIKit
import KeyboardCore

/// Bridges `UITextChecker` to `KeyboardCore.TextChecking`. Lives in the extension target because it
/// imports UIKit; `KeyboardCore` stays UIKit-free.
///
/// `@unchecked Sendable`: holds a `UITextChecker` (not formally `Sendable`) but is only ever
/// touched on the main actor where the keyboard runs.
final class UITextCheckerAdapter: TextChecking, @unchecked Sendable {
	private let checker: UITextChecker

	init(_ checker: UITextChecker) {
		self.checker = checker
	}

	func completions(forPartialWord partialWord: String, language: String) -> [String] {
		guard !partialWord.isEmpty else { return [] }
		// `UITextChecker` is main-actor-isolated, but `TextChecking` is nonisolated so providers stay
		// pure/Sendable. The keyboard only ever computes suggestions on the main actor (makeRoot →
		// currentSuggestions, all main-isolated), so asserting isolation here is safe.
		return MainActor.assumeIsolated {
			let resolved = Self.resolveLanguage(language)
			let range = NSRange(location: 0, length: (partialWord as NSString).length)
			return checker.completions(forPartialWordRange: range, in: partialWord, language: resolved) ?? []
		}
	}

	/// Maps a BCP-47-ish tag (e.g. "en-US", "cs") onto a language `UITextChecker` actually supports:
	/// exact tag → base language → a regional variant of that base → English → any available language.
	/// The base→regional step matters because iOS ships most dictionaries *only* regionally (`cs_CZ`,
	/// `de_DE`, `pt_BR` — there is no bare `cs`/`de`/`pt`), so the accent/device completion language
	/// (task 78) arrives as a bare code that would otherwise collapse straight to English. Without this
	/// whole chain `completions` silently returns nothing for an unsupported tag.
	///
	/// Snapshot of `UITextChecker.availableLanguages`, computed once (task 73, Phase B). The list is
	/// fixed for the process lifetime, so rebuilding the `Set` on every keystroke was pure waste. The
	/// ordered list is kept too so the final fallback stays deterministic (Set ordering isn't).
	@MainActor private static let availableLanguagesList: [String] = UITextChecker.availableLanguages
	@MainActor private static let availableLanguages: Set<String> = Set(availableLanguagesList)

	/// `@MainActor` because the cached `UITextChecker.availableLanguages` snapshot is main-actor state;
	/// this is only ever called from inside the `MainActor.assumeIsolated` block above, so isolation holds.
	@MainActor
	private static func resolveLanguage(_ language: String) -> String {
		let available = availableLanguages
		let normalized = language.replacingOccurrences(of: "-", with: "_")

		if available.contains(normalized) {
			return normalized
		}
		let base = String(normalized.prefix { $0 != "_" })

		if available.contains(base) {
			return base
		}
		// A bare/unmatched code whose dictionary ships only regionally (`cs` → `cs_CZ`, `pt` → `pt_BR`)
		// resolves to a regional variant of the *same* language before falling back to English — else a
		// perfectly good accent/device dictionary would be lost. English keeps its `en_US`-preferred
		// pick; other bases take the first available variant (ordered list → deterministic).
		if base == "en", available.contains("en_US") {
			return "en_US"
		}
		if let regionalVariant = availableLanguagesList.first(where: { $0.hasPrefix(base + "_") }) {
			return regionalVariant
		}
		// No dictionary at all for this language (e.g. `sk`, `ja`) → English, then any available language.
		if let englishVariant = available.first(where: { $0 == "en_US" || $0.hasPrefix("en") }) {
			return englishVariant
		}
		return availableLanguagesList.first ?? "en_US"
	}
}

/// Bridges Apple's supplementary lexicon to `KeyboardCore.SystemLexiconProviding`. Holds a plain
/// snapshot of `(trigger, expansion)` string pairs — no UIKit objects — so it's a trivially
/// `Sendable` value type. The controller snapshots `UILexicon.entries` into this form when the
/// lexicon arrives (off the main actor) and hands the result over.
struct UILexiconAdapter: SystemLexiconProviding {
	private let entries: [(trigger: String, expansion: String)]

	init(entries: [(trigger: String, expansion: String)]) {
		self.entries = entries
	}

	func entries(matchingPrefix prefix: String) -> [String] {
		let lowered = prefix.lowercased()
		var seen = Set<String>()
		var result: [String] = []
		for entry in entries where !entry.expansion.isEmpty {
			let matches = entry.trigger.lowercased().hasPrefix(lowered)
				|| entry.expansion.lowercased().hasPrefix(lowered)
			if matches, seen.insert(entry.expansion).inserted {
				result.append(entry.expansion)
			}
		}
		return result
	}
}

/// Maps UIKit field traits onto `KeyboardCore`'s UIKit-free mirror enums so the eligibility matrix
/// can live (and be unit-tested) in `KeyboardCore`. Same pattern as `AutocapitalizationTypeMapping`.
enum SuggestionFieldTraitsMapping {
	static func keyboardKind(_ type: UIKeyboardType) -> KeyboardInputKind {
		switch type {
		case .default:                return .default
		case .asciiCapable:           return .asciiCapable
		case .numbersAndPunctuation:  return .numbersAndPunctuation
		case .URL:                    return .url
		case .numberPad:              return .numberPad
		case .phonePad:               return .phonePad
		case .namePhonePad:           return .namePhonePad
		case .emailAddress:           return .emailAddress
		case .decimalPad:             return .decimalPad
		case .twitter:                return .twitter
		case .webSearch:              return .webSearch
		case .asciiCapableNumberPad:  return .asciiCapableNumberPad
		@unknown default:             return .default
		}
	}

	static func contentKind(_ type: UITextContentType?) -> TextContentKind? {
		guard let type else { return nil }
		switch type {
		case .password:         return .password
		case .newPassword:      return .newPassword
		case .oneTimeCode:      return .oneTimeCode
		case .creditCardNumber: return .creditCardNumber
		case .emailAddress:     return .emailAddress
		// The name family is on the privacy deny-list (never learned).
		case .name, .namePrefix, .givenName, .middleName, .familyName, .nameSuffix, .nickname:
			return .name
		default:                return .other
		}
	}
}
