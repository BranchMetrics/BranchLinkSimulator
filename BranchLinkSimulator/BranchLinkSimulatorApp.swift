//
//  BranchLinkSimulatorApp.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK

@main
struct BranchLinkSimulatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.deepLinkViewModel)
                .onOpenURL(perform: { url in
                    Branch.getInstance().handleDeepLink(url)
                })
        }
    }
}
