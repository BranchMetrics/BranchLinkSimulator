//
//  ContentView.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK
import AppTrackingTransparency
import AdSupport

struct HomeView: View {
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @State private var showingToast = false
    @State private var toastMessage: String = ""
    @State private var branchAPIURL: String = "https://protected-api-test.branch.io"
    @State private var eventAlias: String = ""
    @State private var sessionID: String = UserDefaults.standard.string(forKey: "blsSessionId") ?? UUID().uuidString

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
                            Button(action: sendStandardEvent) {
                                Label("Send Standard Event", systemImage: "paperplane.fill")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
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
                        }
                        .headerProminence(.standard)
                        .listRowSeparator(.hidden)
                        
                        Section(header: Text("Settings"), footer: Text("Branch SDK v3.3.0").frame(maxWidth: .infinity)) {
                            VStack(alignment: .leading) {
                                Text("Branch API URL")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                TextField("Branch API URL", text: $branchAPIURL)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.vertical, 8)
                            
                            VStack(alignment: .leading) {
                                Text("Customer Event Alias")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                TextField("Eg. customAlias", text: $eventAlias)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.vertical, 8)
                            
                            VStack(alignment: .leading) {
                                Text("Branch Link Simulator Session ID")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
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
    }
    
    func sendStandardEvent() {
        let branchUniversalObject = BranchUniversalObject(canonicalIdentifier: "standardEvent")
        let event = BranchEvent.standardEvent(.purchase)
        event.alias = eventAlias
        event.logEvent { result, error in
            if error == nil {
                self.showToast(message: "Sent Standard Event!")
            } else {
                self.showToast(message: "Error Sending Standard Event!")
            }
        }
        
    }
    
    func sendCustomEvent() {
        let branchUniversalObject = BranchUniversalObject(canonicalIdentifier: "customEvent")
        let event = BranchEvent.customEvent(withName:"testedCustomEvent")
        event.alias = eventAlias
        event.logEvent { result, error in
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
                
        UserDefaults.standard.set(sessionID, forKey: "blsSessionId")
        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: sessionID)
        
        self.showToast(message: "Saved Settings!")
     }
    
    func showToast(message: String) {
        self.toastMessage = message
        self.showingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingToast = false
        }
    }
    
    func requestIDFAPermission() {
        if #available(iOS 14, *) {
            DispatchQueue.main.async {
                ATTrackingManager.requestTrackingAuthorization { (status) in
                    if (status == .authorized) {
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier
                        print("IDFA: " + idfa.uuidString)
                    } else {
                        print("Failed to get IDFA")
                    }
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
