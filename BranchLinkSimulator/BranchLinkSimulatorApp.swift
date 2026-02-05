//
//  BranchLinkSimulatorApp.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import BranchSDK
import SwiftUI

@main
struct BranchLinkSimulatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appDelegate.deepLinkViewModel)
                .environmentObject(appDelegate.store)
                .onOpenURL { url in
                    // Use Branch SDK for URL handling
                    BranchLogger.shared().logVerbose("onOpenURL: \(url)", error: nil)

                    // Handle the deep link - Branch SDK will call the init callback
                    Branch.getInstance().handleDeepLink(url)
                }
        }
    }
}
