import Async
public import Clocks
public import Effects

extension Effect.Test {

    public final class Recorder: Sendable {
        private let _invocations: Async.Mutex<[Invocation]> = Async.Mutex([])

        public init() {}
    }
}

extension Effect.Test.Recorder {

    public struct Invocation: Sendable {

        public let effectType: any Effect.`Protocol`.Type

        public let effect: any Effect.`Protocol` & Sendable

        public let timestamp: Clock.Continuous.Instant

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

}

extension Effect.Test.Recorder {

    public var invocations: [Invocation] {
        _invocations.withLock { $0 }
    }

    public var count: Int {
        _invocations.withLock { $0.count }
    }

    internal func record<E: Effect.`Protocol`>(_ effect: E, succeeded: Bool) where E: Sendable {
        let invocation = Invocation(
            effectType: E.self,
            effect: effect,
            timestamp: Clock.Continuous.now,
            succeeded: succeeded
        )
        _invocations.withLock { $0.append(invocation) }
    }

    public func reset() {
        _invocations.withLock { $0.removeAll() }
    }

    public func invocations<E: Effect.`Protocol`>(of type: E.Type) -> [E] {
        _invocations.withLock {
            $0.compactMap { $0.effect as? E }
        }
    }

    public func count<E: Effect.`Protocol`>(of type: E.Type) -> Int {
        _invocations.withLock {
            $0.filter { $0.effect is E }.count
        }
    }
}

extension Effect.Test.Recorder {

    public func handler<E: Effect.`Protocol`>(
        wrapping inner: Effect.Test.Handler<E>
    ) -> RecordingHandler<E> where E: Sendable, E.Value: Copyable & Sendable {
        RecordingHandler(recorder: self, inner: inner)
    }

    public func handler<E: Effect.`Protocol`>(
        returning value: E.Value
    ) -> RecordingHandler<E>
    where E: Sendable, E.Value: Copyable & Sendable, E.Failure == Never {
        RecordingHandler(recorder: self, inner: Effect.Test.Handler(returning: value))
    }

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
