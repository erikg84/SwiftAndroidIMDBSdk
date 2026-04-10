import Testing
import Foundation
@testable import SwiftAndroidSDK

// MARK: - Mock HTTP Client

struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    init(_ json: String, statusCode: Int = 200) {
        self.data = Data(json.utf8)
        self.statusCode = statusCode
    }

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let resp = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (data, resp)
    }
}

// MARK: - Fixtures

private let movieJSON = """
{
  "id": 42,
  "title": "Interstellar",
  "original_title": "Interstellar",
  "overview": "A team of explorers travel through a wormhole in space.",
  "poster_path": "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
  "backdrop_path": null,
  "release_date": "2014-11-05",
  "vote_average": 8.4,
  "vote_count": 34000,
  "popularity": 134.56,
  "genre_ids": [12, 18, 878],
  "adult": false,
  "video": false,
  "original_language": "en"
}
"""

private let moviePageJSON = """
{
  "page": 1,
  "results": [\(movieJSON)],
  "total_pages": 500,
  "total_results": 10000
}
"""

private let tvShowJSON = """
{
  "id": 99,
  "name": "Breaking Bad",
  "original_name": "Breaking Bad",
  "overview": "Chemistry teacher turned drug kingpin.",
  "poster_path": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
  "backdrop_path": null,
  "first_air_date": "2008-01-20",
  "vote_average": 9.5,
  "vote_count": 12000,
  "popularity": 321.0,
  "genre_ids": [18, 80],
  "adult": false,
  "original_language": "en",
  "origin_country": ["US"]
}
"""

private let tvShowPageJSON = """
{
  "page": 1,
  "results": [\(tvShowJSON)],
  "total_pages": 200,
  "total_results": 4000
}
"""

private let mediaItemMovieJSON = """
{"id":1,"media_type":"movie","title":"Dune","overview":"Epic sci-fi.","popularity":500.0,"vote_average":7.8,"vote_count":8000}
"""
private let mediaItemTVJSON = """
{"id":2,"media_type":"tv","name":"The Bear","overview":"Cooking drama.","popularity":200.0,"vote_average":8.6,"vote_count":3000,"first_air_date":"2022-06-23"}
"""
private let mediaItemPageJSON = """
{
  "page": 1,
  "results": [\(mediaItemMovieJSON), \(mediaItemTVJSON)],
  "total_pages": 1,
  "total_results": 2
}
"""

// MARK: - Configuration Tests

@Suite("TMDBConfiguration")
struct ConfigurationTests {
    @Test func defaultsAreCorrect() {
        let config = TMDBConfiguration(bearerToken: "tok", apiKey: "key")
        #expect(config.bearerToken == "tok")
        #expect(config.apiKey == "key")
        #expect(config.baseURL.absoluteString == "https://api.themoviedb.org/3")
        #expect(config.defaultLanguage == "en-US")
    }

    @Test func imageURLBuildsCorrectly() {
        let config = TMDBConfiguration(bearerToken: "tok")
        let url = config.imageURL(path: "/poster.jpg", size: .w500)
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w500/poster.jpg")
    }

    @Test func imageURLWithCustomSize() {
        let config = TMDBConfiguration(bearerToken: "tok")
        let url = config.imageURL(path: "/backdrop.jpg", size: .original)
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/original/backdrop.jpg")
    }
}

// MARK: - Model Tests

@Suite("Models")
struct ModelTests {
    @Test func movieDecodes() throws {
        let movie = try JSONDecoder().decode(Movie.self, from: Data(movieJSON.utf8))
        #expect(movie.id == 42)
        #expect(movie.title == "Interstellar")
        #expect(movie.voteAverage == 8.4)
        #expect(movie.posterPath == "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg")
        #expect(movie.backdropPath == nil)
    }

    @Test func tvShowDecodes() throws {
        let show = try JSONDecoder().decode(TVShow.self, from: Data(tvShowJSON.utf8))
        #expect(show.id == 99)
        #expect(show.name == "Breaking Bad")
        #expect(show.firstAirDate == "2008-01-20")
        #expect(show.originCountry == ["US"])
    }

    @Test func mediaItemNormalizesMovieTitle() throws {
        let item = try JSONDecoder().decode(MediaItem.self, from: Data(mediaItemMovieJSON.utf8))
        #expect(item.mediaType == "movie")
        #expect(item.title == "Dune")
    }

    @Test func mediaItemNormalizesTVTitle() throws {
        let item = try JSONDecoder().decode(MediaItem.self, from: Data(mediaItemTVJSON.utf8))
        #expect(item.mediaType == "tv")
        #expect(item.title == "The Bear")
        #expect(item.releaseDate == "2022-06-23")
    }

    @Test func timeWindowRawValues() {
        #expect(TimeWindow.day.rawValue == "day")
        #expect(TimeWindow.week.rawValue == "week")
    }
}

