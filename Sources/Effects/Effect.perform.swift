public import Effect_Primitives
import Dependency_Primitives

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

        // Result-wrapping workaround: stdlib's withCheckedThrowingContinuation
        // throws `any Error`, which erases the typed E.Failure and previously
        // forced a `throw error as! E.Failure` force-cast. Deliver the outcome
        // as a Result through a non-throwing CheckedContinuation and call
        // `.get()` outside, matching Dependency.Scope.with for the same reason.
        let result: Result<E.Value, E.Failure> = await withCheckedContinuation(isolation: nil) {
            (swiftContinuation: CheckedContinuation<Result<E.Value, E.Failure>, Never>) in

            Task {
                let effectContinuation = Effect.Continuation.one {
                    @Sendable (result: Result<E.Value, E.Failure>) async in
                    swiftContinuation.resume(returning: result)
                }

                await handler.handle(effect, continuation: effectContinuation)
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

        return await withCheckedContinuation(isolation: nil) {
            (swiftContinuation: CheckedContinuation<E.Value, Never>) in

            Task {
                let effectContinuation = Effect.Continuation.one {
                    @Sendable (result: Result<E.Value, Never>) async in
                    switch result {
                    case .success(let value):
                        swiftContinuation.resume(returning: value)
                    }
                }

                await handler.handle(effect, continuation: effectContinuation)
            }
        }
    }
}
