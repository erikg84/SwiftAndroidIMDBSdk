import Foundation

/// ViewModel for the standalone **Trending** screen — movies-only with
/// day/week toggle.
///
/// Stateless command object — the screen holds its own UI state. See
/// `PROPOSAL-shared-viewmodels.md` §4.4 for the rationale.
public final class TMDBTrendingViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    /// Trending movies for the requested time window.
    /// - Parameters:
    ///   - timeWindow: `.day` or `.week`
    ///   - page: 1-based page number
    public func loadTrendingMovies(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MoviePage {
        try await repository.trendingMovies(timeWindow: timeWindow, page: page)
    }
}
