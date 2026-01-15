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

        Branch.enableLogging(at: .verbose) { _, _, _, request, response in
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
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
