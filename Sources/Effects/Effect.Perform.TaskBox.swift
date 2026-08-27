import Effect
import Synchronization

extension Effect.Perform {

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

                return false
            }
        }
        if cancelImmediately {
            task.cancel()
        }
    }

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
