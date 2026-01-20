//
//  SceneDelegate.swift
//  BranchLinkSimulator
//
//  Created for testing double-open bug demonstration
//

import BranchSDK
import os.log
import SwiftUI
import UIKit

// Create a custom log category for debugging
private let debugLog = OSLog(subsystem: "io.branch.link-simulator", category: "SceneDelegate")

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // Reference to shared app state
    var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    // Helper to write debug log to file for cold launch analysis
    private func writeDebugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "\(timestamp): \(message)\n"

        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFile = documentsPath.appendingPathComponent("cold_launch_debug.txt")

            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    if let data = logMessage.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }
            } else {
                try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        os_log("🚀 SceneDelegate scene:willConnectTo:options CALLED", log: debugLog, type: .error)
        os_log("📋 urlContexts.count = %d", log: debugLog, type: .error, connectionOptions.urlContexts.count)
        os_log("📋 userActivities.count = %d", log: debugLog, type: .error, connectionOptions.userActivities.count)

        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = appDelegate else { return }

        let window = UIWindow(windowScene: windowScene)

        let homeView = HomeView()
            .environmentObject(appDelegate.deepLinkViewModel)
            .environmentObject(appDelegate.store)

        window.rootViewController = UIHostingController(rootView: homeView)
        self.window = window
        window.makeKeyAndVisible()

        // CRITICAL DEBUG: Write to file for cold launch analysis
        writeDebugLog("═══════════════════════════════════════════════════")
        writeDebugLog("COLD LAUNCH - scene:willConnectTo:options:")
        writeDebugLog("connectionOptions.urlContexts.count = \(connectionOptions.urlContexts.count)")
        writeDebugLog("connectionOptions.userActivities.count = \(connectionOptions.userActivities.count)")

        for (index, urlContext) in connectionOptions.urlContexts.enumerated() {
            writeDebugLog("  urlContext[\(index)]: \(urlContext.url.absoluteString)")
        }

        for (index, activity) in connectionOptions.userActivities.enumerated() {
            writeDebugLog("  userActivity[\(index)]: \(activity.activityType) - \(activity.webpageURL?.absoluteString ?? "nil")")
        }

        // Log launch type detection
        let hasURLContexts = !connectionOptions.urlContexts.isEmpty
        let hasUserActivities = !connectionOptions.userActivities.isEmpty
        let launchType = hasURLContexts ? "URL Scheme" : (hasUserActivities ? "Universal Link" : "Normal")

        writeDebugLog("Launch type determined: \(launchType)")

        appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate.store.addLogEntry("[APP] COLD LAUNCH detected")
        appDelegate.store.addLogEntry("[APP] Launch type: \(launchType)")

        if let url = connectionOptions.urlContexts.first?.url {
            appDelegate.store.addLogEntry("[APP] URL: \(url.absoluteString)")
        }
        if let activity = connectionOptions.userActivities.first, let url = activity.webpageURL {
            appDelegate.store.addLogEntry("[APP] Universal Link: \(url.absoluteString)")
        }

        // Check which API mode to use
        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // ═══════════════════════════════════════════════════════════════
            // NEW API - EMT-2816 FIX
            // Uses BranchScene.initSessionWithSceneConnectionOptions
            // This correctly detects deep link launches and prevents double OPEN
            // ═══════════════════════════════════════════════════════════════
            initializeWithNewAPI(scene: scene, connectionOptions: connectionOptions, appDelegate: appDelegate)
        } else {
            // ═══════════════════════════════════════════════════════════════
            // OLD API - DEMONSTRATES THE BUG
            // This is the buggy integration pattern for scene-based apps
            // ═══════════════════════════════════════════════════════════════
            initializeWithOldAPI(connectionOptions: connectionOptions, appDelegate: appDelegate)
        }
    }

    // MARK: - NEW API (EMT-2816 Fix)

    private func initializeWithNewAPI(scene _: UIScene, connectionOptions: UIScene.ConnectionOptions, appDelegate: AppDelegate) {
        writeDebugLog("═══════════════════════════════════════════════════")
        writeDebugLog("NEW API - initializeWithNewAPI() called")
        writeDebugLog("connectionOptions.urlContexts.count = \(connectionOptions.urlContexts.count)")
        writeDebugLog("connectionOptions.userActivities.count = \(connectionOptions.userActivities.count)")

        print("[BLS] Using NEW API - Double Open FIX")
        appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate.store.addLogEntry("[INIT] ✅ EMT-2816 FIX - NEW API")

        // Check if we have URL or UserActivity in connectionOptions
        let hasURLInConnectionOptions = !connectionOptions.urlContexts.isEmpty
        let hasUserActivityInConnectionOptions = !connectionOptions.userActivities.isEmpty
        let hasLinkInConnectionOptions = hasURLInConnectionOptions || hasUserActivityInConnectionOptions

        if hasLinkInConnectionOptions {
            // CASE 1: URL/UserActivity in connectionOptions - call initSession immediately
            // The SDK will see the URL and send only ONE OPEN with the link data
            writeDebugLog("NEW API CASE 1: URL/UserActivity present in connectionOptions")
            writeDebugLog("Calling BranchScene.initSession(with: connectionOptions) WITH link data")

            appDelegate.store.addLogEntry("[INIT] Using BranchScene.initSession(with: connectionOptions)")
            appDelegate.store.addLogEntry("[INIT] → URL present in connectionOptions")
            appDelegate.store.addLogEntry("[INIT] → SDK will send ONE OPEN with link data")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            sessionInitialized = true

            // Log the URL for debugging
            if let urlContext = connectionOptions.urlContexts.first {
                let url = urlContext.url
                appDelegate.store.addLogEntry("[URL] URL in connectionOptions:")
                appDelegate.store.addLogEntry("[URL] \(url.absoluteString)")
            }
            if let userActivity = connectionOptions.userActivities.first,
               let url = userActivity.webpageURL
            {
                appDelegate.store.addLogEntry("[UL] Universal Link in connectionOptions:")
                appDelegate.store.addLogEntry("[UL] \(url.absoluteString)")
            }

            // ═══════════════════════════════════════════════════════════════════════
            // CRITICAL: Only call initSession - the SDK processes the URL internally!
            // DO NOT also call scene:openURLContexts: - that causes the double-open bug
            // ═══════════════════════════════════════════════════════════════════════
            BranchScene.shared().initSession(with: connectionOptions) { [weak self] params, error, _ in
                self?.writeDebugLog("NEW API CASE 1 CALLBACK: initSession callback received")
                self?.handleBranchCallback(params: params as? [String: AnyObject], error: error)
            }
        } else {
            // CASE 2: NO URL in connectionOptions - URL may arrive later via openURLContexts
            // ⚠️ THIS IS THE CRITICAL FIX: Do NOT call initSession here!
            // Wait for the URL to arrive via scene:openURLContexts: and call initSession there
            writeDebugLog("NEW API CASE 2: NO URL in connectionOptions")
            writeDebugLog("⚠️ DEFERRING initSession - will wait for URL via scene:openURLContexts:")
            writeDebugLog("This prevents sending OPEN without link data")

            appDelegate.store.addLogEntry("[INIT] ⚠️ DEFERRING initSession")
            appDelegate.store.addLogEntry("[INIT] → No URL in connectionOptions (iOS delivers later)")
            appDelegate.store.addLogEntry("[INIT] → Will call initSession when URL arrives")
            appDelegate.store.addLogEntry("[INIT] → This prevents double-OPEN!")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Mark that we're deferring initialization
            sessionInitialized = false

            // Start a timer to call initSession if no URL arrives within 5 seconds
            // This handles normal launches (not via deep link)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                if !self.sessionInitialized {
                    self.writeDebugLog("NEW API CASE 2: Timeout - no URL arrived, initializing now")
                    self.sessionInitialized = true
                    appDelegate.store.addLogEntry("[INIT] Timeout - no URL arrived, initializing Branch")

                    // Use the regular Branch API for normal launch (no URL)
                    Branch.getInstance().initSession(launchOptions: nil) { params, error in
                        self.writeDebugLog("NEW API CASE 2 CALLBACK: deferred initSession callback")
                        self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
                    }
                }
            }
        }
    }

    // MARK: - OLD API (Demonstrates Bug)

    private func initializeWithOldAPI(connectionOptions: UIScene.ConnectionOptions, appDelegate: AppDelegate) {
        writeDebugLog("═══════════════════════════════════════════════════")
        writeDebugLog("OLD API - initializeWithOldAPI() called")
        writeDebugLog("connectionOptions.urlContexts.count = \(connectionOptions.urlContexts.count)")

        print("[BLS] Demonstrating DOUBLE-OPEN BUG")
        appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appDelegate.store.addLogEntry("[INIT] 🔴 DOUBLE-OPEN BUG DEMO")
        appDelegate.store.addLogEntry("[INIT] Step 1: Branch.initSession(launchOptions: nil)")
        appDelegate.store.addLogEntry("[INIT] → launchOptions is nil in scene-based apps!")
        appDelegate.store.addLogEntry("[INIT] → This sends OPEN #1")
        appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        writeDebugLog("STEP 1: Calling Branch.getInstance().initSession(launchOptions: nil)")

        // STEP 1: Init session with nil (this is what scene-based apps get)
        // This sends OPEN #1
        Branch.getInstance().initSession(launchOptions: nil) { params, error in
            self.writeDebugLog("STEP 1 CALLBACK: initSession callback received")
            self.handleBranchCallback(params: params as? [String: AnyObject], error: error)
        }

        writeDebugLog("STEP 1: initSession() call returned (async)")

        // STEP 2: Process URLs from connectionOptions
        // This triggers OPEN #2 - THE BUG!
        if let urlContext = connectionOptions.urlContexts.first {
            let url = urlContext.url
            writeDebugLog("STEP 2: URL FOUND in connectionOptions!")
            writeDebugLog("STEP 2: URL = \(url.absoluteString)")

            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[URL] Step 2: Processing URL separately")
            appDelegate.store.addLogEntry("[URL] \(url.absoluteString)")
            appDelegate.store.addLogEntry("[URL] → Using Branch.application(_:open:options:)")
            appDelegate.store.addLogEntry("[URL] → This triggers OPEN #2! 🐛")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            writeDebugLog("STEP 2: Calling Branch.getInstance().application(_:open:options:)")

            // This causes the second OPEN request - THE BUG!
            Branch.getInstance().application(
                UIApplication.shared,
                open: url,
                options: [:]
            )

            writeDebugLog("STEP 2: Branch.application() call returned")
        } else {
            writeDebugLog("STEP 2: NO URL in connectionOptions - urlContexts is EMPTY!")
            writeDebugLog("STEP 2: This explains why only 1 OPEN is sent")
        }

        // Handle Universal Links - also causes double OPEN
        if let userActivity = connectionOptions.userActivities.first,
           let url = userActivity.webpageURL
        {
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate.store.addLogEntry("[UL] Step 2: Processing Universal Link separately")
            appDelegate.store.addLogEntry("[UL] \(url.absoluteString)")
            appDelegate.store.addLogEntry("[UL] → Using Branch.continue(_:)")
            appDelegate.store.addLogEntry("[UL] → This triggers OPEN #2! 🐛")
            appDelegate.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            Branch.getInstance().continue(userActivity)
        }
    }

    // MARK: - URL Opened After Scene Connect (Warm Launch or Delayed Cold Launch)

    // Track if initSession has been called to differentiate cold vs warm launch
    private var sessionInitialized = false

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first else { return }
        let url = urlContext.url

        writeDebugLog("═══════════════════════════════════════════════════")
        writeDebugLog("scene:openURLContexts CALLED")
        writeDebugLog("URL: \(url.absoluteString)")
        writeDebugLog("sessionInitialized: \(sessionInitialized)")

        print("[BLS] scene:openURLContexts - \(url)")

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: Check if session was deferred
            if !sessionInitialized {
                // Session was deferred - this is a cold launch with URL arriving late
                // Call initSession NOW with the URL, this will be the ONLY OPEN request
                writeDebugLog("NEW API: Session was DEFERRED - calling initSession now WITH URL")
                writeDebugLog("This is the ONLY OPEN that will be sent! ✅")

                appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                appDelegate?.store.addLogEntry("[URL] URL received via scene:openURLContexts")
                appDelegate?.store.addLogEntry("[URL] \(url.absoluteString)")
                appDelegate?.store.addLogEntry("[URL] → Session was DEFERRED (no premature OPEN)")
                appDelegate?.store.addLogEntry("[URL] → Calling initSession NOW with URL")
                appDelegate?.store.addLogEntry("[URL] → This is the ONLY OPEN! ✅")
                appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                sessionInitialized = true

                // For deferred cold launch with URL, we need to:
                // 1. NOT call initSession separately (it would send OPEN without link)
                // 2. Just call scene:openURLContexts - BranchScene should handle init internally
                // This is the key: let BranchScene handle the session init WITH the URL
                BranchScene.shared().scene(scene, openURLContexts: URLContexts)
            } else {
                // Session already initialized - this is a warm launch
                writeDebugLog("NEW API: Session already initialized - warm launch URL handling")

                appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                appDelegate?.store.addLogEntry("[URL] URL received via scene:openURLContexts (warm launch)")
                appDelegate?.store.addLogEntry("[URL] \(url.absoluteString)")
                appDelegate?.store.addLogEntry("[URL] → Using BranchScene for warm launch")
                appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                BranchScene.shared().scene(scene, openURLContexts: URLContexts)
            }
        } else {
            // OLD API: This will always trigger an additional OPEN request
            writeDebugLog("OLD API: Using Branch.getInstance().application(_:open:)")
            writeDebugLog("This triggers OPEN request → DOUBLE-OPEN BUG!")

            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate?.store.addLogEntry("[URL] URL received via scene:openURLContexts")
            appDelegate?.store.addLogEntry("[URL] \(url.absoluteString)")
            appDelegate?.store.addLogEntry("[URL] → Using Branch.application (triggers OPEN)")
            appDelegate?.store.addLogEntry("[URL] → This causes DOUBLE-OPEN! 🐛")
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

        writeDebugLog("═══════════════════════════════════════════════════")
        writeDebugLog("scene:continue CALLED")
        if let url = userActivity.webpageURL {
            writeDebugLog("URL: \(url.absoluteString)")
        }

        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")

        if useNewAPI {
            // NEW API: Use BranchScene
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate?.store.addLogEntry("[UL] Universal Link via scene:continue")
            if let url = userActivity.webpageURL {
                appDelegate?.store.addLogEntry("[UL] \(url.absoluteString)")
            }
            appDelegate?.store.addLogEntry("[UL] → Using BranchScene (deduplicates internally)")
            appDelegate?.store.addLogEntry("[UL] → No double OPEN! ✅")
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            BranchScene.shared().scene(scene, continue: userActivity)
        } else {
            // OLD API: This will trigger an additional OPEN
            appDelegate?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            appDelegate?.store.addLogEntry("[UL] Universal Link via scene:continue")
            if let url = userActivity.webpageURL {
                appDelegate?.store.addLogEntry("[UL] \(url.absoluteString)")
            }
            appDelegate?.store.addLogEntry("[UL] → Using Branch.continue (triggers OPEN)")
            appDelegate?.store.addLogEntry("[UL] → This causes DOUBLE-OPEN! 🐛")
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
