//
//  AppDelegate.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK

<<<<<<< HEAD
class DeepLinkViewModel: ObservableObject {
    @Published var deepLinkHandled = false
    @Published var deepLinkData: [String: AnyObject]? = nil
=======
struct AlertItem: Identifiable {
    var id: String { message }
    var message: String
}

class DeepLinkViewModel: ObservableObject {
    @Published var deepLinkHandled = false
    @Published var deepLinkData: [String: AnyObject]? = nil
    @Published var errorItem: AlertItem? = nil
>>>>>>> 7631405 ([other] ENGMT-1881: updates for staging)
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkViewModel = DeepLinkViewModel()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
<<<<<<< HEAD
        Branch.setAPIUrl("https://protected-api.branch.io")
        Branch.getInstance().enableLogging()
=======
        let config = loadConfigOrDefault()
        Branch.setAPIUrl(config.apiUrl)
        Branch.setBranchKey(config.branchKey)
        
        Branch.enableLogging(at: .debug) { msg, logLevel, err in
            processLog(msg)
        }
>>>>>>> 7631405 ([other] ENGMT-1881: updates for staging)

        // Retrieve or create the bls_session_id
        let blsSessionId: String
        if let savedId = UserDefaults.standard.string(forKey: "blsSessionId") {
            blsSessionId = savedId
        } else {
            // Generate a new UUID if one does not exist
            blsSessionId = UUID().uuidString
            UserDefaults.standard.set(blsSessionId, forKey: "blsSessionId")
        }
        
        // Set the bls_session_id in Branch request metadata
        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: blsSessionId)

        Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
            print(params as? [String: AnyObject] ?? {})
<<<<<<< HEAD
=======
            if let error = error {
                var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                if config.staging {
                  message += " Are you connected to VPN?"
                }
                self.deepLinkViewModel.errorItem = AlertItem(message: message)
            }
>>>>>>> 7631405 ([other] ENGMT-1881: updates for staging)
            if let params = params as? [String: AnyObject] {
                if let clickedBranchLink = params["+clicked_branch_link"] as? NSNumber, clickedBranchLink.boolValue == true {
                    DispatchQueue.main.async {
                        self.deepLinkViewModel.deepLinkData = params
                        self.deepLinkViewModel.deepLinkHandled = true
                    }
                } else {
                    print("Didn't click Branch link")
                }

            }
        }
        
        return true
    }
    
}
