import Async_Primitives
public import Clocks
public import Effects

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
        // Deliberate type erasure: this recorder records invocations across
        // heterogeneous effect types in a single collection (see class doc above).
        // swiftlint:disable no_any_protocol_existential
        /// A type-erased recorded invocation.
        public struct Invocation: Sendable {
            /// The type of effect that was performed.
            public let effectType: any Effect.`Protocol`.Type

            /// The effect that was performed, type-erased.
            public let effect: any Effect.`Protocol` & Sendable

            /// The time at which the effect was handled.
            public let timestamp: Clock.Continuous.Instant

            /// Whether the effect completed successfully.
            public let succeeded: Bool

            public init(
                effectType: any Effect.`Protocol`.Type,
                effect: any Effect.`Protocol` & Sendable,
                timestamp: Clock.Continuous.Instant,
                succeeded: Bool
            ) {
                self.effectType = effectType
                self.effect = effect
                self.timestamp = timestamp
                self.succeeded = succeeded
            }
        }
        // swiftlint:enable no_any_protocol_existential

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
        internal func record<E: Effect.`Protocol`>(_ effect: E, succeeded: Bool) where E: Sendable {
            let invocation = Invocation(
                effectType: E.self,
                effect: effect,
                timestamp: Clock.Continuous.now,
                succeeded: succeeded
            )
            _invocations.withLock { $0.append(invocation) }
        }

        /// Clears all recorded invocations.
        public func reset() {
            _invocations.withLock { $0.removeAll() }
        }

        /// Returns all invocations of a specific effect type.
        public func invocations<E: Effect.`Protocol`>(of type: E.Type) -> [E] {
            _invocations.withLock {
                $0.compactMap { $0.effect as? E }
            }
        }

        /// Returns the count of invocations of a specific effect type.
        public func count<E: Effect.`Protocol`>(of type: E.Type) -> Int {
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
    public func handler<E: Effect.`Protocol`>(
        wrapping inner: Effect.Test.Handler<E>
    ) -> RecordingHandler<E> where E: Sendable, E.Value: Copyable & Sendable {
        RecordingHandler(recorder: self, inner: inner)
    }

    /// Creates a handler that records invocations and returns the given value.
    ///
    /// - Parameter value: The value to return for all effects.
    /// - Returns: A handler that records and returns the value.
    public func handler<E: Effect.`Protocol`>(
        returning value: E.Value
    ) -> RecordingHandler<E>
    where E: Sendable, E.Value: Copyable & Sendable, E.Failure == Never {
        RecordingHandler(recorder: self, inner: Effect.Test.Handler(returning: value))
    }

    /// A handler that records invocations to a recorder while delegating to an inner handler.
    public struct RecordingHandler<E: Effect.`Protocol`>: Effect.Handler.`Protocol`, Sendable
    where E: Sendable, E.Value: Copyable & Sendable {
        public typealias Handled = E

        private let recorder: Effect.Test.Recorder
        private let inner: Effect.Test.Handler<E>

        internal init(recorder: Effect.Test.Recorder, inner: Effect.Test.Handler<E>) {
            self.recorder = recorder
            self.inner = inner
        }

        public func handle(
            _ effect: borrowing E,
            continuation: consuming Effect.Continuation.One<E.Value, E.Failure>
        ) async {
            // Copy the borrow for closure capture; E is Copyable & Sendable here.
            let recordedEffect = copy effect
            let wrapped = continuation.onResume { [recorder] result in
                let succeeded: Bool
                switch result {
                case .success: succeeded = true
                case .failure: succeeded = false
                }
                recorder.record(recordedEffect, succeeded: succeeded)
            }

            await inner.handle(effect, continuation: wrapped)
        }
    }
}
