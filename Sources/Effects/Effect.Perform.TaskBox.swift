import Effect_Primitives
import Synchronization

extension Effect.Perform {
    /// Coordinates the dispatch `Task` created inside `perform` with the
    /// enclosing `withTaskCancellationHandler`'s `onCancel`.
    ///
    /// `onCancel` may run before, during, or after the dispatch `Task` is
    /// created — `withTaskCancellationHandler` gives no ordering guarantee
    /// between the two. This box makes both orderings converge on the same
    /// outcome: the dispatch `Task` is cancelled exactly once, whichever side
    /// arrives first.
    ///
    /// ## Safety Invariant
    ///
    /// `store(_:)` and `cancel()` race to be first under a single `Mutex`.
    /// Whichever call arrives first records its intent as the terminal state;
    /// the second call reacts to that state (`store` after `cancel` cancels
    /// immediately; `cancel` after `store` cancels the recorded `Task`
    /// directly). Each transition happens exactly once under the lock, so the
    /// dispatch `Task`'s `.cancel()` is invoked at most once regardless of
    /// interleaving.
    @usableFromInline
    final class TaskBox: @unchecked Sendable {
        private let state: Mutex<State>

        @usableFromInline
        init() {
            self.state = Mutex(.pending)
        }
    }
}

extension Effect.Perform.TaskBox {
    @usableFromInline
    enum State {
        case pending
        case stored(Task<Void, Never>)
        case cancelledBeforeStore
    }
}

extension Effect.Perform.TaskBox {
    /// Records the dispatch `Task`, cancelling it immediately if `cancel()`
    /// already ran before this call.
    @usableFromInline
    func store(_ task: Task<Void, Never>) {
        let cancelImmediately = state.withLock { current -> Bool in
            switch current {
            case .pending:
                current = .stored(task)
                return false
            case .cancelledBeforeStore:
                return true
            case .stored:
                // `store` is only ever called once per box, from the single
                // `withCheckedContinuation` resumer closure in `perform`.
                return false
            }
        }
        if cancelImmediately {
            task.cancel()
        }
    }

    /// Cancels the dispatch `Task`, or — if it has not been created yet —
    /// records that cancellation arrived first, so the eventual `store(_:)`
    /// cancels on arrival.
    @usableFromInline
    func cancel() {
        let taskToCancel = state.withLock { current -> Task<Void, Never>? in
            switch current {
            case .pending:
                current = .cancelledBeforeStore
                return nil
            case .stored(let task):
                return task
            case .cancelledBeforeStore:
                return nil
            }
        }
        taskToCancel?.cancel()
    }
}
