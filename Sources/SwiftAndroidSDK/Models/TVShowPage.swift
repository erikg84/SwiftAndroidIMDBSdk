public struct TVShowPage: Codable, Sendable {
    public let page: Int
    public let results: [TVShow]
    public let totalPages: Int
    public let totalResults: Int

    private enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages   = "total_pages"
        case totalResults = "total_results"
    }
}
