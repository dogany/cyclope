//
//  WindowSnapper.swift
//  Cyclope
//

import AppKit
import ApplicationServices
import Foundation
import os

private func accessibilityCoordinateYReference(fallbackScreenFrame: CGRect? = nil) -> CGFloat? {
    // AX and CG window bounds use a top-left global Y axis anchored to the primary
    // display. AppKit screen frames use a bottom-left Y axis, so every display must
    // be flipped against the primary display, not against its own frame.
    if let primaryScreen = NSScreen.screens.first(where: \.isPrimaryDisplay) {
        return primaryScreen.frame.maxY
    }

    if let originScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
        return originScreen.frame.maxY
    }

    return fallbackScreenFrame?.maxY ?? NSScreen.screens.first?.frame.maxY
}

enum WindowNudgeDirection {
    case left
    case right
    case up
    case down

    init?(event: NSEvent) {
        guard Self.hasNoCommandModifiers(event) else { return nil }

        switch Int(event.keyCode) {
        case 123:
            self = .left
        case 124:
            self = .right
        case 125:
            self = .down
        case 126:
            self = .up
        default:
            return nil
        }
    }

    var statusTitle: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        case .up:
            return "up"
        case .down:
            return "down"
        }
    }

    func accessibilityOffset(distance: CGFloat) -> CGVector {
        switch self {
        case .left:
            return CGVector(dx: -distance, dy: 0)
        case .right:
            return CGVector(dx: distance, dy: 0)
        case .up:
            return CGVector(dx: 0, dy: -distance)
        case .down:
            return CGVector(dx: 0, dy: distance)
        }
    }

    func appKitOffset(distance: CGFloat) -> CGVector {
        switch self {
        case .left:
            return CGVector(dx: -distance, dy: 0)
        case .right:
            return CGVector(dx: distance, dy: 0)
        case .up:
            return CGVector(dx: 0, dy: distance)
        case .down:
            return CGVector(dx: 0, dy: -distance)
        }
    }

    private static func hasNoCommandModifiers(_ event: NSEvent) -> Bool {
        event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
            .isEmpty
    }
}

struct WindowSnapper {
    private let ignoredBundleIdentifiers: Set<String> = [
        "com.apple.ControlCenter",
        "com.apple.Dock",
        "com.apple.SystemEvents",
        "com.apple.SystemUIServer",
        "com.apple.loginwindow",
    ]
    private let logger = Logger(subsystem: "com.dogany.cyclope", category: "WindowSnapper")

    func snap(_ action: SnapAction, targetApplication: NSRunningApplication?) throws {
        try snap(targetApplication: targetApplication) { currentFrame, screen in
            targetFrame(for: action, currentFrame: currentFrame, screen: screen)
        }
    }

    func snap(_ action: SnapAction, targetApplication: NSRunningApplication?, on screen: NSScreen) throws {
        try snap(targetApplication: targetApplication, screenOverride: screen) { currentFrame, screen in
            targetFrame(for: action, currentFrame: currentFrame, screen: screen)
        }
    }

    func snap(_ action: SnapAction, targetWindow: NSWindow) throws {
        try snap(targetWindow: targetWindow) { currentFrame, screen in
            appKitTargetFrame(for: action, currentFrame: currentFrame, screen: screen)
        }
    }

    func snap(_ action: SnapAction, targetWindow: NSWindow, on screen: NSScreen) throws {
        try snap(targetWindow: targetWindow, screenOverride: screen) { currentFrame, screen in
            appKitTargetFrame(for: action, currentFrame: currentFrame, screen: screen)
        }
    }

