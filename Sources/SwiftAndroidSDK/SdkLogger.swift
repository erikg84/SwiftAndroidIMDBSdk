import Logging

/// SDK-wide logger instance.
///
/// Uses `apple/swift-log` which routes to:
/// - iOS/macOS: StreamLogHandler (stdout) — consumers can bootstrap OSLog
/// - Android: Logcat via AndroidLogging (when bootstrapped by the host app)
///
/// Consumers can customize the logging backend by calling
/// `LoggingSystem.bootstrap(...)` before `TMDBContainer.configure()`.
/// If no bootstrap is called, swift-log defaults to stdout.
let sdkLog = Logger(label: "com.dallaslabs.sdk")
