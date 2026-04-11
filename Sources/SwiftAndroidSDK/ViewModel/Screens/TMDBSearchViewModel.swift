import Foundation

/// ViewModel for the **Search** screen — movie search by title.
///
/// Stateless command object. Debouncing is intentionally a UI concern and
/// lives in the consumer (Compose `snapshotFlow.debounce` / SwiftUI
/// `task(id:)` + `Task.sleep`). See `PROPOSAL-shared-viewmodels.md` §4.4
/// for the rationale.
public final class TMDBSearchViewModel: Sendable {
    private let repository: any TMDBRepository

    public init(repository: any TMDBRepository) {
        self.repository = repository
    }

    /// Search for movies by title.
    /// - Parameters:
    ///   - query: search term — must be non-empty (the repository throws
    ///     `TMDBError.emptyQuery` for empty/whitespace-only input)
    ///   - page: 1-based page number
    public func search(query: String, page: Int = 1) async throws -> MoviePage {
        try await repository.searchMovies(query: query, page: page)
    }
}
