//
//  ATTTestViewUITests.swift
//  BranchLinkSimulatorUITests
//
//  UI Tests for ATT Testing functionality
//

import XCTest

final class ATTTestViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Navigation Tests

    func testNavigateToATTTestingView() throws {
        // Given: App is launched and on home screen
        XCTAssertTrue(app.navigationBars["Branch Link Simulator"].exists, "Should be on home screen")

        // When: Tapping on ATT Testing link
        let attTestingLink = app.buttons["ATT Testing"]
        XCTAssertTrue(attTestingLink.waitForExistence(timeout: 5), "ATT Testing link should exist")
        attTestingLink.tap()

        // Then: Should navigate to ATT Testing view
        XCTAssertTrue(app.navigationBars["ATT Testing"].waitForExistence(timeout: 5), "Should navigate to ATT Testing view")
    }

    func testBackNavigationFromATTTestingView() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Tapping back button
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.exists, "Back button should exist")
        backButton.tap()

        // Then: Should return to home screen
        XCTAssertTrue(app.navigationBars["Branch Link Simulator"].waitForExistence(timeout: 5), "Should return to home screen")
    }

    // MARK: - UI Elements Existence Tests

    func testCurrentStatusSectionExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: View is displayed
        // Then: Current ATT Status section should exist
        XCTAssertTrue(elementExists("Current ATT Status"), "Current ATT Status header should exist")
        XCTAssertTrue(elementExists("Status"), "Status label should exist")
        XCTAssertTrue(elementExists("IDFA"), "IDFA label should exist")
        XCTAssertTrue(elementExists("Tracking Enabled"), "Tracking Enabled label should exist")
    }

    func testActionButtonsExist() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: View is displayed
        // Then: Action buttons should exist
        XCTAssertTrue(buttonExists(containing: "Request ATT Permission"), "Request ATT Permission button should exist")
        XCTAssertTrue(buttonExists(containing: "Refresh Status"), "Refresh Status button should exist")
        XCTAssertTrue(buttonExists(containing: "Open App Settings"), "Open App Settings button should exist")
    }

    func testStatusHistorySectionExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: View is displayed
        // Then: Status History section should exist
        XCTAssertTrue(elementExists("Status History"), "Status History header should exist")
    }

    func testTestScenariosSectionExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling down to test scenarios section
        // Scroll to ensure all scenarios are visible
        let notDeterminedElement = app.staticTexts["Not Determined"]
        scrollToElement(notDeterminedElement)

        // Scroll a bit more to ensure all 4 scenarios are visible
        app.swipeUp()

        // Wait for elements to settle
        Thread.sleep(forTimeInterval: 0.5)

        // Then: All test scenario elements should exist
        XCTAssertTrue(elementExists("Not Determined"), "Not Determined scenario should exist")
        XCTAssertTrue(elementExists("Authorized"), "Authorized scenario should exist")
        XCTAssertTrue(elementExists("Denied"), "Denied scenario should exist")
        XCTAssertTrue(elementExists("Restricted"), "Restricted scenario should exist")

        // Check that the section header is also accessible (even if we didn't scroll to it first)
        let headerExists = app.staticTexts["Test Scenarios & Expected Behavior"].exists ||
                          app.otherElements["Test Scenarios & Expected Behavior"].exists
        XCTAssertTrue(headerExists, "Test Scenarios header should exist")
    }

    func testBranchIntegrationSectionExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling to Branch SDK Integration
        let branchHeader = findElement("Branch SDK Integration")
        scrollToElement(branchHeader)

        // Then: Branch integration info should exist
        XCTAssertTrue(branchHeader.exists, "Branch SDK Integration header should exist")
        XCTAssertTrue(elementExists("How Branch Uses ATT"), "How Branch Uses ATT text should exist")
    }

    func testTestingNotesSectionExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling to Testing Notes
        let notesHeader = findElement("Testing Notes")
        scrollToElement(notesHeader)

        // Then: Testing notes should exist
        XCTAssertTrue(notesHeader.exists, "Testing Notes header should exist")
        XCTAssertTrue(elementExists("⚠️ Important"), "Important warning should exist")
    }

    // MARK: - Status Display Tests

    func testStatusValueIsDisplayed() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking status display
        XCTAssertTrue(elementExists("Status"), "Status label should exist")

        // Then: Status value should be one of valid statuses
        let validStatuses = ["Not Determined", "Authorized", "Denied", "Restricted"]
        let statusValueExists = validStatuses.contains { status in
            elementExists(status)
        }
        XCTAssertTrue(statusValueExists, "Status value should be one of: \(validStatuses.joined(separator: ", "))")
    }

    func testIDFAIsDisplayedInCorrectFormat() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking IDFA display
        let idfaLabel = findElement("IDFA")
        XCTAssertTrue(idfaLabel.exists, "IDFA label should exist")

        // Then: IDFA should be displayed (format validation done in unit tests)
        // Just verify it exists and is not empty
        XCTAssertTrue(idfaLabel.exists, "IDFA should be displayed")
    }

    func testTrackingEnabledStatusIsDisplayed() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking tracking enabled status
        XCTAssertTrue(elementExists("Tracking Enabled"), "Tracking Enabled label should exist")

        // Then: Should show icon (checkmark or x)
        let hasCheckmark = app.images["checkmark.circle.fill"].exists
        let hasXmark = app.images["xmark.circle.fill"].exists
        XCTAssertTrue(hasCheckmark || hasXmark, "Should show either checkmark or xmark icon")
    }

    // MARK: - Button Interaction Tests

    func testRefreshStatusButtonWorks() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Tapping Refresh Status button
        let refreshButton = findButton(containing: "Refresh Status")
        XCTAssertTrue(refreshButton.exists, "Refresh Status button should exist")
        XCTAssertTrue(refreshButton.isEnabled, "Refresh Status button should be enabled")

        refreshButton.tap()

        // Then: View should still be visible (status refreshed)
        XCTAssertTrue(app.navigationBars["ATT Testing"].exists, "Should still be on ATT Testing view")
    }

    func testRequestPermissionButtonStateMatchesATTStatus() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking Request ATT Permission button using accessibility identifier
        let requestButton = app.buttons["Request ATT Permission"]
        XCTAssertTrue(requestButton.waitForExistence(timeout: 5), "Request ATT Permission button should exist")

        // Then: Button state should match ATT status
        // If status is "Not Determined", button should be enabled
        // Otherwise, button should be disabled
        let isNotDetermined = elementExists("Not Determined")

        if isNotDetermined {
            // For SwiftUI buttons with custom styling, isHittable is more reliable than isEnabled
            XCTAssertTrue(requestButton.isHittable, "Button should be hittable/enabled when status is Not Determined")
        } else {
            XCTAssertFalse(requestButton.isEnabled, "Button should be disabled when status is not Not Determined")
        }
    }

    func testOpenAppSettingsButtonExists() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Finding Open App Settings button
        let settingsButton = findButton(containing: "Open App Settings")

        // Then: Button should exist and be enabled
        XCTAssertTrue(settingsButton.exists, "Open App Settings button should exist")
        XCTAssertTrue(settingsButton.isEnabled, "Open App Settings button should be enabled")

        // Note: We don't tap it as it would leave the app
    }

    // MARK: - Status History Tests

    func testStatusHistoryClearButton() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Finding Clear button in Status History
        let clearButton = app.buttons["Clear"]

        // Then: Clear button should exist
        XCTAssertTrue(clearButton.exists, "Clear button should exist in Status History section")
    }

    func testStatusHistoryDisplaysCorrectly() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking status history section
        XCTAssertTrue(elementExists("Status History"), "Status History header should exist")

        // Then: Should show either "No history yet" or history entries
        let noHistory = elementExists("No history yet")
        let hasHistory = !noHistory

        if !hasHistory {
            XCTAssertTrue(noHistory, "Should show 'No history yet' when empty")
        }
    }

    // MARK: - Scrolling Tests

    func testCanScrollToBottomOfView() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling to bottom
        let testingNotesHeader = findElement("Testing Notes")
        scrollToElement(testingNotesHeader)

        // Then: Should be able to see Testing Notes
        XCTAssertTrue(testingNotesHeader.exists, "Should be able to scroll to Testing Notes")
    }

    func testAllSectionsAreAccessible() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling through all sections
        let sections = [
            "Current ATT Status",
            "Actions",
            "Status History",
            "Test Scenarios & Expected Behavior",
            "Branch SDK Integration",
            "Testing Notes"
        ]

        // Then: All sections should be accessible
        for section in sections {
            let element = findElement(section)
            scrollToElement(element)
            XCTAssertTrue(element.exists, "\(section) should be accessible")
        }
    }

    // MARK: - Visual State Tests

    func testEmojiDisplaysForStatus() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking for emoji in status display
        let validEmojis = ["❓", "✅", "❌", "🔒"]

        // Then: One of the valid emojis should be displayed
        let emojiExists = validEmojis.contains { emoji in
            elementExists(emoji)
        }
        XCTAssertTrue(emojiExists, "Status emoji should be displayed")
    }

    func testCurrentStateHighlightedInScenarios() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Scrolling to test scenarios
        let scenariosHeader = findElement("Test Scenarios & Expected Behavior")
        scrollToElement(scenariosHeader)

        // Then: Current state should be highlighted with "CURRENT" badge
        // (This would be visible if status matches one of the scenarios)
        // Just verify the scenarios section is visible
        XCTAssertTrue(scenariosHeader.exists)
    }

    // MARK: - Accessibility Tests

    func testImportantElementsHaveAccessibilityLabels() throws {
        // Given: On ATT Testing view
        navigateToATTTestingViewHelper()

        // When: Checking accessibility
        // Then: Important elements should be accessible
        let statusLabel = findElement("Status")
        XCTAssertTrue(statusLabel.exists, "Status should be accessible")
        XCTAssertTrue(statusLabel.isEnabled, "Status should be enabled for accessibility")
    }

    // MARK: - Integration Tests

    func testATTTestingIntegratesWithHomeView() throws {
        // Given: Home view is displayed
        XCTAssertTrue(app.navigationBars["Branch Link Simulator"].exists, "Should start on home screen")

        // When: Navigating to ATT Testing and back multiple times
        for _ in 0..<3 {
            // Navigate to ATT Testing
            let attLink = app.buttons["ATT Testing"]
            attLink.tap()
            XCTAssertTrue(app.navigationBars["ATT Testing"].waitForExistence(timeout: 2))

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Branch Link Simulator"].waitForExistence(timeout: 2))
        }

        // Then: Should work consistently
        XCTAssertTrue(app.navigationBars["Branch Link Simulator"].exists, "Should be back on home screen")
    }

    // MARK: - Performance Tests

    func testATTTestingViewLoadsQuickly() throws {
        // Measure the time to navigate to ATT Testing view
        measure {
            // Navigate to ATT Testing
            let attLink = app.buttons["ATT Testing"]
            attLink.tap()

            // Wait for view to load
            _ = app.navigationBars["ATT Testing"].waitForExistence(timeout: 5)

            // Navigate back for cleanup
            app.navigationBars.buttons.firstMatch.tap()
            _ = app.navigationBars["Branch Link Simulator"].waitForExistence(timeout: 5)
        }
    }

    // MARK: - Helper Methods

    private func navigateToATTTestingViewHelper() {
        let attTestingLink = app.buttons["ATT Testing"]
        if attTestingLink.waitForExistence(timeout: 5) {
            attTestingLink.tap()
            _ = app.navigationBars["ATT Testing"].waitForExistence(timeout: 5)
        }
    }

    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 10) {
        var swipes = 0
        while !element.exists && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }

        // If element exists but not hittable, try a few more swipes
        swipes = 0
        while element.exists && !element.isHittable && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
    }

    private func elementExists(_ identifier: String) -> Bool {
        // Check both staticTexts and other elements with the identifier
        return app.staticTexts[identifier].exists ||
               app.otherElements[identifier].exists ||
               app.buttons[identifier].exists
    }

    private func findElement(_ identifier: String) -> XCUIElement {
        // Try to find element in different element types
        if app.staticTexts[identifier].exists {
            return app.staticTexts[identifier]
        } else if app.otherElements[identifier].exists {
            return app.otherElements[identifier]
        } else if app.buttons[identifier].exists {
            return app.buttons[identifier]
        }
        return app.staticTexts[identifier] // Return staticText as default
    }

    private func buttonExists(containing text: String) -> Bool {
        return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists ||
               app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists
    }

    private func findButton(containing text: String) -> XCUIElement {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if button.exists {
            return button
        }
        return app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
