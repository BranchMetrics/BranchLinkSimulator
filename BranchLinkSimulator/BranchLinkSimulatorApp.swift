//
//  BranchLinkSimulatorApp.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//
//  IMPORTANT: This app uses UIKit SceneDelegate for proper Branch SDK integration.
//  The SceneDelegate handles window creation and Branch initialization.
//  We use UIApplicationMain instead of SwiftUI @main to ensure SceneDelegate is called.

import UIKit

// Use UIApplicationMain to ensure SceneDelegate is used for window/scene management
// This is required for proper Branch SDK integration with connectionOptions
@main
class AppMain {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(AppDelegate.self)
        )
    }
}
