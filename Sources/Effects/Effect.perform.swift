import Dependency
public import Effect

extension Effect {

    @inlinable

    public static func perform<E: Effect.`Protocol`>(
        _ effect: E
    ) async throws(E.Failure) -> E.Value
    where
        E: EffectWithHandler,
        E.Value: Copyable,
        E.HandlerKey.Value: Copyable
    {
        let handler = Self.Context.current[E.HandlerKey.self]

        let transfer = Self.Perform.Transfer(effect)

        let dispatchTask = Self.Perform.TaskBox()

        let result: Result<E.Value, E.Failure> = await withTaskCancellationHandler(
            operation: {
                await withCheckedContinuation(isolation: nil) {
                    (swiftContinuation: CheckedContinuation<Result<E.Value, E.Failure>, Never>) in

                    let task = Task {
                        let effectContinuation = Self.Continuation.one {
                            @Sendable (result: sending Result<E.Value, E.Failure>) async in
                            swiftContinuation.resume(returning: result)
                        }

                        await handler.handle(transfer.value, continuation: effectContinuation)
                    }

                    dispatchTask.store(task)
                }
            },
            onCancel: {
                dispatchTask.cancel()
            },
            isolation: nil
        )

        return try result.get()
    }
}

extension Effect {

    @inlinable

    public static func perform<E: Effect.`Protocol`>(
        _ effect: E
    ) async -> E.Value
    where
        E: EffectWithHandler,
        E.Failure == Never,
        E.Value: Copyable,
        E.HandlerKey.Value: Copyable
    {
        let handler = Self.Context.current[E.HandlerKey.self]

        let transfer = Self.Perform.Transfer(effect)

        let dispatchTask = Self.Perform.TaskBox()

        return await withTaskCancellationHandler(
            operation: {
                await withCheckedContinuation(isolation: nil) {
                    (swiftContinuation: CheckedContinuation<E.Value, Never>) in

                    let task = Task {
                        let effectContinuation = Self.Continuation.one {
                            @Sendable (result: sending Result<E.Value, Never>) async in
                            switch result {
                            case .success(let value):
                                swiftContinuation.resume(returning: value)
                            }
                        }

                        await handler.handle(transfer.value, continuation: effectContinuation)
                    }

                    dispatchTask.store(task)
                }
            },
            onCancel: {
                dispatchTask.cancel()
            },
            isolation: nil
        )
    }
}
