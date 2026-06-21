//
//  SnapLayoutIcon.swift
//  Cyclope
//

import AppKit
import SwiftUI

struct ShortcutCommandIcon: View {
    let command: ShortcutCommand
    var isSelected = false
    var tint: Color = .accentColor

    var body: some View {
        Group {
            if command.usesPositionOnlyCenterPreview {
                PositionOnlySnapIcon(
                    position: .center,
                    isSelected: isSelected,
                    baseCornerRadius: 2,
                    tint: tint
                )
            } else if let layout = command.previewLayout {
                SnapLayoutIcon(
                    layout: layout,
                    isSelected: isSelected,
                    baseCornerRadius: 2,
                    fillCornerRadius: 2,
                    tint: tint
                )
            } else {
                Image(systemName: command.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
            }
        }
    }
}

struct PositionOnlySnapIcon: View {
    var position: CustomSnapPosition = .center
    var isSelected = false
    var baseCornerRadius: CGFloat = 4
    var windowCornerRadius: CGFloat = 3
    var tint: Color = .accentColor
    var usesPositionColor = true

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = Self.cellCornerRadius(
                in: proxy.size,
                preferred: min(baseCornerRadius, windowCornerRadius)
            )

            ZStack(alignment: .topLeading) {
                ForEach(CustomSnapPosition.allCases) { cellPosition in
                    let cellRect = Self.cellRect(in: proxy.size, position: cellPosition)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(cellFillColor(for: cellPosition))
                        .frame(width: max(2, cellRect.width), height: max(2, cellRect.height))
                        .offset(x: cellRect.minX, y: cellRect.minY)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(cellStrokeColor(for: cellPosition), lineWidth: cellPosition == position ? 1.1 : 0.65)
                        .frame(width: max(2, cellRect.width), height: max(2, cellRect.height))
                        .offset(x: cellRect.minX, y: cellRect.minY)
                }
            }
        }
    }

    private func cellFillColor(for cellPosition: CustomSnapPosition) -> Color {
        if cellPosition == position {
            return selectedColor.opacity(isSelected ? 1.0 : 0.94)
        }

        return isSelected ? Color.white.opacity(0.24) : Color.primary.opacity(0.16)
    }

    private func cellStrokeColor(for cellPosition: CustomSnapPosition) -> Color {
        if cellPosition == position {
            return isSelected ? Color.white.opacity(0.82) : selectedColor.opacity(0.95)
        }

        return isSelected ? Color.white.opacity(0.18) : Color.primary.opacity(0.08)
    }

    private var selectedColor: Color {
        usesPositionColor ? position.iconColor : tint
    }

    private static func cellRect(in size: CGSize, position: CustomSnapPosition) -> CGRect {
        let gap = gridGap(in: size)
        let cellWidth = max(2, (size.width - gap * 2) / 3)
        let cellHeight = max(2, (size.height - gap * 2) / 3)

        return CGRect(
            x: CGFloat(position.column) * (cellWidth + gap),
            y: CGFloat(position.row) * (cellHeight + gap),
            width: cellWidth,
            height: cellHeight
        )
    }

    private static func gridGap(in size: CGSize) -> CGFloat {
        max(1.2, min(size.width, size.height) * 0.11)
    }

    private static func cellCornerRadius(in size: CGSize, preferred: CGFloat) -> CGFloat {
        let gap = gridGap(in: size)
        let cellWidth = max(2, (size.width - gap * 2) / 3)
        let cellHeight = max(2, (size.height - gap * 2) / 3)
        return max(1, min(preferred, min(cellWidth, cellHeight) * 0.36))
    }
}

struct SnapLayoutIcon: View {
    let layout: SnapLayout
    var isSelected = false
    var baseCornerRadius: CGFloat = 4
    var fillCornerRadius: CGFloat = 2
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { proxy in
            let rect = layout.topOriginIconRect(in: proxy.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: baseCornerRadius, style: .continuous)
                    .fill(baseColor)

                RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(2, rect.width), height: max(2, rect.height))
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
    }

    private var baseColor: Color {
        isSelected ? Color.white.opacity(0.30) : Color.primary.opacity(0.16)
    }

    private var fillColor: Color {
        isSelected ? .white : tint
    }
}

struct ShortcutCommandMenuIcon: View {
    let command: ShortcutCommand

    var body: some View {
        if let image = ShortcutCommandIconRenderer.menuImage(for: command) {
            Image(nsImage: image)
        } else {
            Image(systemName: command.systemImage)
        }
    }
}

struct SnapPresetMenuIcon: View {
    let layout: SnapLayout
    var position: CustomSnapPosition = .center
    var isPositionOnly = false

    init(layout: SnapLayout, position: CustomSnapPosition = .center, isPositionOnly: Bool = false) {
        self.layout = layout
        self.position = position
        self.isPositionOnly = isPositionOnly
    }

    init(preset: CustomSnapPreset) {
        layout = preset.layout
        position = preset.position
        isPositionOnly = preset.isPositionOnly
    }

    var body: some View {
        if isPositionOnly {
            Image(
                nsImage: PositionOnlySnapIconRenderer.menuImage(
                    position: position,
                    usesPositionColor: false
                )
            )
        } else {
            Image(nsImage: SnapLayoutIconRenderer.menuImage(for: layout))
        }
    }
}

enum ShortcutCommandIconRenderer {
    static let defaultMenuIconSize = CGSize(width: 24, height: 18)

