//
//  CommandCheatSheetPanel.swift
//  Cyclope
//

import AppKit

final class CommandCheatSheetPanel: NSPanel {
    var onCommand: ((CheatSheetCommand) -> Void)?
    var onNudge: ((WindowNudgeDirection) -> Void)?
    var onDismiss: (() -> Void)?
    var commandResolver: ((NSEvent) -> CheatSheetCommand?)?

    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(contentViewController: NSViewController) {
        let windowSize = NSSize(
            width: CommandCheatSheetLayout.fallbackWindowSize.width,
            height: CommandCheatSheetLayout.fallbackWindowSize.height
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hasShadow = false
        isMovableByWindowBackground = false
        isOpaque = false
        isReleasedWhenClosed = false
        level = .floating
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        startOutsideClickMonitoring()
    }

    override func orderOut(_ sender: Any?) {
        stopOutsideClickMonitoring()
        super.orderOut(sender)
    }

    override func close() {
        stopOutsideClickMonitoring()
        super.close()
    }

    func showWithoutActivatingApp() {
        orderFrontRegardless()
        makeKey()
        startOutsideClickMonitoring()
    }

    override func keyDown(with event: NSEvent) {
        guard !handleCommandEvent(event) else { return }
        super.keyDown(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type != .keyDown || !handleCommandEvent(event) else { return }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleCommandEvent(event)
    }

    deinit {
        stopOutsideClickMonitoring()
    }

    private func handleCommandEvent(_ event: NSEvent) -> Bool {
        if Int(event.keyCode) == 53 {
            onDismiss?()
            return true
        }

        if let direction = WindowNudgeDirection(event: event) {
            onNudge?(direction)
            return true
        }

        if let command = commandResolver?(event) {
            onCommand?(command)
            return true
        }

        return false
    }

    private func startOutsideClickMonitoring() {
        guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }

        let mouseDownMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDownMask) { [weak self] event in
            self?.dismissIfClickIsOutside(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDownMask) { [weak self] event in
            self?.dismissIfClickIsOutside(event)
        }
    }

    private func stopOutsideClickMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func dismissIfClickIsOutside(_ event: NSEvent) {
        guard isVisible else { return }

        let clickPoint: NSPoint
        if let eventWindow = event.window {
            clickPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            clickPoint = NSEvent.mouseLocation
        }

        guard !cardFrameInScreen.contains(clickPoint) else { return }
        onDismiss?()
    }

    private var cardFrameInScreen: NSRect {
        frame.insetBy(
            dx: CommandCheatSheetLayout.shadowPadding,
            dy: CommandCheatSheetLayout.shadowPadding
        )
    }
}
