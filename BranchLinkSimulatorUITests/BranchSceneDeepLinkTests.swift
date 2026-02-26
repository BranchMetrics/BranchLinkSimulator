import XCTest

/// Tests 8a-8d: Deep Link handling via BranchScene (SceneDelegate)
///
/// Verifies that deep links are correctly processed when the app uses
/// `BranchScene.shared().initSession(with:scene:)` via a UIWindowSceneDelegate.
///
/// The `--use-scene-delegate` flag activates SceneDelegate, which replaces
/// the AppDelegate-based Branch init with the scene-based BranchScene API.
final class BranchSceneDeepLinkTests: DeepLinkUITestCase {
    override func setUp() {
        super.setUp()
        app.launchArguments.append("--use-scene-delegate")
    }

    // MARK: - 8a. Cold Launch + Universal Link

    func test8a_coldLaunch_universalLink() {
        coldLaunchWithDeepLink(Self.universalLinkURL)
        assertCallbackFired()
        assertDeepLinkHandled()
    }

    // MARK: - 8b. Warm Launch + Universal Link

    func test8b_warmLaunch_universalLink() {
        warmLaunchWithDeepLink(Self.universalLinkURL)
        assertCallbackFired()
        assertDeepLinkHandled(timeout: 30)
    }

    // MARK: - 8c. Cold Launch + URI Scheme

    func test8c_coldLaunch_uriScheme() {
        coldLaunchWithDeepLink(Self.uriSchemeURL)
        assertCallbackFired()
        assertDeepLinkHandled()
    }

    // MARK: - 8d. Warm Launch + URI Scheme

    func test8d_warmLaunch_uriScheme() {
        warmLaunchWithDeepLink(Self.uriSchemeURL)
        assertCallbackFired()
        assertDeepLinkHandled(timeout: 30)
    }
}
