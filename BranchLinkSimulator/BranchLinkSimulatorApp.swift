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
        // Note: SceneDelegate handles window creation and Branch initialization
        // This WindowGroup is kept for compatibility but SceneDelegate takes precedence
        // when UIApplicationSceneManifest is configured in Info.plist
        WindowGroup {
            HomeView()
                .environmentObject(appDelegate.deepLinkViewModel)
                .environmentObject(appDelegate.store)
        }
    }
}
