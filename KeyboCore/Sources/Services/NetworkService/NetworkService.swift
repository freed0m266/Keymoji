//
//  NetworkService.swift
//  KeyboCore
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

// MARK: - Type aliases

typealias HTTPHeaders = [String: String]
typealias HTTPQueryParameters = [String: String]

// MARK: - Protocol

protocol NetworkServicing: Sendable {
	func request(
		url: String,
		method: HTTPMethod,
		queryParameters: HTTPQueryParameters?,
		headers: HTTPHeaders?,
		body: Data?
	) async throws -> Data
}

extension NetworkServicing {
	func request(
		url: String,
		method: HTTPMethod = .get,
		queryParameters: HTTPQueryParameters? = nil,
		headers: HTTPHeaders? = nil,
		body: Data? = nil
	) async throws -> Data {
		try await request(
			url: url,
			method: method,
			queryParameters: queryParameters,
			headers: headers,
			body: body
		)
	}
}

// MARK: - Implementation

final class NetworkService: NetworkServicing {

	private let session: URLSession

	// MARK: Init

	init(session: URLSession = .shared) {
		self.session = session
	}

	// MARK: Public API

	func request(
		url: String,
		method: HTTPMethod,
		queryParameters: HTTPQueryParameters?,
		headers: HTTPHeaders?,
		body: Data?
	) async throws -> Data {
		let url = try makeURL(from: url, queryParameters: queryParameters)
		let urlRequest = makeURLRequest(url: url, method: method, headers: headers, body: body)

		Logger.verbose("→ \(method.rawValue) \(url.path())...\(url.absoluteString.suffix(64))")

		let data: Data
		let response: URLResponse

		do {
			(data, response) = try await session.data(for: urlRequest)
		} catch let error as URLError {
			Logger.error("Network failure: \(error.localizedDescription)")
			throw NetworkError.networkFailure(error)
		}
		// swiftlint:disable:next force_cast
		let httpResponse = response as! HTTPURLResponse

		Logger.verbose("← \(httpResponse.statusCode) (\(data.count) bytes) \(url.lastPathComponent)")

		switch httpResponse.statusCode {
		case 200...299:
			return data
		case 429:
			Logger.warning("Rate limited")
			throw NetworkError.rateLimited
		default:
			Logger.error("HTTP error \(httpResponse.statusCode)")
			throw NetworkError.httpError(status: httpResponse.statusCode, data: data)
		}
	}

	// MARK: Private API

	private func makeURL(from urlString: String, queryParameters: HTTPQueryParameters?) throws -> URL {
		guard var components = URLComponents(string: urlString) else {
			throw NetworkError.invalidURL
		}

		if let queryParameters, !queryParameters.isEmpty {
			components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
		}

		guard let url = components.url else {
			throw NetworkError.invalidURL
		}

		return url
	}

	private func makeURLRequest(url: URL, method: HTTPMethod, headers: HTTPHeaders?, body: Data?) -> URLRequest {
		var request = URLRequest(url: url)
		request.httpMethod = method.rawValue
		request.httpBody = body

		for (key, value) in headers ?? [:] {
			request.setValue(value, forHTTPHeaderField: key)
		}

		return request
	}
}
