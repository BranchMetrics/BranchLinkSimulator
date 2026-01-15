import BranchSDK
import Foundation

class RoundTripStore: ObservableObject {
    let FAILED = "failed to parse"

    @Published var roundTrips: [RoundTrip] = [] {
        didSet {
            saveRoundTrips()
        }
    }

    @Published var logEntries: [LogEntry] = []

    private let storageKey = "savedRoundTrips"

    init() {
        loadRoundTrips()
    }

    // MARK: - Log Entries

    func addLogEntry(_ message: String) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message)
            self.logEntries.insert(entry, at: 0)
            // Keep only last 50 log entries
            if self.logEntries.count > 50 {
                self.logEntries = Array(self.logEntries.prefix(50))
            }
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }

    // MARK: - Round Trips

    func addRoundTrip(with request: BranchRequest, url: String) {
        DispatchQueue.main.async {
            let isOpenRequest = self.isOpenRequest(url: url, body: request.body)
            let roundTrip = RoundTrip(
                timestamp: Date(),
                url: url,
                request: request,
                response: nil,
                isOpenRequest: isOpenRequest
            )
            self.roundTrips.insert(roundTrip, at: 0)
            self.trimToLimit()

            // Log OPEN requests for visibility
            if isOpenRequest {
                self.addLogEntry("[OPEN] Request sent to: \(url)")
            }
        }
    }

    func addResponse(_ response: BranchResponse) {
        DispatchQueue.main.async {
            if let index = self.roundTrips.indices.first {
                var currentTrip = self.roundTrips[index]
                currentTrip.response = response
                self.roundTrips[index] = currentTrip
                self.trimToLimit()
            }
        }
    }

    func clearRoundTrips() {
        DispatchQueue.main.async {
            self.roundTrips.removeAll()
            UserDefaults.standard.removeObject(forKey: self.storageKey)
        }
    }

    // MARK: - OPEN Request Detection

    private func isOpenRequest(url: String, body: String) -> Bool {
        // Check URL patterns for OPEN requests
        if url.contains("/v1/open") || url.contains("/v2/event") {
            // For v2/event, check if it's an "open" event
            if url.contains("/v2/event") {
                return body.contains("\"name\":\"open\"") || body.contains("\"name\": \"open\"")
            }
            return true
        }
        return false
    }

    // MARK: - Statistics

    var openRequestCount: Int {
        roundTrips.filter { $0.isOpenRequest }.count
    }

    var recentOpenRequests: [RoundTrip] {
        roundTrips.filter { $0.isOpenRequest }
    }

    // MARK: - Private

    private func trimToLimit() {
        if roundTrips.count > 30 {
            roundTrips = Array(roundTrips.prefix(30))
        }
    }

    private func saveRoundTrips() {
        do {
            let data = try JSONEncoder().encode(roundTrips)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save round trips: \(error)")
        }
    }

    private func loadRoundTrips() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let savedRoundTrips = try JSONDecoder().decode([RoundTrip].self, from: data)
            roundTrips = savedRoundTrips
        } catch {
            print("Failed to load round trips: \(error)")
        }
    }

    func processLog(_ request: NSMutableURLRequest?, _ response: BNCServerResponse?) {
        if let req = request {
            let branchReq = process(request: req)
            addRoundTrip(with: branchReq, url: req.url?.absoluteString ?? FAILED)
        }
        if let resp = response {
            let branchResp = process(response: resp)
            addResponse(branchResp)
        }
    }

    func process(request req: NSMutableURLRequest) -> BranchRequest {
        let body = req.httpBody.flatMap { String(data: $0, encoding: .utf8) }

        return BranchRequest(
            headers: req.allHTTPHeaderFields?.description ?? FAILED,
            body: body ?? FAILED
        )
    }

    func process(response resp: BNCServerResponse) -> BranchResponse {
        let statusCode = String(resp.statusCode.intValue)

        var body = FAILED
        if let dictionary = resp.data as? NSDictionary {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
                body = String(data: jsonData, encoding: .utf8) ?? FAILED
            } catch {
                print("Failed to serialize dictionary: \(error)")
            }
        }
        return BranchResponse(statusCode: statusCode, body: body)
    }
}

// MARK: - Log Entry Model

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
