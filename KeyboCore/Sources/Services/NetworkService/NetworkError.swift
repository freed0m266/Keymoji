//
//  NetworkError.swift
//  KeyboCore
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeyboResources

public enum NetworkError: Error, Sendable {
	case invalidURL
	case httpError(status: Int, data: Data)
	case rateLimited
	case networkFailure(URLError)
}
