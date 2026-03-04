public import Effects
public import Witness_Primitives

// MARK: - Yield Effect

extension Effect {
    /// An effect that yields control to the scheduler.
    ///
    /// In production, this delegates to `Task.yield()`.
    /// In tests, this can be controlled for deterministic behavior.
    public struct Yield: __EffectProtocol, EffectWithHandler, Sendable {
        public typealias Value = Void
        public typealias Failure = Never
        public typealias HandlerKey = Handler.Key

        public init() {}
    }
}

// MARK: - Handler

extension Effect.Yield {
    /// Handler for yield effects.
    public struct Handler: __EffectHandler, Sendable, Witness.`Protocol` {
        public typealias Handled = Effect.Yield

        private let _handle: @Sendable () async -> Void

        public init(_ handle: @escaping @Sendable () async -> Void) {
            self._handle = handle
        }

        public func handle(
            _ effect: Effect.Yield,
            continuation: consuming Effect.Continuation.One<Void, Never>
        ) async {
            await _handle()
            await continuation.resume()
        }
    }
}

// MARK: - Live Handler

extension Effect.Yield.Handler {
    /// The live handler that delegates to `Task.yield()`.
    public static let live = Effect.Yield.Handler {
        await Task.yield()
    }
}

// MARK: - Handler Key

extension Effect.Yield.Handler {
    /// Context key for registering yield handlers.
    public struct Key: Dependency.Key {
        public typealias Value = Effect.Yield.Handler

        public static var liveValue: Effect.Yield.Handler { .live }
        public static var testValue: Effect.Yield.Handler { .live }
    }
}

// MARK: - Convenience

extension Effect.Yield {
    /// Performs a yield effect, suspending until the scheduler resumes.
    @inlinable
    public static func perform() async {
        await Effect.perform(Effect.Yield())
    }
}
