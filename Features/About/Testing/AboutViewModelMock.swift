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
final class AboutViewModelMock: AboutViewModeling {
	var versionString: String = "1.0 (1)"

	func openAppStoreReview() {}
	func openPrivacyPolicy() {}
	func openSupportEmail() {}
}
#endif
