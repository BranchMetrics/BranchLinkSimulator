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

        // Log launch type detection
        let hasURLContexts = !connectionOptions.urlContexts.isEmpty
        let hasUserActivities = !connectionOptions.userActivities.isEmpty
        let launchType = hasURLContexts ? "URL Scheme" : (hasUserActivities ? "Universal Link" : "Normal")

        appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate.store.addLogEntry("[APP] COLD LAUNCH detected")
        appDelegate.store.addLogEntry("[APP] Launch type: \(launchType)")

        if let url = connectionOptions.urlContexts.first?.url {
            appDelegate.store.addLogEntry("[APP] URL: \(url.absoluteString)")
        }
        if let activity = connectionOptions.userActivities.first, let url = activity.webpageURL {
            appDelegate.store.addLogEntry("[APP] Universal Link: \(url.absoluteString)")
        }

        // Check if using new API (double-open fix)
        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: Uses BranchScene with connection options
            // This prevents double OPEN on cold launch via deep links
            print("[BLS] Using NEW API: initSessionWithSceneConnectionOptions")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[INIT] 🟢 Using NEW API (FIX)")
            appDelegate.store.addLogEntry("[INIT] BranchScene.initSession(with:)")
            appDelegate.store.addLogEntry("[INIT] Expected: 1 OPEN request")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            BranchScene.shared().initSession(with: connectionOptions) { params, error, _ in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }
        } else {
            // OLD API: Standard initSession - may cause double OPEN
            print("[BLS] Using OLD API: initSession(launchOptions:)")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[INIT] 🔴 Using OLD API (BUG)")
            appDelegate.store.addLogEntry("[INIT] Branch.initSession(launchOptions:)")
            appDelegate.store.addLogEntry("[INIT] Expected: 2 OPEN requests on deep link")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Note: launchOptions is nil in scene-based apps
            Branch.getInstance().initSession(launchOptions: nil) { params, error in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }
        }

        // Handle URLs that were passed at launch
        // With OLD API: This will cause DOUBLE OPEN (the bug we want to demonstrate)
        // With NEW API: BranchScene.initSession already handled the URL, skip this
        if !useNewAPI {
            if !connectionOptions.urlContexts.isEmpty {
                appDelegate.store.addLogEntry("[URL] Processing URL from connectionOptions (OLD API)")
                appDelegate.store.addLogEntry("[URL] ⚠️ This will trigger SECOND OPEN request!")
                self.scene(scene, openURLContexts: connectionOptions.urlContexts)
            }

            // Handle Universal Links that were passed at launch
            if let userActivity = connectionOptions.userActivities.first {
                appDelegate.store.addLogEntry("[UL] Processing Universal Link from connectionOptions (OLD API)")
                appDelegate.store.addLogEntry("[UL] ⚠️ This will trigger SECOND OPEN request!")
                self.scene(scene, continue: userActivity)
            }
        } else {
            // NEW API already handled URLs in initSession, just log
            if !connectionOptions.urlContexts.isEmpty {
                appDelegate.store.addLogEntry("[URL] ✅ URL already handled by BranchScene.initSession")
            }
            if connectionOptions.userActivities.first != nil {
                appDelegate.store.addLogEntry("[UL] ✅ Universal Link already handled by BranchScene.initSession")
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("[BLS] scene:openURLContexts - \(url)")
        appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate?.store.addLogEntry("[URL] WARM LAUNCH via URL Scheme")
        appDelegate?.store.addLogEntry("[URL] \(url.absoluteString)")

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: BranchScene handles deduplication
            appDelegate?.store.addLogEntry("[URL] 🟢 Using BranchScene (with dedup)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            BranchScene.shared().scene(scene, openURLContexts: URLContexts)
        } else {
            // OLD API: Direct handleDeepLink - will cause double OPEN on cold launch
            appDelegate?.store.addLogEntry("[URL] 🔴 Using Branch.handleDeepLink (no dedup)")
            appDelegate?.store.addLogEntry("[URL] This WILL send another OPEN request!")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Branch.getInstance().handleDeepLink(url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("[BLS] scene:continueUserActivity")
        appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate?.store.addLogEntry("[UL] WARM LAUNCH via Universal Link")
        if let url = userActivity.webpageURL {
            appDelegate?.store.addLogEntry("[UL] \(url.absoluteString)")
        }

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: BranchScene handles deduplication
            appDelegate?.store.addLogEntry("[UL] 🟢 Using BranchScene (with dedup)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            BranchScene.shared().scene(scene, continue: userActivity)
        } else {
            // OLD API: Direct handleDeepLink - will cause double OPEN on cold launch
            appDelegate?.store.addLogEntry("[UL] 🔴 Using Branch.handleDeepLink (no dedup)")
            appDelegate?.store.addLogEntry("[UL] This WILL send another OPEN request!")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if let url = userActivity.webpageURL {
                Branch.getInstance().handleDeepLink(url)
            }
        }
    }

    private func handleBranchCallback(params: [String: AnyObject]?, error: Error?) {
        guard let appDelegate = appDelegate else { return }

        appDelegate.store.addLogEntry("[CALLBACK] Branch session callback received")

        if let error = error {
            appDelegate.store.addLogEntry("[CALLBACK] ❌ Error: \(error.localizedDescription)")
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
                appDelegate.store.addLogEntry("[CALLBACK] ✅ Branch link clicked!")
                if let feature = params["~feature"] as? String {
                    appDelegate.store.addLogEntry("[CALLBACK] Feature: \(feature)")
                }
                if let campaign = params["~campaign"] as? String {
                    appDelegate.store.addLogEntry("[CALLBACK] Campaign: \(campaign)")
                }
                DispatchQueue.main.async {
                    appDelegate.deepLinkViewModel.deepLinkData = params
                    appDelegate.deepLinkViewModel.deepLinkHandled = true
                }
            } else {
                appDelegate.store.addLogEntry("[CALLBACK] No Branch link clicked (normal launch)")
            }
        } else {
            appDelegate.store.addLogEntry("[CALLBACK] No params received")
        }
    }
}
