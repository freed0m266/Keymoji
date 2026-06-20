import Foundation

/// Pure helper that translates a vertical "move N lines" intent into the character offset that
/// `UITextDocumentProxy.adjustTextPosition(byCharacterOffset:)` needs — the only cursor primitive
/// iOS gives keyboard extensions. There is no 2D / point / line cursor API (confirmed against the
/// iOS 26/27 SDKs), so vertical scrubbing has to be emulated by walking newlines in the document
/// context window and preserving the user's column.
///
/// Keyboard extensions only see a capped slice of text around the cursor
/// (`documentContextBeforeInput` / `documentContextAfterInput`, typically ~1024 chars, undocumented).
/// When the target line lies beyond that window — or there simply aren't enough `\n` characters in
/// the requested direction — `computeLineJumpOffset` returns 0 so the caller can fall through to a
/// horizontal scrub instead of jumping somewhere wrong. Hidden contexts (password fields) report
/// empty contexts and therefore always fall through, exactly like the word-delete escalation does.
enum CursorLineWalker {

	/// Character offset that moves the cursor `lines` away (negative = up, positive = down),
	/// preserving the current column clamped to the target line's length. Returns 0 when there
	/// aren't `|lines|` newlines available in the required direction within the context window.
	///
	/// `before` is the text immediately preceding the cursor, `after` the text immediately
	/// following it. The current column is the number of characters since the last `\n` in `before`
	/// (or the whole of `before` when it holds no newline).
	static func computeLineJumpOffset(lines: Int, before: String, after: String) -> Int {
		guard lines != 0 else { return 0 }
		let column = currentColumn(before: before)
		return lines < 0
			? upOffset(lineCount: -lines, column: column, before: before)
			: downOffset(lineCount: lines, column: column, after: after)
	}

	/// Characters between the last newline in `before` and the cursor. The whole length of `before`
	/// when it contains no newline (cursor sits on the document's first line).
	private static func currentColumn(before: String) -> Int {
		let chars = Array(before)
		guard let lastNewline = chars.lastIndex(of: "\n") else { return chars.count }
		return chars.count - 1 - lastNewline
	}

	/// Negative offset that walks `lineCount` lines up through `before`. The lines above the cursor
	/// are exactly the newline-separated segments of `before`; we need at least `lineCount` newlines
	/// for the move to be possible.
	private static func upOffset(lineCount: Int, column: Int, before: String) -> Int {
		let chars = Array(before)
		let newlines = chars.indices.filter { chars[$0] == "\n" }
		// `newlines.count` is the number of lines that exist *above* the current one.
		let endIndexInNewlines = newlines.count - lineCount
		guard endIndexInNewlines >= 0 else { return 0 }

		// The newline that terminates the target line, and the start of that line.
		let targetLineEnd = newlines[endIndexInNewlines]
		let targetLineStart = endIndexInNewlines - 1 >= 0 ? newlines[endIndexInNewlines - 1] + 1 : 0
		let targetLineLength = targetLineEnd - targetLineStart
		let targetColumn = min(column, targetLineLength)
		let targetPosition = targetLineStart + targetColumn
		// Cursor currently sits at `chars.count`; moving left to `targetPosition`.
		return targetPosition - chars.count
	}

	/// Positive offset that walks `lineCount` lines down through `after`. The current line's
	/// remainder plus the lines below are the newline-separated segments of `after`; we need at
	/// least `lineCount` newlines for the move to be possible.
	private static func downOffset(lineCount: Int, column: Int, after: String) -> Int {
		let chars = Array(after)
		let newlines = chars.indices.filter { chars[$0] == "\n" }
		guard newlines.count >= lineCount else { return 0 }

		// The target line starts right after the `lineCount`-th newline below the cursor.
		let targetLineStart = newlines[lineCount - 1] + 1
		// It ends at the next newline, or at the end of the context window if it's the last line.
		let targetLineEnd = lineCount < newlines.count ? newlines[lineCount] : chars.count
		let targetLineLength = targetLineEnd - targetLineStart
		let targetColumn = min(column, targetLineLength)
		// Cursor currently sits at position 0 of `after`; moving right to the target position.
		return targetLineStart + targetColumn
	}
}