    func snap(_ layout: SnapLayout, targetApplication: NSRunningApplication?) throws {
        try snap(targetApplication: targetApplication) { _, screen in
            let snappedFrame = layout.snappedFrame(in: screen.visibleFrame)
            return WindowSnapTargetFrame(
                frame: accessibilityFrame(fromAppKitFrame: snappedFrame, screenFrame: screen.frame),
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snap(_ layout: SnapLayout, targetApplication: NSRunningApplication?, on screen: NSScreen) throws {
        try snap(targetApplication: targetApplication, screenOverride: screen) { _, screen in
            let snappedFrame = layout.snappedFrame(in: screen.visibleFrame)
            return WindowSnapTargetFrame(
                frame: accessibilityFrame(fromAppKitFrame: snappedFrame, screenFrame: screen.frame),
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snap(_ layout: SnapLayout, targetWindow: NSWindow) throws {
        try snap(targetWindow: targetWindow) { _, screen in
            WindowSnapTargetFrame(
                frame: layout.snappedFrame(in: screen.visibleFrame),
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snap(_ layout: SnapLayout, targetWindow: NSWindow, on screen: NSScreen) throws {
        try snap(targetWindow: targetWindow, screenOverride: screen) { _, screen in
            WindowSnapTargetFrame(
                frame: layout.snappedFrame(in: screen.visibleFrame),
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snapPositionOnly(_ layout: SnapLayout, targetApplication: NSRunningApplication?) throws {
        try snap(targetApplication: targetApplication) { currentFrame, screen in
            let targetFrame = accessibilityFrame(
                fromAppKitFrame: layout.snappedFrame(in: screen.visibleFrame),
                screenFrame: screen.frame
            )
            return positionOnlyTargetFrame(
                targetFrame: targetFrame,
                currentSize: currentFrame.size,
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snapPositionOnly(_ layout: SnapLayout, targetApplication: NSRunningApplication?, on screen: NSScreen) throws {
        try snap(targetApplication: targetApplication, screenOverride: screen) { currentFrame, screen in
            let targetFrame = accessibilityFrame(
                fromAppKitFrame: layout.snappedFrame(in: screen.visibleFrame),
                screenFrame: screen.frame
            )
            return positionOnlyTargetFrame(
                targetFrame: targetFrame,
                currentSize: currentFrame.size,
                horizontalAlignment: layout.horizontalSnapAlignment,
                verticalAlignment: layout.verticalSnapAlignment
            )
        }
    }

    func snapPositionOnly(_ layout: SnapLayout, targetWindow: NSWindow) throws {
        try snap(targetWindow: targetWindow) { currentFrame, screen in
            WindowSnapTargetFrame(
                frame: positionOnlyAppKitFrame(
                    for: layout,
                    currentSize: currentFrame.size,
                    screen: screen
                ),
                horizontalAlignment: .minimum,
                verticalAlignment: .minimum
            )
        }
    }

    func snapPositionOnly(_ layout: SnapLayout, targetWindow: NSWindow, on screen: NSScreen) throws {
        try snap(targetWindow: targetWindow, screenOverride: screen) { currentFrame, screen in
            WindowSnapTargetFrame(
                frame: positionOnlyAppKitFrame(
                    for: layout,
                    currentSize: currentFrame.size,
                    screen: screen
                ),
                horizontalAlignment: .minimum,
                verticalAlignment: .minimum
            )
        }
    }

    func nudge(
        _ direction: WindowNudgeDirection,
        distance: CGFloat,
        targetApplication: NSRunningApplication?
    ) throws {
        try snap(targetApplication: targetApplication) { currentFrame, screen in
            let frame = currentFrame
                .offsetBy(direction.accessibilityOffset(distance: distance))
                .constrainedOrigin(to: accessibilityVisibleFrame(for: screen))
            return WindowSnapTargetFrame(
                frame: frame,
                horizontalAlignment: .minimum,
                verticalAlignment: .minimum
            )
        }
    }

    func nudge(
        _ direction: WindowNudgeDirection,
        distance: CGFloat,
        targetWindow: NSWindow
    ) throws {
        try snap(targetWindow: targetWindow) { currentFrame, screen in
            let frame = currentFrame
                .offsetBy(direction.appKitOffset(distance: distance))
                .constrainedOrigin(to: screen.visibleFrame)
            return WindowSnapTargetFrame(
                frame: frame,
                horizontalAlignment: .minimum,
                verticalAlignment: .minimum
            )
        }
    }

    private func snap(
        targetApplication: NSRunningApplication?,
        screenOverride: NSScreen? = nil,
        targetFrame: (CGRect, NSScreen) -> WindowSnapTargetFrame
    ) throws {
        guard AXIsProcessTrusted() else {
            throw WindowSnapperError.accessibilityPermissionRequired
        }

        let applications = targetApplicationCandidates(preferredApplication: targetApplication)
        guard !applications.isEmpty else {
            throw WindowSnapperError.noTargetApplication
        }

        var lastRecoverableError: Error?
        var sawMessagingFailure = false
        var sawOtherRecoverableFailure = false
        for application in applications {
            do {
                try snap(application: application, screenOverride: screenOverride, targetFrame: targetFrame)
                return
            } catch let error as WindowSnapperError {
                switch error {
                case .accessibilityMessagingUnavailable:
                    sawMessagingFailure = true
                    lastRecoverableError = error
                    continue
                case .noFocusedWindow, .noScreen, .windowFrameUnavailable:
                    sawOtherRecoverableFailure = true
                    lastRecoverableError = error
                    continue
                case .accessibilityPermissionRequired, .noTargetApplication, .windowMoveFailed:
                    throw error
                }
            }
        }

        // Every candidate refused Accessibility messaging (kAXErrorCannotComplete)
        // while AXIsProcessTrusted() reported true, and none yielded a real window.
        // That is a stale TCC grant, not an absent window — report it as such so the
        // caller can tell the user to re-grant instead of "no focused window".
        if sawMessagingFailure && !sawOtherRecoverableFailure {
            throw WindowSnapperError.accessibilityMessagingUnavailable
        }

        throw lastRecoverableError ?? WindowSnapperError.noTargetApplication
    }

    private func snap(
        application: NSRunningApplication,
        screenOverride: NSScreen? = nil,
        targetFrame: (CGRect, NSScreen) -> WindowSnapTargetFrame
    ) throws {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let window = try focusedWindow(in: appElement)
        let currentFrame = try frame(of: window)
        guard let screen = screenOverride ?? screen(containing: currentFrame) ?? NSScreen.main else {
            throw WindowSnapperError.noScreen
        }

        let targetFrame = targetFrame(currentFrame, screen)
        try set(targetFrame: targetFrame.integral, on: window)
    }

    private func targetApplicationCandidates(preferredApplication: NSRunningApplication?) -> [NSRunningApplication] {
        var applications: [NSRunningApplication] = []

        if let preferredApplication {
            applications.append(preferredApplication)
        }

        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            applications.append(frontmostApplication)
        }

        applications.append(contentsOf: NSWorkspace.shared.runningApplications.filter(\.isActive))
        applications.append(contentsOf: frontmostExternalWindowOwners())

        var seen = Set<pid_t>()
        return applications.filter { application in
            guard seen.insert(application.processIdentifier).inserted else { return false }
            return isWindowSnapCandidate(application)
        }
    }

    private func isWindowSnapCandidate(_ application: NSRunningApplication) -> Bool {
        guard application.activationPolicy == .regular,
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier,
              !ignoredBundleIdentifiers.contains(bundleIdentifier) else {
            return false
        }

        return true
    }

    private func frontmostExternalWindowOwners() -> [NSRunningApplication] {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var applications: [NSRunningApplication] = []
        var seen = Set<pid_t>()
        for window in windowInfo {
            if let layer = window[kCGWindowLayer as String] as? Int, layer != 0 {
                continue
            }

            guard let processIdentifier = window[kCGWindowOwnerPID as String] as? pid_t,
                  let application = NSRunningApplication(processIdentifier: processIdentifier),
                  isWindowSnapCandidate(application) else {
                continue
            }

            guard seen.insert(processIdentifier).inserted else {
                continue
            }

            applications.append(application)
        }

        return applications
    }

    private func snap(
        targetWindow: NSWindow,
        screenOverride: NSScreen? = nil,
        targetFrame: (CGRect, NSScreen) -> WindowSnapTargetFrame
    ) throws {
        let currentFrame = targetWindow.frame
        guard let screen = screenOverride ?? screen(containingAppKitFrame: currentFrame) ?? targetWindow.screen ?? NSScreen.main else {
            throw WindowSnapperError.noScreen
        }

        let targetFrame = targetFrame(currentFrame, screen)
        set(targetFrame: targetFrame.integral, on: targetWindow)
    }

    private func positionOnlyTargetFrame(
        targetFrame: CGRect,
        currentSize: CGSize,
        horizontalAlignment: WindowSnapAxisAlignment,
        verticalAlignment: WindowSnapAxisAlignment
    ) -> WindowSnapTargetFrame {
        let origin = CGPoint(
            x: horizontalAlignment.origin(
                requestedMin: targetFrame.minX,
                requestedMax: targetFrame.maxX,
                actualLength: currentSize.width
            ),
            y: verticalAlignment.origin(
                requestedMin: targetFrame.minY,
                requestedMax: targetFrame.maxY,
                actualLength: currentSize.height
            )
        )

        return WindowSnapTargetFrame(
            frame: CGRect(origin: origin, size: currentSize),
            horizontalAlignment: .minimum,
            verticalAlignment: .minimum
        )
    }

    private func positionOnlyAppKitFrame(
        for layout: SnapLayout,
        currentSize: CGSize,
        screen: NSScreen
    ) -> CGRect {
        let targetFrame = layout.snappedFrame(in: screen.visibleFrame)
        return positionOnlyTargetFrame(
            targetFrame: targetFrame,
            currentSize: currentSize,
            horizontalAlignment: layout.horizontalSnapAlignment,
            verticalAlignment: layout.appKitVerticalPositionAlignment
        ).frame
    }

    private func focusedWindow(in appElement: AXUIElement) throws -> AXUIElement {
        var focusedWindow: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if focusedResult == .success, let focusedWindow {
            return focusedWindow as! AXUIElement
        }

        var mainWindow: CFTypeRef?
        let mainResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindow
        )

        if mainResult == .success, let mainWindow {
            return mainWindow as! AXUIElement
        }

        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windows
        )

        if windowsResult == .success, let firstWindow = firstWindow(from: windows) {
            return firstWindow
        }

        // Every window lookup failed. Log the raw AXError codes so the cause is
        // diagnosable, then disambiguate the failure. When the Accessibility API
        // itself refuses the query, the window can't be read for a permission
        // reason — not because the app has no window. This happens when the
        // Accessibility (TCC) authorization is stale for the current code
        // signature (e.g. right after enabling App Sandbox / Hardened Runtime, or
        // after a rebuild re-signs the app) even though AXIsProcessTrusted() still
        // reports true. Reporting it as a permission error gives the user an
        // actionable message ("re-grant Accessibility") instead of the misleading
        // "no focused window".
        logger.error("focused window lookup failed focused=\(focusedResult.rawValue, privacy: .public) main=\(mainResult.rawValue, privacy: .public) windows=\(windowsResult.rawValue, privacy: .public)")

        if isAccessibilityAuthorizationFailure(focusedResult)
            || isAccessibilityAuthorizationFailure(mainResult)
            || isAccessibilityAuthorizationFailure(windowsResult) {
            throw WindowSnapperError.accessibilityPermissionRequired
        }

        // AXIsProcessTrusted() was true on entry (guarded in snap), yet every window
        // query was refused with kAXErrorCannotComplete. That is the fingerprint of a
        // stale Accessibility (TCC) authorization — the trust flag still reports
        // granted while cross-process messaging is denied — not a missing window.
        if isAccessibilityMessagingFailure(focusedResult)
            && isAccessibilityMessagingFailure(mainResult)
            && isAccessibilityMessagingFailure(windowsResult) {
            throw WindowSnapperError.accessibilityMessagingUnavailable
        }

        throw WindowSnapperError.noFocusedWindow
    }

    private func isAccessibilityAuthorizationFailure(_ error: AXError) -> Bool {
        // .apiDisabled is returned to the *caller* when its Accessibility access is
        // not authorized, regardless of which target app is queried — so it is an
        // unambiguous signal that the permission (not the window) is the problem.
        error == .apiDisabled
    }

    private func isAccessibilityMessagingFailure(_ error: AXError) -> Bool {
        // .cannotComplete means the Accessibility message could not be delivered to
        // the target app. On its own it can mean a momentarily unresponsive app, but
        // when it is returned for every window attribute of every candidate app while
        // the process is trusted, the authorization itself is stale.
        error == .cannotComplete
    }

    private func firstWindow(from value: CFTypeRef?) -> AXUIElement? {
        if let windowList = value as? [AXUIElement] {
            return windowList.first
        }

        guard let windowList = value as? [AnyObject] else {
            return nil
        }

        return windowList.first.map { $0 as! AXUIElement }
    }

    private func frame(of window: AXUIElement) throws -> CGRect {
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard positionResult == .success,
              sizeResult == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue else {
            throw WindowSnapperError.windowFrameUnavailable
        }

        var origin = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size) else {
            throw WindowSnapperError.windowFrameUnavailable
        }

        return CGRect(origin: origin, size: size)
    }

    private func set(targetFrame: WindowSnapTargetFrame, on window: AXUIElement) throws {
        let frame = targetFrame.frame

        _ = set(position: frame.origin, on: window)
        _ = set(size: frame.size, on: window)
        try setAlignedPosition(for: targetFrame, on: window)

        _ = set(position: frame.origin, on: window)
        guard set(size: frame.size, on: window) else {
            throw WindowSnapperError.windowMoveFailed
        }

        try setAlignedPosition(for: targetFrame, on: window)
    }

    private func set(targetFrame: WindowSnapTargetFrame, on window: NSWindow) {
        let frame = targetFrame.frame
        window.setFrame(frame, display: true)
        setAlignedPosition(for: targetFrame, on: window)
    }

    @discardableResult
    private func set(size: CGSize, on window: AXUIElement) -> Bool {
        var targetSize = size
        guard let dimensions = AXValueCreate(.cgSize, &targetSize) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            dimensions
        ) == .success
    }

    @discardableResult
    private func set(position: CGPoint, on window: AXUIElement) -> Bool {
        var targetPosition = position
        guard let position = AXValueCreate(.cgPoint, &targetPosition) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            position
        ) == .success
    }

    private func setAlignedPosition(for targetFrame: WindowSnapTargetFrame, on window: AXUIElement) throws {
        let frame = targetFrame.frame
        let actualFrame = (try? self.frame(of: window)) ?? frame
        let origin = CGPoint(
            x: targetFrame.horizontalAlignment.origin(
                requestedMin: frame.minX,
                requestedMax: frame.maxX,
                actualLength: actualFrame.width
            ),
            y: targetFrame.verticalAlignment.origin(
                requestedMin: frame.minY,
                requestedMax: frame.maxY,
                actualLength: actualFrame.height
            )
        )

        guard set(position: origin, on: window) else {
            throw WindowSnapperError.windowMoveFailed
        }
    }

    private func setAlignedPosition(for targetFrame: WindowSnapTargetFrame, on window: NSWindow) {
        let frame = targetFrame.frame
        let actualFrame = window.frame
        let origin = CGPoint(
            x: targetFrame.horizontalAlignment.origin(
                requestedMin: frame.minX,
                requestedMax: frame.maxX,
                actualLength: actualFrame.width
            ),
            y: targetFrame.verticalAlignment.origin(
                requestedMin: frame.minY,
                requestedMax: frame.maxY,
                actualLength: actualFrame.height
            )
        )

        window.setFrameOrigin(origin)
    }

    private func targetFrame(
        for action: SnapAction,
        currentFrame: CGRect,
        screen: NSScreen
    ) -> WindowSnapTargetFrame {
        let targetFrame = appKitTargetFrame(for: action, currentFrame: currentFrame, screen: screen)
        return WindowSnapTargetFrame(
            frame: accessibilityFrame(fromAppKitFrame: targetFrame.frame, screenFrame: screen.frame),
            horizontalAlignment: targetFrame.horizontalAlignment,
            verticalAlignment: targetFrame.verticalAlignment
        )
    }

    private func appKitTargetFrame(
        for action: SnapAction,
        currentFrame: CGRect,
        screen: NSScreen
    ) -> WindowSnapTargetFrame {
        let visibleFrame = screen.visibleFrame
        let appKitFrame: CGRect

        switch action {
        case .leftHalf:
            appKitFrame = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .rightHalf:
            appKitFrame = CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .topHalf:
            appKitFrame = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.midY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
        case .bottomHalf:
            appKitFrame = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
        case .fullScreen:
            appKitFrame = visibleFrame
        case .center:
            let width = currentFrame.width
            let height = currentFrame.height
            appKitFrame = CGRect(
                x: visibleFrame.midX - width / 2,
                y: visibleFrame.midY - height / 2,
                width: width,
                height: height
            )
        }

        return WindowSnapTargetFrame(
            frame: appKitFrame,
            horizontalAlignment: action.horizontalSnapAlignment,
            verticalAlignment: action.verticalSnapAlignment
        )
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        let appKitFrame = appKitFrame(fromAccessibilityFrame: frame)
        return screen(containingAppKitFrame: appKitFrame)
    }

    private func screen(containingAppKitFrame frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { first, second in
            first.visibleFrame.intersection(frame).area <
                second.visibleFrame.intersection(frame).area
        }
    }

    private func accessibilityVisibleFrame(for screen: NSScreen) -> CGRect {
        accessibilityFrame(fromAppKitFrame: screen.visibleFrame, screenFrame: screen.frame)
    }

    private func accessibilityFrame(fromAppKitFrame frame: CGRect, screenFrame: CGRect) -> CGRect {
        let yReference = accessibilityCoordinateYReference(fallbackScreenFrame: screenFrame) ?? screenFrame.maxY
        return CGRect(
            x: frame.minX,
            y: yReference - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect {
        let yReference = accessibilityCoordinateYReference() ?? frame.maxY
        return CGRect(
            x: frame.minX,
            y: yReference - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

private struct WindowSnapTargetFrame {
    var frame: CGRect
    var horizontalAlignment: WindowSnapAxisAlignment
    var verticalAlignment: WindowSnapAxisAlignment

    var integral: WindowSnapTargetFrame {
        WindowSnapTargetFrame(
            frame: frame.integral,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment
        )
    }
}

private enum WindowSnapAxisAlignment {
    case minimum
    case center
    case maximum

    func origin(requestedMin: CGFloat, requestedMax: CGFloat, actualLength: CGFloat) -> CGFloat {
        switch self {
        case .minimum:
            return requestedMin
        case .center:
            return requestedMin + (requestedMax - requestedMin - actualLength) / 2
        case .maximum:
            return requestedMax - actualLength
        }
    }
}

private extension SnapAction {
    var horizontalSnapAlignment: WindowSnapAxisAlignment {
        switch self {
        case .rightHalf:
            return .maximum
        case .center:
            return .center
        case .leftHalf, .topHalf, .bottomHalf, .fullScreen:
            return .minimum
        }
    }

    var verticalSnapAlignment: WindowSnapAxisAlignment {
        switch self {
        case .bottomHalf:
            return .maximum
        case .center:
            return .center
        case .leftHalf, .rightHalf, .topHalf, .fullScreen:
            return .minimum
        }
    }
}

private extension SnapLayout {
    var horizontalSnapAlignment: WindowSnapAxisAlignment {
        if startColumn <= 0 {
            return .minimum
        }

        if startColumn + columnSpan >= columns {
            return .maximum
        }

        return .center
    }

    var verticalSnapAlignment: WindowSnapAxisAlignment {
        if startRow <= 0 {
            return .minimum
        }

        if startRow + rowSpan >= rows {
            return .maximum
        }

        return .center
    }

    var appKitVerticalPositionAlignment: WindowSnapAxisAlignment {
        if startRow <= 0 {
            return .maximum
        }

        if startRow + rowSpan >= rows {
            return .minimum
        }

        return .center
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    var isPrimaryDisplay: Bool {
        displayID == CGMainDisplayID()
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }

    func offsetBy(_ offset: CGVector) -> CGRect {
        offsetBy(dx: offset.dx, dy: offset.dy)
    }

    func constrainedOrigin(to bounds: CGRect) -> CGRect {
        var result = self

        if result.width <= bounds.width {
            result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
        } else if result.maxX < bounds.minX {
            result.origin.x = bounds.minX - result.width
        } else if result.minX > bounds.maxX {
            result.origin.x = bounds.maxX
        }

        if result.height <= bounds.height {
            result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
        } else if result.maxY < bounds.minY {
            result.origin.y = bounds.minY - result.height
        } else if result.minY > bounds.maxY {
            result.origin.y = bounds.maxY
        }

        return result
    }
}

enum WindowSnapperError: LocalizedError {
    case accessibilityPermissionRequired
    case accessibilityMessagingUnavailable
    case noFocusedWindow
    case noScreen
    case noTargetApplication
    case windowFrameUnavailable
    case windowMoveFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required for window snapping."
        case .accessibilityMessagingUnavailable:
            return "Cyclope’s Accessibility access looks stale. Open System Settings → Privacy & Security → Accessibility and turn Cyclope off, then on (or remove and re-add it)."
        case .noFocusedWindow:
            return "No focused window was found in the target app."
        case .noScreen:
            return "No display was available for the active window."
        case .noTargetApplication:
            return "No target application was available."
        case .windowFrameUnavailable:
            return "The active window frame could not be read."
        case .windowMoveFailed:
            return "The active window could not be moved or resized."
        }
    }
}

@MainActor
final class WindowDragSnapManager {
    private enum DragKind {
        case unknown
        case moving
        case resizing
    }

    private struct DragSession {
        let window: AXUIElement
        let initialFrame: CGRect
        let initialAccessibilityMouseLocation: CGPoint
        let initialAppKitMouseLocation: CGPoint
        var kind: DragKind = .unknown
    }

    private weak var snapSettings: SnapSettingsStore?
    private var shouldHandleOwnApplicationDrag: (() -> Bool)?
    private var snapHandler: ((WindowDragSnapTarget, NSScreen) -> Void)?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var dragSession: DragSession?
    private var activeTarget: WindowDragSnapTarget?
    private var activeTargetScreen: NSScreen?
    private var pendingTarget: WindowDragSnapTarget?
    private var pendingTargetScreen: NSScreen?
    private var pendingTargetWorkItem: DispatchWorkItem?
    private var previewPanel: SnapPreviewPanel?
    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private let frameChangeThreshold: CGFloat = 3
    private let mouseDragThreshold: CGFloat = 8
    private let resizeEdgeThreshold: CGFloat = 10

    private var snapActivationDwellDelay: TimeInterval {
        snapSettings?.snapActivationDwellDelay ?? SnapSettingsSnapshot.defaultSnapActivationDwellDelay
    }

    func start(
        snapSettings: SnapSettingsStore,
        shouldHandleOwnApplicationDrag: @escaping () -> Bool = { false },
        snapHandler: @escaping (WindowDragSnapTarget, NSScreen) -> Void
    ) {
        stop()
        self.snapSettings = snapSettings
        self.shouldHandleOwnApplicationDrag = shouldHandleOwnApplicationDrag
        self.snapHandler = snapHandler
        // A CGEvent session tap gets disabled mid-gesture by the system
        // (kCGEventTapDisabledByUserInput) right after mouse-down, which silently
        // drops the rest of the drag and breaks snapping. NSEvent monitors observe
        // the same events without that failure mode, so prefer them and only fall
        // back to a tap if the monitors can't be installed.
        if !startMouseMonitors() {
            _ = startEventTap()
        }
    }

    @discardableResult
    private func startMouseMonitors() -> Bool {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                let appKitMouseLocation = NSEvent.mouseLocation
                self?.handleMouseEvent(
                    event.type,
                    accessibilityMouseLocation: Self.accessibilityMouseLocation(fromAppKitPoint: appKitMouseLocation),
                    appKitMouseLocation: appKitMouseLocation
                )
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                let appKitMouseLocation = NSEvent.mouseLocation
                self?.handleMouseEvent(
                    event.type,
                    accessibilityMouseLocation: Self.accessibilityMouseLocation(fromAppKitPoint: appKitMouseLocation),
                    appKitMouseLocation: appKitMouseLocation
                )
            }
            return event
        }

        return globalMouseMonitor != nil
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }

        eventTap = nil

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        resetDragSession()
        snapSettings = nil
        shouldHandleOwnApplicationDrag = nil
        snapHandler = nil
    }

    private func startEventTap() -> Bool {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: windowDragSnapEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = eventTap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    fileprivate func handleEventTapEvent(
        _ type: CGEventType,
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint
    ) {
        switch type {
        case .leftMouseDown:
            beginDrag(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation
            )
        case .leftMouseDragged:
            updateDrag(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation,
                allowsLateMovingSession: true
            )
        case .leftMouseUp:
            finishDrag()
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }

    private func handleMouseEvent(
        _ type: NSEvent.EventType,
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint
    ) {
        switch type {
        case .leftMouseDown:
            beginDrag(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation
            )
        case .leftMouseDragged:
            updateDrag(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation,
                allowsLateMovingSession: true
            )
        case .leftMouseUp:
            finishDrag()
        default:
            break
        }
    }

    private func beginDrag(accessibilityMouseLocation: CGPoint, appKitMouseLocation: CGPoint) {
        guard shouldHandleCurrentDrag else {
            resetDragSession()
            return
        }

        guard let session = currentDragSession(
            accessibilityMouseLocation: accessibilityMouseLocation,
            appKitMouseLocation: appKitMouseLocation,
            assumedKind: nil
        ) else {
            resetDragSession()
            return
        }

        dragSession = session
        clearActiveTarget()
        updateDrag(
            accessibilityMouseLocation: accessibilityMouseLocation,
            appKitMouseLocation: appKitMouseLocation
        )
    }

    private func updateDrag(
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint,
        allowsLateMovingSession: Bool = false
    ) {
        guard shouldHandleCurrentDrag else {
            resetDragSession()
            return
        }

        if dragSession == nil {
            dragSession = currentDragSession(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation,
                assumedKind: allowsLateMovingSession ? .moving : nil
            )
        }

        guard refreshDragKind(
            accessibilityMouseLocation: accessibilityMouseLocation,
            appKitMouseLocation: appKitMouseLocation
        ) else {
            clearActiveTarget()
            return
        }

        guard let match = matchingPreset(appKitMouseLocation: appKitMouseLocation) else {
            clearActiveTarget()
            return
        }

        armSnapTarget(match)
    }

    private func finishDrag() {
        let target = activeTarget
        let screen = activeTargetScreen
        let shouldSnap = dragSession?.kind == .moving
        resetDragSession()

        guard shouldSnap, let target, let screen else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.snapHandler?(target, screen)
        }
    }

    private var shouldHandleCurrentDrag: Bool {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else { return true }
        return !isOwnApplication(frontmostApplication) || canHandleOwnApplicationDrag
    }

    private var canHandleOwnApplicationDrag: Bool {
        shouldHandleOwnApplicationDrag?() == true
    }

    private func isOwnApplication(_ application: NSRunningApplication) -> Bool {
        application.bundleIdentifier == ownBundleIdentifier
    }

    private func currentDragSession(
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint,
        assumedKind: DragKind?
    ) -> DragSession? {
        guard let window = focusedWindow(),
              let frame = frame(of: window) else {
            return nil
        }

        return DragSession(
            window: window,
            initialFrame: frame,
            initialAccessibilityMouseLocation: accessibilityMouseLocation,
            initialAppKitMouseLocation: appKitMouseLocation,
            kind: assumedKind ?? initialDragKind(
                accessibilityMouseLocation: accessibilityMouseLocation,
                appKitMouseLocation: appKitMouseLocation,
                frame: frame
            )
        )
    }

    private func refreshDragKind(
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint
    ) -> Bool {
        guard var session = dragSession,
              let currentFrame = frame(of: session.window) else {
            resetDragSession()
            return false
        }

        let sizeDelta = max(
            abs(currentFrame.width - session.initialFrame.width),
            abs(currentFrame.height - session.initialFrame.height)
        )
        let originDelta = max(
            abs(currentFrame.minX - session.initialFrame.minX),
            abs(currentFrame.minY - session.initialFrame.minY)
        )

        if originDelta > frameChangeThreshold && originDelta - sizeDelta > frameChangeThreshold {
            // The window moved much more than it resized, so treat it as a move even
            // when its size jitters (e.g. crossing displays or clamping at a screen
            // edge). Otherwise an incidental size change would flip the drag to
            // .resizing and silently block snapping.
            session.kind = .moving
        } else if sizeDelta > frameChangeThreshold {
            session.kind = .resizing
        } else if originDelta > frameChangeThreshold {
            session.kind = .moving
        } else if session.kind == .unknown &&
                    movedFarEnough(
                        session: session,
                        accessibilityMouseLocation: accessibilityMouseLocation,
                        appKitMouseLocation: appKitMouseLocation
                    ) &&
                    isLikelyWindowMoveStart(session: session) {
            session.kind = .moving
        }

        dragSession = session
        return session.kind == .moving
    }

    private func matchingPreset(appKitMouseLocation: CGPoint) -> (target: WindowDragSnapTarget, screen: NSScreen)? {
        matchingPreset(at: appKitMouseLocation)
    }

    private func armSnapTarget(_ match: (target: WindowDragSnapTarget, screen: NSScreen)) {
        if activeTarget == match.target && isSameScreen(activeTargetScreen, as: match.screen) {
            showPreview(for: match.target, on: match.screen)
            return
        }

        if pendingTarget == match.target && isSameScreen(pendingTargetScreen, as: match.screen) {
            return
        }

        cancelPendingTarget()
        activeTarget = nil
        activeTargetScreen = nil
        hidePreview()

        pendingTarget = match.target
        pendingTargetScreen = match.screen

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.pendingTarget == match.target,
                  self.isSameScreen(self.pendingTargetScreen, as: match.screen) else {
                return
            }

            self.pendingTarget = nil
            self.pendingTargetScreen = nil
            self.pendingTargetWorkItem = nil
            self.activeTarget = match.target
            self.activeTargetScreen = match.screen
            self.showPreview(for: match.target, on: match.screen)
        }

        pendingTargetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + snapActivationDwellDelay, execute: workItem)
    }

    private func isSameScreen(_ screen: NSScreen?, as otherScreen: NSScreen) -> Bool {
        guard let screen else { return false }
        return screen === otherScreen || screen.frame.equalTo(otherScreen.frame)
    }

    private func activationScreens(containing point: CGPoint) -> [NSScreen] {
        let contained = NSScreen.screens.filter { $0.frame.contains(point) }
        guard contained.isEmpty else { return contained }

        // CGRect.contains excludes the max edges, so a cursor pinned to the very top
        // or right of a display matches no screen. Fall back to a boundary-inclusive
        // test so edge gestures (top/right snapping) still resolve a screen.
        return NSScreen.screens.filter { screen in
            let frame = screen.frame
            return point.x >= frame.minX && point.x <= frame.maxX &&
                point.y >= frame.minY && point.y <= frame.maxY
        }
    }

    private func matchingPreset(at point: CGPoint) -> (target: WindowDragSnapTarget, screen: NSScreen)? {
        guard let snapSettings else { return nil }

        for screen in activationScreens(containing: point) {
            let visibleFrame = screen.visibleFrame

            if let preset = snapSettings.presets.reversed().first(where: { preset in
                preset.isSnapActivationEnabled &&
                    preset.snapActivationLayouts.contains { layout in
                        layout.contains(point: point, in: visibleFrame, screenFrame: screen.frame)
                    }
            }) {
                return (
                    WindowDragSnapTarget(
                        title: preset.name,
                        layout: preset.layout,
                        snapAction: nil,
                        position: preset.isPositionOnly ? preset.position : nil
                    ),
                    screen
                )
            }

            if let command = ShortcutCommand.defaultCommands.reversed().first(where: { command in
                guard let preference = snapSettings.snapActivationPreference(for: command),
                      preference.isEnabled else {
                    return false
                }

                return preference.layouts.contains { layout in
                    layout.contains(point: point, in: visibleFrame, screenFrame: screen.frame)
                }
            }), let layout = command.previewLayout {
                return (
                    WindowDragSnapTarget(
                        title: command.title,
                        layout: layout,
                        snapAction: command.snapAction,
                        position: nil
                    ),
                    screen
                )
            }
        }

        return nil
    }

    private func showPreview(for target: WindowDragSnapTarget, on screen: NSScreen) {
        let targetFrame = previewFrame(for: target, on: screen).integral
        let panel = previewPanel ?? SnapPreviewPanel()
        previewPanel = panel
        panel.show(frame: targetFrame)
    }

    private func previewFrame(for target: WindowDragSnapTarget, on screen: NSScreen) -> CGRect {
        guard let currentFrame = currentDragAppKitFrame() else {
            return target.layout.snappedFrame(in: screen.visibleFrame)
        }

        if target.snapAction == .center {
            let visibleFrame = screen.visibleFrame
            return CGRect(
                x: visibleFrame.midX - currentFrame.width / 2,
                y: visibleFrame.midY - currentFrame.height / 2,
                width: currentFrame.width,
                height: currentFrame.height
            )
        }

        if let position = target.position {
            return positionOnlyAppKitFrame(
                for: position.layout,
                currentSize: currentFrame.size,
                screen: screen
            )
        }

        return target.layout.snappedFrame(in: screen.visibleFrame)
    }

    private func positionOnlyAppKitFrame(
        for layout: SnapLayout,
        currentSize: CGSize,
        screen: NSScreen
    ) -> CGRect {
        let targetFrame = layout.snappedFrame(in: screen.visibleFrame)
        let origin = CGPoint(
            x: layout.horizontalSnapAlignment.origin(
                requestedMin: targetFrame.minX,
                requestedMax: targetFrame.maxX,
                actualLength: currentSize.width
            ),
            y: layout.appKitVerticalPositionAlignment.origin(
                requestedMin: targetFrame.minY,
                requestedMax: targetFrame.maxY,
                actualLength: currentSize.height
            )
        )

        return CGRect(origin: origin, size: currentSize)
    }

    private func currentDragAppKitFrame() -> CGRect? {
        if let window = dragSession?.window,
           let frame = frame(of: window),
           let appKitFrame = Self.appKitFrame(fromAccessibilityFrame: frame) {
            return appKitFrame
        }

        guard let initialFrame = dragSession?.initialFrame else {
            return nil
        }

        return Self.appKitFrame(fromAccessibilityFrame: initialFrame)
    }

    private func clearActiveTarget() {
        cancelPendingTarget()
        activeTarget = nil
        activeTargetScreen = nil
        hidePreview()
    }

    private func resetDragSession() {
        dragSession = nil
        clearActiveTarget()
    }

    private func hidePreview() {
        previewPanel?.orderOut(nil)
    }

    private func cancelPendingTarget() {
        pendingTargetWorkItem?.cancel()
        pendingTargetWorkItem = nil
        pendingTarget = nil
        pendingTargetScreen = nil
    }

    private func initialDragKind(
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint,
        frame: CGRect
    ) -> DragKind {
        let appKitFrame = Self.appKitFrame(fromAccessibilityFrame: frame)
        if isLikelyResizeStart(mouseLocation: accessibilityMouseLocation, frame: frame) ||
            appKitFrame.map({ isLikelyResizeStart(mouseLocation: appKitMouseLocation, frame: $0) }) == true {
            return .resizing
        }

        return .unknown
    }

    private func isLikelyResizeStart(mouseLocation: CGPoint, frame: CGRect) -> Bool {
        guard frame.contains(mouseLocation) else { return false }

        let nearLeft = abs(mouseLocation.x - frame.minX) <= resizeEdgeThreshold
        let nearRight = abs(mouseLocation.x - frame.maxX) <= resizeEdgeThreshold
        let nearTop = abs(mouseLocation.y - frame.minY) <= 4
        let nearBottom = abs(mouseLocation.y - frame.maxY) <= resizeEdgeThreshold

        return nearLeft || nearRight || nearTop || nearBottom
    }

    private func isLikelyWindowMoveStart(mouseLocation: CGPoint, frame: CGRect) -> Bool {
        guard frame.contains(mouseLocation),
              !isLikelyResizeStart(mouseLocation: mouseLocation, frame: frame) else {
            return false
        }

        let titlebarHeight = min(max(frame.height * 0.18, 56), 150)
        return mouseLocation.y >= frame.minY &&
            mouseLocation.y <= frame.minY + titlebarHeight
    }

    private func movedFarEnough(
        session: DragSession,
        accessibilityMouseLocation: CGPoint,
        appKitMouseLocation: CGPoint
    ) -> Bool {
        mouseDistance(
            from: session.initialAccessibilityMouseLocation,
            to: accessibilityMouseLocation
        ) > mouseDragThreshold ||
            mouseDistance(
                from: session.initialAppKitMouseLocation,
                to: appKitMouseLocation
            ) > mouseDragThreshold
    }

    private func isLikelyWindowMoveStart(session: DragSession) -> Bool {
        if isLikelyWindowMoveStart(
            mouseLocation: session.initialAccessibilityMouseLocation,
            frame: session.initialFrame
        ) {
            return true
        }

        guard let appKitFrame = Self.appKitFrame(fromAccessibilityFrame: session.initialFrame) else {
            return false
        }

        return isLikelyWindowMoveStart(
            mouseLocation: session.initialAppKitMouseLocation,
            frame: appKitFrame
        )
    }

    private func mouseDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    fileprivate static func accessibilityMouseLocation(fromAppKitPoint point: CGPoint) -> CGPoint {
        guard let yReference = accessibilityCoordinateYReference() else {
            return point
        }

        return CGPoint(
            x: point.x,
            y: yReference - point.y
        )
    }

    private static func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect? {
        guard let yReference = accessibilityCoordinateYReference() else {
            return nil
        }

        let appKitFrame = CGRect(
            x: frame.minX,
            y: yReference - frame.maxY,
            width: frame.width,
            height: frame.height
        )

        guard NSScreen.screens.contains(where: { $0.frame.intersection(appKitFrame).area > 0 }) else {
            return nil
        }

        return appKitFrame
    }

    private func focusedWindow() -> AXUIElement? {
        guard AXIsProcessTrusted(),
              let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        if isOwnApplication(application), !canHandleOwnApplicationDrag {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindow: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if focusedResult == .success, let focusedWindow {
            return (focusedWindow as! AXUIElement)
        }

        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windows
        )

        guard windowsResult == .success,
              let windowList = windows as? [AXUIElement] else {
            return nil
        }

        return windowList.first
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard positionResult == .success,
              sizeResult == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

}

struct WindowDragSnapTarget: Equatable {
    let title: String
    let layout: SnapLayout
    let snapAction: SnapAction?
    let position: CustomSnapPosition?
}

private let windowDragSnapEventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<WindowDragSnapManager>.fromOpaque(refcon).takeUnretainedValue()
    let appKitMouseLocation = NSEvent.mouseLocation
    let accessibilityMouseLocation = WindowDragSnapManager.accessibilityMouseLocation(
        fromAppKitPoint: appKitMouseLocation
    )
    Task { @MainActor in
        manager.handleEventTapEvent(
            type,
            accessibilityMouseLocation: accessibilityMouseLocation,
            appKitMouseLocation: appKitMouseLocation
        )
    }

    return Unmanaged.passUnretained(event)
}

private final class SnapPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = SnapPreviewView()
    }

    func show(frame: CGRect) {
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
}

private final class SnapPreviewView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 5, dy: 5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        let isDarkMode = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fillColor = isDarkMode ?
            NSColor(calibratedWhite: 0.22, alpha: 0.62) :
            NSColor(calibratedWhite: 0.16, alpha: 0.38)
        let strokeColor = isDarkMode ?
            NSColor(calibratedWhite: 0.58, alpha: 0.86) :
            NSColor(calibratedWhite: 0.24, alpha: 0.78)

        fillColor.setFill()
        path.fill()

        strokeColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}
