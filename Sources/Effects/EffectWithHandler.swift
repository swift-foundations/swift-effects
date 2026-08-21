public import Dependency_Primitives
public import Effect_Primitives

public protocol EffectWithHandler: Effect.`Protocol` {

    associatedtype HandlerKey: Dependency.Key
    where HandlerKey.Value: Effect.Handler.`Protocol`, HandlerKey.Value.Handled == Self
}
