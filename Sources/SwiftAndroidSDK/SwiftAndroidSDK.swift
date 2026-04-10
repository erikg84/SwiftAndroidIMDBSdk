#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - SDK Entry Point

/// Top-level SDK client. Create one instance and reuse it.
public final class SwiftAndroidSDK {

    public static let version = "1.0.0"

    public init() {}

    /// Returns the SDK version string.
    public func sdkVersion() -> String { SwiftAndroidSDK.version }
}

// MARK: - String Utilities

/// Reverses a UTF-8 string.
public func reverseString(_ input: String) -> String {
    String(input.reversed())
}

/// Computes a simple checksum (sum of UTF-8 byte values mod 256).
public func checksum(_ input: String) -> Int {
    input.utf8.reduce(0) { ($0 + Int($1)) % 256 }
}

// MARK: - Encoding

/// Base64-encodes a UTF-8 string.
public func base64Encode(_ input: String) -> String {
    Data(input.utf8).base64EncodedString()
}

/// Decodes a Base64 string. Returns an empty string if the input is invalid.
public func base64Decode(_ encoded: String) -> String {
    guard
        let data = Data(base64Encoded: encoded),
        let result = String(data: data, encoding: .utf8)
    else { return "" }
    return result
}

// MARK: - JSON

/// Returns `true` if the string is valid JSON.
public func isValidJSON(_ input: String) -> Bool {
    guard let data = input.data(using: .utf8) else { return false }
    return (try? JSONSerialization.jsonObject(with: data)) != nil
}

/// Pretty-prints a compact JSON string. Returns the original string on failure.
public func prettyPrintJSON(_ input: String) -> String {
    guard
        let data = input.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data),
        let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
        let result = String(data: pretty, encoding: .utf8)
    else { return input }
    return result
}
