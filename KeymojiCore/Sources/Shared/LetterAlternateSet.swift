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
		preferredLanguageCode: String? = Locale.preferredLanguages.first
			.map { Locale(identifier: $0).language.languageCode?.identifier ?? "" },
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
