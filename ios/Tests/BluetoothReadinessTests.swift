import XCTest
@testable import BluetoothReadinessCore

final class BluetoothReadinessTests: XCTestCase {
    private final class Adapter: ReadinessAdapter {
        var callback: ((ReadinessState) -> Void)?
        var stops = 0
        var initial: ReadinessState?
        func start(_ changed: @escaping (ReadinessState) -> Void) {
            callback = changed
            if let initial = initial { changed(initial) }
        }
        // Deliberately retain the callback to simulate late platform delivery.
        func stop() { stops += 1 }
    }
    private final class Clock {
        var callbacks: [() -> Void] = []
        var deadlines: [Int] = []
        var cancelled = 0
        func schedule(_ ms: Int, _ callback: @escaping () -> Void) -> () -> Void {
            callbacks.append(callback); deadlines.append(ms)
            return { self.cancelled += 1 }
        }
    }

    func testTerminalStatesResolveOnceAndCleanUp() {
        let states: [(ReadinessState, String)] = [(.on, "on"), (.off, "off"),
            (.unauthorized, "unauthorized"), (.unavailable, "unavailable"), (.unknown, "unknown")]
        for (state, value) in states {
            let adapter = Adapter(), clock = Clock()
            let session = BluetoothReadinessSession(makeAdapter: { adapter }, schedule: clock.schedule)
            var results: [ReadinessOutcome] = []
            session.ensureReady(id: 1, timeoutMs: 70) { results.append($0) }
            adapter.callback?(state)
            adapter.callback?(.on)
            clock.callbacks[0]()
            session.cancel()
            XCTAssertEqual(results, [.state(value)])
            XCTAssertEqual(adapter.stops, 1)
            XCTAssertEqual(clock.cancelled, 1)
        }
    }

    func testWaitingStatesKeepOriginalDeadline() {
        let adapter = Adapter(), clock = Clock()
        let session = BluetoothReadinessSession(makeAdapter: { adapter }, schedule: clock.schedule)
        var results: [ReadinessOutcome] = []
        session.ensureReady(id: 1, timeoutMs: 20) { results.append($0) }
        adapter.callback?(.waiting)
        adapter.callback?(.waiting)
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(clock.deadlines, [20])
        clock.callbacks[0]()
        adapter.callback?(.on)
        XCTAssertEqual(results, [.timedOut])
        XCTAssertEqual(adapter.stops, 1)
    }

    func testTargetedAndGlobalCancellation() {
        let adapter = Adapter(), clock = Clock()
        let session = BluetoothReadinessSession(makeAdapter: { adapter }, schedule: clock.schedule)
        var results: [ReadinessOutcome] = []
        session.ensureReady(id: 4294967297, timeoutMs: 20) { results.append($0) }
        session.cancel(id: 1)
        XCTAssertTrue(results.isEmpty)
        session.cancel(id: 4294967297)
        adapter.callback?(.on)
        clock.callbacks[0]()
        XCTAssertEqual(results, [.cancelled])
        session.ensureReady(id: 2, timeoutMs: 20) { results.append($0) }
        session.cancel()
        session.cancel()
        XCTAssertEqual(results, [.cancelled, .cancelled])
        XCTAssertEqual(adapter.stops, 2)
    }

    func testSupersessionDropsStaleStateAndTimerEvenWithReusedID() {
        let first = Adapter(), next = Adapter(), clock = Clock()
        var adapters = [first, next]
        let session = BluetoothReadinessSession(makeAdapter: { adapters.removeFirst() }, schedule: clock.schedule)
        var oldResults: [ReadinessOutcome] = [], newResults: [ReadinessOutcome] = []
        session.ensureReady(id: 1, timeoutMs: 20) { oldResults.append($0) }
        session.ensureReady(id: 1, timeoutMs: 30) { newResults.append($0) }
        XCTAssertEqual(oldResults, [.cancelled])
        first.callback?(.on)
        clock.callbacks[0]()
        XCTAssertTrue(newResults.isEmpty)
        next.callback?(.off)
        clock.callbacks[1]()
        XCTAssertEqual(newResults, [.state("off")])
        XCTAssertEqual(first.stops, 1)
        XCTAssertEqual(next.stops, 1)
    }

    func testSynchronousAdapterCompletion() {
        let adapter = Adapter(), clock = Clock()
        adapter.initial = .on
        let session = BluetoothReadinessSession(makeAdapter: { adapter }, schedule: clock.schedule)
        var results: [ReadinessOutcome] = []
        session.ensureReady(id: 1, timeoutMs: 20) { results.append($0) }
        clock.callbacks[0]()
        XCTAssertEqual(results, [.state("on")])
        XCTAssertEqual(adapter.stops, 1)
        XCTAssertEqual(clock.cancelled, 1)
    }

