import Foundation

/// State machine that owns shift/caps-lock transitions. Pure-functional `reduce` for tests;
/// `apply(_:to:)` convenience that mutates the larger `KeyboardState` in the dispatcher.
@MainActor
public enum ShiftStateMachine {

	/// Window within which two shift taps collapse into caps-lock. Apple uses ~300ms;
	/// 400ms gives slower thumbs a little more grace.
	public static let doubleTapWindow: TimeInterval = 0.4

	public struct State: Sendable, Equatable {
		public var page: KeyboardPage
		public var lastShiftTapAt: Date?

		public init(page: KeyboardPage = .letters(.lower), lastShiftTapAt: Date? = nil) {
			self.page = page
			self.lastShiftTapAt = lastShiftTapAt
		}
	}

	public enum Event: Sendable, Equatable {
		case shiftTapped(at: Date)
		/// A character was inserted; downshift one-shot upper, leave caps-lock and lower alone.
		case characterInserted
		case pageSwitched(to: KeyboardPage)
	}

	public static func reduce(_ state: State, _ event: Event) -> State {
		var next = state
		switch event {
		case .shiftTapped(let now):
			next.page = nextPageAfterShiftTap(state.page, lastTapAt: state.lastShiftTapAt, now: now)
			// Only update the double-tap clock if we acted on the tap (i.e., we were on letters).
			if case .letters = state.page {
				// Leaving caps lock resets the clock: now that `.lower` is double-tap-sensitive, a
				// quick follow-up tap must be a one-shot upper, not snap straight back into caps lock.
				let leftCapsLock = state.page == .letters(.capsLock) && next.page == .letters(.lower)
				next.lastShiftTapAt = leftCapsLock ? nil : now
			}

		case .characterInserted:
			if case .letters(.upper) = state.page {
				next.page = .letters(.lower)
			}
			// capsLock stays sticky; lower stays lower; symbols unaffected.
			// A typed character ends any shift-tap streak, so the next quick shift tap is a fresh
			// one-shot upper, not the second half of a double-tap — which would otherwise caps-lock
			// now that the `.lower` branch honors the double-tap window.
			next.lastShiftTapAt = nil

		case .pageSwitched(let target):
			next.page = target
			next.lastShiftTapAt = nil
		}
		return next
	}

	/// Apply an event directly to a `KeyboardState`. Convenience for `InputDispatcher`.
	public static func apply(_ event: Event, to state: inout KeyboardState) {
		var sm = State(page: state.page, lastShiftTapAt: state.lastShiftTapAt)
		sm = reduce(sm, event)
		state.page = sm.page
		state.lastShiftTapAt = sm.lastShiftTapAt
	}

	// MARK: - Internal

	private static func nextPageAfterShiftTap(
		_ page: KeyboardPage,
		lastTapAt: Date?,
		now: Date
	) -> KeyboardPage {
		guard case .letters(let shift) = page else {
			// Shift tap on symbols page is a no-op.
			return page
		}

		let isDoubleTap = lastTapAt.map { now.timeIntervalSince($0) < doubleTapWindow } ?? false
		switch shift {
		case .lower:
			// Empty auto-capitalized fields start on `.upper`, so a double-tap there bounces
			// `.upper` → `.lower` → here; honor the second tap as caps lock too (task 65). In a
			// non-empty field `.lower` has no recent tap, so a single tap is still one-shot upper.
			return isDoubleTap ? .letters(.capsLock) : .letters(.upper)
		case .upper:
			return isDoubleTap ? .letters(.capsLock) : .letters(.lower)
		case .capsLock:
			return .letters(.lower)
		}
	}
}
