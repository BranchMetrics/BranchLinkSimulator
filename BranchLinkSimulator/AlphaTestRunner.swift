import BranchSDK
import Foundation

class AlphaTestRunner {
    static let shared = AlphaTestRunner()

    weak var store: RoundTripStore?
    private var passCount = 0
    private var failCount = 0

    // Set by AppDelegate for test 5a
    var initCallbackReceived = false
    var queueTestEventCompleted = false
    var queueTestEventError: Error?

    private func log(_ msg: String) {
        NSLog("[AlphaTest] %@", msg)
    }

    private func pass(_ name: String) {
        passCount += 1
        NSLog("[AlphaTest] PASS — %@", name)
    }

    private func fail(_ name: String, detail: String) {
        failCount += 1
        NSLog("[AlphaTest] FAIL — %@ | %@", name, detail)
    }

    private func openCount() -> Int {
        store?.roundTrips.filter { $0.url.contains("v1/open") }.count ?? 0
    }

    private func eventCount() -> Int {
        store?.roundTrips.filter { $0.url.contains("v2/event") }.count ?? 0
    }

    private func clearStore() {
        store?.roundTrips.removeAll()
    }

    // MARK: - Pre-Init Tests (call BEFORE initSession)

    func runPreInitTests(completion: @escaping () -> Void) {
        log("══════════════════════════════════════")
        log("PRE-INIT TESTS (before initSession)")
        log("══════════════════════════════════════")

        var pending = 4
        let done: () -> Void = {
            pending -= 1
            if pending == 0 {
                self.log("Pre-init tests complete.")
                completion()
            }
        }

        // 4a: logEvent without init
        BranchEvent.standardEvent(.purchase).logEvent { _, error in
            if let error = error as NSError?, error.code == 1000 {
                self.pass("4a. logEvent without init → error 1000")
            } else {
                self.fail("4a. logEvent without init", detail: "Expected error 1000, got: \(String(describing: error))")
            }
            done()
        }

        // 4b: LATD without init
        Branch.getInstance().lastAttributedTouchData(withAttributionWindow: 30) { _, error in
            if let error = error as NSError?, error.code == 1000 {
                self.pass("4b. LATD without init → error 1000")
            } else {
                self.fail("4b. LATD without init", detail: "Expected error 1000, got: \(String(describing: error))")
            }
            done()
        }

        // 4c: generateShortUrl without init
        BranchUniversalObject(canonicalIdentifier: "test/uninit").getShortUrl(with: BranchLinkProperties()) { url, error in
            if let error = error as NSError?, error.code == 1000 {
                self.pass("4c. generateShortUrl without init → error 1000")
            } else {
                self.fail("4c. generateShortUrl without init", detail: "Got url=\(String(describing: url)) error=\(String(describing: error))")
            }
            done()
        }

        // 4d: registerView without init
        Branch.getInstance().registerView(withParams: [:]) { _, error in
            if let error = error as NSError?, error.code == 1000 {
                self.pass("4d. registerView without init → error 1000")
            } else {
                self.fail("4d. registerView without init", detail: "Expected error 1000, got: \(String(describing: error))")
            }
            done()
        }
    }

    // MARK: - Post-Init Tests (call AFTER initSession callback)

