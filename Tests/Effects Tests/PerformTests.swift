import Testing
import Effects
import Effects_Testing
import Dependency_Primitives

@Test
func performReturnsHandlerValue() async {
    // Define a simple test effect
    struct TestEffect: EffectProtocol, EffectWithHandler {
        typealias Value = Int
        typealias Failure = Never
        typealias HandlerKey = Key

        struct Key: EffectContextKey {
            typealias Value = Effect.Test.Handler<TestEffect>
            static var liveValue: Effect.Test.Handler<TestEffect> {
                Effect.Test.Handler(returning: 0)
            }
            static var testValue: Effect.Test.Handler<TestEffect> { liveValue }
        }
    }

    let handler = Effect.Test.Handler<TestEffect>(returning: 42)

    let result = await Effect.Context.with({ handlers in
        handlers[TestEffect.Key.self] = handler
    }) {
        await Effect.perform(TestEffect())
    }

    #expect(result == 42)
}

@Test
func performThrowsHandlerError() async throws {
    struct TestError: Error, Equatable {}

    struct TestEffect: EffectProtocol, EffectWithHandler {
        typealias Value = Int
        typealias Failure = TestError
        typealias HandlerKey = Key

        struct Key: EffectContextKey {
            typealias Value = Effect.Test.Handler<TestEffect>
            static var liveValue: Effect.Test.Handler<TestEffect> {
                Effect.Test.Handler(throwing: TestError())
            }
            static var testValue: Effect.Test.Handler<TestEffect> { liveValue }
        }
    }

    let handler = Effect.Test.Handler<TestEffect>(throwing: TestError())

    do {
        _ = try await Effect.Context.with({ handlers in
            handlers[TestEffect.Key.self] = handler
        }) {
            try await Effect.perform(TestEffect())
        }
        Issue.record("Expected error to be thrown")
    } catch {
        #expect(error is TestError)
    }
}
