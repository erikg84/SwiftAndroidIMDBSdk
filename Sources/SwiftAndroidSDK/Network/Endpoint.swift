import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum Endpoint {
    case trendingAll(timeWindow: TimeWindow, page: Int, language: String)
    case trendingMovies(timeWindow: TimeWindow, page: Int, language: String)
    case popularMovies(page: Int, language: String)
    case popularTVShows(page: Int, language: String)
    case searchMovies(query: String, page: Int, language: String)

    func urlRequest(baseURL: URL, bearerToken: String) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw TMDBError.invalidURL
        }
        components.queryItems = queryItems
        guard let finalURL = components.url else {
            throw TMDBError.invalidURL
        }
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private var path: String {
        switch self {
        case .trendingAll(let tw, _, _):    return "trending/all/\(tw.rawValue)"
        case .trendingMovies(let tw, _, _): return "trending/movie/\(tw.rawValue)"
        case .popularMovies:                return "movie/popular"
        case .popularTVShows:               return "tv/popular"
        case .searchMovies:                 return "search/movie"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case .trendingAll(_, let page, let lang),
             .trendingMovies(_, let page, let lang),
             .popularMovies(let page, let lang),
             .popularTVShows(let page, let lang):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "language", value: lang),
            ]
        case .searchMovies(let query, let page, let lang):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "language", value: lang),
            ]
        }
    }
}
