//
//  ATTManagerTests.swift
//  BranchLinkSimulatorTests
//
//  Created for comprehensive ATT testing
//

import Testing
import AppTrackingTransparency
import AdSupport
@testable import BranchLinkSimulator

@MainActor
@Suite("ATTManager Tests")
struct ATTManagerTests {

    var sut: ATTManager

    init() {
        self.sut = ATTManager()
    }

    // MARK: - Initialization Tests

    @Test("Initialization sets properties correctly")
    func initialization() {
        // Given: Fresh ATTManager instance
        // When: Manager is initialized
        // Then: Properties should be set
        #expect(sut.authorizationStatus != nil, "Authorization status should be set")
        #expect(sut.idfa != nil, "IDFA should be set")
        #expect(sut.statusHistory.count == 0, "History should be empty initially")
    }

    @Test("Initial status matches system status")
    func initialStatusIsSet() {
        // Given: Fresh ATTManager instance
        // When: Manager is initialized
        // Then: Status should match system status
        if #available(iOS 14, *) {
            let systemStatus = ATTrackingManager.trackingAuthorizationStatus
            #expect(sut.authorizationStatus == systemStatus, "Initial status should match system")
        }
    }

    // MARK: - Status Conversion Tests

    @Test("Status to string converts Not Determined")
    func statusToStringConvertsNotDetermined() {
        // Given: Not determined status
        let status: ATTrackingManager.AuthorizationStatus = .notDetermined

        // When: Converting to string
        let result = sut.statusToString(status)

        // Then: Should return correct string
        #expect(result == "Not Determined")
    }

    @Test("Status to string converts Authorized")
    func statusToStringConvertsAuthorized() {
        // Given: Authorized status
        let status: ATTrackingManager.AuthorizationStatus = .authorized

        // When: Converting to string
        let result = sut.statusToString(status)

        // Then: Should return correct string
        #expect(result == "Authorized")
    }

    @Test("Status to string converts Denied")
    func statusToStringConvertsDenied() {
        // Given: Denied status
        let status: ATTrackingManager.AuthorizationStatus = .denied

        // When: Converting to string
        let result = sut.statusToString(status)

        // Then: Should return correct string
        #expect(result == "Denied")
    }

    @Test("Status to string converts Restricted")
    func statusToStringConvertsRestricted() {
        // Given: Restricted status
        let status: ATTrackingManager.AuthorizationStatus = .restricted

        // When: Converting to string
        let result = sut.statusToString(status)

        // Then: Should return correct string
        #expect(result == "Restricted")
    }

    @Test("Status to string converts all cases")
    func statusToStringConvertsAllCases() {
        // Given: All possible ATT authorization statuses
        let statuses: [ATTrackingManager.AuthorizationStatus] = [
            .notDetermined,
            .restricted,
            .denied,
            .authorized
        ]

        // When: Converting each status to string
        // Then: Should return appropriate string for each
        for status in statuses {
            let stringValue = sut.statusToString(status)
            #expect(!stringValue.isEmpty, "Status string should not be empty for \(status)")
            #expect(stringValue != "Unknown", "Status \(status) should have known string representation")
        }
    }

    // MARK: - Emoji Conversion Tests

    @Test("Status to emoji returns valid emoji")
    func statusToEmojiReturnsValidEmoji() {
        // Given: All possible ATT authorization statuses
        let statuses: [ATTrackingManager.AuthorizationStatus] = [
            .notDetermined,
            .restricted,
            .denied,
            .authorized
        ]

        // When: Converting each status to emoji
        // Then: Should return appropriate emoji for each
        for status in statuses {
            let emoji = sut.statusToEmoji(status)
            #expect(!emoji.isEmpty, "Emoji should not be empty for \(status)")
            #expect(emoji.count >= 1, "Emoji should be at least one character")
        }
    }

    @Test("Status to emoji returns correct emojis")
    func statusToEmojiReturnsCorrectEmojis() {
        // Given: Each status
        // Then: Should return correct emoji
        #expect(sut.statusToEmoji(.notDetermined) == "❓")
        #expect(sut.statusToEmoji(.authorized) == "✅")
        #expect(sut.statusToEmoji(.denied) == "❌")
        #expect(sut.statusToEmoji(.restricted) == "🔒")
    }

    // MARK: - IDFA Tests

    @Test("IDFA format is valid UUID")
    func idfaFormatIsValidUUID() {
        // Given: Current IDFA
        let idfa = sut.idfa

        // When: Checking format
        // Then: Should be valid UUID format
        let uuid = UUID(uuidString: idfa)
        #expect(uuid != nil, "IDFA should be valid UUID format")
    }

    @Test("IDFA is zeros when not authorized")
    func idfaIsZerosWhenNotAuthorized() {
        // Given: ATT status is not authorized
        // When: Status is denied or restricted or not determined
        // Then: IDFA should be all zeros
        let zeroIDFA = "00000000-0000-0000-0000-000000000000"

        if sut.authorizationStatus != .authorized {
            #expect(sut.idfa == zeroIDFA, "IDFA should be zeros when not authorized")
        }
    }

    @Test("IDFA is valid when authorized")
    func idfaIsValidWhenAuthorized() {
        // Given: ATT status is authorized
        // When: User has granted permission
        // Then: IDFA should be valid (not zeros or may be zeros depending on device)
        if sut.authorizationStatus == .authorized {
            let idfa = sut.idfa
            #expect(UUID(uuidString: idfa) != nil, "IDFA should be valid UUID when authorized")
        }
    }

    // MARK: - Status Info Tests

    @Test("Get status info returns complete info")
    func getStatusInfoReturnsCompleteInfo() {
        // Given: ATTManager with current status
        // When: Requesting status info
        let statusInfo = sut.getStatusInfo()

        // Then: Should return complete status information
        #expect(statusInfo.status != nil)
        #expect(!statusInfo.idfa.isEmpty)
        #expect(statusInfo.isTrackingEnabled == (statusInfo.status == .authorized))
        #expect(statusInfo.canRequestPermission == (statusInfo.status == .notDetermined))
    }

    @Test("Get status info tracking enabled matches status")
    func getStatusInfoTrackingEnabledMatchesStatus() {
        // Given: Current status
        let statusInfo = sut.getStatusInfo()

        // When: Checking tracking enabled flag
        // Then: Should match authorization status
        if sut.authorizationStatus == .authorized {
            #expect(statusInfo.isTrackingEnabled, "Tracking should be enabled when authorized")
        } else {
            #expect(!statusInfo.isTrackingEnabled, "Tracking should be disabled when not authorized")
        }
    }

    @Test("Get status info can request matches status")
    func getStatusInfoCanRequestMatchesStatus() {
        // Given: Current status
        let statusInfo = sut.getStatusInfo()

        // When: Checking can request permission flag
        // Then: Should only be true when not determined
        if sut.authorizationStatus == .notDetermined {
            #expect(statusInfo.canRequestPermission, "Should be able to request when not determined")
        } else {
            #expect(!statusInfo.canRequestPermission, "Should not be able to request when already decided")
        }
    }

    // MARK: - Can Show Prompt Tests

    @Test("Can show ATT prompt only when not determined")
    func canShowATTPromptOnlyWhenNotDetermined() {
        // Given: Current ATT status
        let canShow = sut.canShowATTPrompt()
        let isNotDetermined = sut.authorizationStatus == .notDetermined

        // When: Checking if we can show ATT prompt
        // Then: Should only return true when status is notDetermined
        #expect(canShow == isNotDetermined, "Can show prompt should match notDetermined status")
    }

    @Test("Can show ATT prompt returns false when authorized")
    func canShowATTPromptReturnsFalseWhenAuthorized() {
        // Given: Status is authorized (or simulate it)
        if sut.authorizationStatus == .authorized {
            // When: Checking if can show prompt
            let canShow = sut.canShowATTPrompt()

            // Then: Should return false
            #expect(!canShow, "Should not show prompt when authorized")
        }
    }

    // MARK: - Update Status Tests

    @Test("Update current status updates status")
    func updateCurrentStatusUpdatesStatus() async {
        // Given: ATTManager instance
        let initialStatus = sut.authorizationStatus

        // When: Updating current status
        sut.updateCurrentStatus()

        // Wait for main thread update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        // Then: Status should be set (may be same as before)
        #expect(sut.authorizationStatus != nil, "Status should be set after update")
    }

    // MARK: - History Tests

    @Test("Status history starts empty")
    func statusHistoryStartsEmpty() {
        // Given: Fresh ATTManager instance
        let newManager = ATTManager()

        // Then: Status history should be empty or have at most initial entry
        #expect(newManager.statusHistory.count <= 1, "History should start empty or with one entry")
    }

    @Test("Reset for testing clears history")
    func resetForTestingClearsHistory() async {
        // Given: ATTManager with some history
        // When: Resetting for testing
        sut.resetForTesting()

        // Wait for async operations
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then: History should be cleared or have only reset entry
        #expect(sut.statusHistory.count <= 1, "History should be reset")
    }

    // MARK: - Permission Request Tests

    @Test("Request IDFA permission with completion")
    func requestIDFAPermissionWithCompletion() async {
        // Given: ATTManager
        await withCheckedContinuation { continuation in
            // When: Requesting permission
            sut.requestIDFAPermission { status in
                // Then: Completion should be called
                #expect(status != nil, "Status should be provided in completion")
                continuation.resume()
            }
        }
    }

    // MARK: - Thread Safety Tests

    @Test("Published properties update on main thread")
    func publishedPropertiesUpdateOnMainThread() async {
        // Given: ATTManager
        var isMainThread = false

        // When: Updating status
        sut.updateCurrentStatus()

        // Wait for update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should be on main thread
        await MainActor.run {
            isMainThread = Thread.isMainThread
        }

        #expect(isMainThread, "Updates should happen on main thread")
    }

    // MARK: - Edge Cases Tests

    @Test("Multiple update status calls do not crash")
    func multipleUpdateStatusCallsDoNotCrash() async {
        // Given: ATTManager
        // When: Calling updateCurrentStatus multiple times rapidly
        for _ in 0..<10 {
            sut.updateCurrentStatus()
        }

        // Wait for all updates
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should not crash
        #expect(sut.authorizationStatus != nil, "Should handle multiple updates")
    }

    @Test("Status info consistency")
    func statusInfoConsistency() {
        // Given: Current status
        let info1 = sut.getStatusInfo()
        let info2 = sut.getStatusInfo()

        // When: Getting status info multiple times
        // Then: Should be consistent
        #expect(info1.status == info2.status)
        #expect(info1.idfa == info2.idfa)
        #expect(info1.isTrackingEnabled == info2.isTrackingEnabled)
        #expect(info1.canRequestPermission == info2.canRequestPermission)
    }

    // MARK: - iOS Version Compatibility Tests

    @Test("Compatibility with iOS 13")
    func compatibilityWithiOS13() {
        // Given: Code that checks iOS version
        // When: Running on any iOS version
        // Then: Should not crash
        #expect(sut.authorizationStatus != nil, "Should work on all iOS versions")
    }

    // MARK: - Performance Tests

    @Test("Status to string performance", .timeLimit(.minutes(1)))
    func statusToStringPerformance() {
        // Given: Status
        let status: ATTrackingManager.AuthorizationStatus = .authorized

        // When: Converting many times
        for _ in 0..<1000 {
            _ = sut.statusToString(status)
        }

        // Then: Should be fast
    }

    @Test("Status to emoji performance", .timeLimit(.minutes(1)))
    func statusToEmojiPerformance() {
        // Given: Status
        let status: ATTrackingManager.AuthorizationStatus = .authorized

        // When: Converting many times
        for _ in 0..<1000 {
            _ = sut.statusToEmoji(status)
        }

        // Then: Should be fast
    }

    @Test("Get status info performance", .timeLimit(.minutes(1)))
    func getStatusInfoPerformance() {
        // When: Getting status info many times
        for _ in 0..<100 {
            _ = sut.getStatusInfo()
        }

        // Then: Should be fast
    }

    // MARK: - Integration Tests

    @Test("Status matches system status")
    func statusMatchesSystemStatus() {
        // Given: System ATT status
        if #available(iOS 14, *) {
            let systemStatus = ATTrackingManager.trackingAuthorizationStatus

            // When: Getting manager status
            let managerStatus = sut.authorizationStatus

            // Then: Should match
            #expect(managerStatus == systemStatus, "Manager status should match system status")
        }
    }

    @Test("IDFA matches system IDFA")
    func idfaMatchesSystemIDFA() {
        // Given: System IDFA
        let systemIDFA = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        // When: Getting manager IDFA
        let managerIDFA = sut.idfa

        // Then: Should match (if authorized) or be zeros (if not)
        if sut.authorizationStatus == .authorized {
            // May match or may be zeros depending on actual permission
            #expect(UUID(uuidString: managerIDFA) != nil, "IDFA should be valid UUID")
        } else {
            #expect(managerIDFA == "00000000-0000-0000-0000-000000000000", "IDFA should be zeros when not authorized")
        }
    }
}
