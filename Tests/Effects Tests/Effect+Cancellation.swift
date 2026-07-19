import Dependency_Primitives
import Effects
import Effects_Testing
import Testing

extension Effect {
    @Suite struct Cancellation {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

// MARK: - Unit Tests

extension Effect.Cancellation.Unit {
    /// F-001: `Effect.perform`'s dispatch ran on a fully unstructured `Task`
    /// (`Effect.perform.swift:92`, the infallible `Failure == Never` overload),
    /// completely disconnected from the calling task's cancellation. A
    /// cancellation-aware handler had no way to ever observe that the caller
    /// had been cancelled — `Task.isCancelled` inside the dispatch task was
    /// always `false`, even after the calling task was cancelled from outside.
    ///
    /// `perform` now propagates the calling task's cancellation into the
    /// dispatch task via `withTaskCancellationHandler`, so a cancellation-aware
    /// handler CAN observe it (though `perform` itself remains opaque to its
    /// own suspension — see `Effect.perform`'s "Cancellation" doc).
    @Test
    func `infallible perform propagates caller cancellation to the handler dispatch task`() async {
        struct Probe: Effect.`Protocol`, EffectWithHandler {
            typealias Value = Bool
            typealias Failure = Never
            typealias HandlerKey = Key

            struct Key: Dependency.Key {
                typealias Value = Effect.Test.Handler<Probe>
                static var liveValue: Effect.Test.Handler<Probe> { testValue }
                static var testValue: Effect.Test.Handler<Probe> {
                    Effect.Test.Handler { _ in
                        // Poll for cancellation to reach this dispatch task.
                        // Bounded so a pre-fix (disconnected) run fails fast
                        // rather than hanging.
                        for _ in 0..<500 {
                            if Task.isCancelled { return .success(true) }
                            await Task.yield()
                        }
                        return .success(false)
                    }
                }
            }
        }

        let task = Task {
            await Effect.Context.with(
                { handlers in handlers[Probe.Key.self] = Probe.Key.testValue },
                operation: { await Effect.perform(Probe()) }
            )
        }

        await Task.yield()
        task.cancel()

        let observedCancellation = await task.value
        #expect(observedCancellation == true)
    }

    /// F-001: same coverage as above for the fallible (`throws(E.Failure)`)
    /// overload — `Effect.perform.swift:44`. The two `perform` overloads
    /// dispatch independently, so each needs its own regression coverage.
    @Test
    func `fallible perform propagates caller cancellation to the handler dispatch task`() async {
        struct Probe: Effect.`Protocol`, EffectWithHandler {
            typealias Value = Bool
            typealias Failure = TestFailure
            typealias HandlerKey = Key

            struct TestFailure: Swift.Error, Equatable {}

            struct Key: Dependency.Key {
                typealias Value = Effect.Test.Handler<Probe>
                static var liveValue: Effect.Test.Handler<Probe> { testValue }
                static var testValue: Effect.Test.Handler<Probe> {
                    Effect.Test.Handler { _ in
                        for _ in 0..<500 {
                            if Task.isCancelled { return .success(true) }
                            await Task.yield()
                        }
                        return .success(false)
                    }
                }
            }
        }

        let task = Task {
            await Effect.Context.with(
                { handlers in handlers[Probe.Key.self] = Probe.Key.testValue },
                operation: {
                    (try? await Effect.perform(Probe())) ?? false
                }
            )
        }

        await Task.yield()
        task.cancel()

        let observedCancellation = await task.value
        #expect(observedCancellation == true)
    }
}
