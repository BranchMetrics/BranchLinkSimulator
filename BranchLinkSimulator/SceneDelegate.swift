//
//  SceneDelegate.swift
//  BranchLinkSimulator
//
//  Created for testing double-open fix
//

import BranchSDK
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // Reference to shared app state
    var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = appDelegate else { return }

        let window = UIWindow(windowScene: windowScene)

        let homeView = HomeView()
            .environmentObject(appDelegate.deepLinkViewModel)
            .environmentObject(appDelegate.store)

        window.rootViewController = UIHostingController(rootView: homeView)
        self.window = window
        window.makeKeyAndVisible()

        // Check if using new API (double-open fix)
        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: Uses BranchScene with connection options
            // This prevents double OPEN on cold launch via deep links
            print("[BLS] Using NEW API: initSessionWithSceneConnectionOptions")
            appDelegate.store.addLogEntry("[INIT] Using NEW API (double-open fix)")

            BranchScene.shared().initSession(with: connectionOptions) { params, error, _ in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }
        } else {
            // OLD API: Standard initSession - may cause double OPEN
            print("[BLS] Using OLD API: initSession(launchOptions:)")
            appDelegate.store.addLogEntry("[INIT] Using OLD API (may double-open)")

            // Note: launchOptions is nil in scene-based apps
            Branch.getInstance().initSession(launchOptions: nil) { params, error in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }
        }

        // Handle URLs that were passed at launch
        if !connectionOptions.urlContexts.isEmpty {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        }

        // Handle Universal Links that were passed at launch
        if let userActivity = connectionOptions.userActivities.first {
            self.scene(scene, continue: userActivity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("[BLS] scene:openURLContexts - \(url)")
        appDelegate?.store.addLogEntry("[URL] openURLContexts: \(url.absoluteString)")

        BranchScene.shared().scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("[BLS] scene:continueUserActivity")
        appDelegate?.store.addLogEntry("[UL] continueUserActivity")

        BranchScene.shared().scene(scene, continue: userActivity)
    }

    private func handleBranchCallback(params: [String: AnyObject]?, error: Error?) {
        guard let appDelegate = appDelegate else { return }

        if let error = error {
            let config = loadConfigOrDefault()
            var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
            if config.staging {
                message += " Are you connected to VPN?"
            }
            DispatchQueue.main.async {
                appDelegate.deepLinkViewModel.errorItem = AlertItem(message: message)
            }
        }

        if let params = params {
            if let clickedBranchLink = params["+clicked_branch_link"] as? NSNumber, clickedBranchLink.boolValue == true {
                DispatchQueue.main.async {
                    appDelegate.deepLinkViewModel.deepLinkData = params
                    appDelegate.deepLinkViewModel.deepLinkHandled = true
                }
            } else {
                print("[BLS] Didn't click Branch link")
            }
        }
    }
}
