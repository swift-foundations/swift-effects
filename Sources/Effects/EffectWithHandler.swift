public import Dependency
public import Effect

public protocol EffectWithHandler: Effect.`Protocol` {

    associatedtype HandlerKey: Dependency.Key
    where HandlerKey.Value: Effect.Handler.`Protocol`, HandlerKey.Value.Handled == Self
}
