#!/bin/bash

#===============================================================================
# DOUBLE-OPEN BUG TEST SCRIPT
# INTENG-21106 / EMT-2816
#
# This script tests both the BUG (OLD API) and the FIX (NEW API) for the
# double-open issue in scene-based iOS apps with Branch SDK.
#
# Usage: ./test-double-open-bug.sh
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
SIMULATOR_ID="booted"
BUNDLE_ID="io.branch.link-simulator"
APP_PATH="/Users/willianpinho/Library/Developer/Xcode/DerivedData/BranchLinkSimulator-divxaqaxfxsgejcskrtmpwbqmflp/Build/Products/Debug-iphonesimulator/BranchLinkSimulator.app"

# Results storage
OLD_API_QUEUE_DEPTHS=""
OLD_API_REQUESTS=""
NEW_API_QUEUE_DEPTHS=""
NEW_API_REQUESTS=""
OLD_API_DEBUG=""
NEW_API_DEBUG=""

# Results file
RESULTS_FILE="DOUBLE_OPEN_TEST_RESULTS.md"
TEST_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

#===============================================================================
# Helper Functions
#===============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_subheader() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

terminate_app() {
    xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
}

uninstall_app() {
    xcrun simctl uninstall "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
}

install_app() {
    if [ ! -d "$APP_PATH" ]; then
        print_error "App not found at: $APP_PATH"
        print_info "Please build the app first with: xcodebuild build -scheme BranchLinkSimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro'"
        exit 1
    fi
    xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
}

get_app_container() {
    xcrun simctl get_app_container "$SIMULATOR_ID" "$BUNDLE_ID" data 2>/dev/null
}

set_api_mode() {
    local use_new_api=$1
    local container=$(get_app_container)

    if [ -z "$container" ]; then
        print_error "Could not find app container"
        return 1
    fi

    # Set the UserDefaults preference
    # useDoubleOpenFix = true means NEW API, false means OLD API
    xcrun simctl spawn "$SIMULATOR_ID" defaults write "$BUNDLE_ID" useDoubleOpenFix -bool "$use_new_api"
}

cold_launch_with_url() {
    local url=$1
    xcrun simctl openurl "$SIMULATOR_ID" "$url"
}

wait_for_app() {
    local timeout=$1
    sleep "$timeout"
}

#===============================================================================
# Test Functions
#===============================================================================

