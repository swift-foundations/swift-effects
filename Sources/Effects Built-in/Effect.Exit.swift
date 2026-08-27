public import Effects
public import Witness

extension Effect {

    public struct Exit: Effect.`Protocol`, EffectWithHandler, Sendable {

        public let code: Int32

        public init(code: Int32) {
            self.code = code
        }
    }
}

extension Effect.Exit {
    public typealias Value = Never
    public typealias Failure = Never
    public typealias HandlerKey = Handler.Key
}

extension Effect.Exit {

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

        _ = consume continuation
        await _handle(effect.code)
    }
}

extension Effect.Exit.Handler {

    public static let live = Effect.Exit.Handler { code in
        fatalError("Exit with code \(code)")
    }
}

extension Effect.Exit.Handler {

    public struct Key: Dependency.Key {}
}

extension Effect.Exit.Handler.Key {
    public typealias Value = Effect.Exit.Handler

    public static var liveValue: Effect.Exit.Handler { .live }

    public static var testValue: Effect.Exit.Handler {
        Effect.Exit.Handler { _ in

            while !Task.isCancelled {
                await Task.yield()

                do {
                    try await Task.sleep(for: .seconds(3600))
                } catch {}
            }
            await withCheckedContinuation { (_: CheckedContinuation<Never, Never>) in }
        }
    }
}

extension Effect.Exit {

    @inlinable
    public static func perform(code: Int32) async -> Never {
        await Effect.perform(Effect.Exit(code: code))
    }
}
