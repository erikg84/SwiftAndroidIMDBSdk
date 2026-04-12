import Foundation

public struct Country: Codable, Sendable, Identifiable {
    public let code: String
    public let name: String
    public let emoji: String
    public let currency: String?
    public let continent: ContinentRef

    public var id: String { code }
}

public struct ContinentRef: Codable, Sendable {
    public let code: String
    public let name: String
}
