import Testing
import Foundation
@testable import SwiftAndroidSDK

/// Integration tests against the LIVE Countries GraphQL API.
/// No mocks — every test hits https://countries.trevorblades.com/
@Suite("Countries API Integration")
struct CountriesIntegrationTests {

    let repository: CountriesRepository

    init() {
        let httpClient = URLSessionHTTPClient()
        let graphqlClient = GraphqlClient(httpClient: httpClient)
        repository = CountriesRepositoryImpl(graphqlClient: graphqlClient)
    }

    // MARK: - Countries

    @Test func countriesReturnsNonEmptyList() async throws {
        let countries = try await repository.countries()
        #expect(!countries.isEmpty, "Expected at least one country")
    }

    @Test func countriesContainUSA() async throws {
        let countries = try await repository.countries()
        let usa = countries.first(where: { $0.code == "US" })
        #expect(usa != nil, "Expected to find US")
        #expect(usa?.name == "United States")
    }

    @Test func countriesHaveEmojiFlags() async throws {
        let countries = try await repository.countries()
        let withEmoji = countries.filter { !$0.emoji.isEmpty }
        #expect(withEmoji.count == countries.count, "All countries should have emoji flags")
    }

    @Test func countriesHaveContinentRef() async throws {
        let countries = try await repository.countries()
        let usa = countries.first(where: { $0.code == "US" })!
        #expect(usa.continent.code == "NA")
        #expect(usa.continent.name == "North America")
    }

    // MARK: - Continents

    @Test func continentsReturnsSeven() async throws {
        let continents = try await repository.continents()
        #expect(continents.count == 7, "Expected 7 continents")
    }

    @Test func continentsContainCountries() async throws {
        let continents = try await repository.continents()
        let na = continents.first(where: { $0.code == "NA" })
        #expect(na != nil, "Expected North America")
        #expect(!na!.countries.isEmpty, "North America should have countries")
        #expect(na!.countries.contains(where: { $0.code == "US" }), "NA should contain US")
    }

    // MARK: - Languages

    @Test func languagesReturnsNonEmptyList() async throws {
        let languages = try await repository.languages()
        #expect(!languages.isEmpty, "Expected at least one language")
    }

    @Test func languagesContainEnglish() async throws {
        let languages = try await repository.languages()
        let english = languages.first(where: { $0.code == "en" })
        #expect(english != nil, "Expected to find English")
        #expect(english?.name == "English")
    }

    // MARK: - GraphQL error handling

    @Test func graphqlClientHandlesMalformedQuery() async throws {
        let httpClient = URLSessionHTTPClient()
        let client = GraphqlClient(httpClient: httpClient)
        let url = URL(string: "https://countries.trevorblades.com/")!

        // A syntactically invalid query — the server returns errors in the response.
        // The test verifies we don't crash on unexpected response shapes.
        do {
            let _: GraphqlResponse<CountriesData> = try await client.query(
                url: url, query: "{ invalidField }"
            )
            // If it succeeds (some servers return empty data), that's fine
        } catch {
            // Any error is acceptable — the point is no unhandled crash
            #expect(true)
        }
    }
}
