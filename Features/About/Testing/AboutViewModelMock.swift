//
//  AboutViewModelMock.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation

@Observable
@MainActor
public final class AboutViewModelMock: AboutViewModeling {
	public var versionString: String = "1.0 (1)"
	public var openPrivacyPolicyCallCount = 0
	public var openSourceCodeCallCount = 0

	public init() {}

	public func openPrivacyPolicy() { openPrivacyPolicyCallCount += 1 }
	public func openSourceCode() { openSourceCodeCallCount += 1 }
}
#endif
