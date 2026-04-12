import Foundation

/// ViewModel for the **Languages** screen — world languages.
///
/// Stateless command object — the screen holds its own UI state.
public final class LanguagesViewModel: Sendable {
    private let repository: any CountriesRepository

    public init(repository: any CountriesRepository) {
        self.repository = repository
    }

    /// All languages with code, name, and native name.
    public func loadLanguages() async throws -> [Language] {
        try await repository.languages()
    }
}
