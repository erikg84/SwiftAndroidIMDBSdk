import Foundation

public protocol CountriesRepository: Sendable {
    func countries() async throws -> [Country]
    func continents() async throws -> [Continent]
    func languages() async throws -> [Language]
}
