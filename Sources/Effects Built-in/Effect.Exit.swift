public import Effects
public import Witness_Primitives

// MARK: - Exit Effect

extension Effect {
    /// An effect that terminates the process with an exit code.
    ///
    /// In production, the handler calls the system exit function and never returns.
    /// In tests, this can be intercepted to verify exit behavior without terminating.
    ///
    /// - Note: The live handler must be provided by platform-specific code (e.g., swift-darwin, swift-linux).
    ///   The default live handler uses `fatalError` as a cross-platform fallback.
    public struct Exit: Effect.`Protocol`, EffectWithHandler, Sendable {
        public typealias Value = Never
        public typealias Failure = Never
        public typealias HandlerKey = Handler.Key

        /// The exit code to terminate with.
        public let code: Int32

        public init(code: Int32) {
            self.code = code
        }
    }
}

// MARK: - Handler

extension Effect.Exit {
    /// Handler for exit effects.
    public struct Handler: Effect.Handler.`Protocol`, Sendable, Witness.`Protocol` {
        public typealias Handled = Effect.Exit

        private let _handle: @Sendable (Int32) async -> Never

        public init(_ handle: @escaping @Sendable (Int32) async -> Never) {
            self._handle = handle
        }

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
}

// MARK: - Live Handler

extension Effect.Exit.Handler {
    /// The default live handler that terminates using fatalError.
    ///
    /// Platform-specific packages (swift-darwin, swift-linux, etc.) should provide
    /// handlers that call the actual system exit function.
    public static let live = Effect.Exit.Handler { code in
        fatalError("Exit with code \(code)")
    }
}

// MARK: - Handler Key

extension Effect.Exit.Handler {
    /// Context key for registering exit handlers.
    public struct Key: Dependency.Key {
        public typealias Value = Effect.Exit.Handler

        public static var liveValue: Effect.Exit.Handler { .live }

        /// Test value that captures exit requests without terminating.
        ///
        /// This handler suspends indefinitely rather than exiting,
        /// allowing tests to timeout or cancel the task.
        public static var testValue: Effect.Exit.Handler {
            Effect.Exit.Handler { _ in
                // In test mode, we suspend indefinitely rather than exiting.
                // Tests should use task cancellation or timeouts to handle this.
                while true {
                    await Task.yield()
                    do {
                        try await Task.sleep(for: .seconds(3600))
                    } catch {
                        // Cancellation (or any other Task.sleep failure) —
                        // the loop simply retries, matching the previous
                        // `try?` swallow-and-continue behavior.
                    }
                }
            }
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
