//
//  AboutViewModel.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import UIKit
import KeymojiCore

@MainActor
public protocol AboutViewModeling: Observable, AnyObject {
	var versionString: String { get }

	func openPrivacyPolicy()
	func openSupportEmail()
}

@MainActor
public func aboutVM() -> some AboutViewModeling {
	AboutViewModel()
}

@Observable
final class AboutViewModel: BaseViewModel, AboutViewModeling {

	// MARK: - Public API

	func openPrivacyPolicy() {
		guard let url = URL(string: KeymojiURLs.privacyPolicy) else { return }
		UIApplication.shared.open(url)
	}

	func openSupportEmail() {
		guard let url = URL(string: KeymojiURLs.supportEmail) else { return }
		UIApplication.shared.open(url)
	}
}
