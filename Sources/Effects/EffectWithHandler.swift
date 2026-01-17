public import Effect_Primitives

/// Links an effect type to its handler key for automatic lookup.
///
/// Effects conforming to this protocol can be performed using `Effect.perform(_:)`
/// which will automatically look up the handler from the current context.
public protocol EffectWithHandler: EffectProtocol {
    /// The context key type that provides the handler for this effect.
    associatedtype HandlerKey: EffectContextKey
        where HandlerKey.Value: EffectHandler, HandlerKey.Value.Handled == Self
}
