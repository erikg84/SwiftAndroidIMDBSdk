// TMDBContainerTestHooks.swift
// Test-only overrides for the DI container.
//
// This file is EXCLUDED from the Android build target via android/Package.swift
// `exclude:` because JExtractSwiftPlugin cannot bridge @escaping closure parameters
// across the JNI boundary — it generates invalid Java callback types for them.
//
// HOWEVER, JExtractSwiftPlugin's `--input-swift <dir>` walks the source tree on
// disk independently of what the Swift build target compiles. Even though the
// android Package.swift excludes this file from the SwiftAndroidSDK target, the
// plugin still SEES it via the directory walk and emits Java wrapper code that
// references `registerConfiguration` / `registerHTTPClient` / `registerRepository`.
// Those wrappers then fail to compile against the (excluded) target with:
//
//     error: value of type 'TMDBContainer' has no member 'registerConfiguration'
//     error: cannot find 'JavaTMDBContainer' in scope
//
// To make exclusion actually work, we ALSO guard the extension with
// `#if canImport(Darwin)`. JExtractSwiftPlugin still parses the file but the
// extension is empty on non-Darwin platforms, so no Java wrappers are emitted.
//
// On iOS/macOS the hooks are available to test targets via @testable import.

#if canImport(Darwin)
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
#endif
