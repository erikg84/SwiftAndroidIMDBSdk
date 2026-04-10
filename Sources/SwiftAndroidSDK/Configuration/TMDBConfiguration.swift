import Foundation

/// Configuration for the TMDB SDK. Pass your bearer token (preferred) and/or API key.
/// Obtain credentials at https://developer.themoviedb.org/
public struct TMDBConfiguration: Sendable {
    public let bearerToken: String
    public let apiKey: String
    public let baseURL: URL
    public let imageBaseURL: URL
    public let defaultLanguage: String

    public init(
        bearerToken: String,
        apiKey: String = "",
        baseURL: URL = URL(string: "https://api.themoviedb.org/3")!,
        imageBaseURL: URL = URL(string: "https://image.tmdb.org/t/p")!,
        defaultLanguage: String = "en-US"
    ) {
        self.bearerToken = bearerToken
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.imageBaseURL = imageBaseURL
        self.defaultLanguage = defaultLanguage
    }

    /// Builds a full image URL for a given poster/backdrop path.
    public func imageURL(path: String, size: ImageSize = .w500) -> URL? {
        URL(string: "\(imageBaseURL.absoluteString)/\(size.rawValue)\(path)")
    }

    public enum ImageSize: String, Sendable {
        case w92, w154, w185, w342, w500, w780, original
    }
}
