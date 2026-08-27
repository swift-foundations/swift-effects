public import Effect

extension Effect.Perform {

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
