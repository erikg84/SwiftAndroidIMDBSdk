import Foundation

public struct Language: Codable, Sendable, Identifiable {
    public let code: String
    public let name: String?

    /// The language name in its own script (e.g. "Español" for Spanish).
    /// Maps to the `native` field in the GraphQL response.
    public let nativeName: String?

    public var id: String { code }

    private enum CodingKeys: String, CodingKey {
        case code, name
        case nativeName = "native"
    }
}
