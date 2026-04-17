public import Effects

extension Effect.Test {
    /// A configurable handler for testing effects.
    ///
    /// Use this to create handlers that return predetermined values or errors
    /// for testing purposes.
    ///
    /// ```swift
    /// let handler = Effect.Test.Handler<MyEffect> { effect in
    ///     .success(expectedValue)
    /// }
    /// ```
    public struct Handler<E: Effect.`Protocol`>: Effect.Handler.`Protocol`, Sendable
    where E: Sendable, E.Value: Copyable {
        public typealias Handled = E

        @usableFromInline
        internal let _handle: @Sendable (E) async -> Result<E.Value, E.Failure>

        /// Creates a handler with a custom handling closure.
        ///
        /// - Parameter handle: A closure that receives the effect and returns a result.
        public init(_ handle: @escaping @Sendable (E) async -> Result<E.Value, E.Failure>) {
            self._handle = handle
        }

        public func handle(
            _ effect: borrowing E,
            continuation: consuming Effect.Continuation.One<E.Value, E.Failure>
        ) async {
            let result = await _handle(effect)
            await continuation.resume(with: result)
        }
    }
}

// MARK: - Convenience Initializers

extension Effect.Test.Handler where E.Failure == Never {
    /// Creates a handler that always returns the given value.
    ///
    /// - Parameter value: The value to return for all effects.
    public init(returning value: E.Value) {
        self._handle = { _ in .success(value) }
    }

    /// Creates a handler that returns values from a closure.
    ///
    /// - Parameter value: A closure that produces the value to return.
    public init(returning value: @escaping @Sendable (E) async -> E.Value) {
        self._handle = { effect in .success(await value(effect)) }
    }
}

extension Effect.Test.Handler {
    /// Creates a handler that always throws the given error.
    ///
    /// - Parameter error: The error to throw for all effects.
    public init(throwing error: E.Failure) {
        self._handle = { _ in .failure(error) }
    }
}

// MARK: - Void Value Convenience

extension Effect.Test.Handler where E.Value == Void, E.Failure == Never {
    /// Creates a handler that always succeeds with no value.
    public init() {
        self._handle = { _ in .success(()) }
    }
}
