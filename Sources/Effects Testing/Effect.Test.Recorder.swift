public import Effects
import Async_Primitives

extension Effect.Test {
    /// A type-erased recorder that can record invocations of any effect type.
    ///
    /// Use this when you need to record effects of different types in a single collection,
    /// or when the effect type is not known statically.
    ///
    /// ```swift
    /// let recorder = Effect.Test.Recorder()
    /// // ... run code that performs effects ...
    /// #expect(recorder.count == 3)
    /// ```
    public final class Recorder: Sendable {
        /// A type-erased recorded invocation.
        public struct Invocation: Sendable {
            /// The type of effect that was performed.
            public let effectType: any EffectProtocol.Type

            /// The effect that was performed, type-erased.
            public let effect: any EffectProtocol

            /// The time at which the effect was handled.
            public let timestamp: ContinuousClock.Instant

            /// Whether the effect completed successfully.
            public let succeeded: Bool

            public init(
                effectType: any EffectProtocol.Type,
                effect: any EffectProtocol,
                timestamp: ContinuousClock.Instant,
                succeeded: Bool
            ) {
                self.effectType = effectType
                self.effect = effect
                self.timestamp = timestamp
                self.succeeded = succeeded
            }
        }

        private let _invocations: Async.Mutex<[Invocation]> = Async.Mutex([])

        /// All recorded invocations.
        public var invocations: [Invocation] {
            _invocations.withLock { $0 }
        }

        /// The number of recorded invocations.
        public var count: Int {
            _invocations.withLock { $0.count }
        }

        /// Creates a new recorder.
        public init() {}

        /// Records an invocation.
        internal func record<E: EffectProtocol>(_ effect: E, succeeded: Bool) {
            let invocation = Invocation(
                effectType: E.self,
                effect: effect,
                timestamp: ContinuousClock.now,
                succeeded: succeeded
            )
            _invocations.withLock { $0.append(invocation) }
        }

        /// Clears all recorded invocations.
        public func reset() {
            _invocations.withLock { $0.removeAll() }
        }

        /// Returns all invocations of a specific effect type.
        public func invocations<E: EffectProtocol>(of type: E.Type) -> [E] {
            _invocations.withLock {
                $0.compactMap { $0.effect as? E }
            }
        }

        /// Returns the count of invocations of a specific effect type.
        public func count<E: EffectProtocol>(of type: E.Type) -> Int {
            _invocations.withLock {
                $0.filter { $0.effect is E }.count
            }
        }
    }
}

// MARK: - Recording Handler

extension Effect.Test.Recorder {
    /// Creates a handler that records invocations to this recorder.
    ///
    /// - Parameter inner: The handler to delegate to after recording.
    /// - Returns: A handler that records and delegates.
    public func handler<E: EffectProtocol>(
        wrapping inner: Effect.Test.Handler<E>
    ) -> RecordingHandler<E> {
        RecordingHandler(recorder: self, inner: inner)
    }

    /// Creates a handler that records invocations and returns the given value.
    ///
    /// - Parameter value: The value to return for all effects.
    /// - Returns: A handler that records and returns the value.
    public func handler<E: EffectProtocol>(
        returning value: E.Value
    ) -> RecordingHandler<E> where E.Failure == Never {
        RecordingHandler(recorder: self, inner: Effect.Test.Handler(returning: value))
    }

    /// A handler that records invocations to a recorder while delegating to an inner handler.
    public struct RecordingHandler<E: EffectProtocol>: EffectHandler, Sendable {
        public typealias Handled = E

        private let recorder: Effect.Test.Recorder
        private let inner: Effect.Test.Handler<E>

        internal init(recorder: Effect.Test.Recorder, inner: Effect.Test.Handler<E>) {
            self.recorder = recorder
            self.inner = inner
        }

        public func handle(
            _ effect: E,
            continuation: consuming Effect.Continuation.One<E.Value, E.Failure>
        ) async {
            // Wrap the continuation to intercept and record the outcome
            let wrapped = continuation.onResume { [recorder] result in
                let succeeded: Bool
                switch result {
                case .success: succeeded = true
                case .failure: succeeded = false
                }
                recorder.record(effect, succeeded: succeeded)
            }

            await inner.handle(effect, continuation: wrapped)
        }
    }
}
