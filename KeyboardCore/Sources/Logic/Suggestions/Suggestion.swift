import Foundation

/// One ranked suggestion chip. Source-agnostic representation that `SuggestionBarView` renders.
///
/// `displayText` is what the chip shows; `replacementText` is what gets committed when the chip is
/// tapped. For word completions the two are identical (WYSIWYG). For Slack emoji pills they differ:
/// `displayText` carries the `:shortcode:` label while `replacementText` carries the emoji glyph the
/// pill renders and the substitution inserts. See `SlackSuggestionProvider`.
public struct Suggestion: Equatable, Sendable, Identifiable {
	public let id: String
	/// Text shown on the chip. For `.plain` chips this is the word; for `.pill` chips it's the
	/// shortcode label (the emoji is carried in `replacementText`).
	public let displayText: String
	/// Text committed on tap. For `.plain` chips this is the word inserted verbatim (+ a trailing
	/// space, added by the dispatcher); for `.pill` chips this is the emoji glyph.
	public let replacementText: String
	public let renderStyle: ChipRenderStyle
	/// Weighted-merge ranking in `[0, 1]`. Ignored while the Slack provider wins (its chips are
	/// returned wholesale by the coordinator, in the provider's own order).
	public let score: Double
	public let source: SuggestionSource

	public init(
		id: String,
		displayText: String,
		replacementText: String,
		renderStyle: ChipRenderStyle,
		score: Double,
		source: SuggestionSource
	) {
		self.id = id
		self.displayText = displayText
		self.replacementText = replacementText
		self.renderStyle = renderStyle
		self.score = score
		self.source = source
	}
}

/// How a chip is drawn. `.plain` = text label with vertical dividers (word completion); `.pill` =
/// emoji glyph + shortcode label in a rounded background (Slack typeahead).
public enum ChipRenderStyle: Sendable, Equatable {
	case plain
	case pill
}

/// Origin of a suggestion. Drives the coordinator's Slack-priority rule and is useful for debug
/// and any future analytics. The accept handler also branches on this (`.slack` runs the emoji
/// substitution path; `.wordCompletion` runs the prefix-replace path).
public enum SuggestionSource: Sendable, Equatable {
	case slack
	case wordCompletion
}

/// Snapshot of the document + keyboard state a provider needs to compute candidates. Built fresh
/// on every rebuild so providers always see what the proxy sees right now.
public struct SuggestionContext: Sendable, Equatable {
	public let documentContextBeforeInput: String?
	/// Text immediately after the cursor — used only for mid-word cursor detection (the bar
	/// collapses when the caret sits inside a word). Nil/empty when the host hides it.
	public let documentContextAfterInput: String?
	public let page: KeyboardPage
	/// BCP-47-ish language tag from `UITextInputMode.primaryLanguage` (e.g. "en-US"), or nil when
	/// unavailable; providers fall back to `"en"`.
	public let primaryLanguage: String?
	public let eligibility: SuggestionEligibility

	public init(
		documentContextBeforeInput: String?,
		documentContextAfterInput: String?,
		page: KeyboardPage,
		primaryLanguage: String?,
		eligibility: SuggestionEligibility
	) {
		self.documentContextBeforeInput = documentContextBeforeInput
		self.documentContextAfterInput = documentContextAfterInput
		self.page = page
		self.primaryLanguage = primaryLanguage
		self.eligibility = eligibility
	}
}

/// Pure provider — given the current document context, returns ranked candidates. Synchronous and
/// side-effect-free; the coordinator merges across providers. Conformers must be `Sendable` so the
/// coordinator (and any future off-main precompute) can hold them safely.
public protocol SuggestionProviding: Sendable {
	func suggestions(for context: SuggestionContext) -> [Suggestion]
}
