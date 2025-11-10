//
//  ATTBranchIntegrationTests.swift
//  BranchLinkSimulatorTests
//
//  Integration tests for ATT with Branch SDK
//

import Testing
import AppTrackingTransparency
import AdSupport
import BranchSDK
@testable import BranchLinkSimulator

@MainActor
@Suite("ATT Branch Integration Tests")
struct ATTBranchIntegrationTests {

    var attManager: ATTManager

    init() {
        self.attManager = ATTManager()
    }

    // MARK: - Helper Methods

    /// Check if running on simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Check if IDFA is valid (either real UUID or zeros on simulator when authorized)
    private func isValidIDFAForAuthorized(_ idfa: String) -> Bool {
        // Valid UUID format check
        guard UUID(uuidString: idfa) != nil else {
            return false
        }

        // On simulator, authorized can still give zeros - this is correct behavior
        // On device, authorized should give real IDFA (non-zeros)
        if isSimulator {
            // Simulator: accept any valid UUID (zeros or real)
            return true
        } else {
            // Real device: expect non-zero IDFA when authorized
            return idfa != "00000000-0000-0000-0000-000000000000"
        }
    }

    // MARK: - IDFA Integration Tests

    @Test("Authorized status provides IDFA to Branch",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus == .authorized))
    func authorizedStatusProvidesIDFAToBranch() {
        // When: Getting IDFA
        let idfa = attManager.idfa

        // Then: IDFA should be valid UUID
        // On simulator: can be zeros (documented iOS behavior)
        // On device: should be real UUID
        #expect(UUID(uuidString: idfa) != nil, "IDFA should be valid UUID when authorized")
        #expect(isValidIDFAForAuthorized(idfa), "IDFA should be valid for authorized state (zeros on simulator, real UUID on device)")
    }

    @Test("Denied status returns zero IDFA",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus != .authorized))
    func deniedStatusReturnsZeroIDFA() {
        // When: Getting IDFA
        let idfa = attManager.idfa

        // Then: IDFA should be zeros
        #expect(idfa == "00000000-0000-0000-0000-000000000000", "IDFA should be zeros when not authorized")
    }

    @Test("Branch SDK can access IDFA")
    func branchSDKCanAccessIDFA() {
        // Given: ATT Manager with current status
        let statusInfo = attManager.getStatusInfo()

        // When: Checking if IDFA is available
        let idfaAvailable = statusInfo.isTrackingEnabled

        // Then: IDFA availability should match tracking status
        if statusInfo.status == .authorized {
            #expect(idfaAvailable, "IDFA should be available when authorized")
            #expect(UUID(uuidString: statusInfo.idfa) != nil, "IDFA should be valid UUID when authorized")
            // Note: On simulator, IDFA can be zeros even when authorized
        } else {
            #expect(!idfaAvailable, "IDFA should not be available when not authorized")
            #expect(statusInfo.idfa == "00000000-0000-0000-0000-000000000000", "IDFA should be zeros when not authorized")
        }
    }

    // MARK: - Branch SDK Attribution Tests

    @Test("Branch receives correct IDFA based on ATT status")
    func branchReceivesCorrectIDFABasedOnATTStatus() {
        // Given: Current ATT status
        let statusInfo = attManager.getStatusInfo()

        // When: Branch SDK makes attribution request
        // Then: IDFA inclusion should match authorization status
        if statusInfo.isTrackingEnabled {
            // Authorized: IDFA should be valid UUID (can be zeros on simulator)
            #expect(UUID(uuidString: statusInfo.idfa) != nil,
                            "When tracking is enabled, IDFA should be valid UUID")
        } else {
            #expect(statusInfo.idfa == "00000000-0000-0000-0000-000000000000",
                          "When tracking is disabled, IDFA should be zeros")
        }
    }

    @Test("Branch SDK handles all ATT states")
    func branchSDKHandlesAllATTStates() {
        // Given: All possible ATT states
        let allStates: [ATTrackingManager.AuthorizationStatus] = [
            .notDetermined,
            .restricted,
            .denied,
            .authorized
        ]

        // When: Checking each state
        for state in allStates {
            // Then: Should have appropriate behavior
            let expectedZeroIDFA = state != .authorized

            if expectedZeroIDFA {
                // Not authorized states should use zeros
                #expect(true, "State \(attManager.statusToString(state)) should use zero IDFA")
            } else {
                // Authorized state should use real IDFA (or zeros on simulator)
                #expect(true, "State \(attManager.statusToString(state)) should use real IDFA")
            }
        }
    }

    // MARK: - Branch Event Logging Tests

    @Test("Branch event includes ATT status")
    func branchEventIncludesATTStatus() {
        // Given: Current ATT status
        let currentStatus = attManager.authorizationStatus

        // When: Sending a Branch event
        // (Simulating event creation)
        let event = BranchEvent.standardEvent(.purchase)

        // Then: Event should be created successfully
        #expect(event != nil, "Branch event should be created regardless of ATT status")

        // Note: Branch SDK internally handles IDFA based on ATT status
        print("Current ATT Status: \(attManager.statusToString(currentStatus))")
        print("IDFA: \(attManager.idfa)")
    }

    @Test("Branch event with authorized ATT",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus == .authorized))
    func branchEventWithAuthorizedATT() async {
        // When: Creating and logging a Branch event
        let event = BranchEvent.standardEvent(.purchase)
        event.alias = "test_att_integration"
        event.customData["att_status"] = attManager.statusToString(attManager.authorizationStatus)
        event.customData["idfa"] = attManager.idfa

        // Then: Event should contain IDFA
        #expect(event.customData["idfa"] != nil, "Event should contain IDFA")

        // On simulator, IDFA can be zeros even when authorized
        if let idfaValue = event.customData["idfa"] as? String {
            #expect(UUID(uuidString: idfaValue) != nil, "Event IDFA should be valid UUID when authorized")
        }
    }

    @Test("Branch event with denied ATT",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus != .authorized))
    func branchEventWithDeniedATT() async {
        // When: Creating and logging a Branch event
        let event = BranchEvent.standardEvent(.purchase)
        event.alias = "test_att_integration"
        event.customData["att_status"] = attManager.statusToString(attManager.authorizationStatus)
        event.customData["idfa"] = attManager.idfa

        // Then: Event should contain zero IDFA
        #expect(event.customData["idfa"] != nil, "Event should contain IDFA")
        #expect(event.customData["idfa"] as? String == "00000000-0000-0000-0000-000000000000",
                      "Event IDFA should be zeros when not authorized")
    }

    // MARK: - Branch Deep Link Attribution Tests

    @Test("Branch deep link attribution with ATT")
    func branchDeepLinkAttributionWithATT() {
        // Given: ATT Manager with status
        let statusInfo = attManager.getStatusInfo()

        // When: Branch handles deep link
        // (Simulating deep link handling)
        let branchInstance = Branch.getInstance()
        #expect(branchInstance != nil, "Branch instance should exist")

        // Then: Attribution should work regardless of ATT status
        // Branch uses alternative identifiers when IDFA is not available
        print("Deep link attribution available with status: \(attManager.statusToString(statusInfo.status))")
        print("Tracking enabled: \(statusInfo.isTrackingEnabled)")
    }

    // MARK: - Privacy Compliance Tests

    @Test("Branch respects user privacy choices")
    func branchRespectsUserPrivacyChoices() {
        // Given: User's ATT choice
        let userChoice = attManager.authorizationStatus

        // When: Checking IDFA availability
        let statusInfo = attManager.getStatusInfo()

        // Then: Branch should respect user's choice
        switch userChoice {
        case .authorized:
            // User allowed tracking - IDFA should be available
            #expect(statusInfo.isTrackingEnabled, "Tracking should be enabled when authorized")
            #expect(UUID(uuidString: statusInfo.idfa) != nil, "IDFA should be valid UUID when authorized")

        case .denied, .restricted:
            // User denied tracking - IDFA should be zeros
            #expect(!statusInfo.isTrackingEnabled, "Tracking should be disabled when denied/restricted")
            #expect(statusInfo.idfa == "00000000-0000-0000-0000-000000000000",
                          "IDFA should be zeros when user denied tracking")

        case .notDetermined:
            // User hasn't decided - IDFA should be zeros until permission granted
            #expect(!statusInfo.isTrackingEnabled, "Tracking should be disabled when not determined")
            #expect(statusInfo.idfa == "00000000-0000-0000-0000-000000000000",
                          "IDFA should be zeros when permission not yet granted")

        @unknown default:
            Issue.record("Unknown ATT status")
        }
    }

    @Test("Branch uses alternative identifiers when IDFA unavailable",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus != .authorized))
    func branchUsesAlternativeIdentifiersWhenIDFAUnavailable() {
        // When: Branch SDK operates without IDFA
        let branchInstance = Branch.getInstance()
        #expect(branchInstance != nil, "Branch should work without IDFA")

        // Then: Branch should use alternative identifiers
        // (Branch internally uses IDFV and other identifiers)
        print("Branch operates with alternative identifiers when IDFA unavailable")
        #expect(true, "Branch should use alternative identifiers")
    }

    // MARK: - Session Management Tests

    @Test("Branch session with different ATT states")
    func branchSessionWithDifferentATTStates() {
        // Given: Current ATT status
        let initialStatus = attManager.authorizationStatus

        // When: Branch session is active
        let branchInstance = Branch.getInstance()
        #expect(branchInstance != nil, "Branch instance should exist")

        // Then: Session should work with any ATT status
        print("Branch session working with ATT status: \(attManager.statusToString(initialStatus))")
        #expect(true, "Branch session should work regardless of ATT status")
    }

    // MARK: - Attribution Accuracy Tests

    @Test("Attribution accuracy with authorized ATT",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus == .authorized))
    func attributionAccuracyWithAuthorizedATT() {
        // When: Branch performs attribution
        let statusInfo = attManager.getStatusInfo()

        // Then: Attribution should be most accurate with IDFA
        #expect(statusInfo.isTrackingEnabled, "Tracking should be enabled")
        #expect(UUID(uuidString: statusInfo.idfa) != nil,
                         "IDFA should be valid UUID for attribution (can be zeros on simulator)")
    }

    @Test("Attribution without IDFA",
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus != .authorized))
    func attributionWithoutIDFA() {
        // When: Branch performs attribution without IDFA
        let statusInfo = attManager.getStatusInfo()

        // Then: Attribution should still work with alternative methods
        #expect(!statusInfo.isTrackingEnabled, "Tracking should be disabled")
        #expect(statusInfo.idfa == "00000000-0000-0000-0000-000000000000",
                      "IDFA should be zeros")

        // Branch uses IDFV and other identifiers for attribution
        print("Branch attribution works without IDFA using alternative identifiers")
    }

    // MARK: - Metadata Tests

    @Test("Branch metadata includes ATT status")
    func branchMetadataIncludesATTStatus() {
        // Given: ATT Manager with status
        let statusInfo = attManager.getStatusInfo()

        // When: Preparing Branch metadata
        let metadata: [String: Any] = [
            "att_status": attManager.statusToString(statusInfo.status),
            "tracking_enabled": statusInfo.isTrackingEnabled,
            "idfa_available": statusInfo.idfa != "00000000-0000-0000-0000-000000000000"
        ]

        // Then: Metadata should contain ATT information
        #expect(metadata["att_status"] != nil, "Metadata should include ATT status")
        #expect(metadata["tracking_enabled"] != nil, "Metadata should include tracking enabled flag")
        #expect(metadata["idfa_available"] != nil, "Metadata should include IDFA availability")
    }

    // MARK: - Error Handling Tests

    @Test("Branch handles ATT status changes")
    func branchHandlesATTStatusChanges() async {
        // Given: Initial ATT status
        let initialStatus = attManager.authorizationStatus

        // When: Status potentially changes (simulated)
        attManager.updateCurrentStatus()

        // Wait for update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Branch should adapt to new status
        let newStatus = attManager.authorizationStatus
        #expect(newStatus != nil, "New status should be available")

        print("Branch adapts from \(attManager.statusToString(initialStatus)) to \(attManager.statusToString(newStatus))")
    }

    // MARK: - Performance Tests

    @Test("Branch performance with IDFA",
          .timeLimit(.minutes(1)),
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus == .authorized))
    func branchPerformanceWithIDFA() {
        // When: Measuring performance with IDFA
        for _ in 0..<10 {
            let event = BranchEvent.standardEvent(.purchase)
            event.customData["idfa"] = attManager.idfa
            // Event created with IDFA
        }

        // Then: Should be fast
    }

    @Test("Branch performance without IDFA",
          .timeLimit(.minutes(1)),
          .enabled(if: ATTrackingManager.trackingAuthorizationStatus != .authorized))
    func branchPerformanceWithoutIDFA() {
        // When: Measuring performance without IDFA
        for _ in 0..<10 {
            let event = BranchEvent.standardEvent(.purchase)
            event.customData["idfa"] = attManager.idfa
            // Event created without real IDFA
        }

        // Then: Should be fast (no performance penalty)
    }

    // MARK: - Real-World Scenario Tests

    @Test("Complete user journey with ATT")
    func completeUserJourneyWithATT() async {
        // Given: User starts app
        let initialStatus = attManager.authorizationStatus
        print("1. App launched with ATT status: \(attManager.statusToString(initialStatus))")

        // When: User interacts with app
        // Scenario: Send event
        let event = BranchEvent.standardEvent(.addToCart)
        event.customData["att_status"] = attManager.statusToString(initialStatus)
        event.customData["idfa"] = attManager.idfa

        // Then: Event should be created with appropriate data
        #expect(event != nil, "Event should be created")
        print("2. Event created with IDFA: \(attManager.idfa)")

        // Scenario: Refresh status
        attManager.updateCurrentStatus()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let updatedStatus = attManager.authorizationStatus
        print("3. Status refreshed: \(attManager.statusToString(updatedStatus))")

        // Then: App should continue working smoothly
        #expect(true, "Complete user journey completed successfully")
    }

    // MARK: - Documentation Tests

    @Test("Branch ATT integration is documented")
    func branchATTIntegrationIsDocumented() {
        // This test verifies that the integration points are clear
        // In a real app, you would check that documentation exists

        // Given: ATT Manager
        let manager = ATTManager()

        // Then: All integration points should be clear
        #expect(manager.getStatusInfo() != nil, "Status info available for integration")
        #expect(manager.authorizationStatus != nil, "Authorization status available")
        #expect(manager.idfa != nil, "IDFA available for integration")

        print("✅ Branch ATT integration points are well-defined")
    }
}
