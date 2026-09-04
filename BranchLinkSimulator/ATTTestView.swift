//
//  ATTTestView.swift
//  BranchLinkSimulator
//
//  Created for comprehensive ATT testing
//

import SwiftUI
import AppTrackingTransparency

struct ATTTestView: View {
    @StateObject private var attManager = ATTManager()
    @State private var showingRequestAlert = false
    @State private var showingStatusHistory = false
    @State private var showingCopyConfirmation = false

    var body: some View {
        List {
            // Current Status Section
            Section(header: Text("Current ATT Status")
                .accessibilityIdentifier("Current ATT Status")) {
                HStack {
                    Text("Status")
                        .font(.headline)
                        .accessibilityIdentifier("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Text(attManager.statusToEmoji(attManager.authorizationStatus))
                            .accessibilityIdentifier("statusEmoji")
                        Text(attManager.statusToString(attManager.authorizationStatus))
                            .foregroundColor(statusColor)
                            .accessibilityIdentifier("statusValue")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("statusDisplay")
                }
                .padding(.vertical, 4)

                HStack {
                    Text("IDFA")
                        .font(.headline)
                        .accessibilityIdentifier("IDFA")
                    Spacer()
                    Text(attManager.idfa)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("idfaValue")
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIPasteboard.general.string = attManager.idfa
                    showingCopyConfirmation = true
                }
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = attManager.idfa
                        showingCopyConfirmation = true
                    }) {
                        Label("Copy IDFA", systemImage: "doc.on.doc")
                    }
                }

                if let lastRequest = attManager.lastRequestDate {
                    HStack {
                        Text("Last Request")
                            .font(.headline)
                            .accessibilityIdentifier("lastRequestLabel")
                        Spacer()
                        Text(lastRequest, style: .relative)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("lastRequestValue")
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("lastRequestRow")
                }

                HStack {
                    Text("Tracking Enabled")
                        .font(.headline)
                        .accessibilityIdentifier("Tracking Enabled")
                    Spacer()
                    Image(systemName: attManager.authorizationStatus == .authorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(attManager.authorizationStatus == .authorized ? .green : .red)
                        .accessibilityIdentifier(attManager.authorizationStatus == .authorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                }
                .padding(.vertical, 4)
            }

            // Actions Section
            Section(header: Text("Actions")
                .accessibilityIdentifier("Actions")) {
                Button(action: {
                    requestPermission()
                }) {
                    Label("Request ATT Permission", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(canRequestPermission ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canRequestPermission)
                .accessibilityIdentifier("Request ATT Permission")
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                Button(action: {
                    attManager.updateCurrentStatus()
                }) {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .accessibilityIdentifier("Refresh Status")
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                Button(action: {
                    openSettings()
                }) {
                    Label("Open App Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .accessibilityIdentifier("Open App Settings")
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            // Status History Section
            Section(header: HStack {
                Text("Status History")
                    .accessibilityIdentifier("Status History")
                Spacer()
                Button(action: {
                    attManager.resetForTesting()
                }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .accessibilityIdentifier("Clear")
            }) {
                if attManager.statusHistory.isEmpty {
                    Text("No history yet")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("No history yet")
                } else {
                    ForEach(attManager.statusHistory.prefix(10)) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(attManager.statusToEmoji(entry.status))
                                    .font(.title3)
                                Text(entry.event)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(entry.date, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(attManager.statusToString(entry.status))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("IDFA: \(entry.idfa)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            // Test Scenarios Section
            Section(header: Text("Test Scenarios & Expected Behavior")
                .accessibilityIdentifier("Test Scenarios & Expected Behavior")) {
                TestScenarioRow(
                    emoji: "❓",
                    title: "Not Determined",
                    description: "Initial state. ATT prompt can be shown.",
                    isCurrentState: attManager.authorizationStatus == .notDetermined
                )

                TestScenarioRow(
                    emoji: "✅",
                    title: "Authorized",
                    description: "User granted permission. IDFA is available.",
                    isCurrentState: attManager.authorizationStatus == .authorized
                )

                TestScenarioRow(
                    emoji: "❌",
                    title: "Denied",
                    description: "User denied permission. IDFA returns zeros.",
                    isCurrentState: attManager.authorizationStatus == .denied
                )

                TestScenarioRow(
                    emoji: "🔒",
                    title: "Restricted",
                    description: "Tracking restricted by parental controls or MDM.",
                    isCurrentState: attManager.authorizationStatus == .restricted
                )
            }

            // Integration Info Section
            Section(header: Text("Branch SDK Integration")
                .accessibilityIdentifier("Branch SDK Integration")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How Branch Uses ATT")
                        .font(.headline)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("How Branch Uses ATT")

                    Text("• The Branch SDK automatically checks ATT status")
                        .font(.caption)

                    Text("• If authorized, IDFA is included in attribution")
                        .font(.caption)

                    Text("• If denied/restricted, Branch uses alternative identifiers")
                        .font(.caption)

                    Text("• Branch respects user privacy choices")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }

            // Testing Notes Section
            Section(header: Text("Testing Notes")
                .accessibilityIdentifier("Testing Notes")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚠️ Important")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("⚠️ Important")

                    Text("• ATT prompt can only be shown once per app install")
                        .font(.caption)

                    Text("• To test again, delete and reinstall the app")
                        .font(.caption)

                    Text("• Or reset 'Advertising Identifier' in Settings > Privacy")
                        .font(.caption)

                    Text("• Status changes take effect immediately")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("ATT Testing")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            attManager.updateCurrentStatus()
        }
        .overlay(
            Group {
                if showingCopyConfirmation {
                    VStack {
                        Spacer()
                        Text("IDFA Copied!")
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .accessibilityIdentifier("copyConfirmation")
                        Spacer()
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingCopyConfirmation = false
                            }
                        }
                    }
                }
            }
        )
        .alert("Request ATT Permission?", isPresented: $showingRequestAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Request") {
                requestPermission()
            }
        } message: {
            Text("This will show the system ATT permission dialog. You can only request this once per app install.")
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch attManager.authorizationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return .blue
        @unknown default:
            return .gray
        }
    }

    private var canRequestPermission: Bool {
        attManager.canShowATTPrompt()
    }

    // MARK: - Methods

    private func requestPermission() {
        attManager.requestIDFAPermission { status in
            print("ATT Permission Result: \(attManager.statusToString(status))")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct TestScenarioRow: View {
    let emoji: String
    let title: String
    let description: String
    let isCurrentState: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title2)
                .accessibilityIdentifier(emoji)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier(title)

                    if isCurrentState {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .accessibilityIdentifier("CURRENT")
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ATTTestView()
    }
}
