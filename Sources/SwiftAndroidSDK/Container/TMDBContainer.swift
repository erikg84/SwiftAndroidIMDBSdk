import Foundation
// Internal import: Factory types do not appear in the public .swiftinterface,
// which prevents a known naming-conflict bug when building with
// BUILD_LIBRARY_FOR_DISTRIBUTION=YES (XCFramework).
internal import Factory

// ─── Internal Factory container (hidden from consumers) ──────────────────────
final class _TMDBContainer: SharedContainer, @unchecked Sendable {
    static let shared = _TMDBContainer()
    var manager = ContainerManager()
}

extension _TMDBContainer {
    var configuration: Factory<TMDBConfiguration> {
        self { TMDBConfiguration(bearerToken: "") }
    }
    var httpClient: Factory<any HTTPClient> {
        self { URLSessionHTTPClient() as any HTTPClient }.singleton
    }
    var repository: Factory<any TMDBRepository> {
        self {
            TMDBRepositoryImpl(
                configuration: self.configuration(),
                httpClient: self.httpClient()
            ) as any TMDBRepository
        }.singleton
    }
    var viewModel: Factory<TMDBViewModel> {
        self { TMDBViewModel(repository: self.repository()) }.cached
    }
}

// ─── Public facade — no Factory types in public surface ──────────────────────
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
        _TMDBContainer.shared.configuration.register {
            TMDBConfiguration(bearerToken: bearerToken, apiKey: apiKey)
        }
    }

    // ── Resolved dependencies ────────────────────────────────────────────────

    /// The TMDB repository. Singleton for the container's lifetime.
    public var repository: any TMDBRepository { _TMDBContainer.shared.repository() }

    /// A ready-to-use ViewModel. Cached — same instance until `reset()`.
    public var viewModel: TMDBViewModel { _TMDBContainer.shared.viewModel() }

    /// Reset all cached/singleton instances. Call in test `tearDown`.
    public func reset() { _TMDBContainer.shared.manager.reset() }
}
