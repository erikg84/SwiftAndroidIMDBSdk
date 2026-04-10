import Foundation

/// A normalized item from the `trending/all` endpoint.
/// Covers movies (`media_type == "movie"`), TV shows (`"tv"`), and people (`"person"`).
public struct MediaItem: Sendable, Identifiable {
    public let id: Int
    /// Discriminator: "movie", "tv", or "person"
    public let mediaType: String
    /// Normalized display title (movie `title` or TV `name`)
    public let title: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let popularity: Double
    public let voteAverage: Double
    public let voteCount: Int
    /// Normalized date: movie `release_date` or TV `first_air_date`
    public let releaseDate: String?
    public let originalLanguage: String?
}

extension MediaItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case mediaType        = "media_type"
        case posterPath       = "poster_path"
        case backdropPath     = "backdrop_path"
        case voteAverage      = "vote_average"
        case voteCount        = "vote_count"
        case releaseDate      = "release_date"
        case firstAirDate     = "first_air_date"
        case originalLanguage = "original_language"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self, forKey: .id)
        mediaType    = try c.decode(String.self, forKey: .mediaType)
        overview     = (try? c.decodeIfPresent(String.self, forKey: .overview)) ?? ""
        posterPath   = try? c.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try? c.decodeIfPresent(String.self, forKey: .backdropPath)
        popularity   = (try? c.decodeIfPresent(Double.self, forKey: .popularity)) ?? 0
        voteAverage  = (try? c.decodeIfPresent(Double.self, forKey: .voteAverage)) ?? 0
        voteCount    = (try? c.decodeIfPresent(Int.self, forKey: .voteCount)) ?? 0
        originalLanguage = try? c.decodeIfPresent(String.self, forKey: .originalLanguage)

        // Normalize title
        if let t = try? c.decodeIfPresent(String.self, forKey: .title), !t.isEmpty {
            title = t
        } else if let n = try? c.decodeIfPresent(String.self, forKey: .name), !n.isEmpty {
            title = n
        } else {
            title = ""
        }

        // Normalize release date
        let rd = try? c.decodeIfPresent(String.self, forKey: .releaseDate)
        let fad = try? c.decodeIfPresent(String.self, forKey: .firstAirDate)
        releaseDate = (rd?.isEmpty == false) ? rd : fad
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(mediaType, forKey: .mediaType)
        try c.encode(title, forKey: .title)
        try c.encode(overview, forKey: .overview)
        try c.encodeIfPresent(posterPath, forKey: .posterPath)
        try c.encodeIfPresent(backdropPath, forKey: .backdropPath)
        try c.encode(popularity, forKey: .popularity)
        try c.encode(voteAverage, forKey: .voteAverage)
        try c.encode(voteCount, forKey: .voteCount)
        try c.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try c.encodeIfPresent(originalLanguage, forKey: .originalLanguage)
    }
}
