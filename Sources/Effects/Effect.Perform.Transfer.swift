public import Effect_Primitives

extension Effect.Perform {
    /// An `@unchecked Sendable` transfer intermediary that carries a
    /// non-`Sendable` effect value into the dispatch `Task` in `perform`.
    ///
    /// A domain-local wrapper is used in preference to the ecosystem's
    /// `Reference.Sendability.Unchecked`: that type is unconditionally
    /// `~Copyable`, so it is captured *by reference* into the dispatch `Task`
    /// closure (a `~Copyable` value cannot be copied into an escaping closure),
    /// which leaves the reference accessible to the suspended caller and fails
    /// the region check. This `Copyable` wrapper is captured *by value*, which
    /// transfers cleanly. `Reference.Sendability.Unchecked`'s own guidance also
    /// recommends a domain-local `@unchecked Sendable` wrapper for types you
    /// control.
    ///
    /// ## Safety Invariant
    ///
    /// The wrapped value is read exactly once, inside the single dispatch
    /// `Task`, while the performing task is suspended on its
    /// `CheckedContinuation`. There is no concurrent access: the continuation
    /// resumes exactly once and the performing task does not touch the value
    /// after constructing the transfer. Because a handler may store the
    /// continuation and resume it after `handle` returns, the dispatch must run
    /// on a `Task`; the region checker cannot model this continuation-mediated
    /// handoff across the `withCheckedContinuation` closure boundary
    /// ([MEM-SEND-008], [MEM-SEND-011]), so the `Sendable` conformance is
    /// asserted rather than synthesized — preferred over constraining the effect
    /// `Value` to `Sendable` ([MEM-SEND-012]).
    @usableFromInline
    struct Transfer<Value>: @unchecked Sendable {
        @usableFromInline
        let value: Value

        @usableFromInline
        init(_ value: Value) {
            self.value = value
        }
    }
}
