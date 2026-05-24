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
public func aboutVM() -> AboutViewModel {
	AboutViewModel()
}

@Observable
public final class AboutViewModel: BaseViewModel, AboutViewModeling {

	public let versionString: String

	public override init() {
		self.versionString = Self.makeVersionString()
		super.init()
	}

	public func openPrivacyPolicy() {
		guard let url = URL(string: KeyboURLs.privacyPolicy) else { return }
		UIApplication.shared.open(url)
	}

	public func openSourceCode() {
		guard let url = URL(string: KeyboURLs.sourceCode) else { return }
		UIApplication.shared.open(url)
	}

	private static func makeVersionString() -> String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
		return "\(version) (\(build))"
	}
}
