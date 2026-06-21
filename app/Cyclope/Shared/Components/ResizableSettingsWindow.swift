//
//  ResizableSettingsWindow.swift
//  Cyclope
//

import AppKit
import SwiftUI

extension View {
    func resizableSettingsWindow(minSize: NSSize) -> some View {
        background(ResizableSettingsWindowAccessor(minSize: minSize))
    }
}

private struct ResizableSettingsWindowAccessor: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> ResizableSettingsWindowProbe {
        let view = ResizableSettingsWindowProbe()
        view.configureWindow = configureWindow
        return view
    }

    func updateNSView(_ nsView: ResizableSettingsWindowProbe, context: Context) {
        nsView.configureWindow = configureWindow
        nsView.configureCurrentWindow()
    }

    private func configureWindow(_ window: NSWindow) {
        applyResizableSettings(to: window)

        DispatchQueue.main.async {
            applyResizableSettings(to: window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            applyResizableSettings(to: window)
        }
    }

    private func applyResizableSettings(to window: NSWindow) {
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = minSize
        window.contentMinSize = minSize
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        guard window.frame.width < minSize.width || window.frame.height < minSize.height else {
            return
        }

        let size = NSSize(
            width: max(window.frame.width, minSize.width),
            height: max(window.frame.height, minSize.height)
        )
        window.setContentSize(size)
    }
}

private final class ResizableSettingsWindowProbe: NSView {
    var configureWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureCurrentWindow()
    }

    func configureCurrentWindow() {
        guard let window else { return }
        configureWindow?(window)
    }
}
