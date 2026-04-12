# Workplan: GraphQL Countries API + Network Interceptor Support

## Summary

Add 3 new features powered by the Countries GraphQL API and ensure all HTTP
traffic (REST + GraphQL) flows through the client-injectable `HTTPClient`
protocol for interceptor support (Chucker on Android via OkHttp adapter,
Pulse on iOS via URLSession delegate).

**API**: https://countries.trevorblades.com/ (public, no auth, no rate limits)

---

## Tasks

### Phase 1: GraphQL Infrastructure

- [ ] **1.1** Create `Countries/Network/GraphqlClient.swift`
  - `public final class GraphqlClient: Sendable`
  - Init takes `HTTPClient` (same protocol as TMDB calls)
  - `func query<T: Decodable>(url: URL, query: String) async throws -> T`
  - Builds `URLRequest` with POST, JSON body `{"query": "..."}`
  - Validates HTTP response, decodes JSON, handles errors
  - Because it uses the shared `HTTPClient`, any interceptor registered by the
    client app (Chucker's OkHttp adapter on Android, Pulse on iOS) captures
    GraphQL traffic alongside TMDB REST traffic

- [ ] **1.2** Create `Countries/Network/GraphqlResponse.swift`
  - `struct GraphqlResponse<T: Decodable>: Decodable` with `data: T`
  - `struct GraphqlError: Decodable` with `message: String`
  - `struct GraphqlErrorResponse: Decodable` with `errors: [GraphqlError]`

### Phase 2: Countries Models

- [ ] **2.1** Create `Countries/Models/Country.swift`
  - `public struct Country: Codable, Sendable, Identifiable`
  - Properties: `code`, `name`, `emoji`, `currency` (optional), `continent: ContinentRef`
  - `id` computed from `code`

- [ ] **2.2** Create `Countries/Models/Continent.swift`
  - `public struct Continent: Codable, Sendable, Identifiable`
  - Properties: `code`, `name`, `countries: [CountryRef]`
  - `public struct ContinentRef: Codable, Sendable` — lightweight reference
  - `public struct CountryRef: Codable, Sendable, Identifiable`

- [ ] **2.3** Create `Countries/Models/Language.swift`
  - `public struct Language: Codable, Sendable, Identifiable`
  - Properties: `code`, `name` (optional), `native` (optional)
  - `nativeName` is the Swift property name (CodingKey maps to `native`)

### Phase 3: Repository

- [ ] **3.1** Create `Countries/Repository/CountriesRepository.swift`
  - Protocol with 3 async throws functions:
    - `func countries() async throws -> [Country]`
    - `func continents() async throws -> [Continent]`
    - `func languages() async throws -> [Language]`

- [ ] **3.2** Create `Countries/Repository/CountriesRepositoryImpl.swift`
  - `public final class CountriesRepositoryImpl: CountriesRepository, Sendable`
  - Init takes `GraphqlClient`
  - Static endpoint: `https://countries.trevorblades.com/`
  - Each method sends the appropriate GraphQL query string
  - Unwraps `GraphqlResponse<T>.data` before returning

### Phase 4: ViewModels

- [ ] **4.1** Create `Countries/ViewModel/CountriesViewModel.swift`
  - `public final class CountriesViewModel: Sendable`
  - Init takes `CountriesRepository`
  - `public func loadCountries() async throws -> [Country]`
  - Stateless command pattern (matches existing TMDB ViewModels)

- [ ] **4.2** Create `Countries/ViewModel/ContinentsViewModel.swift`
  - Same pattern: `public func loadContinents() async throws -> [Continent]`

- [ ] **4.3** Create `Countries/ViewModel/LanguagesViewModel.swift`
  - Same pattern: `public func loadLanguages() async throws -> [Language]`

### Phase 5: DI Registration

- [ ] **5.1** Update `TMDBContainer.swift` — `_TMDBContainer`
  - Register `GraphqlClient` as singleton (injected with shared `HTTPClient`)
  - Register `CountriesRepository` → `CountriesRepositoryImpl` as singleton
  - Register 3 ViewModel factories

- [ ] **5.2** Update `TMDBContainer.swift` — public facade
  - Add static accessors:
    - `public static func getCountriesViewModel() -> CountriesViewModel`
    - `public static func getContinentsViewModel() -> ContinentsViewModel`
    - `public static func getLanguagesViewModel() -> LanguagesViewModel`
  - Add `public var countriesRepository: CountriesRepository` property

### Phase 6: Integration Tests

- [ ] **6.1** Create `Tests/SwiftAndroidSDKTests/CountriesIntegrationTests.swift`
  - Uses real `URLSessionHTTPClient` + real Countries API
  - Tests (all `async throws`):
    - `countriesReturnsNonEmptyList()` — verify > 0 countries
    - `countriesContainUSA()` — find US by code
    - `countriesHaveEmojiFlags()` — verify emoji field populated
    - `continentsReturnsSeven()` — verify 7 continents
    - `continentsContainCountries()` — verify nested countries
    - `languagesReturnsNonEmptyList()` — verify > 0 languages
    - `languagesContainEnglish()` — find English by code "en"
    - `graphqlClientHandlesMalformedQuery()` — verify error handling

- [ ] **6.2** Create `Tests/SwiftAndroidSDKTests/TMDBIntegrationTests.swift`
  - Uses real `URLSessionHTTPClient` + real TMDB API
  - Reads `TMDB_READ_TOKEN` from environment (skip if missing)
  - Tests:
    - `trendingAllReturnsResults()` — verify non-empty
    - `popularMoviesReturnsResults()` — verify non-empty
    - `popularTVShowsReturnsResults()` — verify non-empty
    - `searchMoviesReturnsResults()` — search "batman", verify results
    - `searchMoviesWithEmptyQueryThrows()` — verify TMDBError.emptyQuery

- [ ] **6.3** Run all tests locally: `swift test`

### Phase 7: CI Update

- [ ] **7.1** Update `ci.yml` — pass TMDB token to test step
  ```yaml
  - name: Build and Test
    env:
      TMDB_READ_TOKEN: ${{ secrets.TMDB_READ_TOKEN }}
    run: swift test
  ```

- [ ] **7.2** Add `TMDB_READ_TOKEN` secret to the GitHub repo

### Phase 8: Publish

- [ ] **8.1** Commit all changes
- [ ] **8.2** Bump version in `android/gradle.properties` (1.1.4)
- [ ] **8.3** Tag new version (v1.1.4)
- [ ] **8.4** Verify CI passes (tests + publish)
- [ ] **8.5** Verify new ViewModels appear in JExtract-generated Java bindings

---

## Files Changed/Created Summary

| Action | File |
|--------|------|
| CREATE | `Sources/SwiftAndroidSDK/Countries/Models/Country.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Models/Continent.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Models/Language.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Network/GraphqlClient.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Network/GraphqlResponse.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Repository/CountriesRepository.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/Repository/CountriesRepositoryImpl.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/ViewModel/CountriesViewModel.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/ViewModel/ContinentsViewModel.swift` |
| CREATE | `Sources/SwiftAndroidSDK/Countries/ViewModel/LanguagesViewModel.swift` |
| CREATE | `Tests/SwiftAndroidSDKTests/CountriesIntegrationTests.swift` |
| CREATE | `Tests/SwiftAndroidSDKTests/TMDBIntegrationTests.swift` |
| MODIFY | `Sources/SwiftAndroidSDK/Container/TMDBContainer.swift` |
| MODIFY | `.github/workflows/ci.yml` |

## Dependencies

No new dependencies. `URLSession` + `JSONDecoder` handle GraphQL POST + JSON
deserialization natively.

## Network Interceptor Notes

No SDK code changes needed for interceptor support. The existing architecture
already supports it:

- **`HTTPClient` protocol**: Client apps can register any implementation via
  `TMDBContainer.getShared().registerHTTPClient(...)`. The new `GraphqlClient`
  reuses the same `HTTPClient` instance from Swinject, so interceptors
  automatically capture both REST and GraphQL traffic.

- **iOS (Pulse)**: Client passes `URLSessionHTTPClient(session: pulseSession)`
  where `pulseSession` is a `URLSession` configured with Pulse's
  `URLSessionProxyDelegate`.

- **Android (Chucker)**: Client creates a Kotlin class implementing the
  `HTTPClient` protocol (via JExtract binding) backed by OkHttp with Chucker
  interceptor, then registers it via `registerHTTPClient()`.

The interceptor wiring is client-side work (separate phase after SDK publish).
