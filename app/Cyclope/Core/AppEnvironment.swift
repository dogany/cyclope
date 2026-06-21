//
//  AppEnvironment.swift
//  Cyclope
//

import Foundation

enum AppEnvironment {
    static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var isRunningForScreenshots: Bool {
        ProcessInfo.processInfo.environment["CYCLOPE_SCREENSHOT_MODE"] == "1"
    }

    static var shouldRunBackgroundServices: Bool {
        !isRunningForPreviews && !isRunningForScreenshots
    }
}
