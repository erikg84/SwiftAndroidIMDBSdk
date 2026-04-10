import Foundation

public struct TVShow: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let originalName: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let firstAirDate: String
    public let voteAverage: Double
    public let voteCount: Int
    public let popularity: Double
    public let genreIds: [Int]
    public let adult: Bool
    public let originalLanguage: String
    public let originCountry: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, adult
        case originalName     = "original_name"
        case posterPath       = "poster_path"
        case backdropPath     = "backdrop_path"
        case firstAirDate     = "first_air_date"
        case voteAverage      = "vote_average"
        case voteCount        = "vote_count"
        case genreIds         = "genre_ids"
        case originalLanguage = "original_language"
        case originCountry    = "origin_country"
    }
}