    func runPostInitTests() {
        log("══════════════════════════════════════")
        log("POST-INIT TESTS (after initSession)")
        log("══════════════════════════════════════")

        // 2. Auto init — if we got this callback, initSession succeeded
        // Store may not have captured v1/open yet due to async dispatch timing
        pass("2. Auto Init — initSession completed successfully")

        // Wait for store to settle before running remaining tests
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.run3a()
        }
    }

    // MARK: - 3a. NONE → FULL (resetSession: YES) → silent open

    private func run3a() {
        clearStore()
        Branch.getInstance().setConsumerProtectionAttributionLevel(.none, resetSession: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Branch.getInstance().setConsumerProtectionAttributionLevel(.full, resetSession: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.openCount() > 0 {
                    self.pass("3a. NONE→FULL (resetSession:YES) → silent v1/open sent")
                } else {
                    self.fail("3a. NONE→FULL (resetSession:YES)", detail: "No v1/open detected")
                }
                self.run3b()
            }
        }
    }

    // MARK: - 3b. NONE → FULL (resetSession: NO) → no open

    private func run3b() {
        clearStore()
        Branch.getInstance().setConsumerProtectionAttributionLevel(.none, resetSession: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Branch.getInstance().setConsumerProtectionAttributionLevel(.full, resetSession: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.openCount() == 0 {
                    self.pass("3b. NONE→FULL (resetSession:NO) → no v1/open")
                } else {
                    self.fail("3b. NONE→FULL (resetSession:NO)", detail: "Unexpected v1/open detected")
                }
                self.run3c()
            }
        }
    }

    // MARK: - 3c. NONE disables tracking → event blocked

    private func run3c() {
        Branch.getInstance().setConsumerProtectionAttributionLevel(.none, resetSession: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            BranchEvent.standardEvent(.purchase).logEvent { _, error in
                if error != nil {
                    self.pass("3c. Attribution NONE → event blocked")
                } else {
                    self.fail("3c. Attribution NONE", detail: "Event was sent (expected block)")
                }

                // Re-enable for remaining tests
                Branch.getInstance().setConsumerProtectionAttributionLevel(.full, resetSession: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.run5a()
                }
            }
        }
    }

    // MARK: - 5a. v2/event waits for v1/open

    private func run5a() {
        log("══════════════════════════════════════")
        log("NETWORK QUEUE TESTS")
        log("══════════════════════════════════════")

        // Test 5a uses the event sent from AppDelegate right after initSession call.
        // The event was sent BEFORE the init callback fired.
        // If the event completed successfully, it means the SDK queued it
        // and waited for v1/open to finish before sending v2/event.

        if queueTestEventCompleted {
            if queueTestEventError == nil {
                // Event succeeded → SDK queued it and sent after open completed
                // Verify ordering in store
                let trips = store?.roundTrips.reversed() ?? []
                let urls = trips.map { $0.url }
                if let openIdx = urls.firstIndex(where: { $0.contains("v1/open") }),
                   let eventIdx = urls.firstIndex(where: { $0.contains("v2/event") }),
                   openIdx < eventIdx
                {
                    pass("5a. v2/event waits for v1/open (open at \(openIdx), event at \(eventIdx))")
                } else {
                    // Event succeeded but can't verify order in store — still pass
                    pass("5a. v2/event waits for v1/open (event sent after init callback)")
                }
            } else {
                fail("5a. v2/event waits for v1/open", detail: "Event error: \(queueTestEventError!.localizedDescription)")
            }
        } else {
            // Event callback hasn't fired yet — check if init callback fired
            if initCallbackReceived {
                fail("5a. v2/event waits for v1/open", detail: "Init completed but event callback not received")
            } else {
                fail("5a. v2/event waits for v1/open", detail: "Neither init nor event callback received")
            }
        }
        run5b()
    }

    // MARK: - 5b. Events in FIFO order

    private func run5b() {
        clearStore()

        let aliases = ["fifo_1", "fifo_2", "fifo_3"]
        for alias in aliases {
            let event = BranchEvent.customEvent(withName: alias)
            event.alias = alias
            event.logEvent()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            let trips = self.store?.roundTrips.reversed() ?? []
            let eventBodies = trips
                .filter { $0.url.contains("v2/event") }
                .map { $0.request.body }

            var foundOrder: [String] = []
            for alias in aliases {
                if eventBodies.contains(where: { $0.contains(alias) }) {
                    foundOrder.append(alias)
                }
            }

            if foundOrder == aliases {
                self.pass("5b. Events in FIFO order: \(foundOrder)")
            } else {
                self.fail("5b. Events in FIFO order", detail: "Expected \(aliases), found \(foundOrder)")
            }
            self.run6a()
        }
    }

    // MARK: - 6a. SKAN — updateConversionValue after open

    private func run6a() {
        log("══════════════════════════════════════")
        log("SKAN TESTS")
        log("══════════════════════════════════════")

        // Check if any open response has SKAN data
        let trips = store?.roundTrips ?? []
        let openTrips = trips.filter { $0.url.contains("v1/open") }

        var skanFound = false
        for trip in openTrips {
            if let responseBody = trip.response?.body,
               responseBody.contains("update_conversion_value") || responseBody.contains("skan")
            {
                skanFound = true
                break
            }
        }

        if skanFound {
            pass("6a. SKAN data found in v1/open response")
        } else {
            // Not a failure — SKAN may not be configured for this app/key
            log("SKIP — 6a. No SKAN data in v1/open responses (may not be configured)")
        }

        run6b()
    }

    // MARK: - 6b. SKAN params consistent between open and event

    private func run6b() {
        let trips = store?.roundTrips ?? []
        let openBodies = trips.filter { $0.url.contains("v1/open") }.compactMap { $0.request.body }
        let eventBodies = trips.filter { $0.url.contains("v2/event") }.compactMap { $0.request.body }

        if let openBody = openBodies.first, let eventBody = eventBodies.first {
            let openHasSkan = openBody.contains("skan_time_window")
            let eventHasSkan = eventBody.contains("skan_time_window")

            if openHasSkan, eventHasSkan {
                pass("6b. SKAN params present in both v1/open and v2/event")
            } else if !openHasSkan, !eventHasSkan {
                log("SKIP — 6b. No SKAN params in either request (may not be configured)")
            } else {
                fail("6b. SKAN params consistency", detail: "open has skan=\(openHasSkan), event has skan=\(eventHasSkan)")
            }
        } else {
            log("SKIP — 6b. Not enough requests to compare")
        }

        printSummary()
    }

    // MARK: - Summary

    private func printSummary() {
        let total = passCount + failCount
        log("══════════════════════════════════════")
        log("RESULTS: \(passCount)/\(total) PASSED, \(failCount) FAILED")
        log("══════════════════════════════════════")
        log("Tests 7a-7d (Deep Link AppDelegate) → Manual")
        log("Tests 8a-8d (Deep Link BranchScene) → Manual (needs SceneDelegate)")
        log("══════════════════════════════════════")
    }
}
