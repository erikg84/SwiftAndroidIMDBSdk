import Foundation

/// ViewModel for the **Countries** screen — list of all countries.
///
/// Stateless command object — the screen holds its own UI state.
public final class CountriesViewModel: Sendable {
    private let repository: any CountriesRepository

    public init(repository: any CountriesRepository) {
        self.repository = repository
    }

    /// All countries with code, name, emoji flag, currency, and continent.
    public func loadCountries() async throws -> [Country] {
        try await repository.countries()
    }
}
