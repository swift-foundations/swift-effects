public import Effects
public import Witness_Primitives

extension Effect {

    public struct Yield: Effect.`Protocol`, EffectWithHandler, Sendable {
        public init() {}
    }
}

extension Effect.Yield {
    public typealias Value = Void
    public typealias Failure = Never
    public typealias HandlerKey = Handler.Key
}

extension Effect.Yield {

    public struct Handler: Effect.Handler.`Protocol`, Sendable, Witness.`Protocol` {
        private let _handle: @Sendable () async -> Void

        public init(_ handle: @escaping @Sendable () async -> Void) {
            self._handle = handle
        }
    }
}

extension Effect.Yield.Handler {
    public typealias Handled = Effect.Yield

    public func handle(
        _ effect: borrowing Effect.Yield,
        continuation: consuming Effect.Continuation.One<Void, Never>
    ) async {
        await _handle()
        await continuation.resume()
    }
}

extension Effect.Yield.Handler {

    public static let live = Effect.Yield.Handler {
        await Task.yield()
    }
}

extension Effect.Yield.Handler {

    public struct Key: Dependency.Key {}
}

extension Effect.Yield.Handler.Key {
    public typealias Value = Effect.Yield.Handler

    public static var liveValue: Effect.Yield.Handler { .live }
    public static var testValue: Effect.Yield.Handler { .live }
}

extension Effect.Yield {

    @inlinable
    public static func perform() async {
        await Effect.perform(Effect.Yield())
    }
}
