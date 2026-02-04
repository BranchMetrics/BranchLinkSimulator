//
//  BranchLinkSimulatorApp.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import BranchSDK
import BranchSwiftSDK
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
                    // Use the Modern SessionManager for URL handling
                    BranchLogger.shared().logVerbose("onOpenURL: \(url)", error: nil)

                    SessionManager.shared.handleDeepLink(url) { session, error in
                        if let session = session {
                            BranchLogger.shared().logDebug("onOpenURL session: \(session.id)", error: nil)
                            // Update ViewModel for deep link handling
                            if session.hasDeepLinkData || (session.params["+clicked_branch_link"] as? Bool ?? false) {
                                var displayParams: [String: AnyObject] = [:]
                                for (key, value) in session.params {
                                    displayParams[key] = value as AnyObject
                                }
                                appDelegate.deepLinkViewModel.deepLinkData = displayParams
                                appDelegate.deepLinkViewModel.deepLinkHandled = true
                            }
                        } else if let error = error {
                            BranchLogger.shared().logError("onOpenURL error: \(error.localizedDescription)", error: error)
                        }
                    }
                }
        }
    }
}
