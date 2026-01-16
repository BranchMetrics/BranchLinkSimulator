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
            // ═══════════════════════════════════════════════════════════════
            // NEW API (FIX): Single unified call that handles everything
            // BranchScene.initSession checks connectionOptions and only sends
            // ONE OPEN request, even when launched via deep link
            // ═══════════════════════════════════════════════════════════════
            print("[BLS] Using NEW API: BranchScene.initSession(with:)")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[INIT] 🟢 NEW API (FIX)")
            appDelegate.store.addLogEntry("[INIT] BranchScene.initSession(with: connectionOptions)")
            appDelegate.store.addLogEntry("[INIT] → URL handled internally")
            appDelegate.store.addLogEntry("[INIT] → Expected: 1 OPEN request")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            BranchScene.shared().initSession(with: connectionOptions) { params, error, _ in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }

            // With NEW API, URLs are already handled - just log
            if !connectionOptions.urlContexts.isEmpty {
                appDelegate.store.addLogEntry("[URL] ✅ URL handled by initSession (no extra OPEN)")
            }
            if connectionOptions.userActivities.first != nil {
                appDelegate.store.addLogEntry("[UL] ✅ Universal Link handled by initSession (no extra OPEN)")
            }

        } else {
            // ═══════════════════════════════════════════════════════════════
            // OLD API (BUG): Simulates pre-fix integration pattern
            // Step 1: initSession with nil launchOptions (scene-based apps get nil)
            // Step 2: Manually process URL from connectionOptions
            // This causes TWO OPEN requests because the SDK doesn't know
            // the URL was already in connectionOptions
            // ═══════════════════════════════════════════════════════════════
            print("[BLS] Using OLD API: Branch.initSession(launchOptions:)")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[INIT] 🔴 OLD API (BUG)")
            appDelegate.store.addLogEntry("[INIT] Step 1: Branch.initSession(launchOptions: nil)")
            appDelegate.store.addLogEntry("[INIT] → launchOptions is nil in scene-based apps!")
            appDelegate.store.addLogEntry("[INIT] → Sends OPEN #1")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // STEP 1: Init session with nil (this is what scene-based apps get)
            // This sends OPEN #1
            Branch.getInstance().initSession(launchOptions: nil) { params, error in
                self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }

            // STEP 2: Process URLs from connectionOptions
            // In the OLD integration, this would trigger another OPEN
            if let urlContext = connectionOptions.urlContexts.first {
                let url = urlContext.url
                appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                appDelegate.store.addLogEntry("[URL] Step 2: Processing URL separately")
                appDelegate.store.addLogEntry("[URL] \(url.absoluteString)")
                appDelegate.store.addLogEntry("[URL] → Using Branch.application(_:open:options:)")
                appDelegate.store.addLogEntry("[URL] → This triggers OPEN #2!")
                appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Use the OLD AppDelegate method that causes the second OPEN
                Branch.getInstance().application(
                    UIApplication.shared,
                    open: url,
                    options: [:]
                )
            }

            // Handle Universal Links with OLD API
            if let userActivity = connectionOptions.userActivities.first,
               let url = userActivity.webpageURL
            {
                appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                appDelegate.store.addLogEntry("[UL] Step 2: Processing Universal Link separately")
                appDelegate.store.addLogEntry("[UL] \(url.absoluteString)")
                appDelegate.store.addLogEntry("[UL] → Using Branch.application(_:continue:)")
                appDelegate.store.addLogEntry("[UL] → This triggers OPEN #2!")
                appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Use the OLD AppDelegate method for universal links
                Branch.getInstance().continue(userActivity)
            }
        }
    }

    // MARK: - Warm Launch Handlers

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("[BLS] scene:openURLContexts - \(url)")

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate?.store.addLogEntry("[URL] WARM LAUNCH via URL Scheme")
        appDelegate?.store.addLogEntry("[URL] \(url.absoluteString)")

        if useNewAPI {
            appDelegate?.store.addLogEntry("[URL] 🟢 Using BranchScene.scene (with dedup)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            BranchScene.shared().scene(scene, openURLContexts: URLContexts)
        } else {
            appDelegate?.store.addLogEntry("[URL] 🔴 Using Branch.application (OLD)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Branch.getInstance().application(
                UIApplication.shared,
                open: url,
                options: [:]
            )
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("[BLS] scene:continueUserActivity")

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate?.store.addLogEntry("[UL] WARM LAUNCH via Universal Link")
        if let url = userActivity.webpageURL {
            appDelegate?.store.addLogEntry("[UL] \(url.absoluteString)")
        }

        if useNewAPI {
            appDelegate?.store.addLogEntry("[UL] 🟢 Using BranchScene.scene (with dedup)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            BranchScene.shared().scene(scene, continue: userActivity)
        } else {
            appDelegate?.store.addLogEntry("[UL] 🔴 Using Branch.continue (OLD)")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Branch.getInstance().continue(userActivity)
        }
    }

    // MARK: - Branch Callback Handler

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
