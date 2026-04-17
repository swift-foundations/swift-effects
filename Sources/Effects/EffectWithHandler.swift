public import Effect_Primitives
public import Dependency_Primitives

/// Links an effect type to its handler key for automatic lookup.
///
/// Effects conforming to this protocol can be performed using `Effect.perform(_:)`
/// which will automatically look up the handler from the current context.
public protocol EffectWithHandler: Effect.`Protocol` {
    /// The context key type that provides the handler for this effect.
    associatedtype HandlerKey: Dependency.Key
        where HandlerKey.Value: Effect.Handler.`Protocol`, HandlerKey.Value.Handled == Self
}
