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
    
    func processLog(_ log: String) {
        print("\(log)")
        if log.contains("[BNCServerInterface preparePostRequest")
            || log.contains("[BNCServerInterface postRequest") {
            let request = parseRequestLog(log)
            addRoundTrip(with: request, url: parseUrl(log) ?? FAILED)
        } else if log.contains("[BNCServerInterface processServerResponse")
                    || log.contains ("[BNCServerInterface genericHTTPRequest:retryNumber:callback:retryHandler:] <NSHTTPURLResponse: ") {
            let response = parseResponseLog(log)
            addResponse(response)
        } else {
            print(log)
        }
    }

    func parseUrl(_ log: String) -> String? {
        if let urlRange = log.range(of: "(?<=URL: ).*?(?= \\})", options: .regularExpression) {
            return String(log[urlRange])
        }
        return nil
    }

    func parseHeaders(_ log: String) -> String? {
        if let headersStart = log.range(of: "Headers {")?.upperBound,
           let headersEnd = log.range(of: "}\nBody {")?.lowerBound {
            return String("{\(log[headersStart..<headersEnd])").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    func parseBody(_ log: String) -> String? {
        if let bodyStart = log.range(of: "Body {")?.upperBound {
            return String("{\(log[bodyStart...])").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }


    func parseRequestLog(_ log: String) -> BranchRequest {
        return BranchRequest(
            headers: parseHeaders(log) ?? FAILED,
            body: parseBody(log) ?? FAILED
        )
    }


    func parseResponseLog(_ log: String) -> BranchResponse {
        let statusCode = log.range(of: "(?<=Status Code: )\\d+", options: .regularExpression)
            .flatMap { Int(log[$0]) }
            .map { String($0) }

        return BranchResponse(
            statusCode: statusCode ?? FAILED,
            headers: parseHeaders(log) ?? FAILED,
            body: parseBody(log) ?? FAILED
        )
    }

}


