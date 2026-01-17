public import Effect_Primitives
public import Dependency_Primitives

extension Effect {
    /// Performs an effect by looking up its handler from the current context.
    ///
    /// This suspends the current task until the handler resumes the continuation.
    ///
    /// - Parameter effect: The effect to perform.
    /// - Returns: The value produced by the handler.
    /// - Throws: The error produced by the handler, if any.
    @inlinable
    public static func perform<E: __EffectProtocol>(
        _ effect: E
    ) async throws(E.Failure) -> E.Value
    where E: EffectWithHandler {
        let handler = Effect.Context.current[E.HandlerKey.self]

        do {
            return try await withCheckedThrowingContinuation(isolation: nil) {
                (swiftContinuation: CheckedContinuation<E.Value, any Error>) in

                // Create effectContinuation inside Task to avoid move-only capture issues
                Task {
                    let effectContinuation = Effect.Continuation.one {
                        @Sendable (result: Result<E.Value, E.Failure>) async in
                        switch result {
                        case .success(let value):
                            swiftContinuation.resume(returning: value)
                        case .failure(let error):
                            swiftContinuation.resume(throwing: error)
                        }
                    }

                    await handler.handle(effect, continuation: effectContinuation)
                }
            }
        } catch {
            throw error as! E.Failure
        }
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
    public static func perform<E: __EffectProtocol>(
        _ effect: E
    ) async -> E.Value
    where E: EffectWithHandler, E.Failure == Never {
        let handler = Effect.Context.current[E.HandlerKey.self]

        return await withCheckedContinuation(isolation: nil) {
            (swiftContinuation: CheckedContinuation<E.Value, Never>) in

            // Create effectContinuation inside Task to avoid move-only capture issues
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
