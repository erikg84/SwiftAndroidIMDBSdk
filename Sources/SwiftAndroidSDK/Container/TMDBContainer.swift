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
        c.register(TMDBViewModel.self) { resolver in
            TMDBViewModel(repository: resolver.resolve((any TMDBRepository).self)!)
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
    var viewModel: TMDBViewModel {
        resolver.resolve(TMDBViewModel.self)!
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

    // ── Configuration ────────────────────────────────────────────────────────

    /// Configure TMDB credentials. Call once at app launch before any API call.
    public func configure(bearerToken: String, apiKey: String = "") {
        _TMDBContainer.shared.registerConfiguration {
            TMDBConfiguration(bearerToken: bearerToken, apiKey: apiKey)
        }
    }

    // ── Resolved dependencies ────────────────────────────────────────────────

    /// The TMDB repository. Singleton for the container's lifetime.
    public var repository: any TMDBRepository { _TMDBContainer.shared.repository }

    /// A ready-to-use ViewModel. Cached — same instance until `reset()`.
    public var viewModel: TMDBViewModel { _TMDBContainer.shared.viewModel }

    /// Reset all cached/singleton instances. Call in test `tearDown`.
    public func reset() { _TMDBContainer.shared.reset() }
}
