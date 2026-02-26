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
    @Published var callbackStatus: String = "waiting"
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkViewModel = DeepLinkViewModel()
    var store = RoundTripStore()

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
            // Generate a new UUID if one does not exist
            blsSessionId = UUID().uuidString
            UserDefaults.standard.set(blsSessionId, forKey: "blsSessionId")
        }

        // Set the bls_session_id in Branch request metadata
        Branch.getInstance().setRequestMetadataKey("bls_session_id", value: blsSessionId)

        let isUITestMode = ProcessInfo.processInfo.arguments.contains("--ui-test-mode")
        let useSceneDelegate = ProcessInfo.processInfo.arguments.contains("--use-scene-delegate")

        if useSceneDelegate && isUITestMode {
            // BranchScene test mode: init via BranchScene API once the scene is available
            initViaBranchScene(config: config)
            return true
        }

        if isUITestMode {
            // UI Test Mode: simple init + deep link injection (no alpha runner)
            // Track whether handleDeepLink was called so we can navigate on its callback
            var deepLinkInjected = false

            Branch.getInstance().initSession(launchOptions: launchOptions) { params, error in
                print("[UITest] callback fired, deepLinkInjected=\(deepLinkInjected), params=\(params as? [String: AnyObject] ?? [:])")

                DispatchQueue.main.async {
                    self.deepLinkViewModel.callbackStatus = error == nil ? "callback_received" : "callback_error"
                }

                if let error = error {
                    var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                    if config.staging {
                        message += " Are you connected to VPN?"
                    }
                    self.deepLinkViewModel.errorItem = AlertItem(message: message)
                }

                if let params = params as? [String: AnyObject] {
                    // In test mode: navigate if handleDeepLink triggered this callback
                    // (regardless of +clicked_branch_link value)
                    let clickedLink = (params["+clicked_branch_link"] as? NSNumber)?.boolValue == true
                    if clickedLink || deepLinkInjected {
                        DispatchQueue.main.async {
                            self.deepLinkViewModel.deepLinkData = params
                            self.deepLinkViewModel.deepLinkHandled = true
                        }
                    }
                }
            }

            // Inject test deep link after SDK initialization
            if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--test-deep-link=") }) {
                let urlString = String(arg.dropFirst("--test-deep-link=".count))
                if let url = URL(string: urlString) {
                    let isWarm = ProcessInfo.processInfo.arguments.contains("--warm-launch")
                    let delay: TimeInterval = isWarm ? 8.0 : 3.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        deepLinkInjected = true
                        Branch.getInstance().handleDeepLink(url)
                    }
                }
            }
        } else {
            // Normal Mode: Alpha Test Runner + init
            let runner = AlphaTestRunner.shared
            runner.store = store

            runner.runPreInitTests {
                Branch.getInstance().initSession(launchOptions: launchOptions) { params, error in
                    runner.initCallbackReceived = true
                    print(params as? [String: AnyObject] ?? {})
                    if let error = error {
                        var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                        if config.staging {
                            message += " Are you connected to VPN?"
                        }
                        self.deepLinkViewModel.errorItem = AlertItem(message: message)
                    }
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

                    // Alpha Test Runner: post-init tests
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        runner.runPostInitTests()
                    }
                }

                // Test 5a: send event 1s after initSession call (while v1/open is in-flight)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let queueTestEvent = BranchEvent.standardEvent(.purchase)
                    queueTestEvent.alias = "queue_test_5a"
                    queueTestEvent.logEvent { _, error in
                        runner.queueTestEventCompleted = true
                        runner.queueTestEventError = error
                    }
                }
            }
        }

        return true
    }

    // MARK: - BranchScene Init (Tests 8a-8d)

    /// Initialize Branch via the BranchScene API instead of Branch.initSession.
    /// Waits for SwiftUI's scene to activate, then calls
    /// `BranchScene.shared().initSessionWithSceneOptions(_:scene:)`.
    private func initViaBranchScene(config: ApiConfiguration) {
        var deepLinkInjected = false
        var sceneObserver: NSObjectProtocol?

        sceneObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let scene = notification.object as? UIScene else { return }

            // Only init once
            if let obs = sceneObserver {
                NotificationCenter.default.removeObserver(obs)
                sceneObserver = nil
            }

            BranchScene.shared().initSession(withSceneOptions: nil, scene: scene) { params, error, _ in
                print("[UITest-Scene] callback fired, deepLinkInjected=\(deepLinkInjected), params=\(params as? [String: AnyObject] ?? [:])")

                DispatchQueue.main.async {
                    self.deepLinkViewModel.callbackStatus = error == nil ? "callback_received" : "callback_error"
                }

                if let error = error {
                    var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                    if config.staging {
                        message += " Are you connected to VPN?"
                    }
                    self.deepLinkViewModel.errorItem = AlertItem(message: message)
                }

                if let params = params as? [String: AnyObject] {
                    let clickedLink = (params["+clicked_branch_link"] as? NSNumber)?.boolValue == true
                    if clickedLink || deepLinkInjected {
                        DispatchQueue.main.async {
                            self.deepLinkViewModel.deepLinkData = params
                            self.deepLinkViewModel.deepLinkHandled = true
                        }
                    }
                }
            }
        }

        // Inject test deep link after SDK initialization
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--test-deep-link=") }) {
            let urlString = String(arg.dropFirst("--test-deep-link=".count))
            if let url = URL(string: urlString) {
                let isWarm = ProcessInfo.processInfo.arguments.contains("--warm-launch")
                let delay: TimeInterval = isWarm ? 8.0 : 3.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    deepLinkInjected = true
                    Branch.getInstance().handleDeepLink(url)
                }
            }
        }
    }
}
