/// Protocol defining all TMDB data operations used by the SDK.
/// Conforming types perform network I/O; inject a mock for testing.
public protocol TMDBRepository: Sendable {
    /// Trending movies, TV shows, and people for the given time window.
    func trendingAll(timeWindow: TimeWindow, page: Int) async throws -> MediaItemPage

    /// Trending movies for the given time window.
    func trendingMovies(timeWindow: TimeWindow, page: Int) async throws -> MoviePage

    /// Currently popular movies (paginated).
    func popularMovies(page: Int) async throws -> MoviePage

    /// Currently popular TV shows (paginated).
    func popularTVShows(page: Int) async throws -> TVShowPage

    /// Search movies by title query (paginated).
    func searchMovies(query: String, page: Int) async throws -> MoviePage
}
