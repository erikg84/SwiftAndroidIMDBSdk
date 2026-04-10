import Foundation

/// Composition root for the SwiftAndroidSDK.
///
/// Initialise once (e.g. at app launch) with your ``TMDBConfiguration``,
/// then inject ``viewModel`` or ``repository`` wherever needed.
///
/// ```swift
/// let sdk = TMDBContainer(configuration: TMDBConfiguration(
///     bearerToken: BuildConfig.TMDB_BEARER_TOKEN  // read from local.properties / env
/// ))
///
/// let page = try await sdk.viewModel.fetchPopularMovies()
/// ```
public final class TMDBContainer: Sendable {
    public let configuration: TMDBConfiguration
    public let httpClient: HTTPClient
    public let repository: TMDBRepository
    public let viewModel: TMDBViewModel

    /// Create the container.
    /// - Parameters:
    ///   - configuration: TMDB credentials and settings.
    ///   - httpClient: Override for testing; defaults to `URLSessionHTTPClient`.
    public init(
        configuration: TMDBConfiguration,
        httpClient: HTTPClient? = nil
    ) {
        self.configuration = configuration
        let client = httpClient ?? URLSessionHTTPClient()
        self.httpClient = client
        let repo = TMDBRepositoryImpl(configuration: configuration, httpClient: client)
        self.repository = repo
        self.viewModel = TMDBViewModel(repository: repo)
    }
}
