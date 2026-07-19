import Dependency_Primitives
public import Effect_Primitives

extension Effect {
    /// Performs an effect by looking up its handler from the current context.
    ///
    /// This suspends the current task until the handler resumes the continuation.
    ///
    /// ## Cancellation
    ///
    /// `perform` propagates the calling task's cancellation into the handler
    /// dispatch: if the calling task is cancelled while suspended here, the
    /// internal dispatch task is cancelled too, so a cancellation-aware
    /// handler observes `Task.isCancelled` (or a cooperative cancellation
    /// point such as `Task.sleep`) and can react — typically by aborting
    /// (dropping the continuation without resuming), the documented abort
    /// outcome on `Effect.Handler.Protocol`.
    ///
    /// `perform` itself remains cancellation-OPAQUE with respect to its own
    /// suspension: cancellation alone does not resume the continuation and
    /// does not make this call return or throw, because there is no generic
    /// way to synthesize a valid `E.Value` / `E.Failure` outcome for an
    /// arbitrary effect. A handler that wants `perform` to unblock promptly
    /// on cancellation must resume with an outcome it constructs itself
    /// (e.g., throwing a cancellation-flavored `E.Failure` it defines) —
    /// `perform` only makes the cancellation *signal* reach the handler; what
    /// the handler does with it is the handler's choice. A handler that never
    /// resumes (aborts, or blocks indefinitely without checking cancellation)
    /// leaves the caller suspended until the process exits.
    ///
    /// - Parameter effect: The effect to perform.
    /// - Returns: The value produced by the handler.
    /// - Throws: The error produced by the handler, if any.
    @inlinable
    // Generic-parameter constraint: `Self` would demand identity (only
    // `Effect` itself), not conformance to `Effect.Protocol` for any E.
    // swiftlint:disable:next prefer_self_in_static_references
    public static func perform<E: Effect.`Protocol`>(
        _ effect: E
    ) async throws(E.Failure) -> E.Value
    where
        E: EffectWithHandler,
        E.Value: Copyable,
        E.HandlerKey.Value: Copyable
    {
        let handler = Self.Context.current[E.HandlerKey.self]

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
        let transfer = Self.Perform.Transfer(effect)

        // Result-wrapping workaround: stdlib's withCheckedThrowingContinuation
        // throws `any Error`, which erases the typed E.Failure and previously
        // forced a `throw error as! E.Failure` force-cast. Deliver the outcome
        // as a Result through a non-throwing CheckedContinuation and call
        // `.get()` outside, matching Dependency.Scope.with for the same reason.
        //
        // CANCELLATION: the dispatch Task below is unstructured and, left
        // alone, is fully disconnected from the calling task's cancellation
        // state — a handler checking `Task.isCancelled` inside it would never
        // see the caller's cancellation. `dispatchTask` records that Task's
        // handle so `onCancel` can cancel it, closing that gap; see this
        // method's "Cancellation" doc above for the resulting contract.
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

// MARK: - Never Failure Specialization

extension Effect {
    /// Performs an infallible effect by looking up its handler from the current context.
    ///
    /// This suspends the current task until the handler resumes the continuation.
    ///
    /// See the fallible overload above for the full "Cancellation" contract:
    /// this overload propagates the caller's cancellation into the dispatch
    /// task the same way, and remains equally opaque with respect to its own
    /// suspension.
    ///
    /// - Parameter effect: The effect to perform.
    /// - Returns: The value produced by the handler.
    @inlinable
    // Generic-parameter constraint: `Self` would demand identity (only
    // `Effect` itself), not conformance to `Effect.Protocol` for any E.
    // swiftlint:disable:next prefer_self_in_static_references
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

        // SAFETY ([MEM-SEND-008], [MEM-SEND-011]): see the fallible overload above
        // — `effect` is touched only inside the Task while the caller is suspended
        // on `swiftContinuation`, which resumes exactly once. It crosses into the
        // Task region via an `@unchecked Sendable` transfer intermediary; the
        // value crosses back via the `sending` callback parameter ([MEM-SEND-012]).
        let transfer = Self.Perform.Transfer(effect)

        // CANCELLATION: see the fallible overload above — `dispatchTask`
        // closes the same structural gap for this overload's dispatch Task.
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
