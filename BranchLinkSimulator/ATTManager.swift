//
//  ATTManager.swift
//  BranchLinkSimulator
//
//  Created for comprehensive ATT testing
//

import Foundation
import AppTrackingTransparency
import AdSupport
import SwiftUI

/// Comprehensive ATT (App Tracking Transparency) Manager for testing all scenarios
class ATTManager: ObservableObject {

    // MARK: - Published Properties
    @Published var authorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published var idfa: String = "00000000-0000-0000-0000-000000000000"
    @Published var lastRequestDate: Date?
    @Published var statusHistory: [ATTStatusEntry] = []

    // MARK: - Initialization
    init() {
        // Initialize synchronously to avoid race conditions with SwiftUI view rendering
        // This ensures the view has valid data immediately upon first render
        if #available(iOS 14, *) {
            authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        } else {
            authorizationStatus = .authorized
        }
        updateIDFA()

        // Add initial history entry
        addStatusEntry(status: authorizationStatus, event: "App Initialized")
    }

    // MARK: - Public Methods

    /// Request IDFA permission from the user
    /// - Parameter completion: Callback with the authorization status
    func requestIDFAPermission(completion: ((ATTrackingManager.AuthorizationStatus) -> Void)? = nil) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                guard let self = self else { return }

                // Ensure all UI updates happen on main thread
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    self.lastRequestDate = Date()
                    self.updateIDFA()
                    self.addStatusEntry(status: status, event: "Permission Requested")

                    self.logStatusChange(status: status)
                    completion?(status)
                }
            }
        } else {
            // For iOS versions < 14, tracking is allowed by default
            DispatchQueue.main.async {
                self.authorizationStatus = .authorized
                self.updateIDFA()
                completion?(.authorized)
            }
        }
    }

    /// Update the current authorization status
    func updateCurrentStatus() {
        DispatchQueue.main.async {
            if #available(iOS 14, *) {
                self.authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
            } else {
                self.authorizationStatus = .authorized
            }
            self.updateIDFA()
        }
    }

    /// Get detailed status information
    func getStatusInfo() -> ATTStatusInfo {
        return ATTStatusInfo(
            status: authorizationStatus,
            idfa: idfa,
            lastRequestDate: lastRequestDate,
            isTrackingEnabled: authorizationStatus == .authorized,
            canRequestPermission: authorizationStatus == .notDetermined
        )
    }

    /// Check if we can show the ATT prompt
    func canShowATTPrompt() -> Bool {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .notDetermined
        }
        return false
    }

    /// Reset tracking status (for testing - requires app reinstall in production)
    func resetForTesting() {
        DispatchQueue.main.async {
            self.statusHistory.removeAll()
            self.updateCurrentStatus()
            // Add status entry after updateCurrentStatus completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.addStatusEntry(status: self.authorizationStatus, event: "Status Reset for Testing")
            }
        }
    }

    // MARK: - Private Methods

    private func updateIDFA() {
        if authorizationStatus == .authorized {
            let idfaUUID = ASIdentifierManager.shared().advertisingIdentifier
            self.idfa = idfaUUID.uuidString
        } else {
            self.idfa = "00000000-0000-0000-0000-000000000000"
        }
    }

    private func logStatusChange(status: ATTrackingManager.AuthorizationStatus) {
        let statusString = statusToString(status)
        print("📊 ATT Status Changed: \(statusString)")
        print("📱 IDFA: \(idfa)")
    }

    private func addStatusEntry(status: ATTrackingManager.AuthorizationStatus, event: String) {
        let entry = ATTStatusEntry(
            date: Date(),
            status: status,
            idfa: idfa,
            event: event
        )
        statusHistory.insert(entry, at: 0)

        // Keep only last 50 entries
        if statusHistory.count > 50 {
            statusHistory = Array(statusHistory.prefix(50))
        }
    }

    func statusToString(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }

    func statusToEmoji(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "❓"
        case .restricted:
            return "🔒"
        case .denied:
            return "❌"
        case .authorized:
            return "✅"
        @unknown default:
            return "⚠️"
        }
    }
}

// MARK: - Supporting Types

struct ATTStatusInfo {
    let status: ATTrackingManager.AuthorizationStatus
    let idfa: String
    let lastRequestDate: Date?
    let isTrackingEnabled: Bool
    let canRequestPermission: Bool
}

struct ATTStatusEntry: Identifiable {
    let id = UUID()
    let date: Date
    let status: ATTrackingManager.AuthorizationStatus
    let idfa: String
    let event: String
}
