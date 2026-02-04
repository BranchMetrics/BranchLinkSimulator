//
//  AppDelegate.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import BranchSDK
import BranchSwiftSDK
import SwiftUI

struct AlertItem: Identifiable {
    var id: String { message }
    var message: String
}

class DeepLinkViewModel: ObservableObject {
    @Published var deepLinkHandled = false
    @Published var deepLinkData: [String: AnyObject]? = nil
    @Published var errorItem: AlertItem? = nil
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkViewModel = DeepLinkViewModel()
    var store = RoundTripStore()

    /// Reference to the modern SessionManager
    private var sessionManager: SessionManager {
        SessionManager.shared
    }

    /// Convenience logger
    private var logger: BranchLogger {
        BranchLogger.shared()
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let config = loadConfigOrDefault()

        // Configure the SDK for API URL and Branch Key
        Branch.setAPIUrl(config.apiUrl)
        Branch.setBranchKey(config.branchKey)

        // Enable verbose logging with callback for console output and RoundTripStore
        Branch.enableLogging(at: .verbose) { message, logLevel, error, request, response in
            // Log to console (os_log doesn't show verbose/debug in Xcode console)
            let levelStr: String
            switch logLevel {
            case .verbose: levelStr = "VERBOSE"
            case .debug: levelStr = "DEBUG"
            case .warning: levelStr = "WARNING"
            case .error: levelStr = "ERROR"
            @unknown default: levelStr = "UNKNOWN"
            }
            var fullMessage = "[BranchSDK][\(levelStr)] \(message ?? "")"
            if let error = error {
                fullMessage += " Error: \(error.localizedDescription)"
            }
            NSLog("%@", fullMessage)

            // Process for RoundTripStore
            self.store.processLog(request, response)
        }

        // Retrieve or create the bls_session_id
        let blsSessionId: String
        if let savedId = UserDefaults.standard.string(forKey: "blsSessionId") {
            blsSessionId = savedId
        } else {
            blsSessionId = UUID().uuidString
            UserDefaults.standard.set(blsSessionId, forKey: "blsSessionId")
        }

        // Set the bls_session_id in Branch request metadata
        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: blsSessionId)

        // MARK: - Initialize with Modern SessionManager

        // Use the new Swift SessionManager for initialization
        // This provides task coalescing, async/await support, and syncs to BNCPreferenceHelper
        // so that Legacy SDK features (events, links, QR codes) continue to work

        let options = InitializationOptions()
            .with(launchOptions: launchOptions)

        logger.logVerbose("Initializing with Modern SessionManager...", error: nil)

        sessionManager.initialize(options: options) { [weak self] session, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.logError("SessionManager init error: \(error.localizedDescription)", error: error)
                var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                if config.staging {
                    message += " Are you connected to VPN?"
                }
                self.deepLinkViewModel.errorItem = AlertItem(message: message)
            } else if let session = session {
                self.logger.logVerbose("SessionManager initialized successfully!", error: nil)
                self.logger.logDebug("Session ID: \(session.id)", error: nil)
                self.logger.logDebug("Identity ID: \(session.identityId)", error: nil)
                self.logger.logDebug("Device Fingerprint: \(session.deviceFingerprintId)", error: nil)
                self.logger.logDebug("Is First Session: \(session.isFirstSession)", error: nil)
                self.logger.logDebug("Params: \(session.params)", error: nil)

                // Handle deep link data if present
                self.handleSessionInitialized(session)
            }
        }

        return true
    }

    // MARK: - Session Handling

    /// Handle successful session initialization
    private func handleSessionInitialized(_ session: Session) {
        // Check if there's deep link data
        let clickedBranchLink = session.params["+clicked_branch_link"] as? Bool ?? false

        if clickedBranchLink || session.hasDeepLinkData {
            logger.logVerbose("Deep link detected!", error: nil)
            logger.logDebug("Deep link params: \(session.params)", error: nil)

            // Convert params to the format expected by the UI
            var displayParams: [String: AnyObject] = [:]
            displayParams["+clicked_branch_link"] = true as AnyObject
            displayParams["session_id"] = session.id as AnyObject
            displayParams["identity_id"] = session.identityId as AnyObject
            displayParams["+is_first_session"] = session.isFirstSession as AnyObject

            // Copy all params from session
            for (key, value) in session.params {
                displayParams[key] = value as AnyObject
            }

            deepLinkViewModel.deepLinkData = displayParams
            deepLinkViewModel.deepLinkHandled = true
        } else {
            logger.logVerbose("No deep link data - organic session", error: nil)
        }
    }

    // MARK: - Universal Links

    func application(
        _: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL
        else {
            return false
        }

        logger.logVerbose("Received Universal Link: \(url)", error: nil)

        // Handle via Modern SessionManager
        sessionManager.handleDeepLink(url) { [weak self] session, error in
            if let session = session {
                self?.handleSessionInitialized(session)
            } else if let error = error {
                self?.logger.logError("Universal Link error: \(error.localizedDescription)", error: error)
            }
        }

        return true
    }

    // MARK: - URL Scheme Deep Links

    func application(
        _: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        logger.logVerbose("Received URL Scheme: \(url)", error: nil)

        // Handle via Modern SessionManager
        sessionManager.handleDeepLink(url) { [weak self] session, error in
            if let session = session {
                self?.handleSessionInitialized(session)
            } else if let error = error {
                self?.logger.logError("URL Scheme error: \(error.localizedDescription)", error: error)
            }
        }

        return true
    }
}
