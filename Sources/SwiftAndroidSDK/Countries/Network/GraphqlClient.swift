import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thin GraphQL POST client.
///
/// Uses the same `HTTPClient` instance as the TMDB REST calls so any interceptor
/// registered by the client app (Chucker on Android via OkHttp adapter, Pulse on
/// iOS via URLSession delegate) automatically captures GraphQL traffic too.
public final class GraphqlClient: Sendable {
    private let httpClient: any HTTPClient

    public init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    /// Sends a GraphQL `query` string to `url` and deserializes the response.
    public func query<T: Decodable>(
        url: URL,
        query: String,
        responseType: T.Type = T.self
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        SdkLog.debug("GraphQL POST → \(url)")
        let (data, response) = try await httpClient.perform(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            SdkLog.error("GraphQL: invalid response (not HTTPURLResponse)")
            throw GraphqlError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = String(data: data, encoding: .utf8)
            SdkLog.error("GraphQL error: HTTP \(httpResponse.statusCode)")
            throw GraphqlError.httpError(
                statusCode: httpResponse.statusCode,
                message: detail
            )
        }

        SdkLog.debug("GraphQL ← \(httpResponse.statusCode) OK")
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            SdkLog.error("GraphQL decode error: \(error.localizedDescription)")
            throw GraphqlError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Error types

public enum GraphqlError: Error, Sendable, Equatable {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
}

extension GraphqlError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GraphQL server returned an invalid response."
        case .httpError(let code, let message):
            return "GraphQL HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let msg):
            return "Failed to decode GraphQL response: \(msg)"
        }
    }
}
