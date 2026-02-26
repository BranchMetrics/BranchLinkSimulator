import XCTest

/// Tests 7a-7d: Deep Link handling via AppDelegate
///
/// Verifies that deep links are correctly processed and displayed
/// when the app uses AppDelegate-based lifecycle.
///
/// Before running, configure real Branch link URLs in `DeepLinkUITestCase`.
final class AppDelegateDeepLinkTests: DeepLinkUITestCase {
    // MARK: - 7a. Cold Launch + Universal Link

    func test7a_coldLaunch_universalLink() {
        coldLaunchWithDeepLink(Self.universalLinkURL)
        assertCallbackFired()
        assertDeepLinkHandled()
    }

    // MARK: - 7b. Warm Launch + Universal Link

    func test7b_warmLaunch_universalLink() {
        warmLaunchWithDeepLink(Self.universalLinkURL)
        assertCallbackFired()
        assertDeepLinkHandled(timeout: 30)
    }

    // MARK: - 7c. Cold Launch + URI Scheme

    func test7c_coldLaunch_uriScheme() {
        coldLaunchWithDeepLink(Self.uriSchemeURL)
        assertCallbackFired()
        assertDeepLinkHandled()
    }

    // MARK: - 7d. Warm Launch + URI Scheme

    func test7d_warmLaunch_uriScheme() {
        warmLaunchWithDeepLink(Self.uriSchemeURL)
        assertCallbackFired()
        assertDeepLinkHandled(timeout: 30)
    }
}
