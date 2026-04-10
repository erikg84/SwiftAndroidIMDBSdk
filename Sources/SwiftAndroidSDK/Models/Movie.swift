import Foundation

public struct Movie: Codable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let originalTitle: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String
    public let voteAverage: Double
    public let voteCount: Int
    public let popularity: Double
    public let genreIds: [Int]
    public let adult: Bool
    public let video: Bool
    public let originalLanguage: String

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult, video
        case originalTitle    = "original_title"
        case posterPath       = "poster_path"
        case backdropPath     = "backdrop_path"
        case releaseDate      = "release_date"
        case voteAverage      = "vote_average"
        case voteCount        = "vote_count"
        case genreIds         = "genre_ids"
        case originalLanguage = "original_language"
    }
}
