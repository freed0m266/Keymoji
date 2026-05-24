import SnapshotTesting
import SwiftUI
import XCTest

let devices = [
	ViewImageConfig.iPhone8Plus,
	.iPhone13ProMax
]

/// Checks if the given view matches the image references on the disk.
///
/// - Parameters:
///    - layout: The size constraint for a snapshot (similar to PreviewLayout). Leave empty if you want to run snapshots on preselected devices.
///    - perceptualPrecision: Precision that is used to match snapshots. Several attempts showed that 0.93 is the magic number
///                           that makes sure that most snapshots from Apple Silicon match snapshots from Intel
public func AssertSnapshot<View: SwiftUI.View>(
	_ view: View,
	layout: SwiftUISnapshotLayout? = nil,
	record: Bool = false,
	line: UInt = #line,
	file: StaticString = #file,
	function: String = #function,
	perceptualPrecision: Float = 0.93,
	longContentSnapshotHeight: CGFloat? = nil
) {
	var strategies: [Snapshotting<View, UIImage>]

	if let layout {
		strategies = imageStrategies(
			layout: layout,
			perceptualPrecision: perceptualPrecision
		)
	} else {
		strategies = devices.flatMap {
			imageStrategies(
				layout: .device(config: $0),
				perceptualPrecision: perceptualPrecision
			)
		}
	}

	if let longContentSnapshotHeight, let width = ViewImageConfig.iPhone8Plus.size?.width {
		strategies.append(
			.image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: perceptualPrecision,
				layout: .fixed(width: width, height: longContentSnapshotHeight),
				traits: .init(userInterfaceStyle: .light)
			)
		)
	}

	assertSnapshots(
		of: view,
		as: strategies,
		record: record,
		file: file,
		testName: function,
		line: line,
	)
}

// MARK: - Helpers

private func imageStrategies<View: SwiftUI.View>(
	layout: SwiftUISnapshotLayout,
	perceptualPrecision: Float
) -> [Snapshotting<View, UIImage>] {
	// Add dark mode once implemented
	let interfaceStyles: [UIUserInterfaceStyle] = [.light]
	return interfaceStyles.map { style in
			.image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: perceptualPrecision,
				layout: layout,
				traits: .init(userInterfaceStyle: style)
			)
	}
}
