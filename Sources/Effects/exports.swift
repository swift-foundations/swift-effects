@_exported public import Effect_Primitives
@_exported public import Dependency_Primitives

// MARK: - Convenience Type Aliases

/// Alias for `__EffectProtocol` to provide a cleaner API surface.
///
/// This typealias exists because Swift doesn't allow accessing `Effect.Protocol`
/// directly due to `Protocol` being a keyword. Use this alias when defining
/// effect types in client code.
public typealias EffectProtocol = __EffectProtocol

/// Alias for `__EffectHandler` to provide a cleaner API surface.
public typealias EffectHandler = __EffectHandler

/// Alias for `Dependency.Key` to provide effect-specific terminology.
///
/// Use this when defining context keys for effect handlers.
public typealias EffectContextKey = Dependency.Key
