//
//  HomeView.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import AdSupport
import AppTrackingTransparency
import BranchSDK
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @EnvironmentObject var store: RoundTripStore

    @State private var showingToast = false
    @State private var toastMessage: String = ""
    @State private var branchAPIURL: String = "https://protected-api.branch.io"
    @State private var eventAlias: String = UserDefaults.standard.string(forKey: "customerEventAlias") ?? ""
    @State private var sessionID: String = UserDefaults.standard.string(forKey: "blsSessionId") ?? UUID().uuidString

    @State private var showingEventActionSheet = false
    @State private var selectedEventType: BranchStandardEvent = .purchase

    @State private var showingQRSheet = false
    @State private var qrCodeImage: UIImage? = nil

    // Double-Open Fix Toggle
    @AppStorage("useDoubleOpenFix") private var useDoubleOpenFix: Bool = false
    @State private var showingLogs = false

    var body: some View {
        NavigationView {
            VStack {
                if deepLinkViewModel.deepLinkHandled, let deepLinkData = deepLinkViewModel.deepLinkData {
                    NavigationLink(destination: DeeplinkDetailView(pageTitle: deepLinkData["page"] as? String ?? "Data", deepLinkParameters: deepLinkData), isActive: $deepLinkViewModel.deepLinkHandled) {
                        EmptyView()
                    }
                } else {
                    List {
                        Section(header: Text("Deep Link Pages")) {
                            NavigationLink(destination: DeeplinkDetailView(pageTitle: "Tree", deepLinkParameters: [:])) {
                                Label("Go to Tree", systemImage: "tree.fill")
                            }
                            NavigationLink(destination: DeeplinkDetailView(pageTitle: "Twig", deepLinkParameters: [:])) {
                                Label("Go to Twig", systemImage: "line.diagonal")
                            }
                            NavigationLink(destination: DeeplinkDetailView(pageTitle: "Leaf", deepLinkParameters: [:])) {
                                Label("Go to Leaf", systemImage: "leaf.fill")
                            }
                        }
                        .headerProminence(.standard)

                        Section(header: Text("Events")) {
                            Button(action: { self.showingEventActionSheet = true }) {
                                Label("Send Standard Event", systemImage: "paperplane.fill")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .actionSheet(isPresented: $showingEventActionSheet) {
                                ActionSheet(title: Text("Choose Event Type"), message: nil, buttons: [
                                    .default(Text("Purchase"), action: { sendEventOfType(.purchase) }),
                                    .default(Text("Add to Cart"), action: { sendEventOfType(.addToCart) }),
                                    .default(Text("Login"), action: { sendEventOfType(.login) }),
                                    .default(Text("Search"), action: { sendEventOfType(.search) }),
                                    .default(Text("Share"), action: { sendEventOfType(.share) }),

                                    .cancel(),
                                ])
                            }
                            Button(action: sendCustomEvent) {
                                Label("Send Custom Event", systemImage: "paperplane")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            Button(action: createURL) {
                                Label("Create Branch Link", systemImage: "link")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            Button(action: createQRCode) {
                                Label("Create Branch QR Code", systemImage: "qrcode")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: .constant(showingQRSheet), onDismiss: {
                                showingQRSheet = false
                            }) {
                                if let qrImage = qrCodeImage {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Text("No QR Code Available")
                                }
                            }
                        }
                        .headerProminence(.standard)
                        .listRowSeparator(.hidden)

                        Section("API Settings") {
                            ApiSettingsView(store: store)
                        }

                        // MARK: - Double-Open Bug Demo Section

                        Section(header: Text("EMT-2816: Double-Open Test").accessibilityIdentifier("doubleOpenSectionHeader")) {
                            // API Mode Toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $useDoubleOpenFix) {
                                    VStack(alignment: .leading) {
                                        Text("Use EMT-2816 Fix")
                                            .font(.headline)
                                        Text(useDoubleOpenFix ? "NEW API: BranchScene.initSession(with: connectionOptions)" : "OLD API: Branch.initSession(launchOptions: nil)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .accessibilityIdentifier("apiModeDescription")
                                    }
                                }
                                .tint(.green)
                                .accessibilityIdentifier("useDoubleOpenFixToggle")

                                HStack {
                                    Image(systemName: useDoubleOpenFix ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(useDoubleOpenFix ? .green : .orange)
                                    Text(useDoubleOpenFix ? "Fix enabled - restart app to test" : "Bug mode - restart app to test")
                                        .font(.caption)
                                        .foregroundColor(useDoubleOpenFix ? .green : .orange)
                                        .accessibilityIdentifier("fixStatusText")
                                }
                                .padding(.vertical, 4)
                            }

                            // OPEN Request Counter
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("OPEN Requests")
                                            .font(.headline)
                                        Text("Count of /v1/open or /v2/event(open)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(store.openRequestCount)")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(store.openRequestCount > 1 ? .red : .green)
                                        .accessibilityIdentifier("openRequestCount")
                                }

                                if store.openRequestCount > 1 {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text("DOUBLE-OPEN BUG DETECTED!")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                } else if store.openRequestCount == 1 {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Single OPEN - Working correctly!")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Text(useDoubleOpenFix
                                    ? "Using NEW API with EMT-2816 fix. Deep link launches should send only 1 OPEN."
                                    : "Using OLD/BUGGY API. Deep link launches will send 2 OPENs.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            NavigationLink(destination: LogsView(store: store)) {
                                Label("View Logs", systemImage: "doc.text.magnifyingglass")
                            }
                            .accessibilityIdentifier("viewLogsButton")

                            Button(action: {
                                store.clearLogs()
                                store.clearRoundTrips()
                                showToast(message: "Logs cleared")
                            }) {
                                Label("Clear All Logs", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .accessibilityIdentifier("clearLogsButton")
                        }
                        .headerProminence(.standard)

                        Section(header: Text("Event Settings"), footer: Text("Branch SDK 3.9.1 (without deduplication)").frame(maxWidth: .infinity)) {
                            VStack(alignment: .leading) {
                                Text("Customer Event Alias")
                                    .font(.headline)
                                TextField("Eg. customAlias", text: $eventAlias)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.vertical, 8)

                            VStack(alignment: .leading) {
                                Text("Branch Link Simulator Session ID")
                                    .font(.headline)
                                TextField("ID Goes Here", text: $sessionID)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.vertical, 8)

                            Button("Save Settings") {
                                saveSettings()
                            }
                            .foregroundColor(.blue)
                        }
                        .headerProminence(.standard)
                    }
                }
            }
            .navigationTitle("Branch Link Simulator")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                requestIDFAPermission()
            }
        }
        .toast(isShowing: $showingToast, message: toastMessage)
        .onAppear {
            deepLinkViewModel.deepLinkHandled = false
        }
        .alert(item: $deepLinkViewModel.errorItem) { errorItem in
            Alert(
                title: Text("Error"),
                message: Text(errorItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func sendEventOfType(_ eventType: BranchStandardEvent) {
        let event = BranchEvent.standardEvent(eventType)
        event.alias = eventAlias
        event.customData["bls_session_id"] = sessionID
        event.logEvent { _, error in
            if error == nil {
                self.showToast(message: "Sent \(eventType.rawValue) Event!")
            } else {
                self.showToast(message: "Error Sending \(eventType.rawValue) Event!")
            }
        }
    }

    func sendCustomEvent() {
        let event = BranchEvent.customEvent(withName: "testedCustomEvent")
        event.alias = eventAlias
        event.customData["bls_session_id"] = sessionID
        event.logEvent { _, error in
            if error == nil {
                self.showToast(message: "Sent Custom Event!")
            } else {
                self.showToast(message: "Error Sending Custom Event!")
            }
        }
    }

    func saveSettings() {
        print("Setting API URL to  \(branchAPIURL)")
        Branch.setAPIUrl(branchAPIURL)

        UserDefaults.standard.set(eventAlias, forKey: "customerEventAlias")
        UserDefaults.standard.set(sessionID, forKey: "blsSessionId")

        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: sessionID)

        showToast(message: "Saved Settings!")
    }

    func showToast(message: String) {
        toastMessage = message
        showingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingToast = false
        }
    }

    func requestIDFAPermission() {
        if #available(iOS 14, *) {
            DispatchQueue.main.async {
                ATTrackingManager.requestTrackingAuthorization { status in
                    if status == .authorized {
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier
                        print("IDFA: " + idfa.uuidString)
                    } else {
                        print("Failed to get IDFA")
                    }
                }
            }
        }
    }

    func createURL() {
        let buo = BranchUniversalObject(canonicalIdentifier: "item/12345")
        let lp = BranchLinkProperties()

        buo.getShortUrl(with: lp) { url, error in
            if let error = error {
                self.showToast(message: "Error creating link: \(error)")
            } else {
                self.showToast(message: "Created \(url ?? "N/A")")
            }
        }
    }

    func createQRCode() {
        let buo = BranchUniversalObject(canonicalIdentifier: "item/12345")
        let lp = BranchLinkProperties()

        let qrCode = BranchQRCode()
        qrCode.getAsImage(buo, linkProperties: lp) { image, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showToast(message: "Error creating QR Code: \(error.localizedDescription)")
                } else if let image = image {
                    self.qrCodeImage = image
                    self.showingQRSheet = true
                }
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String) -> some View {
        ZStack(alignment: .bottom) {
            self

            if isShowing.wrappedValue {
                VStack {
                    Spacer()
                    Text(message)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.96))
                        .foregroundColor(Color.primary)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .padding()
                }
                .transition(.move(edge: .bottom))
                .onTapGesture {
                    withAnimation {
                        isShowing.wrappedValue = false
                    }
                }
                .zIndex(1)
            }
        }
        .animation(.easeInOut, value: isShowing.wrappedValue)
    }
}

#Preview {
    HomeView()
}
