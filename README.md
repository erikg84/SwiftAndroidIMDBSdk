# SwiftAndroidSDK

A cross-platform **Swift** SDK — business logic shared between **iOS** and **Android** from a single Swift codebase. On Android, Swift is cross-compiled to native `.so` libraries via the Swift SDK for Android and exposed to Kotlin/Java through `swift-java`'s JExtractSwiftPlugin.

## Technology Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Language** | Swift 6.3 | Single source of truth for both platforms |
| **Android Cross-Compilation** | Swift SDK for Android | Compiles Swift to native ARM/x86 `.so` files |
| **Android JNI Bridge** | swift-java / JExtractSwiftPlugin | Auto-generates Java wrappers from Swift public API |
| **Networking (REST)** | URLSession | Native on iOS; FoundationNetworking on Android via swift-java |
| **Networking (GraphQL)** | Raw URLRequest POST | Thin `GraphqlClient` — no Apollo needed |
| **DI** | Swinject (internal import) | Thread-safe container, hidden from public API surface |
| **Logging** | os.Logger (iOS) + print (Android) | Native OSLog on Apple platforms, Logcat-compatible print on Android |
| **Serialization** | JSONDecoder / JSONEncoder | Foundation-native, zero dependencies |
| **Publishing (Android)** | GCS Maven | Public bucket — consumers add one `maven {}` block, no auth |
| **Publishing (iOS)** | GCS + Gitea Swift Registry | XCFramework binary on GCS; Gitea registry serves version metadata so iOS clients use clean `id:` resolution — no hardcoded URLs |
| **CI/CD** | GitHub Actions (self-hosted Mac Studio) | Tag push → build Android AAR → publish to GCS Maven → build XCFramework → upload to GCS → publish source archive to Gitea registry |
| **Testing** | Apple Testing framework | 42 tests including live API integration tests |

## Features

### TMDB Features (REST API)
5 ViewModels powered by the [TMDB API](https://www.themoviedb.org/documentation/api):
- **TMDBHomeViewModel** — trending media
- **TMDBMoviesViewModel** — popular movies
- **TMDBTVShowsViewModel** — popular TV shows
- **TMDBSearchViewModel** — search movies
- **TMDBTrendingViewModel** — trending with day/week toggle

### Countries Features (GraphQL API)
3 ViewModels powered by the [Countries GraphQL API](https://countries.trevorblades.com/):
- **CountriesViewModel** — all countries with flags, currency
- **ContinentsViewModel** — continents with nested countries
- **LanguagesViewModel** — world languages with native names

### Network Interceptor Support
The SDK uses the `HTTPClient` protocol — clients can register any implementation:
- **iOS**: Pass a Pulse-configured `URLSession` to `URLSessionHTTPClient(session:)`
- **Android**: Implement `HTTPClient` backed by OkHttp with Chucker interceptor

Both REST and GraphQL traffic flows through the same `HTTPClient` instance.

## Architecture

```
Sources/SwiftAndroidSDK/
  Configuration/       TMDBConfiguration (bearerToken, apiKey, baseURL)
  Container/           TMDBContainer — public DI facade (hides Swinject)
  Models/              TMDB data models (Movie, TVShow, MediaItem, etc.)
  Network/             HTTPClient protocol, Endpoint enum, TMDBError
  Repository/          TMDBRepository protocol + implementation
  ViewModel/Screens/   5 stateless command-object ViewModels
  Countries/           GraphQL models, client, repository, 3 ViewModels
  SdkLogger.swift      os.Logger on iOS, print on Android
```

## Consumer Setup

**Android:**
```kotlin
// settings.gradle.kts — public, no auth
maven { url = uri("https://storage.googleapis.com/dallaslabs-sdk-artifacts/maven") }

// app/build.gradle.kts
implementation("com.dallaslabs.sdk:swift-android-sdk:1.1.7")
```

**iOS (Gitea Swift Package Registry):**

One-time registry setup per machine:
```bash
swift package-registry set --global --scope dallaslabs-sdk --allow-insecure-http \
  http://34.60.86.141:3000/api/packages/dallaslabs-sdk/swift
```
Then in your `Package.swift`:
```swift
dependencies: [
    .package(id: "dallaslabs-sdk.swift-android-sdk", from: "1.1.7"),
]
```
SPM queries Gitea for the version, Gitea returns a `Package.swift` with a `binaryTarget` pointing at GCS, and SPM downloads the XCFramework automatically. No zip URLs in client code.

> **Note:** XcodeGen does not support `id:`-based registry packages natively. The client repos use a local `Package.swift` wrapper that declares the registry dependency, and XcodeGen references it via `path: .`.

## Integration Tests

42 tests total (14 new integration tests against live APIs):
- 9 Countries GraphQL tests (public, no auth)
- 5 TMDB REST tests (needs `TMDB_READ_TOKEN` env var)
- 28 unit tests with mocks

Run locally: `swift test`

## Client Apps

- [SwiftAndroidImdbDemo-Android](https://github.com/erikg84/SwiftAndroidImdbDemo-Android)
- [SwiftAndroidImdbDemo-iOS](https://github.com/erikg84/SwiftAndroidImdbDemo-iOS)

## License

Apache 2.0
