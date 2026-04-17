public import Effects
import Async_Primitives
public import Clocks

extension Effect.Test {
    /// A spy handler that records all invocations while delegating to an inner handler.
    ///
    /// Use this to verify that effects are performed with the expected arguments
    /// and to inspect the outcomes.
    ///
    /// ```swift
    /// let spy = Effect.Test.Spy(returning: expectedValue)
    /// // ... run code that performs effects ...
    /// #expect(spy.callCount == 1)
    /// #expect(spy.invocations.first?.effect.someProperty == expectedProperty)
    /// ```
    public final class Spy<E: Effect.`Protocol`>: Sendable
    where E: Sendable, E.Value: Copyable {
        /// A recorded invocation of an effect.
        public struct Invocation: Sendable {
            /// The effect that was performed.
            public let effect: E

            /// The time at which the effect was handled.
            public let timestamp: Clock.Continuous.Instant

            /// The outcome of handling the effect.
            public let outcome: Effect.Outcome<E.Value, E.Failure>

            public init(
                effect: E,
                timestamp: Clock.Continuous.Instant,
                outcome: Effect.Outcome<E.Value, E.Failure>
            ) {
                self.effect = effect
                self.timestamp = timestamp
                self.outcome = outcome
            }
        }

        private let _invocations: Async.Mutex<[Invocation]> = Async.Mutex([])
        private let inner: Effect.Test.Handler<E>

        /// All recorded invocations.
        public var invocations: [Invocation] {
            _invocations.withLock { $0 }
        }

        /// The number of times the handler was invoked.
        public var callCount: Int {
            _invocations.withLock { $0.count }
        }

        /// The most recent invocation, if any.
        public var lastInvocation: Invocation? {
            _invocations.withLock { $0.last }
        }

        /// The first invocation, if any.
        public var firstInvocation: Invocation? {
            _invocations.withLock { $0.first }
        }

        /// Creates a spy wrapping a custom handler.
        ///
        /// - Parameter inner: The handler to delegate to after recording.
        public init(wrapping inner: Effect.Test.Handler<E>) {
            self.inner = inner
        }

        /// Creates a spy with a custom handling closure.
        ///
        /// - Parameter handle: A closure that receives the effect and returns a result.
        public init(_ handle: @escaping @Sendable (E) async -> Swift.Result<E.Value, E.Failure>) {
            self.inner = Effect.Test.Handler(handle)
        }

        private func record(effect: E, outcome: Effect.Outcome<E.Value, E.Failure>) {
            let invocation = Invocation(
                effect: effect,
                timestamp: Clock.Continuous.now,
                outcome: outcome
            )
            _invocations.withLock { $0.append(invocation) }
        }

        /// Clears all recorded invocations.
        public func reset() {
            _invocations.withLock { $0.removeAll() }
        }
    }
}

// MARK: - Effect.Handler.Protocol Conformance

extension Effect.Test.Spy: Effect.Handler.`Protocol` {
    public typealias Handled = E

    public func handle(
        _ effect: borrowing E,
        continuation: consuming Effect.Continuation.One<E.Value, E.Failure>
    ) async {
        // Copy the borrow for closure capture; E is Copyable & Sendable here.
        let recordedEffect = copy effect
        let wrapped = continuation.onResume { [weak self] result in
            let outcome = Effect.Outcome(result)
            self?.record(effect: recordedEffect, outcome: outcome)
        }

        await inner.handle(effect, continuation: wrapped)
    }
}

// MARK: - Convenience Initializers

extension Effect.Test.Spy where E.Failure == Never {
    /// Creates a spy that always returns the given value.
    ///
    /// - Parameter value: The value to return for all effects.
    public convenience init(returning value: E.Value) {
        self.init(wrapping: Effect.Test.Handler(returning: value))
    }
}

extension Effect.Test.Spy {
    /// Creates a spy that always throws the given error.
    ///
    /// - Parameter error: The error to throw for all effects.
    public convenience init(throwing error: E.Failure) {
        self.init(wrapping: Effect.Test.Handler(throwing: error))
    }
}

extension Effect.Test.Spy where E.Value == Void, E.Failure == Never {
    /// Creates a spy that always succeeds with no value.
    public convenience init() {
        self.init(wrapping: Effect.Test.Handler())
    }
}
