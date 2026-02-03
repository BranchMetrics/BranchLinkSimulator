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
    // Note: Session state is now managed by SDK's BranchObservableState
    // Access via: BranchSessionCoordinator.shared.observableState.stateDescription
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkViewModel = DeepLinkViewModel()
    var store = RoundTripStore()

    /// Task for observing network logs (keeps the stream alive)
    private var logObserverTask: Task<Void, Never>?

    /// Reference to the modern SessionManager via BranchSessionCoordinator
    private var sessionCoordinator: BranchSessionCoordinator {
        BranchSessionCoordinator.shared
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let config = loadConfigOrDefault()

        // Configure the legacy SDK for API URL and Branch Key
        // (still needed for network layer configuration)
        Branch.setAPIUrl(config.apiUrl)
        Branch.setBranchKey(config.branchKey)

        // Legacy SDK logging (for events, links, QR codes)
        Branch.enableLogging(at: .verbose) { _, _, _, request, response in
            self.store.processLog(request, response)
        }

        // MARK: - Modern AsyncStream Logging (Swift Concurrency)

        // Start observing BEFORE any Branch initialization to capture all logs
        // This uses AsyncStream which buffers logs until observer attaches
        startNetworkLogObserver()

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

        // Use the NEW SessionManager for initialization
        initializeWithModernSessionManager(launchOptions: launchOptions, config: config)

        // Note: Session state observation is handled automatically by SDK's BranchObservableState
        // SwiftUI views can use: @ObservedObject var branchState = BranchSessionCoordinator.shared.observableState

        return true
    }

    // MARK: - Modern Network Log Observer (AsyncStream)

    /// Start observing network logs using modern Swift Concurrency.
    ///
    /// This approach:
    /// - Uses `AsyncStream` which automatically buffers logs
    /// - Eliminates race conditions (logs captured even before observer starts)
    /// - Uses `for await` for reactive processing
    /// - Is fully thread-safe via Actor isolation
    private func startNetworkLogObserver() {
        logObserverTask = Task { [weak self] in
            guard let self else { return }

            print("[BranchLinkSimulator] Starting AsyncStream network log observer...")

            // Process logs as they arrive (buffered logs flush immediately)
            for await entry in BranchNetworkLogger.shared.logStream {
                // Convert NetworkLogEntry to the format expected by RoundTripStore
                await MainActor.run {
                    self.processNetworkLogEntry(entry)
                }
            }

            print("[BranchLinkSimulator] Network log observer ended")
        }
    }

    /// Process a NetworkLogEntry from the modern logger
    @MainActor
    private func processNetworkLogEntry(_ entry: NetworkLogEntry) {
        // Convert Sendable dictionary back to [String: Any] for compatibility
        let requestBody = entry.requestBody as [String: Any]
        let responseBody = entry.responseBody as? [String: Any]

        store.processSwiftNetworkLog(
            url: entry.url,
            requestBody: requestBody,
            responseBody: responseBody,
            statusCode: entry.statusCode,
            error: entry.error.map { NSError(domain: "BranchNetwork", code: -1, userInfo: [NSLocalizedDescriptionKey: $0]) }
        )
    }

    deinit {
        logObserverTask?.cancel()
    }

    // MARK: - Modern SessionManager Integration

    /// Initialize Branch using the new Swift SessionManager with task coalescing
    @MainActor
    private func initializeWithModernSessionManager(
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?,
        config: ApiConfiguration
    ) {
        Task {
            do {
                // Build initialization options using the builder pattern
                let options = InitializationOptions()
                    .with(launchOptions: launchOptions)

                print("[BranchLinkSimulator] Initializing with modern SessionManager...")

                // Initialize using the new SessionManager
                let session = try await sessionCoordinator.sessionManager.initialize(options: options)

                print("[BranchLinkSimulator] Session initialized: \(session)")

                // Convert session to params format for UI compatibility
                await MainActor.run {
                    handleSessionInitialized(session, config: config)
                }

            } catch {
                print("[BranchLinkSimulator] Session initialization failed: \(error)")

                await MainActor.run {
                    var message = "Failed to initialize Branch SDK: \(error.localizedDescription)."
                    if config.staging {
                        message += " Are you connected to VPN?"
                    }
                    self.deepLinkViewModel.errorItem = AlertItem(message: message)
                }
            }
        }
    }

    /// Handle session for UI updates (called from BranchLinkSimulatorApp onOpenURL)
    @MainActor
    func handleSessionForUI(_ session: Session) {
        let config = loadConfigOrDefault()
        handleSessionInitialized(session, config: config)
    }

    /// Handle successful session initialization
    @MainActor
    private func handleSessionInitialized(_ session: Session, config _: ApiConfiguration) {
        print("[BranchLinkSimulator] Session ID: \(session.id)")
        print("[BranchLinkSimulator] Identity ID: \(session.identityId)")
        print("[BranchLinkSimulator] Is First Session: \(session.isFirstSession)")

        // Check if there's deep link data
        if let linkData = session.linkData {
            print("[BranchLinkSimulator] Deep link detected: \(linkData)")

            // Convert to the format expected by the existing UI
            var params: [String: AnyObject] = [:]
            params["+clicked_branch_link"] = true as AnyObject
            params["session_id"] = session.id as AnyObject
            params["identity_id"] = session.identityId as AnyObject
            params["+is_first_session"] = session.isFirstSession as AnyObject

            if let url = linkData.url {
                params["~referring_link"] = url.absoluteString as AnyObject
            }

            // Add custom parameters from link data
            for (key, value) in linkData.parameters {
                params[key] = value.value as AnyObject
            }

            deepLinkViewModel.deepLinkData = params
            deepLinkViewModel.deepLinkHandled = true
        } else {
            print("[BranchLinkSimulator] No deep link data - organic session")
        }
    }

    // MARK: - Universal Links (Scene-based apps)

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

        print("[BranchLinkSimulator] Received Universal Link: \(url)")

        // Handle via the new SessionManager (task coalescing will merge if initialization is in progress)
        Task {
            do {
                var options = InitializationOptions()
                options.url = url

                let session = try await sessionCoordinator.sessionManager.initialize(options: options)

                await MainActor.run {
                    let config = loadConfigOrDefault()
                    handleSessionInitialized(session, config: config)
                }
            } catch {
                print("[BranchLinkSimulator] Universal Link handling failed: \(error)")
            }
        }

        return true
    }

    // MARK: - URL Scheme Deep Links

    func application(
        _: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("[BranchLinkSimulator] Received URL Scheme: \(url)")

        Task {
            do {
                var initOptions = InitializationOptions()
                initOptions.url = url
                initOptions.sourceApplication = options[.sourceApplication] as? String

                let session = try await sessionCoordinator.sessionManager.initialize(options: initOptions)

                await MainActor.run {
                    let config = loadConfigOrDefault()
                    handleSessionInitialized(session, config: config)
                }
            } catch {
                print("[BranchLinkSimulator] URL Scheme handling failed: \(error)")
            }
        }

        return true
    }
}
