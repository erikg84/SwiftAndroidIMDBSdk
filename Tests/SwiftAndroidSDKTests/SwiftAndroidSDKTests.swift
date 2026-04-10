import Testing
@testable import SwiftAndroidSDK

@Suite("SwiftAndroidSDK")
struct SwiftAndroidSDKTests {

    @Test func version() {
        let sdk = SwiftAndroidSDK()
        #expect(sdk.sdkVersion() == SwiftAndroidSDK.version)
    }

    @Test func reverse() {
        #expect(reverseString("hello") == "olleh")
        #expect(reverseString("") == "")
    }

    @Test func checksumIsStable() {
        #expect(checksum("hello") == checksum("hello"))
        #expect(checksum("hello") != checksum("world"))
    }

    @Test func base64RoundTrip() {
        let original = "Swift on Android!"
        let encoded  = base64Encode(original)
        let decoded  = base64Decode(encoded)
        #expect(decoded == original)
    }

    @Test func base64InvalidInput() {
        #expect(base64Decode("not-base64!!!") == "")
    }

    @Test func jsonValidation() {
        #expect(isValidJSON(#"{"key":"value"}"#))
        #expect(!isValidJSON("not json"))
    }

    @Test func jsonPrettyPrint() {
        let compact = #"{"a":1,"b":2}"#
        let pretty  = prettyPrintJSON(compact)
        #expect(pretty.contains("\n"))
    }
}
