import Foundation

/// ViewModel for the **TV Shows** tab — popular shows feed with pagination.
///
/// Stateless command object — the screen holds its own UI state. See
/// `PROPOSAL-shared-viewmodels.md` §4.4 for the rationale.
public final class TMDBTVShowsViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    /// Currently popular TV shows.
    /// - Parameter page: 1-based page number
    public func loadPopular(page: Int = 1) async throws -> TVShowPage {
        try await repository.popularTVShows(page: page)
    }
}
