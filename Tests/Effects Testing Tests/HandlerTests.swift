import Effects
import Effects_Testing
import Testing

struct TestEffect: Effect.`Protocol` {
    typealias Value = String
    typealias Failure = Never

    let input: Int
}

@Test
func handlerReturnsFixedValue() async {
    let handler = Effect.Test.Handler<TestEffect>(returning: "hello")

    let continuation = Effect.Continuation.one {
        @Sendable (result: Result<String, Never>) async in
        switch result {
        case .success(let value):
            #expect(value == "hello")
        }
    }

    await handler.handle(TestEffect(input: 42), continuation: continuation)
}

@Test
func handlerReturnsComputedValue() async {
    let handler = Effect.Test.Handler<TestEffect>(returning: { effect in
        "value: \(effect.input)"
    })

    let continuation = Effect.Continuation.one {
        @Sendable (result: Result<String, Never>) async in
        switch result {
        case .success(let value):
            #expect(value == "value: 42")
        }
    }

    await handler.handle(TestEffect(input: 42), continuation: continuation)
}
