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
                    // Use the modern SessionManager for consistent deep link handling
                    // This ensures task coalescing works correctly across all entry points
                    Task {
                        do {
                            var options = InitializationOptions()
                            options.url = url

                            let session = try await BranchSessionCoordinator.shared.sessionManager.initialize(options: options)
                            print("[BranchLinkSimulator] onOpenURL handled: \(session.id)")

                            // Update ViewModel on main actor
                            await MainActor.run {
                                appDelegate.handleSessionForUI(session)
                            }
                        } catch {
                            print("[BranchLinkSimulator] onOpenURL failed: \(error)")
                        }
                    }
                }
        }
    }
}
