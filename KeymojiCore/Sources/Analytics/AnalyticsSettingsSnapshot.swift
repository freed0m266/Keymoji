import Foundation

/// Effective Plus status at snapshot time. Three buckets so the dashboard can split free vs paid vs
/// trial without exposing dates or transaction details.
public enum AnalyticsPlusStatus: String, Sendable, Equatable {
	case free
	case paid
	case trial

	/// Derive the status the same way the gates do: a paid unlock wins, else an unexpired promo trial,
	/// else free. Mirrors `effectiveIsPlus` but keeps the trial/paid distinction the boolean collapses.
	public static func resolve(paid: Bool, promoExpiresAt: Date?, now: Date) -> AnalyticsPlusStatus {
		if paid { return .paid }
		if let expiry = promoExpiresAt, now < expiry { return .trial }
		return .free
	}
}

/// A coarse count band. Never the exact number — boundary 2 keeps even *quantities* fuzzy so a count
/// can't fingerprint a user. Two presets cover the task's needs (favourites, learned words).
public enum AnalyticsCountBucket: String, Sendable, Equatable {
	case none
	case low
	case medium
	case high
	case veryHigh

	/// Favourites bands from task 86: 0 / 1–3 / 4–6 / 7+.
	public static func favorites(_ count: Int) -> AnalyticsCountBucket {
		switch count {
		case ..<1:  return .none
		case 1...3: return .low
		case 4...6: return .medium
		default:    return .high
		}
	}

	/// Learned-words bands (task 86 "pásmo"): 0 / 1–9 / 10–49 / 50–199 / 200+.
	public static func learnedWords(_ count: Int) -> AnalyticsCountBucket {
		switch count {
		case ..<1:     return .none
		case 1...9:    return .low
		case 10...49:  return .medium
		case 50...199: return .high
		default:       return .veryHigh
		}
	}
}

/// Anonymous snapshot of *which settings the user runs*. Every field is an enumerated state or a
/// coarse bucket — there is deliberately no place to put text — so `parameters` can only ever emit
/// allow-listed, content-free values (boundary 2, ADR 0004).
public struct AnalyticsSettingsSnapshot: Sendable, Equatable {
	public let appearance: AppearancePreference
	public let letterLayout: LetterLayout
	public let letterAlternateSet: LetterAlternateSet
	public let showNumberRow: Bool
	public let hapticFeedbackEnabled: Bool
	public let keyClickSoundEnabled: Bool
	public let spaceDoubleTapAction: SpaceDoubleTapAction
	public let suggestionsEnabled: Bool
	public let autoCapitalizationEnabled: Bool
	public let plusStatus: AnalyticsPlusStatus
	public let analyticsEnabled: Bool
	public let favoritesBucket: AnalyticsCountBucket
	public let learnedWordsBucket: AnalyticsCountBucket

	public init(
		appearance: AppearancePreference,
		letterLayout: LetterLayout,
		letterAlternateSet: LetterAlternateSet,
		showNumberRow: Bool,
		hapticFeedbackEnabled: Bool,
		keyClickSoundEnabled: Bool,
		spaceDoubleTapAction: SpaceDoubleTapAction,
		suggestionsEnabled: Bool,
		autoCapitalizationEnabled: Bool,
		plusStatus: AnalyticsPlusStatus,
		analyticsEnabled: Bool,
		favoritesBucket: AnalyticsCountBucket,
		learnedWordsBucket: AnalyticsCountBucket
	) {
		self.appearance = appearance
		self.letterLayout = letterLayout
		self.letterAlternateSet = letterAlternateSet
		self.showNumberRow = showNumberRow
		self.hapticFeedbackEnabled = hapticFeedbackEnabled
		self.keyClickSoundEnabled = keyClickSoundEnabled
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.suggestionsEnabled = suggestionsEnabled
		self.autoCapitalizationEnabled = autoCapitalizationEnabled
		self.plusStatus = plusStatus
		self.analyticsEnabled = analyticsEnabled
		self.favoritesBucket = favoritesBucket
		self.learnedWordsBucket = learnedWordsBucket
	}

	/// Allow-listed wire parameters. Only enum raw values, booleans, and bucket labels — no content.
	public var parameters: [String: String] {
		[
			"appearance": appearance.rawValue,
			"letterLayout": letterLayout.rawValue,
			"letterAlternateSet": letterAlternateSet.rawValue,
			"showNumberRow": String(showNumberRow),
			"hapticFeedback": String(hapticFeedbackEnabled),
			"keyClickSound": String(keyClickSoundEnabled),
			"spaceDoubleTap": spaceDoubleTapAction.rawValue,
			"suggestions": String(suggestionsEnabled),
			"autoCapitalization": String(autoCapitalizationEnabled),
			"plusStatus": plusStatus.rawValue,
			"analyticsEnabled": String(analyticsEnabled),
			"favoritesCount": favoritesBucket.rawValue,
			"learnedWordsCount": learnedWordsBucket.rawValue
		]
	}
}

public extension AnalyticsSettingsSnapshot {
	/// Build the snapshot from the shared settings store + the host-side analytics consent, bucketing
	/// the two counts. Pure given `now`, and reads **only** enumerated states and quantities — it never
	/// touches `favoriteEmojis` glyphs or learned-word *keys*, only their `count`, so no content is read.
	///
	/// The learned-words count comes from the word-completion recents pool's key count; we deliberately
	/// decode just to count entries and discard the words themselves.
	static func current(
		store: AppGroupStore = .shared,
		consent: AnalyticsConsentStore = .shared,
		now: Date = Date()
	) -> AnalyticsSettingsSnapshot {
		AnalyticsSettingsSnapshot(
			appearance: store.appearance,
			letterLayout: store.letterLayout,
			letterAlternateSet: store.letterAlternateSet,
			showNumberRow: store.showNumberRow,
			hapticFeedbackEnabled: store.hapticFeedbackEnabled,
			keyClickSoundEnabled: store.keyClickSoundEnabled,
			spaceDoubleTapAction: store.spaceDoubleTapAction,
			suggestionsEnabled: store.suggestionsEnabled,
			autoCapitalizationEnabled: store.autoCapitalizationEnabled,
			plusStatus: .resolve(paid: store.isPlus, promoExpiresAt: store.promoPlusExpiresAt, now: now),
			analyticsEnabled: consent.isEnabled,
			favoritesBucket: .favorites(store.favoriteEmojis.count),
			learnedWordsBucket: .learnedWords(store.learnedWordsCount)
		)
	}
}
