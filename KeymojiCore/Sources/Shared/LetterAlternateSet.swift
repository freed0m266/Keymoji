import Foundation

/// Which language's diacritic set the long-press alternates use. Persisted as a string
/// in `AppGroupStore` under `letterAlternateSet`. The actual per-set character maps live
/// in `LayoutBuilder` (KeyboardCore) — this enum is just the selector, mirroring how
/// `LetterLayout` selects row data.
public enum LetterAlternateSet: String, Sendable, CaseIterable {
	case czech
	case slovak
	case german
	case polish
	case french
	case spanish
	/// Union / comprehensive map (today's behavior). Fallback for bilingual users and
	/// unsupported locales.
	case all

	/// Locale-derived default used when the user hasn't explicitly chosen a set.
	/// Language primary (direct signal of what the user writes), region fallback
	/// (catches e.g. a Czech with an English phone UI), `.all` as last resort.
	///
	/// Both inputs default to values derived from the device locale but are injectable so the
	/// detection can be unit-tested without mutating `Locale` globally. `Locale.preferredLanguages`
	/// entries can be regional (`"en-CZ"`, `"zh-Hans-CN"`), so the language code is parsed via
	/// `Locale(identifier:).language.languageCode` rather than a string split; a missing/empty code
	/// simply misses `byLanguage` and falls through to the region (and ultimately `.all`).
	public static func detectedDefault(
		preferredLanguageCode: String? = Locale.preferredLanguageCode,
		regionCode: String? = Locale.current.region?.identifier
	) -> LetterAlternateSet {
		if let lang = preferredLanguageCode, let set = byLanguage[lang] {
			return set
		}
		if let region = regionCode, let set = byRegion[region] {
			return set
		}
		return .all
	}

	/// Language whose dictionary this accent set contributes to word completion, or `nil` when the
	/// set isn't a single concrete language (`.all`). This is the primary link in the completion
	/// chain (`completionLanguage(deviceLanguageCode:)`); on-device availability is handled
	/// downstream by `UITextCheckerAdapter.resolveLanguage` (a missing dictionary falls back to
	/// English).
	public var accentLanguageCode: String? {
		Self.byLanguage.first { $0.value == self }?.key
	}

	/// The single language whose system dictionary (`UITextChecker`) feeds word completion for this
	/// accent set, resolved by a fallback chain: the set's own language when it names one (not
	/// `.all`) → else the device's preferred language → else English. iOS gives a custom keyboard no
	/// signal about the focused field's or device's language beyond the static `PrimaryLanguage`
	/// (`"mul"`), so the accent set drives the choice (task 78, ADR 0002 — supersedes the additive
	/// base+accent model of task 65). On-device availability is handled downstream by
	/// `UITextCheckerAdapter.resolveLanguage` (an unsupported code still falls back to English).
	///
	/// `deviceLanguageCode` is injectable (default derived from `Locale.preferredLanguages.first`) so
	/// the chain is unit-testable without mutating global `Locale`, mirroring `detectedDefault`.
	public func completionLanguage(deviceLanguageCode: String? = LetterAlternateSet.deviceLanguageCode()) -> String {
		accentLanguageCode ?? deviceLanguageCode ?? "en"
	}

	/// The device's current preferred language as a bare language code (`"en"`, `"cs"`, `"ja"`…),
	/// parsed from `Locale.preferredLanguages.first` — which can be regional (`"en-CZ"`) — via
	/// `Locale(identifier:).language.languageCode`, or `nil` when none is resolvable. Mirrors
	/// `detectedDefault`'s derivation but returns `nil` rather than `""` for a missing code so the
	/// completion chain falls through to English. `preferredLanguage` is injectable for tests.
	public static func deviceLanguageCode(preferredLanguage: String? = Locale.preferredLanguage) -> String? {
		guard
			let preferredLanguage,
			let code = Locale(identifier: preferredLanguage).language.languageCode?.identifier,
			!code.isEmpty else
		{
			return nil
		}
		return code
	}

	private static let byLanguage: [String: LetterAlternateSet] = [
		"cs": .czech, "sk": .slovak, "de": .german,
		"pl": .polish, "fr": .french, "es": .spanish
	]

	/// Unambiguous regions only; multilingual ones (CH, BE, LU…) are intentionally omitted so they
	/// fall through to `.all`.
	private static let byRegion: [String: LetterAlternateSet] = [
		"CZ": .czech, "SK": .slovak, "DE": .german, "AT": .german,
		"PL": .polish, "FR": .french, "ES": .spanish
	]
}
