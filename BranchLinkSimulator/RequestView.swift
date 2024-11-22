import SwiftUI

struct RequestView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.roundTrips) { roundTrip in
                    NavigationLink(destination: RoundTripDetailView(roundTrip: roundTrip)) {
                        VStack(alignment: .leading) {
                            Text(roundTrip.request.url)
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
        }
    }
}


struct RoundTripDetailView: View {
    let roundTrip: RoundTrip

    var body: some View {
        Form {
            VariableView(label: "URL", value: roundTrip.request.url)
            
            Section(header: Text("Request")
                .font(.headline)
                .foregroundColor(.primary)
            ) {
                VariableView(label: "Headers", value: roundTrip.request.headers)
                VariableView(label: "Body", value: roundTrip.request.body)
            }
            
            if let response = roundTrip.response {
                Section(header: Text("Response")
                    .font(.headline)
                    .foregroundColor(.primary)
                ) {
                    VariableView(label: "Status Code", value: response.statusCode)
                    VariableView(label: "Headers", value: response.headers)
                    VariableView(label: "Body", value: response.body)
                }
            }
        }
    }
}



struct VariableView: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(label):")
                    .font(.body)
                    .fontWeight(.bold)
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
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .buttonStyle(BorderlessButtonStyle())
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
