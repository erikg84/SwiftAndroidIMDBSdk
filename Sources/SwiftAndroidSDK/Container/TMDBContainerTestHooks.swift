// TMDBContainerTestHooks.swift
// Test-only overrides for the DI container.
//
// This file is EXCLUDED from the Android build target (android/Package.swift)
// because JExtractSwiftPlugin cannot bridge @escaping closure parameters across
// the JNI boundary — it generates invalid Java callback types for them.
//
// On iOS/macOS these hooks are available to test targets via @testable import.

extension TMDBContainer {
    /// Override the TMDB configuration factory. Use in tests, reset after.
    public func registerConfiguration(_ factory: @Sendable @escaping () -> TMDBConfiguration) {
        _TMDBContainer.shared.configuration.register(factory: factory)
    }

    /// Override the HTTP client factory. Use in tests to inject mock responses.
    public func registerHTTPClient(_ factory: @Sendable @escaping () -> any HTTPClient) {
        _TMDBContainer.shared.httpClient.register(factory: factory)
    }

    /// Override the repository factory. Use in tests to inject a full mock.
    public func registerRepository(_ factory: @Sendable @escaping () -> any TMDBRepository) {
        _TMDBContainer.shared.repository.register(factory: factory)
    }
}
