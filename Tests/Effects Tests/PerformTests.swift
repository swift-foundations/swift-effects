import Dependency_Primitives
import Effects
import Effects_Testing
import Testing

@Test
func performReturnsHandlerValue() async {
    // Define a simple test effect
    struct TestEffect: Effect.`Protocol`, EffectWithHandler {
        typealias Value = Int
        typealias Failure = Never
        typealias HandlerKey = Key

        struct Key: Dependency.Key {
            typealias Value = Effect.Test.Handler<TestEffect>
            static var liveValue: Effect.Test.Handler<TestEffect> {
                Effect.Test.Handler(returning: 0)
            }
            static var testValue: Effect.Test.Handler<TestEffect> { liveValue }
        }
    }

    let handler = Effect.Test.Handler<TestEffect>(returning: 42)

    let result = await Effect.Context.with(
        { handlers in
            handlers[TestEffect.Key.self] = handler
        },
        operation: {
            await Effect.perform(TestEffect())
        }
    )

    #expect(result == 42)
}

@Test
func performThrowsHandlerError() async throws {
    struct TestError: Swift.Error, Equatable {}

    struct TestEffect: Effect.`Protocol`, EffectWithHandler {
        typealias Value = Int
        typealias Failure = TestError
        typealias HandlerKey = Key

        struct Key: Dependency.Key {
            typealias Value = Effect.Test.Handler<TestEffect>
            static var liveValue: Effect.Test.Handler<TestEffect> {
                Effect.Test.Handler(throwing: TestError())
            }
            static var testValue: Effect.Test.Handler<TestEffect> { liveValue }
        }
    }

    let handler = Effect.Test.Handler<TestEffect>(throwing: TestError())

    do {
        _ = try await Effect.Context.with(
            { handlers in
                handlers[TestEffect.Key.self] = handler
            },
            operation: {
                try await Effect.perform(TestEffect())
            }
        )
        Issue.record("Expected error to be thrown")
    } catch {
        #expect(error is TestError)
    }
}
