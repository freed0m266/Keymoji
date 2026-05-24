//
//  SettingsViewModelMock.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation

@Observable
@MainActor
public final class SettingsViewModelMock: SettingsViewModeling {
	public var showNumberRow: Bool
	public var hapticFeedbackEnabled: Bool
	public var versionString: String

	public init(
		showNumberRow: Bool = true,
		hapticFeedbackEnabled: Bool = true,
		versionString: String = "1.0 (1)"
	) {
		self.showNumberRow = showNumberRow
		self.hapticFeedbackEnabled = hapticFeedbackEnabled
		self.versionString = versionString
	}
}
#endif
