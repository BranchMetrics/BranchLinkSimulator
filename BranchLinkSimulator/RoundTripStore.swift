import BranchSDK
import Foundation

class RoundTripStore: ObservableObject {
    let FAILED = "failed to parse"

    @Published var roundTrips: [RoundTrip] = [] {
        didSet {
            saveRoundTrips()
        }
    }

    private let storageKey = "savedRoundTrips"

    init() {
        loadRoundTrips()
    }

    func addRoundTrip(with request: BranchRequest, url: String) {
        DispatchQueue.main.async {
            self.roundTrips.insert(RoundTrip(timestamp: Date(), url: url, request: request, response: nil), at: 0)
            self.trimToLimit()
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

    private func trimToLimit() {
        if roundTrips.count > 30 {
            roundTrips = Array(roundTrips.prefix(30))
        }
    }

    private func sortRoundTrips() {
        roundTrips.sort { $0.timestamp > $1.timestamp }
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

    /// Process network logs from the new Swift SessionManager
    func processSwiftNetworkLog(
        url: String,
        requestBody: [String: Any],
        responseBody: [String: Any]?,
        statusCode: Int?,
        error: Error?
    ) {
        // Convert request body to pretty JSON string
        var requestBodyString = FAILED
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            requestBodyString = jsonString
        }

        let branchRequest = BranchRequest(
            headers: "[Swift SessionManager - POST]",
            body: requestBodyString
        )

        addRoundTrip(with: branchRequest, url: url)

        // Add response if available
        if let responseBody = responseBody {
            var responseBodyString = FAILED
            if let jsonData = try? JSONSerialization.data(withJSONObject: responseBody, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                responseBodyString = jsonString
            }

            let statusCodeString = statusCode.map { String($0) } ?? FAILED
            let branchResponse = BranchResponse(statusCode: statusCodeString, body: responseBodyString)
            addResponse(branchResponse)
        } else if let error = error {
            // Add error response
            let branchResponse = BranchResponse(
                statusCode: statusCode.map { String($0) } ?? "Error",
                body: "Error: \(error.localizedDescription)"
            )
            addResponse(branchResponse)
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