    static func menuImage(for command: ShortcutCommand) -> NSImage? {
        if command.usesPositionOnlyCenterPreview {
            return PositionOnlySnapIconRenderer.menuImage(
                position: .center,
                size: defaultMenuIconSize,
                baseCornerRadius: 2,
                windowCornerRadius: 2
            )
        }

        if let layout = command.previewLayout {
            return SnapLayoutIconRenderer.menuImage(
                for: layout,
                size: defaultMenuIconSize,
                baseCornerRadius: 2,
                fillCornerRadius: 2
            )
        }

        return NSImage(systemSymbolName: command.systemImage, accessibilityDescription: command.title)
    }
}

enum PositionOnlySnapIconRenderer {
    static func menuImage(
        position: CustomSnapPosition = .center,
        usesPositionColor: Bool = true,
        size: CGSize = ShortcutCommandIconRenderer.defaultMenuIconSize,
        baseCornerRadius: CGFloat = 4,
        windowCornerRadius: CGFloat = 3
    ) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(
                position: position,
                usesPositionColor: usesPositionColor,
                in: rect,
                baseCornerRadius: baseCornerRadius,
                windowCornerRadius: windowCornerRadius
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func draw(
        position: CustomSnapPosition,
        usesPositionColor: Bool,
        in bounds: CGRect,
        baseCornerRadius: CGFloat,
        windowCornerRadius: CGFloat
    ) {
        let cornerRadius = cellCornerRadius(
            in: bounds,
            preferred: min(baseCornerRadius, windowCornerRadius)
        )

        for cellPosition in CustomSnapPosition.allCases {
            let cellRect = cellRect(in: bounds, position: cellPosition)
            let path = NSBezierPath(
                roundedRect: cellRect,
                xRadius: cornerRadius,
                yRadius: cornerRadius
            )

            if cellPosition == position {
                let selectedColor = usesPositionColor ? cellPosition.nsIconColor : NSColor.controlAccentColor
                selectedColor.withAlphaComponent(0.94).setFill()
                path.fill()
                selectedColor.setStroke()
                path.lineWidth = 1.1
                path.stroke()
            } else {
                NSColor.labelColor.withAlphaComponent(0.16).setFill()
                path.fill()
                NSColor.labelColor.withAlphaComponent(0.08).setStroke()
                path.lineWidth = 0.65
                path.stroke()
            }
        }
    }

    private static func cellRect(in bounds: CGRect, position: CustomSnapPosition) -> CGRect {
        let gap = gridGap(in: bounds.size)
        let cellWidth = max(2, (bounds.width - gap * 2) / 3)
        let cellHeight = max(2, (bounds.height - gap * 2) / 3)

        return CGRect(
            x: bounds.minX + CGFloat(position.column) * (cellWidth + gap),
            y: bounds.maxY - CGFloat(position.row + 1) * cellHeight - CGFloat(position.row) * gap,
            width: cellWidth,
            height: cellHeight
        )
    }

    private static func gridGap(in size: CGSize) -> CGFloat {
        max(1.2, min(size.width, size.height) * 0.11)
    }

    private static func cellCornerRadius(in bounds: CGRect, preferred: CGFloat) -> CGFloat {
        let gap = gridGap(in: bounds.size)
        let cellWidth = max(2, (bounds.width - gap * 2) / 3)
        let cellHeight = max(2, (bounds.height - gap * 2) / 3)
        return max(1, min(preferred, min(cellWidth, cellHeight) * 0.36))
    }
}

private extension CustomSnapPosition {
    var iconColor: Color {
        Color(nsColor: nsIconColor)
    }

    var nsIconColor: NSColor {
        switch self {
        case .topLeft:
            return .systemCyan
        case .top:
            return .systemBlue
        case .topRight:
            return .systemPurple
        case .left:
            return .systemGreen
        case .center:
            return .controlAccentColor
        case .right:
            return .systemOrange
        case .bottomLeft:
            return .systemTeal
        case .bottom:
            return .systemPink
        case .bottomRight:
            return .systemRed
        }
    }
}

enum SnapLayoutIconRenderer {
    static func menuImage(
        for layout: SnapLayout,
        size: CGSize = ShortcutCommandIconRenderer.defaultMenuIconSize,
        baseCornerRadius: CGFloat = 4,
        fillCornerRadius: CGFloat = 2
    ) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(
                layout: layout,
                in: rect,
                baseCornerRadius: baseCornerRadius,
                fillCornerRadius: fillCornerRadius
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func draw(
        layout: SnapLayout,
        in bounds: CGRect,
        baseCornerRadius: CGFloat,
        fillCornerRadius: CGFloat
    ) {
        NSColor.labelColor.withAlphaComponent(0.16).setFill()
        NSBezierPath(
            roundedRect: bounds,
            xRadius: baseCornerRadius,
            yRadius: baseCornerRadius
        ).fill()

        let layoutRect = layout.bottomOriginIconRect(in: bounds)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(
            roundedRect: layoutRect,
            xRadius: fillCornerRadius,
            yRadius: fillCornerRadius
        ).fill()
    }
}

private extension SnapLayout {
    func topOriginIconRect(in size: CGSize) -> CGRect {
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)

        return CGRect(
            x: CGFloat(startColumn) * cellWidth,
            y: CGFloat(startRow) * cellHeight,
            width: CGFloat(columnSpan) * cellWidth,
            height: CGFloat(rowSpan) * cellHeight
        )
    }

    func bottomOriginIconRect(in bounds: CGRect) -> CGRect {
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        return CGRect(
            x: bounds.minX + CGFloat(startColumn) * cellWidth,
            y: bounds.maxY - CGFloat(startRow + rowSpan) * cellHeight,
            width: max(2, CGFloat(columnSpan) * cellWidth),
            height: max(2, CGFloat(rowSpan) * cellHeight)
        )
    }
}
