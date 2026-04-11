import Foundation

/// ViewModel for the **Home** screen — trending media of all types
/// (movies, TV shows, people).
///
/// Stateless command object — the screen holds its own UI state. See
/// `PROPOSAL-shared-viewmodels.md` §4.4 for the rationale.
public final class TMDBHomeViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    /// Trending movies, TV shows, and people across the requested time window.
    /// - Parameters:
    ///   - timeWindow: `.day` or `.week`
    ///   - page: 1-based page number
    public func loadTrending(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MediaItemPage {
        try await repository.trendingAll(timeWindow: timeWindow, page: page)
    }
}
