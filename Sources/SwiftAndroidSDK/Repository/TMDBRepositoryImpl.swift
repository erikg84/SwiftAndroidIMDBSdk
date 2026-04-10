import Foundation

private struct TMDBAPIError: Decodable {
    let status_message: String?
}

public final class TMDBRepositoryImpl: TMDBRepository {
    private let configuration: TMDBConfiguration
    private let httpClient: HTTPClient

    public init(configuration: TMDBConfiguration, httpClient: HTTPClient) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    // MARK: - TMDBRepository

    public func trendingAll(timeWindow: TimeWindow, page: Int = 1) async throws -> MediaItemPage {
        let req = try Endpoint.trendingAll(
            timeWindow: timeWindow, page: page, language: configuration.defaultLanguage
        ).urlRequest(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        return try await fetch(request: req)
    }

    public func trendingMovies(timeWindow: TimeWindow, page: Int = 1) async throws -> MoviePage {
        let req = try Endpoint.trendingMovies(
            timeWindow: timeWindow, page: page, language: configuration.defaultLanguage
        ).urlRequest(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        return try await fetch(request: req)
    }

    public func popularMovies(page: Int = 1) async throws -> MoviePage {
        let req = try Endpoint.popularMovies(
            page: page, language: configuration.defaultLanguage
        ).urlRequest(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        return try await fetch(request: req)
    }

    public func popularTVShows(page: Int = 1) async throws -> TVShowPage {
        let req = try Endpoint.popularTVShows(
            page: page, language: configuration.defaultLanguage
        ).urlRequest(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        return try await fetch(request: req)
    }

    public func searchMovies(query: String, page: Int = 1) async throws -> MoviePage {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw TMDBError.emptyQuery
        }
        let req = try Endpoint.searchMovies(
            query: trimmed, page: page, language: configuration.defaultLanguage
        ).urlRequest(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        return try await fetch(request: req)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await httpClient.perform(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiMsg = try? JSONDecoder().decode(TMDBAPIError.self, from: data)
            throw TMDBError.httpError(statusCode: httpResponse.statusCode, message: apiMsg?.status_message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
}
