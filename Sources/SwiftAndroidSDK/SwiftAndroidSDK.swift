/// SwiftAndroidSDK — Cross-platform TMDB SDK
///
/// Targets iOS (via SPM) and Android (via .aar + swift-java JNI).
///
/// **Quick start:**
/// ```swift
/// let sdk = TMDBContainer(configuration: TMDBConfiguration(bearerToken: "your_token"))
/// let trending = try await sdk.viewModel.fetchTrendingAll()
/// ```
///
/// Entry points:
/// - ``TMDBContainer`` — composition root / DI container
/// - ``TMDBViewModel`` — async API methods (bridges to Java CompletableFuture on Android)
/// - ``TMDBRepository`` — protocol for direct injection / mocking
public enum SDK {
    /// SDK semantic version string.
    public static let version = "0.1.0"
}
