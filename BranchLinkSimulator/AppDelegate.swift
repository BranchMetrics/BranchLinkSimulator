//
//  AppDelegate.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK

class DeepLinkViewModel: ObservableObject {
    @Published var deepLinkHandled = false
    @Published var deepLinkData: [String: AnyObject]? = nil
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkViewModel = DeepLinkViewModel()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        Branch.setAPIUrl("https://protected-api-test.branch.io")
        Branch.getInstance().enableLogging()
        
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
