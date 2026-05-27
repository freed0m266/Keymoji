//
//  AboutViewModel.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import UIKit
import KeyboCore

@MainActor
public protocol AboutViewModeling: Observable, AnyObject {
	var versionString: String { get }
	func openPrivacyPolicy()
	func openSourceCode()
}

@MainActor
public func aboutVM() -> some AboutViewModeling {
	AboutViewModel()
}

@Observable
final class AboutViewModel: BaseViewModel, AboutViewModeling {

	// MARK: - Public API

	func openPrivacyPolicy() {
		guard let url = URL(string: KeyboURLs.privacyPolicy) else { return }
		UIApplication.shared.open(url)
	}

	func openSourceCode() {
		guard let url = URL(string: KeyboURLs.sourceCode) else { return }
		UIApplication.shared.open(url)
	}
}
