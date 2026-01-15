//
//  LogsView.swift
//  BranchLinkSimulator
//
//  Created for double-open fix testing
//

import SwiftUI

struct LogsView: View {
    @ObservedObject var store: RoundTripStore
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker("View", selection: $selectedTab) {
                Text("Timeline").tag(0)
                Text("OPEN Requests (\(store.openRequestCount))").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if selectedTab == 0 {
                // Timeline view - all log entries
                if store.logEntries.isEmpty {
                    VStack {
                        Spacer()
                        Text("No logs yet")
                            .foregroundColor(.secondary)
                        Text("Logs will appear here as SDK events occur")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(store.logEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(entry.message)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(colorForLogEntry(entry))
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                // OPEN requests view
                if store.recentOpenRequests.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No OPEN Requests")
                            .font(.headline)
                            .padding(.top)
                        Text("This is expected if the app hasn't been launched yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                } else {
                    VStack {
                        // Summary header
                        HStack {
                            VStack(alignment: .leading) {
                                Text("OPEN Request Count")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(store.openRequestCount)")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(store.openRequestCount > 1 ? .red : .green)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if store.openRequestCount == 1 {
                                    Label("OK", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if store.openRequestCount > 1 {
                                    Label("Double OPEN!", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                } else {
                                    Label("No OPEN", systemImage: "minus.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // List of OPEN requests
                        List(store.recentOpenRequests) { roundTrip in
                            OpenRequestRow(roundTrip: roundTrip)
                        }
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    store.clearLogs()
                    store.clearRoundTrips()
                }) {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func colorForLogEntry(_ entry: LogEntry) -> Color {
        if entry.message.contains("[OPEN]") || entry.message.contains("[INIT]") {
            return .blue
        } else if entry.message.contains("[URL]") || entry.message.contains("[UL]") {
            return .purple
        } else if entry.message.contains("[APP]") {
            return .orange
        } else if entry.message.contains("Error") || entry.message.contains("error") {
            return .red
        }
        return .primary
    }
}

struct OpenRequestRow: View {
    let roundTrip: RoundTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text(formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let response = roundTrip.response {
                    Text(response.statusCode)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(response.statusCode == "200" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(response.statusCode == "200" ? .green : .red)
                        .cornerRadius(4)
                }
            }

            Text(roundTrip.url)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
                .foregroundColor(.secondary)

            if let sessionId = extractSessionId(from: roundTrip.request.body) {
                HStack {
                    Text("Session ID:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sessionId)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: roundTrip.timestamp)
    }

    private func extractSessionId(from body: String) -> String? {
        // Try to extract session_id from the request body
        if let range = body.range(of: "\"session_id\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = body[range]
            if let valueRange = match.range(of: "\"[^\"]+\"$", options: .regularExpression) {
                return String(match[valueRange]).replacingOccurrences(of: "\"", with: "")
            }
        }
        return nil
    }
}

#Preview {
    NavigationView {
        LogsView(store: RoundTripStore())
    }
}
