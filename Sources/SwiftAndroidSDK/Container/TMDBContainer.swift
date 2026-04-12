import Foundation
// Internal import: Swinject types do not appear in the public .swiftinterface,
// keeping the SDK's public surface free of any DI library leakage. Swinject's
// module name (`Swinject`) does NOT collide with any of its type names (the
// main type is `Container`), so it is unaffected by the upstream
// .swiftinterface ambiguity bug that broke Factory.
internal import Swinject

// ─── Internal Swinject container (hidden from consumers) ─────────────────────
//
// We wrap a single Swinject `Container` and expose typed accessors. The wrapper
// uses `synchronize()` so all reads/writes are thread-safe — Swinject's plain
// Container is NOT thread-safe by default.
final class _TMDBContainer: @unchecked Sendable {
    static let shared = _TMDBContainer()

    // The underlying Swinject container, wrapped in a thread-safe resolver.
    private let container: Container
    private let resolver: Resolver

    private init() {
        let c = Container()

        // Default registrations. Each can be overridden later via re-registration.

        // Configuration: transient by default — every resolve creates a fresh
        // value from whatever factory is currently registered. This matches
        // Factory's plain `self { ... }` semantics.
        c.register(TMDBConfiguration.self) { _ in
            TMDBConfiguration(bearerToken: "")
        }

        // HTTPClient: container-scoped (singleton). Same instance returned for
        // every resolve until the container is reset.
        c.register((any HTTPClient).self) { _ in
            URLSessionHTTPClient() as any HTTPClient
        }.inObjectScope(.container)

        // Repository: container-scoped (singleton). Resolves Configuration and
        // HTTPClient from the same container.
        c.register((any TMDBRepository).self) { resolver in
            TMDBRepositoryImpl(
                configuration: resolver.resolve(TMDBConfiguration.self)!,
                httpClient:    resolver.resolve((any HTTPClient).self)!
            ) as any TMDBRepository
        }.inObjectScope(.container)

        // ViewModel: container-scoped (cached). Same instance until reset.
        // DEPRECATED — superseded by the per-screen viewmodels below.
        c.register(TMDBViewModel.self) { resolver in
            TMDBViewModel(repository: resolver.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        // ── Per-screen viewmodels (v1.1.0+) ──────────────────────────────────
        // Each viewmodel is a stateless command object that wraps a focused
        // subset of the repository API. Container-scoped (singleton) — see
        // PROPOSAL-shared-viewmodels.md §4.5 for the rationale.

        c.register(TMDBHomeViewModel.self) { r in
            TMDBHomeViewModel(repository: r.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        c.register(TMDBMoviesViewModel.self) { r in
            TMDBMoviesViewModel(repository: r.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        c.register(TMDBTVShowsViewModel.self) { r in
            TMDBTVShowsViewModel(repository: r.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        c.register(TMDBSearchViewModel.self) { r in
            TMDBSearchViewModel(repository: r.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        c.register(TMDBTrendingViewModel.self) { r in
            TMDBTrendingViewModel(repository: r.resolve((any TMDBRepository).self)!)
        }.inObjectScope(.container)

        // ── Countries GraphQL (v1.1.4+) ─────────────────────────────────────
        // GraphqlClient shares the same HTTPClient so interceptors (Chucker,
        // Pulse) capture both REST and GraphQL traffic.

        c.register(GraphqlClient.self) { r in
            GraphqlClient(httpClient: r.resolve((any HTTPClient).self)!)
        }.inObjectScope(.container)

        c.register((any CountriesRepository).self) { r in
            CountriesRepositoryImpl(graphqlClient: r.resolve(GraphqlClient.self)!)
                as any CountriesRepository
        }.inObjectScope(.container)

        c.register(CountriesViewModel.self) { r in
            CountriesViewModel(repository: r.resolve((any CountriesRepository).self)!)
        }.inObjectScope(.container)

        c.register(ContinentsViewModel.self) { r in
            ContinentsViewModel(repository: r.resolve((any CountriesRepository).self)!)
        }.inObjectScope(.container)

        c.register(LanguagesViewModel.self) { r in
            LanguagesViewModel(repository: r.resolve((any CountriesRepository).self)!)
        }.inObjectScope(.container)

        self.container = c
        self.resolver = c.synchronize()
    }

    // ── Resolved instances ──────────────────────────────────────────────────

    var configuration: TMDBConfiguration {
        resolver.resolve(TMDBConfiguration.self)!
    }
    var httpClient: any HTTPClient {
        resolver.resolve((any HTTPClient).self)!
    }
    var repository: any TMDBRepository {
        resolver.resolve((any TMDBRepository).self)!
    }
    /// Deprecated — superseded by the per-screen viewmodels below.
    /// Compile-time warnings on the references to `TMDBViewModel` here are
    /// expected; they go away when the type is removed in v2.0.0.
    @available(*, deprecated, message: "Use per-screen viewmodels (homeViewModel etc.). Removed in v2.0.0.")
    var viewModel: TMDBViewModel {
        resolver.resolve(TMDBViewModel.self)!
    }

    // Per-screen viewmodels (v1.1.0+)
    var homeViewModel: TMDBHomeViewModel {
        resolver.resolve(TMDBHomeViewModel.self)!
    }
    var moviesViewModel: TMDBMoviesViewModel {
        resolver.resolve(TMDBMoviesViewModel.self)!
    }
    var tvShowsViewModel: TMDBTVShowsViewModel {
        resolver.resolve(TMDBTVShowsViewModel.self)!
    }
    var searchViewModel: TMDBSearchViewModel {
        resolver.resolve(TMDBSearchViewModel.self)!
    }
    var trendingViewModel: TMDBTrendingViewModel {
        resolver.resolve(TMDBTrendingViewModel.self)!
    }

    // Countries GraphQL viewmodels (v1.1.4+)
    var countriesViewModel: CountriesViewModel {
        resolver.resolve(CountriesViewModel.self)!
    }
    var continentsViewModel: ContinentsViewModel {
        resolver.resolve(ContinentsViewModel.self)!
    }
    var languagesViewModel: LanguagesViewModel {
        resolver.resolve(LanguagesViewModel.self)!
    }
    var countriesRepository: any CountriesRepository {
        resolver.resolve((any CountriesRepository).self)!
    }

    // ── Re-registration (used by configure() and test hooks) ────────────────

    func registerConfiguration(_ factory: @Sendable @escaping () -> TMDBConfiguration) {
        // Swinject permits re-registration of an already-registered service —
        // the new factory replaces the old one. We must also reset the object
        // scope so a previously-cached instance is dropped.
        container.register(TMDBConfiguration.self) { _ in factory() }
        container.resetObjectScope(.container)
    }

    func registerHTTPClient(_ factory: @Sendable @escaping () -> any HTTPClient) {
        container.register((any HTTPClient).self) { _ in factory() }
            .inObjectScope(.container)
        container.resetObjectScope(.container)
    }

    func registerRepository(_ factory: @Sendable @escaping () -> any TMDBRepository) {
        container.register((any TMDBRepository).self) { _ in factory() }
            .inObjectScope(.container)
        container.resetObjectScope(.container)
    }

    // ── Reset ───────────────────────────────────────────────────────────────

    func reset() {
        // Drop all container-scoped cached instances. The default factories
        // (registered in init) remain in place; only the cached singletons
        // are cleared.
        container.resetObjectScope(.container)
    }
}

// ─── Public facade — no Swinject types in public surface ─────────────────────
/// Dependency container for SwiftAndroidSDK.
///
/// **One-time setup at app launch:**
/// ```swift
/// TMDBContainer.shared.configure(bearerToken: "your_token")
/// ```
///
/// **Android — direct call via JNI:**
/// ```swift
/// let vm = TMDBContainer.shared.viewModel
/// ```
///
/// **Testing — override any dependency, reset after:**
/// ```swift
/// TMDBContainer.shared.registerHTTPClient { MockHTTPClient(...) }
/// defer { TMDBContainer.shared.reset() }
/// ```
public final class TMDBContainer: @unchecked Sendable {
    public static let shared = TMDBContainer()
    private init() {}

    /// Returns the shared singleton — exposed as a static func so JExtractSwiftPlugin
    /// generates a Java binding (stored `static let` properties are not bound by JExtract).
    public static func getShared() -> TMDBContainer { shared }

    // ── Configuration ────────────────────────────────────────────────────────

    /// Configure TMDB credentials. Call once at app launch before any API call.
    public func configure(bearerToken: String, apiKey: String = "") {
        sdkLog.info("TMDBContainer.configure() — initializing SDK")
        _TMDBContainer.shared.registerConfiguration {
            TMDBConfiguration(bearerToken: bearerToken, apiKey: apiKey)
        }
        sdkLog.info("TMDBContainer.configure() — SDK ready")
    }

    // ── Resolved dependencies ────────────────────────────────────────────────

    /// The TMDB repository. Singleton for the container's lifetime.
    public var repository: any TMDBRepository { _TMDBContainer.shared.repository }

    /// A ready-to-use ViewModel. Cached — same instance until `reset()`.
    @available(*, deprecated, message: "TMDBViewModel is replaced by per-screen viewmodels (TMDBContainer.getHomeViewModel(), .getMoviesViewModel(), .getTVShowsViewModel(), .getSearchViewModel(), .getTrendingViewModel()). Will be removed in v2.0.0. See PROPOSAL-shared-viewmodels.md.")
    public var viewModel: TMDBViewModel { _TMDBContainer.shared.viewModel }

    /// Reset all cached/singleton instances. Call in test `tearDown`.
    public func reset() { _TMDBContainer.shared.reset() }
}

// MARK: - Per-screen ViewModel static accessors (JExtract-friendly)

extension TMDBContainer {
    /// Returns the Home screen viewmodel — trending media of all types.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getHomeViewModel() -> TMDBHomeViewModel {
        _TMDBContainer.shared.homeViewModel
    }

    /// Returns the Movies tab viewmodel — popular movies.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getMoviesViewModel() -> TMDBMoviesViewModel {
        _TMDBContainer.shared.moviesViewModel
    }

    /// Returns the TV Shows tab viewmodel — popular TV shows.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getTVShowsViewModel() -> TMDBTVShowsViewModel {
        _TMDBContainer.shared.tvShowsViewModel
    }

    /// Returns the Search screen viewmodel.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getSearchViewModel() -> TMDBSearchViewModel {
        _TMDBContainer.shared.searchViewModel
    }

    /// Returns the Trending screen viewmodel — movies-only with day/week toggle.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getTrendingViewModel() -> TMDBTrendingViewModel {
        _TMDBContainer.shared.trendingViewModel
    }

    // ── Countries GraphQL viewmodels (v1.1.4+) ─────────────────────────────

    /// Returns the Countries screen viewmodel — all countries with flag, currency.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getCountriesViewModel() -> CountriesViewModel {
        _TMDBContainer.shared.countriesViewModel
    }

    /// Returns the Continents screen viewmodel — continents with nested countries.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getContinentsViewModel() -> ContinentsViewModel {
        _TMDBContainer.shared.continentsViewModel
    }

    /// Returns the Languages screen viewmodel — world languages.
    /// Static func form for JExtractSwiftPlugin Java binding.
    public static func getLanguagesViewModel() -> LanguagesViewModel {
        _TMDBContainer.shared.languagesViewModel
    }

    /// The Countries repository. Singleton for the container's lifetime.
    public var countriesRepository: any CountriesRepository {
        _TMDBContainer.shared.countriesRepository
    }
}
