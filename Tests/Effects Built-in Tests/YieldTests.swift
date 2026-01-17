import Testing
import Effects_Built_in
import Effects_Testing
import Dependency_Primitives
import Async_Primitives

@Test
func yieldPerformsWithoutError() async {
    let yieldCount = Async.Mutex<Int>(0)

    let handler = Effect.Yield.Handler {
        yieldCount.withLock { $0 += 1 }
    }

    await Effect.Context.with({ handlers in
        handlers[Effect.Yield.Handler.Key.self] = handler
    }) {
        await Effect.Yield.perform()
        await Effect.Yield.perform()
    }

    #expect(yieldCount.withLock { $0 } == 2)
}
