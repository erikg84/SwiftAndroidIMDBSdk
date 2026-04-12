import Foundation

public struct Continent: Codable, Sendable, Identifiable {
    public let code: String
    public let name: String
    public let countries: [CountryRef]

    public var id: String { code }
}

public struct CountryRef: Codable, Sendable, Identifiable {
    public let code: String
    public let name: String
    public let emoji: String

    public var id: String { code }
}