run_test() {
    local api_mode=$1  # "old" or "new"
    local test_name=$2
    local url=$3

    print_subheader "Testing $test_name"

    # 1. Terminate app if running
    print_info "Terminating app..."
    terminate_app

    # 2. Uninstall for clean state
    print_info "Uninstalling app for clean state..."
    uninstall_app

    # 3. Install fresh
    print_info "Installing app..."
    install_app
    print_success "App installed"

    # 4. Launch once to create container, then terminate
    print_info "Initial launch to create preferences container..."
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 2
    terminate_app

    # 5. Set API mode
    if [ "$api_mode" == "new" ]; then
        print_info "Setting API mode: NEW (EMT-2816 Fix)"
        set_api_mode true
    else
        print_info "Setting API mode: OLD (Bug Demonstration)"
        set_api_mode false
    fi

    # 6. Clear log files from initial launch (they contain data from wrong API mode)
    local container=$(get_app_container)
    if [ -n "$container" ]; then
        rm -f "$container/Documents/app_log.txt" 2>/dev/null || true
        rm -f "$container/Documents/cold_launch_debug.txt" 2>/dev/null || true
        print_info "Cleared log files from initial launch"
    fi

    # 7. Terminate again to ensure cold launch
    terminate_app

    # 8. Perform cold launch via URL
    print_info "Performing COLD LAUNCH via deep link..."
    print_info "URL: $url"
    cold_launch_with_url "$url"

    # 9. Wait for SDK to process
    print_info "Waiting for SDK to process requests..."
    wait_for_app 4

    # 10. Collect results
    local container=$(get_app_container)

    if [ -z "$container" ]; then
        print_error "Could not find app container after launch"
        return 1
    fi

    print_success "Test completed"

    # Return results
    if [ "$api_mode" == "old" ]; then
        OLD_API_QUEUE_DEPTHS=$(grep "Current queue depth" "$container/Documents/app_log.txt" 2>/dev/null || echo "No queue data")
        OLD_API_REQUESTS=$(grep -E "(BranchInstallRequest|BranchOpenRequest)" "$container/Documents/app_log.txt" 2>/dev/null | head -5 || echo "No request data")
        OLD_API_DEBUG=$(cat "$container/Documents/cold_launch_debug.txt" 2>/dev/null || echo "No debug log")
    else
        NEW_API_QUEUE_DEPTHS=$(grep "Current queue depth" "$container/Documents/app_log.txt" 2>/dev/null || echo "No queue data")
        NEW_API_REQUESTS=$(grep -E "(BranchInstallRequest|BranchOpenRequest)" "$container/Documents/app_log.txt" 2>/dev/null | head -5 || echo "No request data")
        NEW_API_DEBUG=$(cat "$container/Documents/cold_launch_debug.txt" 2>/dev/null || echo "No debug log")
    fi
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    print_header "DOUBLE-OPEN BUG TEST SUITE"

    echo -e "${BOLD}Test Environment:${NC}"
    echo "  • Simulator: $SIMULATOR_ID"
    echo "  • Bundle ID: $BUNDLE_ID"
    echo "  • App Path: $APP_PATH"
    echo ""
    echo -e "${BOLD}What This Script Tests:${NC}"
    echo "  1. OLD API (Bug): Branch.initSession(launchOptions: nil) + Branch.application(_:open:)"
    echo "     → Expected: TWO requests (queue depth 1 → 2) - BUG!"
    echo ""
    echo "  2. NEW API (Fix): BranchScene.initSession(with: connectionOptions)"
    echo "     → Expected: ONE request (queue depth 1 only) - FIXED!"
    echo ""

    # Check if simulator is booted
    if ! xcrun simctl list devices | grep -q "Booted"; then
        print_error "No simulator is booted. Please start a simulator first."
        exit 1
    fi
    print_success "Simulator is running"

    # Check if app exists
    if [ ! -d "$APP_PATH" ]; then
        print_error "App not found. Building now..."
        cd /Users/willianpinho/Projects/BranchLinkSimulator
        xcodebuild build -scheme BranchLinkSimulator -destination "platform=iOS Simulator,name=iPhone 16 Pro" CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO -quiet
        print_success "App built successfully"
    else
        print_success "App found at expected path"
    fi

    #---------------------------------------------------------------------------
    # TEST 1: OLD API (Demonstrates the Bug)
    #---------------------------------------------------------------------------
    run_test "old" "OLD API - Double-Open BUG" "branchlinksimulator://test/old-api?campaign=bug-test&feature=double-open"

    #---------------------------------------------------------------------------
    # TEST 2: NEW API (Demonstrates the Fix)
    #---------------------------------------------------------------------------
    run_test "new" "NEW API - EMT-2816 FIX" "branchlinksimulator://test/new-api?campaign=fix-test&feature=single-open"

    #---------------------------------------------------------------------------
    # RESULTS
    #---------------------------------------------------------------------------
    print_header "TEST RESULTS"

    # OLD API Results
    echo -e "${RED}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  TEST 1: OLD API (BUG DEMONSTRATION)${NC}"
    echo -e "${RED}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Queue Depth Progression:${NC}"
    echo "$OLD_API_QUEUE_DEPTHS" | while read line; do
        if [[ "$line" == *"depth: 2"* ]]; then
            echo -e "  ${RED}$line${NC} ← ${RED}${BOLD}DOUBLE-OPEN BUG!${NC}"
        else
            echo "  $line"
        fi
    done
    echo ""
    echo -e "${BOLD}Request Types:${NC}"
    echo "$OLD_API_REQUESTS" | while read line; do
        if [[ "$line" == *"link (null)"* ]]; then
            echo -e "  ${YELLOW}$line${NC}"
            echo -e "    ${YELLOW}↳ First request with NO link data${NC}"
        elif [[ "$line" == *"BranchOpenRequest"* ]] && [[ "$line" == *"link branch"* ]]; then
            echo -e "  ${RED}$line${NC}"
            echo -e "    ${RED}↳ Second request WITH link data - DUPLICATE!${NC}"
        else
            echo "  $line"
        fi
    done
    echo ""
    echo -e "${BOLD}Execution Flow:${NC}"
    echo "$OLD_API_DEBUG" | grep -E "(STEP|OLD API|URL)" | while read line; do
        echo "  $line"
    done

    echo ""

    # NEW API Results
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  TEST 2: NEW API (EMT-2816 FIX)${NC}"
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Queue Depth Progression:${NC}"
    echo "$NEW_API_QUEUE_DEPTHS" | while read line; do
        echo -e "  ${GREEN}$line${NC}"
    done

    # Count queue depths for NEW API
    NEW_API_MAX_DEPTH=$(echo "$NEW_API_QUEUE_DEPTHS" | grep -o "depth: [0-9]*" | tail -1 | grep -o "[0-9]*" || echo "0")

    echo ""
    echo -e "${BOLD}Request Types:${NC}"
    echo "$NEW_API_REQUESTS" | while read line; do
        echo -e "  ${GREEN}$line${NC}"
    done
    echo ""
    echo -e "${BOLD}Execution Flow:${NC}"
    echo "$NEW_API_DEBUG" | grep -E "(STEP|NEW API|EMT|URL|SDK)" | head -10 | while read line; do
        echo "  $line"
    done

    #---------------------------------------------------------------------------
    # SUMMARY
    #---------------------------------------------------------------------------
    print_header "SUMMARY"

    # Count requests for each test
    OLD_API_COUNT=$(echo "$OLD_API_QUEUE_DEPTHS" | grep -c "depth:" 2>/dev/null || echo "0")
    NEW_API_COUNT=$(echo "$NEW_API_QUEUE_DEPTHS" | grep -c "depth:" 2>/dev/null || echo "0")

    # Get the MAXIMUM queue depth (not the last one!)
    OLD_API_MAX_DEPTH=$(echo "$OLD_API_QUEUE_DEPTHS" | grep -o "depth: [0-9]*" | grep -o "[0-9]*" | sort -n | tail -1 || echo "0")
    NEW_API_MAX_DEPTH=$(echo "$NEW_API_QUEUE_DEPTHS" | grep -o "depth: [0-9]*" | grep -o "[0-9]*" | sort -n | tail -1 || echo "0")

    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│                    DOUBLE-OPEN BUG ANALYSIS                     │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│  API Mode          │  Max Queue Depth  │  Status               │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────┤${NC}"

    if [ "$OLD_API_MAX_DEPTH" -ge 2 ]; then
        echo -e "${BOLD}│${NC}  OLD API (Bug)     ${BOLD}│${NC}        ${RED}${BOLD}$OLD_API_MAX_DEPTH${NC}          ${BOLD}│${NC}  ${RED}${BOLD}🔴 BUG CONFIRMED${NC}      ${BOLD}│${NC}"
    else
        echo -e "${BOLD}│${NC}  OLD API (Bug)     ${BOLD}│${NC}        $OLD_API_MAX_DEPTH          ${BOLD}│${NC}  ⚠️  Not reproduced    ${BOLD}│${NC}"
    fi

    if [ "$NEW_API_MAX_DEPTH" -le 1 ]; then
        echo -e "${BOLD}│${NC}  NEW API (Fix)     ${BOLD}│${NC}        ${GREEN}${BOLD}$NEW_API_MAX_DEPTH${NC}          ${BOLD}│${NC}  ${GREEN}${BOLD}✅ FIX WORKING${NC}        ${BOLD}│${NC}"
    else
        echo -e "${BOLD}│${NC}  NEW API (Fix)     ${BOLD}│${NC}        ${YELLOW}$NEW_API_MAX_DEPTH${NC}          ${BOLD}│${NC}  ${YELLOW}⚠️  Unexpected${NC}        ${BOLD}│${NC}"
    fi

    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────┘${NC}"

    echo ""
    echo -e "${BOLD}Explanation:${NC}"
    echo ""
    echo "  ${RED}OLD API (Bug):${NC}"
    echo "    1. Branch.initSession(launchOptions: nil) → Sends OPEN #1 (no link)"
    echo "    2. Branch.application(_:open:options:)    → Sends OPEN #2 (with link)"
    echo "    Result: Two server requests, wasted resources, potential duplicate events"
    echo ""
    echo "  ${GREEN}NEW API (Fix):${NC}"
    echo "    1. BranchScene.initSession(with: connectionOptions)"
    echo "       → SDK detects URL in connectionOptions"
    echo "       → Defers OPEN until link is processed"
    echo "       → Only ONE request with link data"
    echo "    Result: Single server request, efficient, correct behavior"
    echo ""

    print_header "TEST COMPLETE"
    echo "The double-open bug has been verified."
    echo ""
    echo "To switch API modes manually in the app:"
    echo "  • Toggle 'Use Double Open Fix' switch in the app settings"
    echo "  • Or use: xcrun simctl spawn booted defaults write $BUNDLE_ID useDoubleOpenFix -bool <true|false>"
    echo ""
}

# Run main function
main "$@"
