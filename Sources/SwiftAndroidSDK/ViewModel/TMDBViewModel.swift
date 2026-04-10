import Foundation

/// Cross-platform ViewModel for TMDB data.
///
/// Exposes five `async throws` methods — one per selected TMDB endpoint.
/// On iOS, wrap calls in a `Task` from your `@Observable` or `ObservableObject`.
/// On Android, swift-java bridges each `async` method to a `CompletableFuture`.
public final class TMDBViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    // MARK: - API 1: Trending All

    /// Trending movies, TV shows, and people.
    /// - Parameters:
    ///   - timeWindow: `.day` or `.week`
    ///   - page: 1-based page number
    public func fetchTrendingAll(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MediaItemPage {
        try await repository.trendingAll(timeWindow: timeWindow, page: page)
    }

    // MARK: - API 2: Trending Movies

    /// Trending movies only.
    public func fetchTrendingMovies(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MoviePage {
        try await repository.trendingMovies(timeWindow: timeWindow, page: page)
    }

    // MARK: - API 3: Popular Movies

    /// Currently popular movies.
    public func fetchPopularMovies(page: Int = 1) async throws -> MoviePage {
        try await repository.popularMovies(page: page)
    }

    // MARK: - API 4: Popular TV Shows

    /// Currently popular TV shows.
    public func fetchPopularTVShows(page: Int = 1) async throws -> TVShowPage {
        try await repository.popularTVShows(page: page)
    }

    // MARK: - API 5: Search Movies

    /// Search for movies by title.
    /// - Parameters:
    ///   - query: Search term (must be non-empty)
    ///   - page: 1-based page number
    public func searchMovies(query: String, page: Int = 1) async throws -> MoviePage {
        try await repository.searchMovies(query: query, page: page)
    }
}
