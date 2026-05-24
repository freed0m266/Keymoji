import SwiftUI
import KeyboardCore

/// Public entry point — renders a complete keyboard given a `KeyboardLayout`.
/// Callers (the keyboard extension's `KeyboardViewController`) pass `onKey` to receive tap dispatches.
/// `onPopoverEntry` and `onHighlightChanged` are haptic hooks wired up in task 08.
public struct KeyboardView: View {
	public let layout: KeyboardLayout
	public let onKey: (Key) -> Void
	public let onPopoverEntry: () -> Void
	public let onHighlightChanged: () -> Void

	public init(
		layout: KeyboardLayout,
		onKey: @escaping (Key) -> Void,
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {}
	) {
		self.layout = layout
		self.onKey = onKey
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
	}

	private let horizontalPadding: CGFloat = 3
	private let verticalPadding: CGFloat = 4
	private let rowSpacing: CGFloat = 6

	public var body: some View {
		GeometryReader { proxy in
			VStack(spacing: rowSpacing) {
				ForEach(layout.rows) { row in
					KeyRowView(
						row: row,
						page: layout.page,
						returnKeyType: layout.returnKeyType,
						totalWidth: max(0, proxy.size.width - horizontalPadding * 2),
						onKey: onKey,
						onPopoverEntry: onPopoverEntry,
						onHighlightChanged: onHighlightChanged
					)
				}
			}
			.padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color(.systemBackground))
		}
		.frame(height: keyboardHeight)
	}

	/// Hardcoded heights for iPhone portrait, v1.0. Adjust after on-device testing.
	private var keyboardHeight: CGFloat {
		layout.showsNumberRow ? 260 : 216
	}
}

#if DEBUG
#Preview("Letters Lower / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default),
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Letters Upper / Light") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default),
		onKey: { _ in }
	)
	.preferredColorScheme(.light)
}

#Preview("Caps Lock / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default),
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Symbols / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .symbols, showNumberRow: true, returnKeyType: .default),
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("No Number Row / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default),
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Return = Search / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search),
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}
#endif
