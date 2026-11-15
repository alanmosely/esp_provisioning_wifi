import Foundation

enum ReadinessState { case waiting, on, off, unauthorized, unavailable, unknown }

protocol ReadinessAdapter: AnyObject {
    func start(_ changed: @escaping (ReadinessState) -> Void)
    func stop()
}

enum ReadinessOutcome: Equatable {
    case state(String)
    case cancelled
    case timedOut
}

/// Main-queue confined lifecycle, shared by Core Bluetooth and deterministic tests.
final class BluetoothReadinessSession {
    typealias Scheduler = (Int, @escaping () -> Void) -> () -> Void
    private final class Attempt {
        let id: Int
        let adapter: ReadinessAdapter
        let result: (ReadinessOutcome) -> Void
        var cancelTimer: (() -> Void)?
        init(_ id: Int, _ adapter: ReadinessAdapter, _ result: @escaping (ReadinessOutcome) -> Void) {
            self.id = id; self.adapter = adapter; self.result = result
        }
    }
    private let makeAdapter: () -> ReadinessAdapter
    private let schedule: Scheduler
    private var active: Attempt?

    init(makeAdapter: @escaping () -> ReadinessAdapter, schedule: @escaping Scheduler = { ms, action in
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms), execute: item)
        return { item.cancel() }
    }) {
        self.makeAdapter = makeAdapter; self.schedule = schedule
    }

    func ensureReady(id: Int, timeoutMs: Int, result: @escaping (ReadinessOutcome) -> Void) {
        cancel()
        let attempt = Attempt(id, makeAdapter(), result)
        active = attempt
        attempt.cancelTimer = schedule(timeoutMs) { [weak self, weak attempt] in
            guard let attempt = attempt else { return }
            self?.finish(attempt, .timedOut)
        }
        attempt.adapter.start { [weak self, weak attempt] state in
            guard let attempt = attempt else { return }
            switch state {
            case .waiting: break
            case .on: self?.finish(attempt, .state("on"))
            case .off: self?.finish(attempt, .state("off"))
            case .unauthorized: self?.finish(attempt, .state("unauthorized"))
            case .unavailable: self?.finish(attempt, .state("unavailable"))
            case .unknown: self?.finish(attempt, .state("unknown"))
            }
        }
    }

    func cancel(id: Int? = nil) {
        guard let attempt = active, id == nil || id == attempt.id else { return }
        finish(attempt, .cancelled)
    }

    private func finish(_ attempt: Attempt, _ outcome: ReadinessOutcome) {
        guard active === attempt else { return }
        active = nil
        attempt.cancelTimer?()
        attempt.adapter.stop()
        attempt.result(outcome)
    }
}
