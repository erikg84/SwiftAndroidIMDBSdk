import Foundation
import Factory

/// Factory-backed DI container for SwiftAndroidSDK.
///
/// **One-time setup at app launch:**
/// ```swift
/// TMDBContainer.shared.configuration.register {
///     TMDBConfiguration(bearerToken: BuildConfig.TMDB_TOKEN)
/// }
/// ```
///
/// **iOS — `@Injected` property wrapper:**
/// ```swift
/// @Injected(\TMDBContainer.viewModel) private var vm
/// ```
///
/// **Android — direct call via JNI:**
/// ```swift
/// let vm = TMDBContainer.shared.viewModel()
/// ```
///
/// **Testing — override any dependency, reset after:**
/// ```swift
/// TMDBContainer.shared.httpClient.register { MockHTTPClient(...) }
/// defer { TMDBContainer.shared.reset() }
/// ```
public final class TMDBContainer: SharedContainer {
    public static let shared = TMDBContainer()
    public let manager = ContainerManager()
    public init() {}
}

extension TMDBContainer {

    /// TMDB API credentials. **Must be registered before first SDK call.**
    public var configuration: Factory<TMDBConfiguration> {
        self { TMDBConfiguration(bearerToken: "") }
    }

    /// Shared HTTP client — singleton scope, one `URLSession` per container lifetime.
    /// Override in tests: `TMDBContainer.shared.httpClient.register { MockHTTPClient(...) }`
    var httpClient: Factory<any HTTPClient> {
        self { URLSessionHTTPClient() as any HTTPClient }.singleton
    }

    /// TMDB repository — singleton, backed by the shared `httpClient`.
    public var repository: Factory<any TMDBRepository> {
        self {
            TMDBRepositoryImpl(
                configuration: self.configuration(),
                httpClient: self.httpClient()
            ) as any TMDBRepository
        }.singleton
    }

    /// TMDB ViewModel — cached scope, re-created after a container reset.
    public var viewModel: Factory<TMDBViewModel> {
        self { TMDBViewModel(repository: self.repository()) }.cached
    }
}
