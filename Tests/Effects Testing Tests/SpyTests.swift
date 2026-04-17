import Testing
import Effects
import Effects_Testing

struct CountEffect: Effect.`Protocol` {
    typealias Value = Int
    typealias Failure = Never

    let id: Int
}

@Test
func spyRecordsInvocations() async {
    let spy = Effect.Test.Spy<CountEffect>(returning: 100)

    #expect(spy.callCount == 0)

    let cont1 = Effect.Continuation.one {
        @Sendable (result: Result<Int, Never>) async in
    }
    await spy.handle(CountEffect(id: 1), continuation: cont1)

    let cont2 = Effect.Continuation.one {
        @Sendable (result: Result<Int, Never>) async in
    }
    await spy.handle(CountEffect(id: 2), continuation: cont2)

    #expect(spy.callCount == 2)
    #expect(spy.invocations[0].effect.id == 1)
    #expect(spy.invocations[1].effect.id == 2)
}

@Test
func spyReset() async {
    let spy = Effect.Test.Spy<CountEffect>(returning: 100)

    let cont = Effect.Continuation.one {
        @Sendable (result: Result<Int, Never>) async in
    }
    await spy.handle(CountEffect(id: 1), continuation: cont)

    #expect(spy.callCount == 1)

    spy.reset()

    #expect(spy.callCount == 0)
    #expect(spy.invocations.isEmpty)
}