// MARK: - Repository Tests

@Suite("TMDBRepositoryImpl")
struct RepositoryTests {
    private func makeRepo(json: String, statusCode: Int = 200) -> TMDBRepositoryImpl {
        let config = TMDBConfiguration(bearerToken: "test_bearer_token")
        return TMDBRepositoryImpl(configuration: config, httpClient: MockHTTPClient(json, statusCode: statusCode))
    }

    @Test func popularMoviesDecodesPage() async throws {
        let repo = makeRepo(json: moviePageJSON)
        let page = try await repo.popularMovies()
        #expect(page.page == 1)
        #expect(page.results.count == 1)
        #expect(page.results[0].title == "Interstellar")
        #expect(page.totalPages == 500)
        #expect(page.totalResults == 10000)
    }

    @Test func popularTVShowsDecodesPage() async throws {
        let repo = makeRepo(json: tvShowPageJSON)
        let page = try await repo.popularTVShows()
        #expect(page.results.count == 1)
        #expect(page.results[0].name == "Breaking Bad")
    }

    @Test func trendingAllDecodesMixedItems() async throws {
        let repo = makeRepo(json: mediaItemPageJSON)
        let page = try await repo.trendingAll(timeWindow: .week)
        #expect(page.results.count == 2)
        #expect(page.results[0].title == "Dune")
        #expect(page.results[1].title == "The Bear")
    }

    @Test func searchMoviesReturnsResults() async throws {
        let repo = makeRepo(json: moviePageJSON)
        let page = try await repo.searchMovies(query: "Interstellar")
        #expect(page.results[0].title == "Interstellar")
    }

    @Test func trendingMoviesDecodesPage() async throws {
        let repo = makeRepo(json: moviePageJSON)
        let page = try await repo.trendingMovies(timeWindow: .day)
        #expect(page.page == 1)
        #expect(page.results.count == 1)
        #expect(page.results[0].title == "Interstellar")
    }

    @Test func searchMoviesRespectsPageParameter() async throws {
        let repo = makeRepo(json: moviePageJSON)
        // Page 2 — mock always returns the same fixture, but we verify no throw
        let page = try await repo.searchMovies(query: "Interstellar", page: 2)
        #expect(page.results[0].title == "Interstellar")
    }

    @Test func searchMoviesThrowsOnEmptyQuery() async throws {
        let repo = makeRepo(json: moviePageJSON)
        await #expect(throws: TMDBError.emptyQuery) {
            _ = try await repo.searchMovies(query: "   ")
        }
    }

    @Test func httpErrorPropagates() async throws {
        let repo = makeRepo(
            json: #"{"status_message":"Invalid API key","status_code":7}"#,
            statusCode: 401
        )
        await #expect(throws: (any Error).self) {
            _ = try await repo.popularMovies()
        }
    }
}

// MARK: - ViewModel Tests

@Suite("TMDBViewModel")
struct ViewModelTests {
    private func makeVM(json: String) -> TMDBViewModel {
        let config = TMDBConfiguration(bearerToken: "test_token")
        let repo = TMDBRepositoryImpl(configuration: config, httpClient: MockHTTPClient(json))
        return TMDBViewModel(repository: repo)
    }

    @Test func fetchTrendingAllForwardsToRepo() async throws {
        let vm = makeVM(json: mediaItemPageJSON)
        let page = try await vm.fetchTrendingAll(timeWindow: .day)
        #expect(page.results.count == 2)
    }

    @Test func fetchPopularMoviesForwardsToRepo() async throws {
        let vm = makeVM(json: moviePageJSON)
        let page = try await vm.fetchPopularMovies()
        #expect(page.results[0].id == 42)
    }
}

// MARK: - Container Tests

@Suite("TMDBContainer", .serialized)
struct ContainerTests {

    /// Reset shared container state before each test to prevent leakage.
    init() { TMDBContainer.shared.reset() }

    @Test func registersConfiguration() {
        TMDBContainer.shared.registerConfiguration {
            TMDBConfiguration(bearerToken: "test_tok", apiKey: "test_key")
        }
        defer { TMDBContainer.shared.reset() }

        let config = _TMDBContainer.shared.configuration()
        #expect(config.bearerToken == "test_tok")
        #expect(config.apiKey == "test_key")
    }

    @Test func injectsCustomHTTPClientViaFactory() async throws {
        TMDBContainer.shared.registerConfiguration {
            TMDBConfiguration(bearerToken: "tok")
        }
        TMDBContainer.shared.registerHTTPClient {
            MockHTTPClient(moviePageJSON) as any HTTPClient
        }
        defer { TMDBContainer.shared.reset() }

        let page = try await TMDBContainer.shared.viewModel.fetchPopularMovies()
        #expect(page.results[0].title == "Interstellar")
    }

    @Test func sdkVersion() {
        #expect(!SwiftAndroidSDK.version.isEmpty)
    }
}
