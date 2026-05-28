import Foundation

/// What the keyboard does when the user double-taps space within
/// `InputDispatcher.doubleSpaceWindow`. Persisted as a string in `AppGroupStore`
/// under `spaceDoubleTapAction`.
public enum SpaceDoubleTapAction: String, Sendable, CaseIterable {
	/// Replace the previous space with ". " (Apple-stock behavior). Default.
	case insertPeriod
	/// Hide the keyboard. The first space stays inserted; the second tap dismisses without inserting.
	case dismissKeyboard
	/// No special handling — the second space is inserted as a regular space.
	case none
}
