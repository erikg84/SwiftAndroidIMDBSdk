import Foundation

struct GraphqlResponse<T: Decodable>: Decodable {
    let data: T
}

struct GraphqlErrorResponse: Decodable {
    let errors: [GraphqlErrorDetail]
}

struct GraphqlErrorDetail: Decodable {
    let message: String
}

// GraphQL response wrappers for the Countries API
struct CountriesData: Decodable { let countries: [Country] }
struct ContinentsData: Decodable { let continents: [Continent] }
struct LanguagesData: Decodable { let languages: [Language] }
