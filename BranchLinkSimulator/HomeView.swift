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

    @State private var qrCodeImage: UIImage? = nil

    var body: some View {
        NavigationStack {
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
                    .sheet(isPresented: Binding(
                        get: { qrCodeImage != nil },
                        set: { if !$0 { qrCodeImage = nil } }
                    )) {
                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                }
                .headerProminence(.standard)
                .listRowSeparator(.hidden)

                Section("API Settings") {
                    ApiSettingsView(store: store)
                }

                Section(header: Text("Event Settings"), footer: Text("Branch SDK (Objective-C)").frame(maxWidth: .infinity)) {
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
            .navigationTitle("Branch Link Simulator")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $deepLinkViewModel.deepLinkHandled) {
                if let deepLinkData = deepLinkViewModel.deepLinkData {
                    DeeplinkDetailView(pageTitle: deepLinkData["page"] as? String ?? "Data", deepLinkParameters: deepLinkData)
                }
            }
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
        BranchLogger.shared().logVerbose("Sending standard event: \(eventType.rawValue)", error: nil)
        let event = BranchEvent.standardEvent(eventType)
        event.alias = eventAlias
        event.customData["bls_session_id"] = sessionID
        event.logEvent { success, error in
            if let error = error {
                BranchLogger.shared().logError("Event error: \(error.localizedDescription)", error: error)
                self.showToast(message: "Error Sending \(eventType.rawValue) Event!")
            } else {
                BranchLogger.shared().logVerbose("Event sent successfully (success=\(success))", error: nil)
                self.showToast(message: "Sent \(eventType.rawValue) Event!")
            }
        }
    }

    func sendCustomEvent() {
        BranchLogger.shared().logVerbose("Sending custom event: testedCustomEvent", error: nil)
        let event = BranchEvent.customEvent(withName: "testedCustomEvent")
        event.alias = eventAlias
        event.customData["bls_session_id"] = sessionID
        event.logEvent { success, error in
            if let error = error {
                BranchLogger.shared().logError("Custom event error: \(error.localizedDescription)", error: error)
                self.showToast(message: "Error Sending Custom Event!")
            } else {
                BranchLogger.shared().logVerbose("Custom event sent successfully (success=\(success))", error: nil)
                self.showToast(message: "Sent Custom Event!")
            }
        }
    }

    func saveSettings() {
        BranchLogger.shared().logDebug("Setting API URL to \(branchAPIURL)", error: nil)
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
                        BranchLogger.shared().logDebug("IDFA: \(idfa.uuidString)", error: nil)
                    } else {
                        BranchLogger.shared().logWarning("Failed to get IDFA", error: nil)
                    }
                }
            }
        }
    }

    func createURL() {
        BranchLogger.shared().logVerbose("Creating Branch link...", error: nil)
        let buo = BranchUniversalObject(canonicalIdentifier: "item/12345")
        let lp = BranchLinkProperties()

        buo.getShortUrl(with: lp) { url, error in
            if let error = error {
                BranchLogger.shared().logError("Link creation error: \(error.localizedDescription)", error: error)
                self.showToast(message: "Error creating link: \(error)")
            } else {
                BranchLogger.shared().logVerbose("Link created: \(url ?? "N/A")", error: nil)
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
