import XCTest

/// Base class for deep link UI tests.
///
/// # Configuration
/// Before running, update the test URLs with real Branch links:
/// 1. Create a link in the Branch dashboard for your app
/// 2. Update `universalLinkURL` with the generated link
/// 3. For URI scheme, use a Branch link or `branchlinksimulator://` URL
///
/// # How it works
/// - Cold launch: App starts with `--test-deep-link=<url>`.
///   After SDK init (3s delay), calls `handleDeepLink(url)`.
/// - Warm launch: Same but with 8s delay (URL arrives well after init).
/// - Test asserts `DeeplinkDetailView` appeared with deep link params.
class DeepLinkUITestCase: XCTestCase {
    var app: XCUIApplication!

    // MARK: - Test URL Configuration

    // Update with real Branch links from https://dashboard.branch.io

    /// Universal Link for this app (real Branch link)
    static var universalLinkURL = "https://ls.branchcustom.xyz/v6kQr5hX10b"

    /// URI Scheme link (uses same Branch link for SDK resolution)
    static var uriSchemeURL = "https://ls.branchcustom.xyz/v6kQr5hX10b"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-mode"]

        // Dismiss any system alerts (IDFA, notifications, etc.)
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            let allowButton = alert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
                return true
            }
            return false
        }
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Launch Helpers

    /// Simulate cold launch with deep link.
    /// URL is handled 3s after init (short delay = cold launch behavior).
    func coldLaunchWithDeepLink(_ url: String) {
        app.launchArguments.append("--test-deep-link=\(url)")
        app.launch()
    }

    /// Simulate warm launch with deep link.
    /// URL is handled 8s after init (long delay = app was already running).
    func warmLaunchWithDeepLink(_ url: String) {
        app.launchArguments.append("--test-deep-link=\(url)")
        app.launchArguments.append("--warm-launch")
        app.launch()
    }

    // MARK: - Assertions

    /// Assert that DeeplinkDetailView appeared (deep link handled successfully).
    /// Requires a valid Branch link that returns +clicked_branch_link = true.
    func assertDeepLinkHandled(timeout: TimeInterval = 25) {
        // Try section header first, then navigation title
        let paramsSection = app.staticTexts["Deep Link Parameters"]
        let navBar = app.navigationBars["Data"]
        let found = paramsSection.waitForExistence(timeout: timeout) || navBar.exists

        if !found {
            let hierarchy = app.debugDescription
            XCTFail(
                "DeeplinkDetailView did not appear after \(timeout)s.\n" +
                    "View hierarchy:\n\(hierarchy)"
            )
        }
    }

    /// Assert that the app shows the home screen (no deep link navigation).
    func assertOnHomeScreen(timeout: TimeInterval = 5) {
        let homeTitle = app.navigationBars["Branch Link Simulator"]
        XCTAssertTrue(
            homeTitle.waitForExistence(timeout: timeout),
            "Home screen not visible"
        )
    }

    /// Assert that the SDK callback fired (checks status label in test mode).
    func assertCallbackFired(timeout: TimeInterval = 20) {
        let status = app.staticTexts["callback_received"]
        XCTAssertTrue(
            status.waitForExistence(timeout: timeout),
            "SDK callback did not fire. Check Branch key and network."
        )
    }
}
