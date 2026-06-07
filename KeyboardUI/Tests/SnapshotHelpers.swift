import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot helper specialized for keyboard renders. Lets each test pick its own
/// `colorScheme` so we cover light + dark without relying on KeymojiTesting's helper
/// (which is currently `.light`-only).
extension XCTestCase {
	func assertKeyboardSnapshot<V: View>(
		_ view: V,
		size: CGSize = CGSize(width: 393, height: 260),
		colorScheme: ColorScheme = .dark,
		// `nil` lets the `SNAPSHOT_TESTING_RECORD` env var drive record mode. Passing a `Bool`/`Record`
		// here would coerce to `.never` and silently override the env var (so `=all` re-records wouldn't
		// take). Keep it optional so re-recording the whole suite via the env var works.
		record: SnapshotTestingConfiguration.Record? = nil,
		line: UInt = #line,
		file: StaticString = #filePath,
		function: String = #function
	) {
		let style: UIUserInterfaceStyle = (colorScheme == .dark) ? .dark : .light
		let host = view
			.environment(\.colorScheme, colorScheme)
			.frame(width: size.width, height: size.height)

		assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: 0.93,
				layout: .fixed(width: size.width, height: size.height),
				traits: .init(userInterfaceStyle: style)
			),
			record: record,
			file: file,
			testName: function + "_" + (colorScheme == .dark ? "dark" : "light"),
			line: line
		)
	}
}