    func testCompletionCanStartSuccessorWithoutOldCleanupCancellingIt() {
        let first = Adapter(), next = Adapter(), clock = Clock()
        var adapters = [first, next]
        let session = BluetoothReadinessSession(makeAdapter: { adapters.removeFirst() }, schedule: clock.schedule)
        var results: [ReadinessOutcome] = []
        session.ensureReady(id: 1, timeoutMs: 20) { _ in
            session.ensureReady(id: 2, timeoutMs: 30) { results.append($0) }
        }
        first.callback?(.on)
        clock.callbacks[0]()
        XCTAssertTrue(results.isEmpty)
        next.callback?(.on)
        XCTAssertEqual(results, [.state("on")])
    }

    func testInvalidCancellationDoesNotDispatchToSession() {
        let invalid: [Any?] = [nil, [], [:], ["requestId": "bad"],
            ["requestId": true], ["requestId": 1.5], ["requestId": 0], ["requestId": -1]]
        let adapter = Adapter(), clock = Clock()
        let session = BluetoothReadinessSession(makeAdapter: { adapter }, schedule: clock.schedule)
        var results: [ReadinessOutcome] = []
        session.ensureReady(id: 1, timeoutMs: 20) { results.append($0) }
        for args in invalid {
            let request = BluetoothChannelRequest.parse("cancelBluetoothReadiness", args)
            XCTAssertEqual(request, .invalid)
            if case .cancelReadiness(let id) = request { session.cancel(id: id) }
            XCTAssertTrue(results.isEmpty)
        }
        adapter.callback?(.on)
        XCTAssertEqual(results, [.state("on")])
    }

    func testValidCancellationRequiresExplicitNullOrPositiveInteger() {
        XCTAssertEqual(BluetoothChannelRequest.parse("cancelBluetoothReadiness", ["requestId": NSNull()]), .cancelReadiness(id: nil))
        XCTAssertEqual(BluetoothChannelRequest.parse("cancelBluetoothReadiness", ["requestId": 4294967297]), .cancelReadiness(id: 4294967297))
    }

    func testReadinessArgumentValidation() {
        let valid: [String: Any] = ["requestId": 1, "timeoutMs": 1000, "requestEnable": true]
        XCTAssertEqual(BluetoothChannelRequest.parse("ensureBluetoothReady", valid), .ensureReady(id: 1, timeoutMs: 1000))
        for (key, values) in ["requestId": [0, -1, true, "1", 1.5] as [Any],
                              "timeoutMs": [0, 120001, true, "1", 1.5],
                              "requestEnable": [0, 1, "true", NSNull()]] {
            for value in values {
                var args = valid; args[key] = value
                XCTAssertEqual(BluetoothChannelRequest.parse("ensureBluetoothReady", args), .invalid, "\(key): \(value)")
            }
        }
    }

    func testUnknownAndReadOnlyMethodsAreClassifiedBeforeArguments() {
        XCTAssertEqual(BluetoothChannelRequest.parse("futureMethod", nil), .unsupported)
        XCTAssertEqual(BluetoothChannelRequest.parse("futureMethod", [:]), .unsupported)
        XCTAssertEqual(BluetoothChannelRequest.parse("getPlatformVersion", nil), .platformVersion)
        XCTAssertEqual(BluetoothChannelRequest.parse("cancelOperations", nil), .cancelOperations)
    }

    func testProvisioningArgumentsValidatedBeforeSupersession() {
        for method in ["scanBleDevices", "scanWifiNetworks", "provisionWifi", "fetchCustomData"] {
            XCTAssertEqual(BluetoothChannelRequest.parse(method, [:]), .invalid)
        }
        XCTAssertEqual(BluetoothChannelRequest.parse("scanBleDevices", ["prefix": "PROV_"]), .provisioning)
        var args: [String: Any] = ["deviceName": "PROV_1", "proofOfPossession": "pop", "security": 2]
        XCTAssertEqual(BluetoothChannelRequest.parse("scanWifiNetworks", args), .invalid)
        args["username"] = "user"
        XCTAssertEqual(BluetoothChannelRequest.parse("scanWifiNetworks", args), .provisioning)
        args["connectTimeoutMs"] = true
        XCTAssertEqual(BluetoothChannelRequest.parse("scanWifiNetworks", args), .invalid)
    }
}
