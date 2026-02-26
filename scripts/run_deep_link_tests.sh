#!/bin/bash
# run_deep_link_tests.sh
#
# True system integration tests for deep linking using simctl.
# This script tests REAL cold/warm launch behavior via simctl openurl.
#
# Usage:
#   ./scripts/run_deep_link_tests.sh [--device "iPhone 16 Pro"]
#
# Prerequisites:
#   - App must be installed on the simulator
#   - Update UNIVERSAL_LINK and URI_SCHEME with real Branch links

set -euo pipefail

# ──────────────────────────────────────────────
# Configuration - UPDATE THESE WITH REAL LINKS
# ──────────────────────────────────────────────
UNIVERSAL_LINK="https://ls.branchcustom.xyz/v6kQr5hX10b"
URI_SCHEME="https://ls.branchcustom.xyz/v6kQr5hX10b"
BUNDLE_ID="io.branch.link-simulator"
DEVICE="${1:-booted}"
WAIT_COLD=8
WAIT_WARM=5

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────
pass_count=0
fail_count=0
skip_count=0

log()  { echo "[DeepLinkTest] $1"; }
pass() { ((pass_count++)); echo "[DeepLinkTest] PASS — $1"; }
fail() { ((fail_count++)); echo "[DeepLinkTest] FAIL — $1 | $2"; }
skip() { ((skip_count++)); echo "[DeepLinkTest] SKIP — $1"; }

check_deep_link_in_logs() {
    local test_name="$1"
    local timeout="$2"

    sleep "$timeout"

    # Check recent logs for deep link callback
    local logs
    logs=$(xcrun simctl spawn "$DEVICE" log show \
        --predicate 'subsystem == "io.branch.sdk" OR process == "BranchLinkSimulator"' \
        --last "${timeout}s" \
        --style compact 2>/dev/null || echo "")

    if echo "$logs" | grep -q "clicked_branch_link.*true\|Deep link data received\|handleDeepLink"; then
        pass "$test_name"
    elif echo "$logs" | grep -q "v1/open\|initSession"; then
        # SDK responded but no deep link data — link might not be valid
        fail "$test_name" "SDK responded but +clicked_branch_link not true. Use a real Branch link."
    else
        fail "$test_name" "No SDK activity detected in logs"
    fi
}

terminate_app() {
    xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
}

launch_app() {
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
    sleep 3
}

# ──────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────

log "══════════════════════════════════════"
log "DEEP LINK SYSTEM INTEGRATION TESTS"
log "══════════════════════════════════════"
log "Device: $DEVICE"
log "Universal Link: $UNIVERSAL_LINK"
log "URI Scheme: $URI_SCHEME"
log "══════════════════════════════════════"

# 7a. Cold Launch + Universal Link
log "Running 7a. Cold Launch + Universal Link..."
terminate_app
xcrun simctl openurl "$DEVICE" "$UNIVERSAL_LINK"
check_deep_link_in_logs "7a. Cold Launch + Universal Link" "$WAIT_COLD"

# 7b. Warm Launch + Universal Link
log "Running 7b. Warm Launch + Universal Link..."
terminate_app
launch_app
xcrun simctl openurl "$DEVICE" "$UNIVERSAL_LINK"
check_deep_link_in_logs "7b. Warm Launch + Universal Link" "$WAIT_WARM"

# 7c. Cold Launch + URI Scheme
log "Running 7c. Cold Launch + URI Scheme..."
terminate_app
xcrun simctl openurl "$DEVICE" "$URI_SCHEME"
check_deep_link_in_logs "7c. Cold Launch + URI Scheme" "$WAIT_COLD"

# 7d. Warm Launch + URI Scheme
log "Running 7d. Warm Launch + URI Scheme..."
terminate_app
launch_app
xcrun simctl openurl "$DEVICE" "$URI_SCHEME"
check_deep_link_in_logs "7d. Warm Launch + URI Scheme" "$WAIT_WARM"

# 8a-8d: BranchScene tests — now automated via XCUITest
# Run: xcodebuild test ... -only-testing:BranchLinkSimulatorUITests/BranchSceneDeepLinkTests
skip "8a-8d. BranchScene tests — run via XCUITest (BranchSceneDeepLinkTests)"

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
total=$((pass_count + fail_count))
log "══════════════════════════════════════"
log "RESULTS: $pass_count/$total PASSED, $fail_count FAILED, $skip_count SKIPPED"
log "══════════════════════════════════════"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
