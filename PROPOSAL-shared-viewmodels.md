# Proposal: Per-Screen Shared ViewModels via Koin

**Status:** Draft — pending review
**Author:** SDK team
**Date:** 2026-04-11
**Affects:** SwiftAndroidIMDBSdk (SDK side) + Android consumer apps (DI migration)

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Goals & non-goals](#2-goals--non-goals)
3. [Background — what we have today](#3-background--what-we-have-today)
4. [Proposed SDK changes](#4-proposed-sdk-changes)
5. [Proposed Android consumer changes](#5-proposed-android-consumer-changes)
6. [iOS consumer guidance](#6-ios-consumer-guidance)
7. [Migration plan](#7-migration-plan)
8. [Risks, limitations, and open questions](#8-risks-limitations-and-open-questions)
9. [Decisions needed before implementation](#9-decisions-needed-before-implementation)
10. [Appendix A — Hilt → Koin dependency diff](#appendix-a--hilt--koin-dependency-diff)
11. [Appendix B — alternatives considered](#appendix-b--alternatives-considered)

---

## 1. Executive summary

Today the SDK exposes a single `TMDBViewModel` with five `async throws` methods, one per endpoint. Every screen on every consumer platform constructs (or pulls from `TMDBContainer.shared`) the same monolithic viewmodel and calls a subset of its methods. This works but has three problems: (a) each screen sees methods it doesn't need, (b) screen-specific state and logic have nowhere natural to live, and (c) the pattern doesn't scale as the SDK grows beyond five endpoints.

This proposal **splits `TMDBViewModel` into five screen-scoped viewmodels** (`HomeViewModel`, `MoviesViewModel`, `TVShowsViewModel`, `SearchViewModel`, `TrendingViewModel`), each exposing only the methods its screen actually uses. The split is purely additive — the existing `TMDBViewModel` stays during the migration window — and each new viewmodel is reachable through a `TMDBContainer.get<Name>ViewModel()` static accessor that JExtractSwiftPlugin will bind to a Java method (since stored `static let` properties are not bound; cf. the existing `TMDBContainer.getShared()`).

On the **Android consumer side**, this proposal also captures the **migration from Hilt to Koin** that the new viewmodel pattern enables. The fundamental constraint that motivated the switch: `@HiltViewModel` requires the annotated class to extend `androidx.lifecycle.ViewModel`, and the JExtract-generated Java wrappers for our SDK viewmodels do not (and cannot, given Java single inheritance). Koin offers a path Hilt does not: `@Single`/`@Factory` **provider functions** inside a `@Module` class that return third-party types Koin doesn't own — exactly the same shape as Dagger/Hilt `@Provides`, but it works for any class regardless of inheritance hierarchy. The five SDK viewmodels can be registered through five annotated provider functions, with **zero wrapper classes**.

iOS consumers are unaffected by the DI migration — they call `TMDBContainer.shared.homeViewModel` (or the equivalent) directly. The split into per-screen viewmodels gives them the same code-organization benefit as the Android side without any framework involvement.

---

## 2. Goals & non-goals

### Goals

1. **One viewmodel per screen** in the SDK, with a focused public API per viewmodel
2. **Same call shape on iOS and Android** — `TMDBContainer.<screen>ViewModel` everywhere; no platform-specific viewmodel construction
3. **Zero hand-written wrapper classes** on Android (no `class HiltMovieListVM(...) : ViewModel()` boilerplate)
4. **Annotation-driven DI on Android** — `@Single`/`@Factory` provider functions register the SDK viewmodels alongside the consumer app's own annotated classes
5. **Hilt removed entirely** from the consumer Android app, replaced by Koin Annotations + manual `@Module` provider functions where needed
6. **Existing v1.0.3 release stays valid** during the migration — the new viewmodels are additive, the old `TMDBViewModel` is deprecated but functional through at least one minor version

### Non-goals

1. **Not adding lifecycle-aware ViewModel-style state holders** — see [§4.4](#44-state-strategy-stateless-for-now) for the rationale. Screens hold UI state in their own idioms (`@State`, `mutableStateOf`, `rememberRetained`); the SDK viewmodels are stateless command objects.
2. **Not making the SDK viewmodels Hilt-injectable** — the entire point of switching to Koin is to sidestep this constraint
3. **Not switching all KSP code generators or build tools** — only the DI framework changes
4. **Not introducing Kotlin Multiplatform** — the SDK stays Swift-source, Android cross-compiled via swift-java; KMP is a separate larger conversation
5. **Not auto-generating wrapper classes via a custom KSP processor** — explicitly considered and rejected; see [Appendix B](#appendix-b--alternatives-considered)

---

## 3. Background — what we have today

### Current SDK shape

The SDK ([commit ad14719+](https://github.com/erikg84/SwiftAndroidIMDBSdk)) exposes:

- `TMDBContainer.shared` — a Swinject-backed container
- `TMDBContainer.getShared()` — static func wrapper around `shared` (added in v1.0.2 because JExtract can't bridge `static let`)
- `TMDBContainer.shared.viewModel` — a single `TMDBViewModel` instance
- `TMDBViewModel` — five `async throws` methods:
  - `fetchTrendingAll(timeWindow:page:) -> MediaItemPage`
  - `fetchTrendingMovies(timeWindow:page:) -> MoviePage`
  - `fetchPopularMovies(page:) -> MoviePage`
  - `fetchPopularTVShows(page:) -> TVShowPage`
  - `searchMovies(query:page:) -> MoviePage`

Source files (relevant):
- `Sources/SwiftAndroidSDK/ViewModel/TMDBViewModel.swift`
- `Sources/SwiftAndroidSDK/Container/TMDBContainer.swift`
- `Sources/SwiftAndroidSDK/Repository/TMDBRepository.swift`
- `Sources/SwiftAndroidSDK/Repository/TMDBRepositoryImpl.swift`

### Current consumer pattern (today)

**iOS:**
```swift
let vm = TMDBContainer.shared.viewModel
let page = try await vm.fetchPopularMovies()
```

**Android (with Hilt today):**
```kotlin
@HiltViewModel
class PopularMoviesScreenViewModel @Inject constructor() : ViewModel() {
    private val sdkVm = TMDBContainer.getShared().viewModel  // wrapper required because JExtract class isn't a ViewModel
    private val _state = MutableStateFlow<UiState>(UiState.Loading)
    val state: StateFlow<UiState> = _state.asStateFlow()
    fun load() = viewModelScope.launch {
        _state.value = try { UiState.Loaded(sdkVm.fetchPopularMovies()) } catch (e: Exception) { UiState.Error(e) }
    }
}
```

The problem this proposal addresses: the `class PopularMoviesScreenViewModel` exists **only because Hilt requires it**. It's pure boilerplate — a `ViewModel` shell that delegates to the SDK call. Five screens means five of these. They add nothing the SDK couldn't provide directly.

### Why we can't just delete that wrapper today

`@HiltViewModel` requires `extends androidx.lifecycle.ViewModel`. The JExtract-generated `TMDBViewModel` Java class extends `org.swift.swiftkit.SwiftClass` (or whatever swift-java's base type is). Java has no multiple inheritance. Therefore the SDK class can't satisfy `@HiltViewModel`'s contract. **Switching to Koin is what unlocks deletion of the wrapper.**

---

## 4. Proposed SDK changes

### 4.1 Five new viewmodel classes

Each new viewmodel encapsulates the methods (and only the methods) one screen needs. They live in `Sources/SwiftAndroidSDK/ViewModel/Screens/`.

```swift
// Sources/SwiftAndroidSDK/ViewModel/Screens/HomeViewModel.swift
import Foundation

/// ViewModel for the Home screen — trending media of all types.
public final class HomeViewModel: Sendable {
    private let repository: any TMDBRepository
    public init(repository: any TMDBRepository) { self.repository = repository }

    public func loadTrending(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MediaItemPage {
        try await repository.trendingAll(timeWindow: timeWindow, page: page)
    }
}
```

```swift
// Sources/SwiftAndroidSDK/ViewModel/Screens/MoviesViewModel.swift
import Foundation

/// ViewModel for the Movies tab — popular movies feed with pagination.
public final class MoviesViewModel: Sendable {
    private let repository: any TMDBRepository
    public init(repository: any TMDBRepository) { self.repository = repository }

    public func loadPopular(page: Int = 1) async throws -> MoviePage {
        try await repository.popularMovies(page: page)
    }
}
```

```swift
// Sources/SwiftAndroidSDK/ViewModel/Screens/TVShowsViewModel.swift
import Foundation

/// ViewModel for the TV Shows tab — popular shows feed with pagination.
public final class TVShowsViewModel: Sendable {
    private let repository: any TMDBRepository
    public init(repository: any TMDBRepository) { self.repository = repository }

    public func loadPopular(page: Int = 1) async throws -> TVShowPage {
        try await repository.popularTVShows(page: page)
    }
}
```

```swift
// Sources/SwiftAndroidSDK/ViewModel/Screens/SearchViewModel.swift
import Foundation

/// ViewModel for the Search screen.
///
/// The viewmodel is intentionally stateless — debouncing is a UI concern
/// and lives in the consumer (Compose `snapshotFlow`/`debounce` or
/// SwiftUI `task(id:)`/`Task.sleep`).
public final class SearchViewModel: Sendable {
    private let repository: any TMDBRepository
    public init(repository: any TMDBRepository) { self.repository = repository }

    public func search(query: String, page: Int = 1) async throws -> MoviePage {
        try await repository.searchMovies(query: query, page: page)
    }
}
```

```swift
// Sources/SwiftAndroidSDK/ViewModel/Screens/TrendingViewModel.swift
import Foundation

/// ViewModel for the standalone Trending screen — movies-only with day/week toggle.
public final class TrendingViewModel: Sendable {
    private let repository: any TMDBRepository
    public init(repository: any TMDBRepository) { self.repository = repository }

    public func loadTrendingMovies(
        timeWindow: TimeWindow = .week,
        page: Int = 1
    ) async throws -> MoviePage {
        try await repository.trendingMovies(timeWindow: timeWindow, page: page)
    }
}
```

Each viewmodel is `Sendable`, dependency-injected with the repository, and exposes one or two `async throws` methods. **No state. No observable properties. No lifecycle hooks.** Stateless command objects.

### 4.2 Container registrations

Add five Swinject registrations to `_TMDBContainer.init()`:

```swift
c.register(HomeViewModel.self)     { r in HomeViewModel(repository: r.resolve((any TMDBRepository).self)!) }.inObjectScope(.container)
c.register(MoviesViewModel.self)   { r in MoviesViewModel(repository: r.resolve((any TMDBRepository).self)!) }.inObjectScope(.container)
c.register(TVShowsViewModel.self)  { r in TVShowsViewModel(repository: r.resolve((any TMDBRepository).self)!) }.inObjectScope(.container)
c.register(SearchViewModel.self)   { r in SearchViewModel(repository: r.resolve((any TMDBRepository).self)!) }.inObjectScope(.container)
c.register(TrendingViewModel.self) { r in TrendingViewModel(repository: r.resolve((any TMDBRepository).self)!) }.inObjectScope(.container)
```

`.inObjectScope(.container)` means each viewmodel is a singleton within the container — the same instance is returned every call until `reset()`. See [§4.5](#45-instance-lifetime--single-vs-factory) for the rationale.

Add typed accessors on `_TMDBContainer`:

```swift
var homeViewModel:     HomeViewModel     { resolver.resolve(HomeViewModel.self)! }
var moviesViewModel:   MoviesViewModel   { resolver.resolve(MoviesViewModel.self)! }
var tvShowsViewModel:  TVShowsViewModel  { resolver.resolve(TVShowsViewModel.self)! }
var searchViewModel:   SearchViewModel   { resolver.resolve(SearchViewModel.self)! }
var trendingViewModel: TrendingViewModel { resolver.resolve(TrendingViewModel.self)! }
```

### 4.3 Public facade — `TMDBContainer` static accessors

Stored `static let` properties on the public `TMDBContainer` are not bridged by JExtract (this is why `getShared()` exists). The same applies to instance `var`s on a singleton: JExtract binds methods, not properties.

```swift
extension TMDBContainer {
    /// Home screen viewmodel — trending media of all types.
    public static func getHomeViewModel() -> HomeViewModel {
        _TMDBContainer.shared.homeViewModel
    }

    /// Movies tab viewmodel — popular movies.
    public static func getMoviesViewModel() -> MoviesViewModel {
        _TMDBContainer.shared.moviesViewModel
    }

    /// TV Shows tab viewmodel — popular TV shows.
    public static func getTVShowsViewModel() -> TVShowsViewModel {
        _TMDBContainer.shared.tvShowsViewModel
    }

    /// Search screen viewmodel.
    public static func getSearchViewModel() -> SearchViewModel {
        _TMDBContainer.shared.searchViewModel
    }

    /// Trending screen viewmodel — movies-only with day/week toggle.
    public static func getTrendingViewModel() -> TrendingViewModel {
        _TMDBContainer.shared.trendingViewModel
    }
}
```

JExtract will generate Java bindings:
- `TMDBContainer.getHomeViewModel(): HomeViewModel`
- `TMDBContainer.getMoviesViewModel(): MoviesViewModel`
- … (etc.)

Same call shape on iOS and Android.

### 4.4 State strategy — stateless for now

Each viewmodel is **stateless**. It exposes async methods and nothing else. The screen UI holds its own state in its idiomatic way:

- **SwiftUI**: `@State`, `@Observable`, `task(id:)` blocks
- **Compose**: `mutableStateOf`, `produceState`, `LaunchedEffect`, `rememberRetained`

This is intentional. Reasons:

1. **Cross-platform observable state via JExtract is unsolved.** Closures, AsyncSequences, Combine, and Kotlin Flows are all either not bridged by JExtract today or require custom adapters. Polling with `getState()` is awkward. Avoiding the problem entirely keeps the SDK shippable now.
2. **Caching belongs in the repository / container,** not the viewmodel. The current `TMDBRepositoryImpl` doesn't cache; if you want caching across navigation, add it to `TMDBRepositoryImpl` (or wrap with a `CachingTMDBRepository` decorator). The viewmodels stay stateless and the cache is shared across all of them.
3. **Pagination state** (current page, accumulated items) is naturally a screen concern — the screen's `mutableStateOf<List<Movie>>` is the right home for it, not the viewmodel.
4. **Debouncing** is a UI input concern. Compose has `snapshotFlow { query }.debounce(300.ms)` and SwiftUI has `task(id: query)` + `Task.sleep`. Neither needs viewmodel state.

If a future screen actually needs viewmodel-side state (e.g. a multi-step wizard), we can add it to that one viewmodel without affecting the others. The split-into-five-classes structure makes per-VM state addition trivial.

### 4.5 Instance lifetime — single vs factory

The Swinject registrations above use `.inObjectScope(.container)` — singleton per container. **One `MoviesViewModel` instance for the entire app process**, returned every time `getMoviesViewModel()` is called.

Tradeoffs:

| Approach | Pro | Con |
|---|---|---|
| **Singleton (`.container`)** | Cheap allocation, identical iOS/Android semantics, matches today's `TMDBContainer.shared.viewModel` behavior | Can't have per-screen instance state (irrelevant since the VMs are stateless) |
| **Fresh per call (`.transient` / `.graph`)** | Per-screen lifecycle, easier to mentally model | Slightly more allocation, no benefit for stateless VMs |

Recommendation: **singleton.** The viewmodels are stateless command objects with no per-instance state to keep alive. There's nothing to gain from per-screen instances. This matches the current behavior of `TMDBContainer.shared.viewModel` and minimizes the surprise factor for existing iOS callers.

If at some future point a viewmodel becomes stateful, we can downgrade just that one to `.transient` without affecting the others.

### 4.6 Tests

Add a test suite per new viewmodel (`HomeViewModelTests`, etc.) under `Tests/SwiftAndroidSDKTests/ViewModels/`. Each follows the existing `MockHTTPClient` pattern from `SwiftAndroidSDKTests.swift`:

```swift
@Suite("HomeViewModel")
struct HomeViewModelTests {
    @Test func loadTrendingDecodesResponse() async throws {
        let config = TMDBConfiguration(bearerToken: "test")
        let repo = TMDBRepositoryImpl(configuration: config, httpClient: MockHTTPClient(mediaItemPageJSON))
        let vm = HomeViewModel(repository: repo)
        let page = try await vm.loadTrending()
        #expect(page.results.count == 2)
    }
}
```

The existing `RepositoryTests`, `ViewModelTests`, and `ContainerTests` continue to test the old `TMDBViewModel` and `TMDBRepository`. They stay unchanged during the migration window.

### 4.7 Deprecation of the old `TMDBViewModel`

`TMDBViewModel` and `TMDBContainer.shared.viewModel` are **not removed** in the version that introduces this proposal. They're marked `@available(*, deprecated, message: "Use the per-screen viewmodels via TMDBContainer.get<Screen>ViewModel(). TMDBViewModel will be removed in v2.0.0.")`.

This means:
- Existing v1.0.3 consumers can upgrade to (e.g.) v1.1.0 without code changes — they'll see deprecation warnings but everything compiles
- New consumers should use the per-screen viewmodels from day one
- A v2.0.0 release at some future point removes `TMDBViewModel` entirely

### 4.8 Public API surface change

| Symbol | Status |
|---|---|
| `TMDBViewModel` | **Deprecated** — removed in v2.0.0 |
| `TMDBContainer.shared.viewModel` | **Deprecated** — removed in v2.0.0 |
| `HomeViewModel`, `MoviesViewModel`, `TVShowsViewModel`, `SearchViewModel`, `TrendingViewModel` | **New** |
| `TMDBContainer.getHomeViewModel()` … `getTrendingViewModel()` | **New** |
| `TMDBContainer.getShared()`, `TMDBContainer.shared.configure(...)`, `TMDBContainer.shared.repository` | **Unchanged** |
| All `TMDBRepository` methods | **Unchanged** |
| All Model types (`Movie`, `MoviePage`, etc.) | **Unchanged** |

This is a **minor version bump** — additive surface, deprecations are warnings. Tag as `v1.1.0`.

---

## 5. Proposed Android consumer changes

This section is the migration plan for an Android consumer app currently on Hilt. The exact line counts and module names will depend on your specific app; the structure below is the template.

### 5.1 Hilt removal checklist

Delete from `app/build.gradle`:
```groovy
plugins {
    id 'com.google.devtools.ksp'              // keep — Koin Annotations needs it
    id 'dagger.hilt.android.plugin'           // remove
    id 'kotlin-kapt'                          // remove unless needed elsewhere
}

dependencies {
    implementation 'com.google.dagger:hilt-android:2.x'                   // remove
    kapt           'com.google.dagger:hilt-android-compiler:2.x'           // remove
    implementation 'androidx.hilt:hilt-navigation-compose:1.x'             // remove
}
```

Delete from `app/src/main/java`:

| File / annotation | Action |
|---|---|
| `@HiltAndroidApp` on `Application` subclass | Remove annotation, but keep `Application` subclass — we'll add `startKoin` here |
| `@AndroidEntryPoint` on every `Activity` / `Fragment` | Remove |
| `@HiltViewModel` on every `ViewModel` | Remove (and see [§5.4](#54-replacing-hiltviewmodel-on-app-side-viewmodels)) |
| `@Inject constructor(...)` on viewmodels and services | Remove (replaced by `@Single` / `@Factory`) |
| `@Module @InstallIn(...)` Hilt modules | Convert to `@Module`-annotated Koin classes (see [§5.3](#53-koin-module-shape)) |
| `hiltViewModel<T>()` calls in Compose screens | Replace with `koinInject<T>()` or `koinViewModel<T>()` (see [§5.5](#55-replacing-hiltviewmodel-call-sites-in-compose)) |

### 5.2 Koin dependencies

Add to `app/build.gradle`:
```groovy
plugins {
    id 'com.google.devtools.ksp'
}

dependencies {
    // Core
    implementation "io.insert-koin:koin-core:$koin_version"
    implementation "io.insert-koin:koin-android:$koin_version"

    // Compose integration — provides koinInject(), koinViewModel(), getKoin()
    implementation "io.insert-koin:koin-androidx-compose:$koin_compose_version"

    // Annotations + KSP processor
    implementation "io.insert-koin:koin-annotations:$koin_annotations_version"
    ksp           "io.insert-koin:koin-ksp-compiler:$koin_annotations_version"

    // Optional: Circuit retained-state for config-change survival without ViewModel base class
    implementation "com.slack.circuit:circuit-retained:$circuit_version"
}
```

Pin versions in `gradle.properties` or `gradle/libs.versions.toml`. As of writing the latest stable releases are roughly `koin: 4.0.x`, `koin-annotations: 2.0.x`, `circuit: 0.21.x` — verify current versions before merging.

### 5.3 Koin module shape

The DI graph for the consumer app is split into modules by responsibility. The SDK viewmodels live in their own module since they need provider-function registration (third-party types from the AAR).

**`SdkModule.kt` — registers the five SDK viewmodels via provider functions:**

```kotlin
package com.example.app.di

import io.github.erikg84.swiftandroidsdk.*
import org.koin.core.annotation.Module
import org.koin.core.annotation.Single

@Module
class SdkModule {

    /// SDK initialization — call once. The bearer token is sourced from
    /// BuildConfig at module-build time. Returning Unit because the SDK uses
    /// a global container; the @Single guarantees this runs exactly once.
    @Single
    fun sdkBootstrap(): SdkBootstrap {
        TMDBContainer.getShared().configure(BuildConfig.TMDB_BEARER_TOKEN)
        return SdkBootstrap
    }

    @Single
    fun homeViewModel(@Suppress("UNUSED_PARAMETER") boot: SdkBootstrap): HomeViewModel =
        TMDBContainer.getHomeViewModel()

    @Single
    fun moviesViewModel(@Suppress("UNUSED_PARAMETER") boot: SdkBootstrap): MoviesViewModel =
        TMDBContainer.getMoviesViewModel()

    @Single
    fun tvShowsViewModel(@Suppress("UNUSED_PARAMETER") boot: SdkBootstrap): TVShowsViewModel =
        TMDBContainer.getTVShowsViewModel()

    @Single
    fun searchViewModel(@Suppress("UNUSED_PARAMETER") boot: SdkBootstrap): SearchViewModel =
        TMDBContainer.getSearchViewModel()

    @Single
    fun trendingViewModel(@Suppress("UNUSED_PARAMETER") boot: SdkBootstrap): TrendingViewModel =
        TMDBContainer.getTrendingViewModel()
}

/// Marker type — exists only to be a dependency edge. Forces Koin to resolve
/// `sdkBootstrap()` before any viewmodel is constructed, guaranteeing the
/// SDK is configured before first use.
object SdkBootstrap
```

The `SdkBootstrap` parameter on each viewmodel function is a marker dependency. Koin's resolver sees the edge and runs `sdkBootstrap()` first, which calls `TMDBContainer.getShared().configure(...)`. After that, every viewmodel resolution is direct. There's no wrapper class — `homeViewModel(...)` is a provider function that returns the SDK type.

**`AppModule.kt` — for the consumer app's own classes (annotation-driven):**

```kotlin
package com.example.app.di

import org.koin.core.annotation.Module
import org.koin.core.annotation.ComponentScan

@Module
@ComponentScan("com.example.app")
class AppModule
```

`@ComponentScan` tells the Koin KSP processor to find every `@Single`, `@Factory`, `@KoinViewModel` annotation in the `com.example.app` package and generate registrations. This is the annotation-driven path for things you control:

```kotlin
@Single
class AnalyticsTracker(private val context: Context) { /* ... */ }

@Factory
class FormatHelpers(private val locale: Locale) { /* ... */ }
```

**`Application.kt` — startKoin:**

```kotlin
package com.example.app

import android.app.Application
import com.example.app.di.AppModule
import com.example.app.di.SdkModule
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin
import org.koin.ksp.generated.module   // generated by koin-ksp-compiler

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@MyApp)
            modules(
                SdkModule().module,        // generated extension property
                AppModule().module,
            )
        }
    }
}
```

The `.module` extension is generated by `koin-ksp-compiler` from the `@Module` annotation. No `@HiltAndroidApp`, no Hilt component graph, no `@AndroidEntryPoint`. Just `startKoin {}`.

### 5.4 Replacing `@HiltViewModel` on app-side viewmodels

**For viewmodels the app owns** (not from the SDK), there are two options:

**Option A — Use Koin's `@KoinViewModel` (preferred when you have constructor dependencies and need androidx ViewModel features):**

```kotlin
import androidx.lifecycle.ViewModel
import org.koin.android.annotation.KoinViewModel

@KoinViewModel
class SettingsViewModel(
    private val analytics: AnalyticsTracker,
    private val sdkSearch: SearchViewModel,   // pulled from the SdkModule registration above
) : ViewModel() {
    // viewModelScope, savedStateHandle, etc. all available
}
```

This still extends `androidx.lifecycle.ViewModel` — the constraint hasn't gone away — but now the constructor gets `SearchViewModel` (an SDK type) injected via Koin's DI graph. The `@KoinViewModel` annotation generates the `viewModel { ... }` Koin definition.

In Compose:
```kotlin
@Composable
fun SettingsScreen(vm: SettingsViewModel = koinViewModel()) { /* ... */ }
```

**Option B — Use `@Factory` or `@Single` for plain state holders (preferred when you don't need ViewModel features):**

```kotlin
@Factory
class TableSorter { /* not a ViewModel; held in remember { } */ }
```

In Compose:
```kotlin
@Composable
fun MyTable() {
    val sorter: TableSorter = koinInject()
    val sorter2 = remember { sorter }   // if you want it scoped to the composition
    // ...
}
```

### 5.5 Replacing `hiltViewModel()` call sites in Compose

For SDK viewmodels, three patterns are available depending on the screen's lifecycle needs.

**Pattern 1 — Direct injection (simplest, recomposition-scoped):**

```kotlin
@Composable
fun HomeScreen(vm: HomeViewModel = koinInject()) {
    var state by remember { mutableStateOf<UiState>(UiState.Loading) }
    LaunchedEffect(Unit) {
        state = try { UiState.Loaded(vm.loadTrending()) } catch (e: Throwable) { UiState.Error(e) }
    }
    HomeContent(state)
}
```

The viewmodel is a Koin singleton — same instance every time. State lives in the screen via `remember`. Survives recomposition, **does not survive configuration change** (rotation resets `state` to `Loading`).

**Pattern 2 — Configuration-change survival via Circuit's `rememberRetained`:**

```kotlin
import com.slack.circuit.retained.rememberRetained
import org.koin.compose.getKoin

@Composable
fun HomeScreen() {
    val koin = getKoin()
    val vm = remember { koin.get<HomeViewModel>() }
    var state by rememberRetained { mutableStateOf<UiState>(UiState.Loading) }
    LaunchedEffect(Unit) {
        if (state is UiState.Loading) {
            state = try { UiState.Loaded(vm.loadTrending()) } catch (e: Throwable) { UiState.Error(e) }
        }
    }
    HomeContent(state)
}
```

The viewmodel itself doesn't need to be retained (it's a Koin singleton — same instance after rotation anyway). What needs retaining is the screen state. `rememberRetained` uses Circuit's hidden ViewModel store under the hood without exposing any `androidx.lifecycle.ViewModel` inheritance to your screen code.

**Pattern 3 — Wrap the SDK call in an app-side `@KoinViewModel` for screens that genuinely need `viewModelScope` / `SavedStateHandle`:**

```kotlin
@KoinViewModel
class SearchScreenViewModel(
    private val sdk: SearchViewModel,
    private val savedState: SavedStateHandle,
) : ViewModel() {
    private val _query = MutableStateFlow(savedState.get<String>("q") ?: "")
    val results: StateFlow<UiState> = _query
        .debounce(300.milliseconds)
        .filter { it.length >= 2 }
        .mapLatest { runCatching { UiState.Loaded(sdk.search(it)) }.getOrElse { UiState.Error(it) } }
        .stateIn(viewModelScope, SharingStarted.Eagerly, UiState.Empty)

    fun setQuery(q: String) { _query.value = q; savedState["q"] = q }
}

@Composable
fun SearchScreen(vm: SearchScreenViewModel = koinViewModel()) { /* ... */ }
```

This **is** a wrapper, but only for the one screen that genuinely benefits from `SavedStateHandle` + `viewModelScope`. Most screens don't need it. The SDK side stays clean — only `SearchViewModel` from the SDK is referenced; the Hilt-style wrapper exists in the consumer app, scoped to the screens that want those features.

### 5.6 Recommendation matrix for Android screens

| Screen needs… | Use |
|---|---|
| Just call SDK + render result | Pattern 1 (`koinInject` direct) |
| Survive rotation / theme change | Pattern 2 (`rememberRetained` for state) |
| `SavedStateHandle` for process-death recovery | Pattern 3 (thin app-side `@KoinViewModel` wrapper) |
| Debounced input streams that should survive recomposition | Pattern 3 |
| Background work tied to a coroutine scope cancelled on screen leave | Pattern 3 |

For the five screens this proposal targets, my best guess is **4 of 5 use Pattern 1 or 2** and **only the search screen needs Pattern 3** for input debouncing. The other four are fetch-and-render. Final decision is per-screen and can be made during implementation.

---

## 6. iOS consumer guidance

The iOS side is simple — Swift consumes Swift directly:

```swift
import SwiftUI
import SwiftAndroidSDK

struct HomeScreen: View {
    @State private var state: UiState = .loading
    private let vm = TMDBContainer.shared.homeViewModel   // or .getHomeViewModel() — both work on iOS

    var body: some View {
        content
            .task { await load() }
    }

    private func load() async {
        do {
            let page = try await vm.loadTrending()
            state = .loaded(page)
        } catch {
            state = .error(error)
        }
    }
}
```

`TMDBContainer.shared.homeViewModel` is the existing instance-property style — works because iOS uses Swift directly and doesn't go through JExtract. `TMDBContainer.getHomeViewModel()` also works on iOS for symmetry. Pick one in your codebase and stay consistent.

iOS state holders use SwiftUI's normal mechanisms (`@State`, `@Observable`, `@Bindable`). The SDK viewmodel is held as a `let` constant; state lives in the view.

---

## 7. Migration plan

### Phase 1 — SDK changes (this proposal, one PR)

1. Add the five new viewmodel files under `Sources/SwiftAndroidSDK/ViewModel/Screens/`
2. Add the five Swinject registrations in `_TMDBContainer`
3. Add the five `TMDBContainer.get<Name>ViewModel()` static accessors
4. Add tests for each viewmodel
5. Mark `TMDBViewModel` and `TMDBContainer.shared.viewModel` `@available(*, deprecated, message: "...")`
6. Update `README.md` and `DISTRIBUTION.md` consumer snippets to show the new accessors
7. Bump `VERSION_NAME` to `1.1.0`, tag, ship through the existing release pipeline (AAR + XCFramework + GH Packages + wrapper repo update)

**Estimated diff size:** ~200 lines added (5 viewmodels × ~25 lines each + container changes + tests + docs)

### Phase 2 — Android consumer migration (one PR per feature module, or one big-bang PR)

1. Add Koin + Koin Annotations + (optional) Circuit deps
2. Create `SdkModule` with the five provider functions
3. Create `AppModule` with `@ComponentScan` for the app's own classes
4. Convert app's own viewmodels: `@HiltViewModel` → `@KoinViewModel`, `@Inject constructor` → either nothing (constructor injection works automatically when annotated) or explicit `@Factory`/`@Single`
5. Convert app's own Hilt `@Module @InstallIn` modules to Koin `@Module` classes
6. Replace `hiltViewModel<T>()` calls with `koinInject<T>()` / `koinViewModel<T>()` per the matrix in §5.6
7. Add `startKoin {}` in `Application.onCreate()`, remove `@HiltAndroidApp`
8. Remove `@AndroidEntryPoint` from activities/fragments
9. Run, test, smoke
10. Delete Hilt deps and the kapt plugin from `build.gradle`

**Phasing options:**

- **Big-bang**: one PR converts everything. Higher risk, faster cutover, no dual-DI period. Best for small apps.
- **Per-module**: introduce Koin alongside Hilt, migrate one feature module at a time, then delete Hilt at the end. Both DI frameworks coexist for the migration window — works fine technically but adds temporary cognitive load.

Recommendation: **big-bang for apps under ~30k LoC**, **per-module for larger ones**. The conversion is mechanical but touches nearly every screen, so the risk profile is "boring tedium" rather than "subtle bugs", which favors a single PR if the codebase fits in head.

### Phase 3 — Cleanup (later release)

After the consumer app is stable on Koin and the new SDK viewmodels:

1. Bump SDK to `v2.0.0`
2. Delete `TMDBViewModel`, `TMDBContainer.shared.viewModel`, and the corresponding container registration
3. Update `Tests/SwiftAndroidSDKTests/SwiftAndroidSDKTests.swift` to remove the old `ViewModelTests` suite
4. README + DISTRIBUTION.md cleanup of references to the old type

This is independent and can happen whenever — months later if needed. The deprecation warnings give consumers time.

---

## 8. Risks, limitations, and open questions

### Known constraints we're not solving

1. **`viewModelScope` is not available on SDK viewmodels.** They don't extend `androidx.lifecycle.ViewModel`. If a future SDK viewmodel needs to manage long-lived coroutines, it'll need to take a `CoroutineScope` parameter or be wrapped on the consumer side with Pattern 3.

2. **`SavedStateHandle` is not available on SDK viewmodels.** Same reason. Process-death state recovery requires Pattern 3 or `rememberSaveable` in the screen.

3. **No automatic cancellation when the screen leaves the composition.** Stateless command objects don't have lifecycle. If a fetch is in flight and the user navigates away, the fetch finishes (and its result is discarded). For the current TMDB use case this is fine — the underlying URLSession requests are trivial. If we add anything more expensive, we'll want to revisit.

4. **`@KoinViewModel` on app-side wrappers still requires `androidx.lifecycle.ViewModel` extension.** Pattern 3 in §5.5 is unavoidable for screens that genuinely need viewModelScope/SavedStateHandle. We're trading "every screen has a wrapper" for "only a few screens have a wrapper, the rest use direct injection".

5. **Circuit's `rememberRetained` is an optional dependency.** If you don't want to add Circuit, screens lose the configuration-change-survival path and either accept rotation resets or use Pattern 3 wrappers everywhere. Adding Circuit is ~100KB and one transitive dependency.

### Open questions for implementation

1. **Naming.** Are `HomeViewModel`/`MoviesViewModel`/etc. the right names, or do you prefer `TMDBHomeViewModel` (prefixed) for namespace clarity in the JExtract-generated Java side? Java doesn't have package aliases, so `io.github.erikg84.swiftandroidsdk.HomeViewModel` could collide with an `app.feature.home.HomeViewModel` in the consumer codebase. **Recommend prefix: `TMDBHomeViewModel`, `TMDBMoviesViewModel`, …** The Swift call site is barely longer; the Java/Kotlin call site benefits from the disambiguation.

2. **The SDK's existing `TMDBViewModel.fetchTrendingMovies` returns `MoviePage`.** The new `TrendingViewModel.loadTrendingMovies` does the same. If the user wants the standalone Trending screen to also handle TV trending, we'd add `loadTrendingTVShows`. Today the SDK has no `trendingTVShows` repository method — would need to add. **Defer until repository extension**.

3. **The exact 5 screens.** This proposal assumes Home / Movies / TV Shows / Search / Trending. If your real app has different screens (Profile, Favorites, Now Playing, …), the viewmodel names and methods change accordingly. The five chosen here are a 1:1 mapping over the existing 5 endpoints — a minimum viable split.

4. **Circuit version pin.** Latest 0.x or wait for 1.0? Latest 0.x is widely used in production at Slack, Tivi, others. 1.0 is not yet announced. Recommend **latest 0.x stable** with manual version bumps as needed.

5. **`koin-androidx-compose` vs `koin-compose`.** Two artifacts exist. `koin-androidx-compose` is the Android-specific one with `koinViewModel()` integration; `koin-compose` is the multiplatform-friendly one without androidx coupling. We need `koin-androidx-compose` because the consumer app uses androidx ViewModel for Pattern 3 wrappers.

---

## 9. Decisions needed before implementation

Please answer the following before I start the implementation PR:

| # | Decision | Options | My recommendation |
|---|---|---|---|
| **1** | **Viewmodel naming prefix** | `HomeViewModel` vs `TMDBHomeViewModel` | `TMDBHomeViewModel` (avoids Java namespace collisions in consumer apps) |
| **2** | **The 5 screens** | Home/Movies/TVShows/Search/Trending vs your real app's screens | Use the 5 in this proposal as a template; rename in implementation if needed |
| **3** | **Instance lifetime in container** | Singleton vs per-call | Singleton — viewmodels are stateless |
| **4** | **Migration phasing** | Big-bang vs per-feature-module | Per app size — your call |
| **5** | **Circuit dependency on Android consumer** | Add it (gives `rememberRetained`) vs skip it | Add it — the only clean way to get config-change survival without `ViewModel` base class |
| **6** | **Search debouncing location** | SDK side (stateful `SearchViewModel`) vs UI side (Compose `snapshotFlow.debounce`) | UI side — keeps SDK stateless |
| **7** | **Old `TMDBViewModel` removal version** | v2.0.0, or never | v2.0.0 with at least 3 months of deprecation warnings first |
| **8** | **Per-module Koin module** | One `SdkModule` for all 5 SDK VMs vs one per screen feature module | One `SdkModule` — simpler |

Once these are answered, I'll open the SDK PR (Phase 1) immediately. The Android consumer migration (Phase 2) is documented here but is your team's work, not mine — I can write a follow-up "Android migration walkthrough" doc once you've started the conversion if useful.

---

## Appendix A — Hilt → Koin dependency diff

```diff
 plugins {
     id 'com.android.application'
     id 'org.jetbrains.kotlin.android'
     id 'com.google.devtools.ksp'
-    id 'dagger.hilt.android.plugin'
-    id 'kotlin-kapt'
 }

 dependencies {
     // Hilt — REMOVE
-    implementation 'com.google.dagger:hilt-android:2.51.1'
-    kapt           'com.google.dagger:hilt-android-compiler:2.51.1'
-    implementation 'androidx.hilt:hilt-navigation-compose:1.2.0'

     // Koin — ADD
+    implementation "io.insert-koin:koin-core:4.0.0"
+    implementation "io.insert-koin:koin-android:4.0.0"
+    implementation "io.insert-koin:koin-androidx-compose:4.0.0"
+    implementation "io.insert-koin:koin-annotations:2.0.0"
+    ksp           "io.insert-koin:koin-ksp-compiler:2.0.0"

     // Circuit retained — ADD (optional but recommended)
+    implementation "com.slack.circuit:circuit-retained:0.21.0"
 }
```

Verify exact versions against [Maven Central](https://central.sonatype.com/) before merging — these are illustrative.

---

## Appendix B — alternatives considered

### B.1 Bytecode rewriting JExtract output to extend `ViewModel`

Write a Gradle plugin that post-processes the JExtract-generated `.class` files with ASM to make each SDK viewmodel class extend `androidx.lifecycle.ViewModel`. This would let `@HiltViewModel` work directly on the SDK class.

**Why rejected:**
- Breaks every time JExtractSwiftPlugin changes its output format (and it's pre-1.0)
- Adds an opaque build-time transformation that future maintainers won't understand
- Doesn't actually solve `viewModelScope` — the Swift code still has no Kotlin-side coroutine scope
- Requires touching the SDK's build, which means consumers can't use it without our gradle plugin

### B.2 Custom KSP processor that generates Hilt wrappers from an annotation

Write a `@HiltExpose` annotation that, when applied to a Swift class via the JExtract config, generates an `@HiltViewModel`-annotated Kotlin wrapper at consumer build time.

**Why rejected:**
- Significant engineering investment (KSP processor, code generation, debugging)
- The result is a code-generated wrapper, which is what we wanted to avoid in the first place
- Wrappers and bytecode rewriting are different points on the same tradeoff axis
- Koin's provider-function pattern achieves the same outcome (direct injection of SDK types) without writing a single line of generated wrapper code

### B.3 Switch the SDK to Kotlin Multiplatform

Rewrite the SDK in Kotlin Multiplatform Common, where the shared viewmodel can extend `androidx.lifecycle.ViewModel` (KMP-supported since 2.8.0) and be `@HiltViewModel`-annotated for Android consumption.

**Why rejected:**
- Throws away the entire Swift-source-of-truth premise of the SDK
- iOS consumers would consume Kotlin/Native frameworks instead of Swift, with all the type-bridging awkwardness Skie tries to mitigate
- Not what the SDK is for
- Different conversation entirely

### B.4 Stateful viewmodels with cross-platform observable state via polling

Make the SDK viewmodels stateful (loading/loaded/error) and expose a `getCurrentState()` method that callers poll. State changes are visible on next poll.

**Why rejected:**
- Polling is awkward in both SwiftUI and Compose
- The state types would need to cross JExtract — feasible but requires careful Sendable / Codable plumbing for every state shape
- The current proposal achieves the same outcome by hoisting state to the screen, which both platforms have idiomatic ways to handle
- Can be added later per-viewmodel if needed; not blocking the v1.1.0 ship

### B.5 Stateful viewmodels with closures/callbacks

Same as B.4 but the viewmodel takes an `onStateChange` closure parameter. JExtract's closure bridging is incomplete (it's why `TMDBContainerTestHooks.swift` is `#if canImport(Darwin)`-guarded — closures with `@escaping` in a return type don't bridge).

**Why rejected:**
- Blocked by JExtract closure-bridging limitations today
- Will probably be feasible in a future swift-java release; revisit then

---

## References

- [SwiftAndroidSDK current source — `TMDBViewModel.swift`](https://github.com/erikg84/SwiftAndroidIMDBSdk/blob/main/Sources/SwiftAndroidSDK/ViewModel/TMDBViewModel.swift)
- [SwiftAndroidSDK current source — `TMDBContainer.swift`](https://github.com/erikg84/SwiftAndroidIMDBSdk/blob/main/Sources/SwiftAndroidSDK/Container/TMDBContainer.swift)
- [Koin Annotations — Definitions docs](https://insert-koin.io/docs/reference/koin-annotations/definitions/)
- [Koin — `koinInject` for Compose](https://insert-koin.io/docs/reference/koin-compose/compose/)
- [Koin — Android ViewModel](https://insert-koin.io/docs/reference/koin-android/viewmodel/)
- [Slack Circuit — `rememberRetained`](https://slackhq.github.io/circuit/api/0.x/circuit-retained/com.slack.circuit.retained/remember-retained.html)
- [Chris Banes — Retaining beyond ViewModels](https://chrisbanes.me/posts/retaining-beyond-viewmodels/)
- [Android Developers — State holders and UI state](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [SwiftPM clones whole repo (issue #6062)](https://github.com/swiftlang/swift-package-manager/issues/6062) — context for why the SDK lives in a wrapper repo for SPM consumers
- [SwiftAndroidIMDBSdk DISTRIBUTION.md](https://github.com/erikg84/SwiftAndroidIMDBSdk/blob/main/DISTRIBUTION.md)
