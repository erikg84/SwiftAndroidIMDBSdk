import Foundation

/// ViewModel for the **Continents** screen — continents with nested countries.
///
/// Stateless command object — the screen holds its own UI state.
public final class ContinentsViewModel: Sendable {
    private let repository: any CountriesRepository

    public init(repository: any CountriesRepository) {
        self.repository = repository
    }

    /// All continents with their countries.
    public func loadContinents() async throws -> [Continent] {
        try await repository.continents()
    }
}
