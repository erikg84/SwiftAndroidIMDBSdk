import Testing
import Foundation
@testable import SwiftAndroidSDK

/// Integration tests against the LIVE TMDB API.
///
/// Requires a valid TMDB bearer token in the `TMDB_READ_TOKEN` environment
/// variable. Tests are skipped if the token is not available.
@Suite("TMDB API Integration")
struct TMDBIntegrationTests {

    let repository: TMDBRepository?

    init() {
        guard let token = ProcessInfo.processInfo.environment["TMDB_READ_TOKEN"],
              !token.isEmpty else {
            repository = nil
            return
        }
        let config = TMDBConfiguration(bearerToken: token)
        let httpClient = URLSessionHTTPClient()
        repository = TMDBRepositoryImpl(configuration: config, httpClient: httpClient)
    }

    // MARK: - Trending

    @Test func trendingAllReturnsResults() async throws {
        guard let repo = repository else {
            print("TMDB_READ_TOKEN not set — skipping")
            return
        }
        let page = try await repo.trendingAll(timeWindow: .week, page: 1)
        #expect(!page.results.isEmpty, "Expected trending results")
        #expect(page.totalResults > 0)
    }

    // MARK: - Movies

    @Test func popularMoviesReturnsResults() async throws {
        guard let repo = repository else { return }
        let page = try await repo.popularMovies(page: 1)
        #expect(!page.results.isEmpty, "Expected popular movies")
    }

    // MARK: - TV Shows

    @Test func popularTVShowsReturnsResults() async throws {
        guard let repo = repository else { return }
        let page = try await repo.popularTVShows(page: 1)
        #expect(!page.results.isEmpty, "Expected popular TV shows")
    }

    // MARK: - Search

    @Test func searchMoviesReturnsResults() async throws {
        guard let repo = repository else { return }
        let page = try await repo.searchMovies(query: "batman", page: 1)
        #expect(!page.results.isEmpty, "Expected search results for 'batman'")
    }

    @Test func searchMoviesWithEmptyQueryThrows() async throws {
        guard let repo = repository else { return }
        do {
            _ = try await repo.searchMovies(query: "", page: 1)
            Issue.record("Expected TMDBError.emptyQuery to be thrown")
        } catch let error as TMDBError {
            #expect(error == .emptyQuery)
        }
    }
}
