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
        
        Branch.getInstance().enableLogging()
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
