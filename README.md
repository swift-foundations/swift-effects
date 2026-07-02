# swift-effects

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Context-scoped effect handling for Swift concurrency — describe side effects as values, perform them with typed throws, and swap the handler per scope for deterministic tests.

## Key Features

- **Typed throws end-to-end** — `Effect.perform(_:)` returns `E.Value` or throws exactly `E.Failure`; infallible effects (`Failure == Never`) perform without `try`.
- **Context-scoped handlers** — handlers resolve through dependency-context keys, so a scope override changes behavior without touching call sites.
- **Test doubles as a separate product** — `Effect.Test.Handler`, `Effect.Test.Spy`, and `Effect.Test.Recorder` live in the `Effects Testing` product, keeping test-only surface out of production builds.
- **Interceptable built-ins** — `Effect.Exit` and `Effect.Yield` turn process termination and scheduler yields into effects a test can observe instead of suffer.

## Quick Start

An effect is a value describing *what* should happen. The handler deciding *how* is looked up from the current context, so the same call site is non-deterministic in production and fixed in a test scope:

```swift
import Effects
import Effects_Testing
import Dependency_Primitives

struct RollDice: Effect.`Protocol`, EffectWithHandler {
    typealias Value = Int
    typealias Failure = Never
    typealias HandlerKey = Key

    struct Key: Dependency.Key {
        typealias Value = Effect.Test.Handler<RollDice>
        static var liveValue: Value { .init(returning: { _ in Int.random(in: 1...6) }) }
        static var testValue: Value { liveValue }
    }
}

// Override the handler for one scope; the perform call site is unchanged.
let roll = await Effect.Context.with({ handlers in
    handlers[RollDice.Key.self] = .init(returning: 4)
}) {
    await Effect.perform(RollDice())
}
// roll == 4
```

Fallible effects declare a concrete `Failure` type, and `Effect.perform` throws exactly that type — no `any Error` to downcast at the catch site.

## Installation

No versions are tagged yet; pin to `main`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-effects.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Effects", package: "swift-effects")
    ]
),
.testTarget(
    name: "YourTargetTests",
    dependencies: [
        .product(name: "Effects Testing", package: "swift-effects")
    ]
)
```

### Requirements

- Swift 6.3+
- macOS 26+, iOS 26+, tvOS 26+, watchOS 26+, visionOS 26+

## Architecture

| Product | Module | When to import |
|---|---|---|
| `Effects` | `Effects` | Declaring and performing effects. Re-exports the effect and dependency primitives it builds on, so one import covers `Effect.perform`, `EffectWithHandler`, and `Effect.Context`. |
| `Effects Built-in` | `Effects_Built_in` | Ready-made `Effect.Exit` and `Effect.Yield`. Re-exports `Effects`. |
| `Effects Testing` | `Effects_Testing` | Test doubles for asserting on performed effects. Test targets only. |

## Built-in Effects

The built-in catalog is deliberately small at this stage:

| Effect | Live behavior | Under test |
|---|---|---|
| `Effect.Exit` | Terminates the process (`Value == Never`). The default live handler is a cross-platform `fatalError` fallback; platform packages supply handlers that call the real exit function. | The test handler suspends instead of terminating, so a test can observe the exit request and cancel or time out. |
| `Effect.Yield` | Delegates to `Task.yield()`. | A custom `Effect.Yield.Handler` can count or suppress yields for deterministic scheduling tests. |

```swift
import Effects_Built_in

await Effect.Exit.perform(code: 1)   // never returns in production
await Effect.Yield.perform()
```

## Testing

The `Effects Testing` product provides three test doubles:

| Type | Purpose |
|---|---|
| `Effect.Test.Handler<E>` | Returns a canned value (`init(returning:)`), a canned error (`init(throwing:)`), or runs a closure per effect. |
| `Effect.Test.Spy<E>` | Wraps a handler and records every invocation — effect value, timestamp, and outcome — for `callCount` / `invocations` assertions. |
| `Effect.Test.Recorder` | Type-erased recorder collecting invocations of *different* effect types into one timeline. |

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public release.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
