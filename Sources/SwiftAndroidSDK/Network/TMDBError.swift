import Foundation

public enum TMDBError: Error, Sendable, Equatable {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case emptyQuery
}

extension TMDBError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL constructed for request."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidResponse:
            return "Server returned an invalid response."
        case .httpError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let msg):
            return "Failed to decode response: \(msg)"
        case .emptyQuery:
            return "Search query must not be empty."
        }
    }
}
