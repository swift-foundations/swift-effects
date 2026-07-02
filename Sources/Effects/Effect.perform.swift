import Dependency_Primitives
public import Effect_Primitives

extension Effect {
    /// Performs an effect by looking up its handler from the current context.
    ///
    /// This suspends the current task until the handler resumes the continuation.
    ///
    /// - Parameter effect: The effect to perform.
    /// - Returns: The value produced by the handler.
    /// - Throws: The error produced by the handler, if any.
    @inlinable
    public static func perform<E: Effect.`Protocol`>(
        _ effect: E
    ) async throws(E.Failure) -> E.Value
    where
        E: EffectWithHandler,
        E.Value: Copyable,
        E.HandlerKey.Value: Copyable
    {
        let handler = Effect.Context.current[E.HandlerKey.self]

        // SAFETY ([MEM-SEND-008], [MEM-SEND-011]): `effect` is dispatched to the
        // handler on the Task below, which runs while the calling task is
        // suspended on `swiftContinuation`. The continuation resumes exactly once,
        // after which control returns to the single caller — there is no
        // concurrent access to `effect`. Because the handler may store the
        // continuation and resume it after `handle` returns, the dispatch must
        // happen on a Task; the region checker cannot prove the value is
        // disconnected across the `withCheckedContinuation` closure boundary, so
        // `effect` crosses into the Task region via an `@unchecked Sendable`
        // transfer intermediary rather than a `Sendable` bound ([MEM-SEND-012]).
        // The resumed value crosses back via the `sending` callback parameter.
        let transfer = Effect.Perform.Transfer(effect)

        // Result-wrapping workaround: stdlib's withCheckedThrowingContinuation
        // throws `any Error`, which erases the typed E.Failure and previously
        // forced a `throw error as! E.Failure` force-cast. Deliver the outcome
        // as a Result through a non-throwing CheckedContinuation and call
        // `.get()` outside, matching Dependency.Scope.with for the same reason.
        let result: Result<E.Value, E.Failure> = await withCheckedContinuation(isolation: nil) {
            (swiftContinuation: CheckedContinuation<Result<E.Value, E.Failure>, Never>) in

            Task {
                let effectContinuation = Effect.Continuation.one {
                    @Sendable (result: sending Result<E.Value, E.Failure>) async in
                    swiftContinuation.resume(returning: result)
                }

                await handler.handle(transfer.value, continuation: effectContinuation)
            }
        }

        return try result.get()
    }
}

// MARK: - Never Failure Specialization

extension Effect {
    /// Performs an infallible effect by looking up its handler from the current context.
    ///
    /// This suspends the current task until the handler resumes the continuation.
    ///
    /// - Parameter effect: The effect to perform.
    /// - Returns: The value produced by the handler.
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
        let handler = Effect.Context.current[E.HandlerKey.self]

        // SAFETY ([MEM-SEND-008], [MEM-SEND-011]): see the fallible overload above
        // — `effect` is touched only inside the Task while the caller is suspended
        // on `swiftContinuation`, which resumes exactly once. It crosses into the
        // Task region via an `@unchecked Sendable` transfer intermediary; the
        // value crosses back via the `sending` callback parameter ([MEM-SEND-012]).
        let transfer = Effect.Perform.Transfer(effect)

        return await withCheckedContinuation(isolation: nil) {
            (swiftContinuation: CheckedContinuation<E.Value, Never>) in

            Task {
                let effectContinuation = Effect.Continuation.one {
                    @Sendable (result: sending Result<E.Value, Never>) async in
                    switch result {
                    case .success(let value):
                        swiftContinuation.resume(returning: value)
                    }
                }

                await handler.handle(transfer.value, continuation: effectContinuation)
            }
        }
    }
}
