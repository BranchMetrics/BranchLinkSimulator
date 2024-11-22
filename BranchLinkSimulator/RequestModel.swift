import Foundation

class RequestViewModel: ObservableObject {
    @Published var roundTrips: [RoundTrip] = [] {
        didSet {
            saveRoundTrips()
        }
    }

    private let storageKey = "savedRoundTrips"

    init() {
        loadRoundTrips()
    }

    func addRequest(_ request: BranchRequest) {
        DispatchQueue.main.async {
            self.roundTrips.insert(RoundTrip(timestamp: Date(), request: request, response: nil), at: 0)
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
}


