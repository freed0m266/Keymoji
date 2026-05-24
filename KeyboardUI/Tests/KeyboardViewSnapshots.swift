import XCTest
import SwiftUI
@testable import KeyboardUI
import KeyboardCore

final class KeyboardViewSnapshots: XCTestCase {

	// MARK: - Letters lower

	func testLettersLower_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Letters upper / caps lock

	func testLettersUpper_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testLettersCapsLock_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Symbols

	func testSymbols_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Without number row

	func testLettersLower_withoutNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, onKey: { _ in })

		let size = CGSize(width: 393, height: 216)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size, colorScheme: .light)
	}

	// MARK: - Adaptive return labels

	func testReturnLabel_search() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search)
		assertKeyboardSnapshot(KeyboardView(layout: layout, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_go() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .go)
		assertKeyboardSnapshot(KeyboardView(layout: layout, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_done() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .done)
		assertKeyboardSnapshot(KeyboardView(layout: layout, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_send() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .send)
		assertKeyboardSnapshot(KeyboardView(layout: layout, onKey: { _ in }), colorScheme: .dark)
	}
}
