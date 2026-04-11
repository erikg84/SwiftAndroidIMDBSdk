import Foundation

/// ViewModel for the **Movies** tab — popular movies feed with pagination.
///
/// Stateless command object — the screen holds its own UI state. See
/// `PROPOSAL-shared-viewmodels.md` §4.4 for the rationale.
public final class TMDBMoviesViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    /// Currently popular movies.
    /// - Parameter page: 1-based page number
    public func loadPopular(page: Int = 1) async throws -> MoviePage {
        try await repository.popularMovies(page: page)
    }
}
