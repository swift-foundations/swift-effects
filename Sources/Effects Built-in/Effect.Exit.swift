public import Effects
public import Witness_Primitives

// MARK: - Exit Effect

extension Effect {
    /// An effect that terminates the process with an exit code.
    ///
    /// In production, the handler calls the system exit function and never returns.
    /// In tests, this can be intercepted to verify exit behavior without terminating.
    ///
    /// - Note: The live handler must be provided by platform-specific code, such as swift-darwin or swift-linux.
    ///   The default live handler uses `fatalError` as a cross-platform fallback.
    public struct Exit: Effect.`Protocol`, EffectWithHandler, Sendable {
        /// The exit code to terminate with.
        public let code: Int32

        public init(code: Int32) {
            self.code = code
        }
    }
}

// MARK: - Exit Typealiases

extension Effect.Exit {
    public typealias Value = Never
    public typealias Failure = Never
    public typealias HandlerKey = Handler.Key
}

// MARK: - Handler

extension Effect.Exit {
    /// Handler for exit effects.
    public struct Handler: Effect.Handler.`Protocol`, Sendable, Witness.`Protocol` {
        private let _handle: @Sendable (Int32) async -> Never

        public init(_ handle: @escaping @Sendable (Int32) async -> Never) {
            self._handle = handle
        }
    }
}

extension Effect.Exit.Handler {
    public typealias Handled = Effect.Exit

    public func handle(
        _ effect: borrowing Effect.Exit,
        continuation: consuming Effect.Continuation.One<Never, Never>
    ) async {
        // The handler calls exit, which never returns.
        // The continuation is consumed but never resumed.
        _ = consume continuation
        await _handle(effect.code)
    }
}

// MARK: - Live Handler

extension Effect.Exit.Handler {
    /// The default live handler that terminates using fatalError.
    ///
    /// Platform-specific packages, such as swift-darwin or swift-linux, should provide
    /// handlers that call the actual system exit function.
    public static let live = Effect.Exit.Handler { code in
        fatalError("Exit with code \(code)")
    }
}

// MARK: - Handler Key

extension Effect.Exit.Handler {
    /// Context key for registering exit handlers.
    public struct Key: Dependency.Key {}
}

extension Effect.Exit.Handler.Key {
    public typealias Value = Effect.Exit.Handler

    public static var liveValue: Effect.Exit.Handler { .live }

    /// Test value that captures exit requests without terminating.
    ///
    /// This handler suspends rather than exiting. `Effect.perform` propagates
    /// the calling task's cancellation into this handler's dispatch task (see
    /// `Effect.perform`'s "Cancellation" doc), so once the surrounding
    /// operation is cancelled, this handler stops retrying `Task.sleep` in a
    /// loop and parks on an unresumed continuation instead — avoiding a
    /// cancelled-but-still-spinning background task.
    ///
    /// - Important: Cancelling the surrounding task does NOT make
    ///   `Effect.Exit.perform` itself return or throw — its `Value` is
    ///   `Never`, so no outcome can ever resume that call, and this handler
    ///   itself never returns either (parking, not exiting, once cancelled —
    ///   matching the live handler's `fatalError` contract that `_handle`
    ///   never returns normally). Tests that need to move past a call to
    ///   `Effect.Exit.perform` (e.g., to assert an exit was requested with a
    ///   given code) must race the OPERATION THAT CALLS `perform` from the
    ///   outside — for example with `withThrowingTaskGroup`, discarding the
    ///   losing branch — rather than expect cancellation to unblock `perform`
    ///   itself.
    public static var testValue: Effect.Exit.Handler {
        Effect.Exit.Handler { _ in
            // In test mode, we suspend rather than exiting. Once the
            // surrounding operation is cancelled, `Task.sleep` stops actually
            // sleeping (it throws immediately on a cancelled task), so
            // retrying it in a loop would busy-spin. Once cancellation is
            // observed, park on a continuation that is deliberately never
            // resumed instead — see the doc above for why this handler
            // cannot exit (return) here.
            while !Task.isCancelled {
                await Task.yield()
                // The only error `Task.sleep` raises is cancellation, which the
                // loop condition above already re-checks on the next iteration —
                // the error is deliberately discarded, not silently swallowed
                // ([IMPL-108]).
                do {
                    try await Task.sleep(for: .seconds(3600))
                } catch {}
            }
            await withCheckedContinuation { (_: CheckedContinuation<Never, Never>) in }
        }
    }
}

// MARK: - Convenience

extension Effect.Exit {
    /// Performs an exit effect, terminating the process.
    ///
    /// This function never returns in production.
    /// In tests with a mock handler, behavior depends on the handler configuration.
    @inlinable
    public static func perform(code: Int32) async -> Never {
        await Effect.perform(Effect.Exit(code: code))
    }
}
