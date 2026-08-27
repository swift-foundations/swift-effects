import Dependency
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

extension Effect.Cancellation.Unit {

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
