//
//  AppDelegate.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import BranchSDK
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

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Branch SDK (but don't initialize - SceneDelegate will do that)
        let config = loadConfigOrDefault()
        Branch.setAPIUrl(config.apiUrl)
        Branch.setBranchKey(config.branchKey)

        // Register URLProtocol interceptor BEFORE any Branch calls
        // This intercepts ALL Branch network requests to count OPENs
        BranchNetworkInterceptor.store = store
        URLProtocol.registerClass(BranchNetworkInterceptor.self)
        store.addLogEntry("[APP] URLProtocol interceptor registered")

        // Enable verbose logging with basic callback (SDK 3.5.0 compatible)
        // SDK 3.5.0 only has 3-param callback: (message, logLevel, error)
        // Parse log messages to detect OPEN requests
        Branch.enableLogging(at: .verbose) { [weak self] message, _, _ in
            // Log all Branch messages for debugging
            self?.store.addLogEntry("[SDK] \(message)")

            // Detect OPEN requests from log messages
            // SDK logs requests like: "<NSMutableURLRequest: 0x...> https://api.branch.io/v1/open"
            // Also logs: "makeRequest [BranchOpenRequest]" or similar
            let lowerMessage = message.lowercased()
            let isOpenRequest = lowerMessage.contains("/v1/open") ||
                lowerMessage.contains("v1/open") ||
                lowerMessage.contains("branchopenrequest") ||
                (lowerMessage.contains("api.branch.io") && lowerMessage.contains("open"))

            if isOpenRequest {
                self?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                self?.store.addLogEntry("🔴 OPEN REQUEST DETECTED from SDK log!")
                self?.store.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Add round trip for counting
                let branchRequest = BranchRequest(
                    headers: "SDK log detection",
                    body: message
                )
                self?.store.addRoundTrip(with: branchRequest, url: "/v1/open")
            }
        }

        // Retrieve or create the bls_session_id
        let blsSessionId: String
        if let savedId = UserDefaults.standard.string(forKey: "blsSessionId") {
            blsSessionId = savedId
        } else {
            blsSessionId = UUID().uuidString
            UserDefaults.standard.set(blsSessionId, forKey: "blsSessionId")
        }

        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: blsSessionId)

        // Log launch info
        let useNewAPI = UserDefaults.standard.bool(forKey: "useDoubleOpenFix")
        store.addLogEntry("[APP] didFinishLaunching - API mode: \(useNewAPI ? "NEW (fix)" : "OLD")")

        if let url = launchOptions?[.url] as? URL {
            store.addLogEntry("[APP] Launch URL: \(url.absoluteString)")
        }

        // NOTE: Branch initialization moved to SceneDelegate
        // This allows testing both OLD and NEW APIs

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("[BLS-AppDelegate] configurationForConnecting called")
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        // Explicitly set the delegate class to ensure SceneDelegate is used
        config.delegateClass = SceneDelegate.self
        print("[BLS-AppDelegate] Returning config with delegateClass: \(String(describing: config.delegateClass))")
        return config
    }
}
