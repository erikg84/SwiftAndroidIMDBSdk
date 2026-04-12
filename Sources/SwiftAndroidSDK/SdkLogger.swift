import Foundation

#if canImport(os)
import os
#endif

/// SDK-wide logger. Uses:
/// - iOS/macOS: Apple's `os.Logger` (OSLog) for native Console.app integration
/// - Android/Linux: `print()` with level prefix (shows in Logcat)
///
/// No external dependencies — works on all Swift platforms.
enum SdkLog: Sendable {

    #if canImport(os)
    @available(iOS 14.0, macOS 11.0, *)
    private static let osLogger = os.Logger(subsystem: "com.dallaslabs.sdk", category: "SDK")
    #endif

    static func debug(_ message: String) {
        #if canImport(os)
        if #available(iOS 14.0, macOS 11.0, *) {
            osLogger.debug("\(message, privacy: .public)")
            return
        }
        #endif
        print("[DEBUG] [com.dallaslabs.sdk] \(message)")
    }

    static func info(_ message: String) {
        #if canImport(os)
        if #available(iOS 14.0, macOS 11.0, *) {
            osLogger.info("\(message, privacy: .public)")
            return
        }
        #endif
        print("[INFO] [com.dallaslabs.sdk] \(message)")
    }

    static func error(_ message: String) {
        #if canImport(os)
        if #available(iOS 14.0, macOS 11.0, *) {
            osLogger.error("\(message, privacy: .public)")
            return
        }
        #endif
        print("[ERROR] [com.dallaslabs.sdk] \(message)")
    }
}
