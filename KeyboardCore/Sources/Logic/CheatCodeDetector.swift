import Foundation

/// Detects the promo cheat code in the text the user has typed (task 64 Scope 9). The keyword lives in
/// exactly one place — `code` — so changing it is a one-line edit; everything else derives from it.
///
/// **Window match, not a strict suffix.** `textDidChange` in a keyboard extension does *not* tick
/// 1:1 with characters — when typing fast (and especially when accepting a suggestion) the document
/// buffer can jump in one callback (e.g. from a partial code straight to the full code plus a trailing
/// character), so the buffer almost never ends *exactly* on the code. A `hasSuffix` check therefore
/// misses most real activations (verified on-device in the first attempt — revert log #1). Instead we
/// look for the code anywhere in a short window at the end of the buffer, tolerating a few trailing chars.
///
/// Pure and `documentContextBeforeInput`-only — the same local-scanning category as
/// `SlackEmojiSuggester` and word completion (no new privacy surface, nothing leaves the device).
public enum CheatCodeDetector {

	/// The trigger string — the **single source of truth** for the cheat keyword. Change it here and the
	/// matcher + window size follow automatically. Case-insensitive at match time. (Input string, not
	/// branding — no Rockstar assets anywhere in the feature; see task 64 Scope 11.)
	public static let code = "hesoyam"

	/// How many trailing characters of the buffer to scan. `code.count + 10` slack absorbs the
	/// trailing space / punctuation / extra char that a coalesced `textDidChange` may have appended
	/// before the keyboard got to look. Calibrate on-device against real `textDidChange` jumps.
	public static let windowLength = code.count + 10

	/// Whether `context` contains the cheat code within its trailing window (case-insensitive).
	/// `nil`/short/empty contexts return `false`.
	public static func matches(context: String?) -> Bool {
		guard let context, !context.isEmpty else { return false }
		let window = context.suffix(windowLength).lowercased()
		return window.contains(code)
	}
}
