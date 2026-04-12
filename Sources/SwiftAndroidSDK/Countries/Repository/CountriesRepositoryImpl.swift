import Foundation

public final class CountriesRepositoryImpl: CountriesRepository, Sendable {
    private let graphqlClient: GraphqlClient

    static let endpoint = URL(string: "https://countries.trevorblades.com/")!

    static let countriesQuery = """
        { countries { code name emoji currency continent { code name } } }
        """

    static let continentsQuery = """
        { continents { code name countries { code name emoji } } }
        """

    static let languagesQuery = """
        { languages { code name native } }
        """

    public init(graphqlClient: GraphqlClient) {
        self.graphqlClient = graphqlClient
    }

    public func countries() async throws -> [Country] {
        let response: GraphqlResponse<CountriesData> = try await graphqlClient.query(
            url: Self.endpoint,
            query: Self.countriesQuery
        )
        return response.data.countries
    }

    public func continents() async throws -> [Continent] {
        let response: GraphqlResponse<ContinentsData> = try await graphqlClient.query(
            url: Self.endpoint,
            query: Self.continentsQuery
        )
        return response.data.continents
    }

    public func languages() async throws -> [Language] {
        let response: GraphqlResponse<LanguagesData> = try await graphqlClient.query(
            url: Self.endpoint,
            query: Self.languagesQuery
        )
        return response.data.languages
    }
}
