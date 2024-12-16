import SwiftUI

struct RoundTripView: View {
    @ObservedObject var store: RoundTripStore

    var body: some View {
        List {
            ForEach(store.roundTrips) { roundTrip in
                NavigationLink(destination: RoundTripDetailView(roundTrip: roundTrip)) {
                    VStack(alignment: .leading) {
                        Text(roundTrip.url)
                            .font(.headline)
                        Text(roundTrip.timestamp.formattedDateString())
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let response = roundTrip.response {
                            Text("Status Code: \(response.statusCode)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .navigationTitle("Requests")
        .overlay {
            if store.roundTrips.isEmpty {
                ContentUnavailableView.init("No Requests", systemImage: "nosign", description: Text("No requests have been logged yet."))
            }
        }
    }
}


struct RoundTripDetailView: View {
    let roundTrip: RoundTrip

    var body: some View {
        Form {
            VariableView(label: "URL", value: roundTrip.url)
            
            Section("Request") {
                VariableView(label: "Headers", value: roundTrip.request.headers)
                VariableView(label: "Body", value: roundTrip.request.body)
            }
            
            if let response = roundTrip.response {
                Section("Response") {
                    VariableView(label: "Status Code", value: response.statusCode)
                    VariableView(label: "Body", value: response.body)
                }
            }
        }
        .navigationTitle("Request")
    }
}

struct VariableView: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(label)")
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = value
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.blue)
                }
            }
            Text("\(value)")
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .multilineTextAlignment(.leading)
        .cornerRadius(10)
    }
}

extension Date {
    func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
}
