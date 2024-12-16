import Foundation
import BranchSDK

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


