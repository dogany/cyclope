//
//  SnapGridEditor.swift
//  Cyclope
//

import AppKit
import SwiftUI

enum SnapGridSelectionStyle {
    case filled
    case outlineWithCenterDot
}

struct SnapGridEditor: NSViewRepresentable {
    let layout: SnapLayout
    var selectionStyle: SnapGridSelectionStyle = .filled
    let onChange: (SnapLayout) -> Void

    func makeNSView(context: Context) -> SnapGridEditorView {
        SnapGridEditorView(
            layout: layout,
            selectionStyle: selectionStyle,
            onChange: onChange
        )
    }

    func updateNSView(_ view: SnapGridEditorView, context: Context) {
        view.layout = layout
        view.selectionStyle = selectionStyle
        view.onChange = onChange
    }
}

final class SnapGridEditorView: NSView {
    var layout: SnapLayout {
        didSet { needsDisplay = true }
    }
    var selectionStyle: SnapGridSelectionStyle {
        didSet { needsDisplay = true }
    }
    var onChange: (SnapLayout) -> Void

    private var dragStart: SnapGridCell?
    private let contentInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    init(
        layout: SnapLayout,
        selectionStyle: SnapGridSelectionStyle,
        onChange: @escaping (SnapLayout) -> Void
    ) {
        self.layout = layout
        self.selectionStyle = selectionStyle
        self.onChange = onChange
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let gridRect = bounds.inset(by: contentInsets)
        guard gridRect.width > 0, gridRect.height > 0 else { return }

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let cellWidth = gridRect.width / CGFloat(layout.columns)
        let cellHeight = gridRect.height / CGFloat(layout.rows)

        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        gridRect.fill()

        let selectedFrame = NSRect(
            x: gridRect.minX + CGFloat(layout.startColumn) * cellWidth,
            y: gridRect.minY + CGFloat(layout.startRow) * cellHeight,
            width: CGFloat(layout.columnSpan) * cellWidth,
            height: CGFloat(layout.rowSpan) * cellHeight
        )

        drawSelectionBackground(in: selectedFrame)

        NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()
        for column in 1..<layout.columns {
            let x = gridRect.minX + CGFloat(column) * cellWidth
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: gridRect.minY))
            path.line(to: NSPoint(x: x, y: gridRect.maxY))
            path.lineWidth = 0.5
            path.stroke()
        }

        for row in 1..<layout.rows {
            let y = gridRect.minY + CGFloat(row) * cellHeight
            let path = NSBezierPath()
            path.move(to: NSPoint(x: gridRect.minX, y: y))
            path.line(to: NSPoint(x: gridRect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()
        }

        drawSelectionOverlay(in: selectedFrame)
    }

    override func mouseDown(with event: NSEvent) {
        guard let cell = cell(for: event) else { return }
        dragStart = cell
        updateSelection(endingAt: cell)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let cell = cell(for: event) else { return }
        updateSelection(endingAt: cell)
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil }
        guard let cell = cell(for: event) else { return }
        updateSelection(endingAt: cell)
    }

    private func updateSelection(endingAt cell: SnapGridCell) {
        guard let dragStart else { return }
        onChange(
            SnapLayout(
                start: dragStart,
                end: cell,
                columns: layout.columns,
                rows: layout.rows
            )
        )
    }

    private func drawSelectionBackground(in selectedFrame: NSRect) {
        switch selectionStyle {
        case .filled:
            NSColor.controlAccentColor.setFill()
            selectedFrame.fill()
        case .outlineWithCenterDot:
            let highlightFrame = selectedFrame.insetBy(dx: 4, dy: 4)
            let highlightPath = NSBezierPath(rect: highlightFrame)
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            highlightPath.fill()
        }
    }

    private func drawSelectionOverlay(in selectedFrame: NSRect) {
        guard selectionStyle == .outlineWithCenterDot else { return }

        let highlightFrame = selectedFrame.insetBy(dx: 4, dy: 4)
        let highlightPath = NSBezierPath(rect: highlightFrame)
        NSColor.controlAccentColor.setStroke()
        highlightPath.lineWidth = 2
        highlightPath.stroke()

        let dotSize: CGFloat = 7
        let dotRect = NSRect(
            x: selectedFrame.midX - dotSize / 2,
            y: selectedFrame.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    private func cell(for event: NSEvent) -> SnapGridCell? {
        let location = convert(event.locationInWindow, from: nil)
        let gridRect = bounds.inset(by: contentInsets)
        guard gridRect.width > 0, gridRect.height > 0 else { return nil }

        let clampedX = min(max(location.x, gridRect.minX), gridRect.maxX.nextDown)
        let clampedY = min(max(location.y, gridRect.minY), gridRect.maxY.nextDown)
        let column = Int((clampedX - gridRect.minX) / (gridRect.width / CGFloat(layout.columns)))
        let row = Int((clampedY - gridRect.minY) / (gridRect.height / CGFloat(layout.rows)))
        return SnapGridCell(column: column, row: row)
    }
}

struct SnapActivationOccupiedArea: Equatable {
    let id: String
    let title: String
    let layout: SnapActivationLayout
}

struct SnapActivationGridEditor: NSViewRepresentable {
    let layouts: [SnapActivationLayout]
    let isEnabled: Bool
    let occupiedAreas: [SnapActivationOccupiedArea]
    let onAdd: (SnapActivationLayout) -> Void
    let onDelete: (SnapActivationLayout) -> Void

    func makeNSView(context: Context) -> SnapActivationGridEditorView {
        SnapActivationGridEditorView(
            layouts: layouts,
            isEnabled: isEnabled,
            occupiedAreas: occupiedAreas,
            onAdd: onAdd,
            onDelete: onDelete
        )
    }

    func updateNSView(_ view: SnapActivationGridEditorView, context: Context) {
        view.layouts = layouts
        view.isEnabled = isEnabled
        view.occupiedAreas = occupiedAreas
        view.onAdd = onAdd
        view.onDelete = onDelete
    }
}

final class SnapActivationGridEditorView: NSView {
    var layouts: [SnapActivationLayout] {
        didSet { needsDisplay = true }
    }
    var isEnabled: Bool {
        didSet { needsDisplay = true }
    }
    var occupiedAreas: [SnapActivationOccupiedArea] {
        didSet { needsDisplay = true }
    }
    var onAdd: (SnapActivationLayout) -> Void
    var onDelete: (SnapActivationLayout) -> Void

    private var dragStart: SnapGridCell?
    private var lastDragCell: SnapGridCell?
    private var dragPreview: SnapActivationLayout?
    private var isDragPreviewValid = false
    private var hoveredOccupiedAreaID: String? {
        didSet {
            if oldValue != hoveredOccupiedAreaID {
                needsDisplay = true
            }
        }
    }
    private var layoutPendingDeletion: SnapActivationLayout?
    private var trackingArea: NSTrackingArea?
    private let contentInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    private let edgeThickness: CGFloat = 19
    private let edgeGap: CGFloat = 8

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var isOpaque: Bool { false }

    init(
        layouts: [SnapActivationLayout],
        isEnabled: Bool,
        occupiedAreas: [SnapActivationOccupiedArea],
        onAdd: @escaping (SnapActivationLayout) -> Void,
        onDelete: @escaping (SnapActivationLayout) -> Void
    ) {
        self.layouts = layouts
        self.isEnabled = isEnabled
        self.occupiedAreas = occupiedAreas
        self.onAdd = onAdd
        self.onDelete = onDelete
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let contentRect = bounds.inset(by: contentInsets)
        let desktopRect = desktopRect(in: contentRect)
        guard contentRect.width > 0,
              contentRect.height > 0,
              desktopRect.width > 0,
              desktopRect.height > 0 else {
            return
        }

        let cellWidth = desktopRect.width / CGFloat(SnapActivationLayout.desktopColumns)
        let cellHeight = desktopRect.height / CGFloat(SnapActivationLayout.desktopRows)

        drawEdgeArea(around: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)

        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        desktopRect.fill()

        drawOccupiedAreas(in: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
        if isEnabled || dragPreview != nil {
            drawSelectedArea(in: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }
        drawCellGrid(in: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
        drawGridStroke(in: desktopRect)
        if isEnabled || dragPreview != nil {
            drawSelectedAreaOuterBorders(in: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let cell = cell(for: event) else { return }
        dragStart = cell
        lastDragCell = cell
        updateDragPreview(endingAt: cell)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let cell = dragCell(for: event) else {
            setDragPreview(nil, isValid: false)
            return
        }
        lastDragCell = cell
        updateDragPreview(endingAt: cell)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            lastDragCell = nil
            setDragPreview(nil, isValid: false)
        }
        guard let cell = dragCell(for: event) else { return }
        lastDragCell = cell
        updateDragPreview(endingAt: cell)
        if let dragPreview, isDragPreviewValid {
            onAdd(dragPreview)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let cell = cell(for: event) else {
            hoveredOccupiedAreaID = nil
            return
        }

        hoveredOccupiedAreaID = occupiedArea(containing: cell)?.id
    }

    override func mouseExited(with event: NSEvent) {
        hoveredOccupiedAreaID = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isEnabled,
              let cell = cell(for: event),
              let layout = layout(containing: cell)
        else { return }

        layoutPendingDeletion = layout
        showDeleteMenu(with: event)
    }

    @objc private func deleteSnapArea() {
        guard let layoutPendingDeletion else { return }
        onDelete(layoutPendingDeletion)
        self.layoutPendingDeletion = nil
    }

    private func showDeleteMenu(with event: NSEvent) {
        let menu = NSMenu()
        let deleteItem = NSMenuItem(title: String(localized: "Delete"), action: #selector(deleteSnapArea), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func drawEdgeArea(around desktopRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        let gapRect = desktopRect.insetBy(dx: -edgeGap, dy: -edgeGap)
        let edgeRect = gapRect.insetBy(dx: -edgeThickness, dy: -edgeThickness)
        guard edgeRect.width > 0, edgeRect.height > 0 else { return }

        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        let edgeCellRects = edgeCells(around: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
        edgeCellRects.forEach { rect in
            NSBezierPath(rect: rect).fill()
        }

        drawEdgeCellStrokes(edgeCellRects)
        drawEdgeGrid(around: desktopRect, cellWidth: cellWidth, cellHeight: cellHeight)
    }

    private func edgeCells(around desktopRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) -> [NSRect] {
        let topY = desktopRect.minY - edgeGap - edgeThickness
        let bottomY = desktopRect.maxY + edgeGap
        let leftX = desktopRect.minX - edgeGap - edgeThickness
        let rightX = desktopRect.maxX + edgeGap
        var rects: [NSRect] = [
            NSRect(x: leftX, y: topY, width: edgeThickness, height: edgeThickness),
            NSRect(x: rightX, y: topY, width: edgeThickness, height: edgeThickness),
            NSRect(x: leftX, y: bottomY, width: edgeThickness, height: edgeThickness),
            NSRect(x: rightX, y: bottomY, width: edgeThickness, height: edgeThickness)
        ]

        for column in 0..<SnapActivationLayout.desktopColumns {
            let x = desktopRect.minX + CGFloat(column) * cellWidth
            rects.append(NSRect(x: x, y: topY, width: cellWidth, height: edgeThickness))
            rects.append(NSRect(x: x, y: bottomY, width: cellWidth, height: edgeThickness))
        }

        for row in 0..<SnapActivationLayout.desktopRows {
            let y = desktopRect.minY + CGFloat(row) * cellHeight
            rects.append(NSRect(x: leftX, y: y, width: edgeThickness, height: cellHeight))
            rects.append(NSRect(x: rightX, y: y, width: edgeThickness, height: cellHeight))
        }

        return rects.filter { $0.width > 0 && $0.height > 0 }
    }

    private func drawEdgeCellStrokes(_ rects: [NSRect]) {
        NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()
        rects.forEach { rect in
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 0.5
            path.lineJoinStyle = .miter
            path.stroke()
        }
    }

    private func drawOccupiedAreas(in gridRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        for area in occupiedAreas {
            let frames = frames(for: area.layout, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
            guard !frames.isEmpty else { continue }

            NSColor.labelColor.withAlphaComponent(0.22).setFill()
            frames.forEach { NSBezierPath(rect: $0).fill() }

            NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()
            frames.forEach { rect in
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 0.5
                path.stroke()
            }

            if area.id == hoveredOccupiedAreaID,
               let titleRect = union(of: frames) {
                drawHoverTitle(area.title, near: titleRect)
            }
        }
    }

    private func drawSelectedArea(in gridRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        NSColor.controlAccentColor.withAlphaComponent(0.78).setFill()
        layouts.flatMap { layout in
            frames(for: layout, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }.forEach { NSBezierPath(rect: $0).fill() }

        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        layouts.flatMap { layout in
            frames(for: layout, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }.forEach { rect in
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 0.5
            path.stroke()
        }

        if let dragPreview {
            let fillColor = isDragPreviewValid ?
                NSColor.controlAccentColor.withAlphaComponent(0.84) :
                NSColor.systemRed.withAlphaComponent(0.18)
            let strokeColor = isDragPreviewValid ?
                NSColor.controlAccentColor.withAlphaComponent(0.98) :
                NSColor.systemRed.withAlphaComponent(0.68)

            fillColor.setFill()
            frames(for: dragPreview, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
                .forEach { NSBezierPath(rect: $0).fill() }

            strokeColor.setStroke()
            frames(for: dragPreview, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
                .forEach { rect in
                    let path = NSBezierPath(rect: rect)
                    path.lineWidth = 0.5
                    path.stroke()
                }
        }
    }

    private func drawSelectedAreaOuterBorders(in gridRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        NSColor.selectedControlTextColor.withAlphaComponent(0.86).setStroke()
        layouts.forEach { layout in
            drawOuterBorder(for: layout, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }

        if let dragPreview {
            let borderColor = isDragPreviewValid ?
                NSColor.selectedControlTextColor.withAlphaComponent(0.92) :
                NSColor.systemRed.withAlphaComponent(0.82)
            borderColor.setStroke()
            drawOuterBorder(for: dragPreview, in: gridRect, cellWidth: cellWidth, cellHeight: cellHeight)
        }
    }

    private func drawCellGrid(in gridRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()

        for column in 1..<SnapActivationLayout.desktopColumns {
            let x = gridRect.minX + CGFloat(column) * cellWidth
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: gridRect.minY))
            path.line(to: NSPoint(x: x, y: gridRect.maxY))
            path.lineWidth = 0.5
            path.stroke()
        }

        for row in 1..<SnapActivationLayout.desktopRows {
            let y = gridRect.minY + CGFloat(row) * cellHeight
            let path = NSBezierPath()
            path.move(to: NSPoint(x: gridRect.minX, y: y))
            path.line(to: NSPoint(x: gridRect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private func drawEdgeGrid(around desktopRect: NSRect, cellWidth: CGFloat, cellHeight: CGFloat) {
        NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()

        let topY = desktopRect.minY - edgeGap - edgeThickness
        let bottomY = desktopRect.maxY + edgeGap
        let horizontalBoundaries = (1..<SnapActivationLayout.desktopColumns).map {
            desktopRect.minX + CGFloat($0) * cellWidth
        }
        for x in horizontalBoundaries {
            [topY, bottomY].forEach { y in
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: y))
                path.line(to: NSPoint(x: x, y: y + edgeThickness))
                path.lineWidth = 0.5
                path.stroke()
            }
        }

        let leftX = desktopRect.minX - edgeGap - edgeThickness
        let rightX = desktopRect.maxX + edgeGap
        let verticalBoundaries = (1..<SnapActivationLayout.desktopRows).map {
            desktopRect.minY + CGFloat($0) * cellHeight
        }
        for y in verticalBoundaries {
            [leftX, rightX].forEach { x in
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: y))
                path.line(to: NSPoint(x: x + edgeThickness, y: y))
                path.lineWidth = 0.5
                path.stroke()
            }
        }
    }

    private func drawGridStroke(in gridRect: NSRect) {
        NSColor.textBackgroundColor.withAlphaComponent(0.55).setStroke()
        let path = NSBezierPath(rect: gridRect)
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawHoverTitle(_ title: String, near rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.86)
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        let size = attributedTitle.size()
        let horizontalPadding: CGFloat = 7
        let verticalPadding: CGFloat = 4
        var labelRect = NSRect(
            x: rect.midX - (size.width + horizontalPadding * 2) / 2,
            y: rect.midY - (size.height + verticalPadding * 2) / 2,
            width: size.width + horizontalPadding * 2,
            height: size.height + verticalPadding * 2
        )

        labelRect.origin.x = min(
            max(labelRect.minX, bounds.minX + 6),
            bounds.maxX - labelRect.width - 6
        )
        labelRect.origin.y = min(
            max(labelRect.minY, bounds.minY + 6),
            bounds.maxY - labelRect.height - 6
        )

        let path = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill()
        path.fill()

        NSColor.separatorColor.withAlphaComponent(0.44).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        attributedTitle.draw(
            at: NSPoint(
                x: labelRect.minX + horizontalPadding,
                y: labelRect.minY + verticalPadding
            )
        )
    }

    private func union(of rects: [NSRect]) -> NSRect? {
        guard var result = rects.first else { return nil }

        for rect in rects.dropFirst() {
            result = result.union(rect)
        }

        return result
    }

    private func drawOuterBorder(
        for activationLayout: SnapActivationLayout,
        in gridRect: NSRect,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) {
        for row in activationLayout.startRow..<(activationLayout.startRow + activationLayout.rowSpan) {
            for column in activationLayout.startColumn..<(activationLayout.startColumn + activationLayout.columnSpan) {
                guard let frame = frame(
                    forColumn: column,
                    row: row,
                    in: gridRect,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                ) else {
                    continue
                }

                drawOuterBorderSides(
                    for: frame,
                    column: column,
                    row: row,
                    activationLayout: activationLayout,
                    in: gridRect,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )
            }
        }
    }

    private func drawOuterBorderSides(
        for frame: NSRect,
        column: Int,
        row: Int,
        activationLayout: SnapActivationLayout,
        in gridRect: NSRect,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) {
        if shouldDrawBorderSide(
            frame,
            neighborColumn: column,
            neighborRow: row - 1,
            side: .top,
            activationLayout: activationLayout,
            in: gridRect,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        ) {
            drawBorderLine(from: NSPoint(x: frame.minX, y: frame.minY), to: NSPoint(x: frame.maxX, y: frame.minY))
        }

        if shouldDrawBorderSide(
            frame,
            neighborColumn: column,
            neighborRow: row + 1,
            side: .bottom,
            activationLayout: activationLayout,
            in: gridRect,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        ) {
            drawBorderLine(from: NSPoint(x: frame.minX, y: frame.maxY), to: NSPoint(x: frame.maxX, y: frame.maxY))
        }

        if shouldDrawBorderSide(
            frame,
            neighborColumn: column - 1,
            neighborRow: row,
            side: .left,
            activationLayout: activationLayout,
            in: gridRect,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        ) {
            drawBorderLine(from: NSPoint(x: frame.minX, y: frame.minY), to: NSPoint(x: frame.minX, y: frame.maxY))
        }

        if shouldDrawBorderSide(
            frame,
            neighborColumn: column + 1,
            neighborRow: row,
            side: .right,
            activationLayout: activationLayout,
            in: gridRect,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        ) {
            drawBorderLine(from: NSPoint(x: frame.maxX, y: frame.minY), to: NSPoint(x: frame.maxX, y: frame.maxY))
        }
    }

    private func shouldDrawBorderSide(
        _ frame: NSRect,
        neighborColumn: Int,
        neighborRow: Int,
        side: BorderSide,
        activationLayout: SnapActivationLayout,
        in gridRect: NSRect,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> Bool {
        guard activationLayout.contains(column: neighborColumn, row: neighborRow),
              let neighborFrame = self.frame(
                forColumn: neighborColumn,
                row: neighborRow,
                in: gridRect,
                cellWidth: cellWidth,
                cellHeight: cellHeight
              ) else {
            return true
        }

        switch side {
        case .top:
            return abs(neighborFrame.maxY - frame.minY) > 0.5
        case .bottom:
            return abs(neighborFrame.minY - frame.maxY) > 0.5
        case .left:
            return abs(neighborFrame.maxX - frame.minX) > 0.5
        case .right:
            return abs(neighborFrame.minX - frame.maxX) > 0.5
        }
    }

    private func drawBorderLine(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = 1.4
        path.stroke()
    }

    private func frames(
        for activationLayout: SnapActivationLayout,
        in gridRect: NSRect,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> [NSRect] {
        var frames: [NSRect] = []

        for row in activationLayout.startRow..<(activationLayout.startRow + activationLayout.rowSpan) {
            for column in activationLayout.startColumn..<(activationLayout.startColumn + activationLayout.columnSpan) {
                if let frame = frame(
                    forColumn: column,
                    row: row,
                    in: gridRect,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                ) {
                    frames.append(frame)
                }
            }
        }

        return frames
    }

    private func frame(
        forColumn column: Int,
        row: Int,
        in desktopRect: NSRect,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> NSRect? {
        let desktopColumnStart = SnapActivationLayout.desktopStartColumn
        let desktopColumnEnd = desktopColumnStart + SnapActivationLayout.desktopColumns
        let desktopRowStart = SnapActivationLayout.desktopStartRow
        let desktopRowEnd = desktopRowStart + SnapActivationLayout.desktopRows

        if column >= desktopColumnStart,
           column < desktopColumnEnd,
           row >= desktopRowStart,
           row < desktopRowEnd {
            return NSRect(
                x: desktopRect.minX + CGFloat(column - desktopColumnStart) * cellWidth,
                y: desktopRect.minY + CGFloat(row - desktopRowStart) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
        }

        if row == 0, column >= desktopColumnStart, column < desktopColumnEnd {
            return NSRect(
                x: desktopRect.minX + CGFloat(column - desktopColumnStart) * cellWidth,
                y: desktopRect.minY - edgeGap - edgeThickness,
                width: cellWidth,
                height: edgeThickness
            )
        }

        if row == SnapActivationLayout.rows - 1, column >= desktopColumnStart, column < desktopColumnEnd {
            return NSRect(
                x: desktopRect.minX + CGFloat(column - desktopColumnStart) * cellWidth,
                y: desktopRect.maxY + edgeGap,
                width: cellWidth,
                height: edgeThickness
            )
        }

        if column == 0, row >= desktopRowStart, row < desktopRowEnd {
            return NSRect(
                x: desktopRect.minX - edgeGap - edgeThickness,
                y: desktopRect.minY + CGFloat(row - desktopRowStart) * cellHeight,
                width: edgeThickness,
                height: cellHeight
            )
        }

        if column == SnapActivationLayout.columns - 1, row >= desktopRowStart, row < desktopRowEnd {
            return NSRect(
                x: desktopRect.maxX + edgeGap,
                y: desktopRect.minY + CGFloat(row - desktopRowStart) * cellHeight,
                width: edgeThickness,
                height: cellHeight
            )
        }

        return cornerFrame(forColumn: column, row: row, in: desktopRect)
    }

    private func updateDragPreview(endingAt cell: SnapGridCell) {
        guard let dragStart else { return }
        let candidate = SnapActivationLayout(start: dragStart, end: cell)
        setDragPreview(candidate, isValid: isDragCandidateAvailable(candidate))
    }

    private func setDragPreview(_ layout: SnapActivationLayout?, isValid: Bool) {
        guard dragPreview != layout || isDragPreviewValid != isValid else { return }
        dragPreview = layout
        isDragPreviewValid = isValid
        needsDisplay = true
    }

    private func isDragCandidateAvailable(_ layout: SnapActivationLayout) -> Bool {
        !occupiedAreas.contains(where: { layout.intersects($0.layout) }) &&
            !layouts.contains(where: { layout.intersects($0) })
    }

    private func layout(containing cell: SnapGridCell) -> SnapActivationLayout? {
        layouts.first { layout in
            layout.contains(column: cell.column, row: cell.row)
        }
    }

    private func occupiedArea(containing cell: SnapGridCell) -> SnapActivationOccupiedArea? {
        occupiedAreas.first { area in
            area.layout.contains(column: cell.column, row: cell.row)
        }
    }

    private func dragCell(for event: NSEvent) -> SnapGridCell? {
        if let cell = cell(for: event) {
            return cell
        }

        // The editor draws visual gaps between desktop and edge zones. While a
        // drag crosses those gaps, keep the preview anchored to the last valid
        // cell instead of clearing and recreating it from the original start.
        guard let lastDragCell,
              isInsideActivationBounds(event) else {
            return nil
        }

        return lastDragCell
    }

    private func cell(for event: NSEvent) -> SnapGridCell? {
        let location = convert(event.locationInWindow, from: nil)
        let desktopRect = desktopRect(in: bounds.inset(by: contentInsets))
        guard desktopRect.width > 0, desktopRect.height > 0 else { return nil }

        if desktopRect.contains(location) {
            return SnapGridCell(
                column: desktopColumn(for: location.x, in: desktopRect),
                row: desktopRow(for: location.y, in: desktopRect)
            )
        }

        let gapRect = desktopRect.insetBy(dx: -edgeGap, dy: -edgeGap)
        let edgeRect = gapRect.insetBy(dx: -edgeThickness, dy: -edgeThickness)
        guard edgeRect.contains(location), !gapRect.contains(location) else { return nil }

        if location.y < gapRect.minY {
            guard let column = edgeColumn(for: location.x, in: desktopRect) else { return nil }
            return SnapGridCell(column: column, row: 0)
        }

        if location.y >= gapRect.maxY {
            guard let column = edgeColumn(for: location.x, in: desktopRect) else { return nil }
            return SnapGridCell(
                column: column,
                row: SnapActivationLayout.rows - 1
            )
        }

        if location.x < gapRect.minX {
            guard let row = edgeRow(for: location.y, in: desktopRect) else { return nil }
            return SnapGridCell(column: 0, row: row)
        }

        if location.x >= gapRect.maxX {
            guard let row = edgeRow(for: location.y, in: desktopRect) else { return nil }
            return SnapGridCell(
                column: SnapActivationLayout.columns - 1,
                row: row
            )
        }

        return nil
    }

    private func isInsideActivationBounds(_ event: NSEvent) -> Bool {
        let location = convert(event.locationInWindow, from: nil)
        let desktopRect = desktopRect(in: bounds.inset(by: contentInsets))
        guard desktopRect.width > 0, desktopRect.height > 0 else { return false }

        let gapRect = desktopRect.insetBy(dx: -edgeGap, dy: -edgeGap)
        let edgeRect = gapRect.insetBy(dx: -edgeThickness, dy: -edgeThickness)
        return edgeRect.contains(location)
    }

    private func desktopColumn(for x: CGFloat, in desktopRect: NSRect) -> Int {
        let clampedX = min(max(x, desktopRect.minX), desktopRect.maxX.nextDown)
        let column = Int(
            (clampedX - desktopRect.minX) /
                (desktopRect.width / CGFloat(SnapActivationLayout.desktopColumns))
        )
        return SnapActivationLayout.desktopStartColumn + min(max(column, 0), SnapActivationLayout.desktopColumns - 1)
    }

    private func desktopRow(for y: CGFloat, in desktopRect: NSRect) -> Int {
        let clampedY = min(max(y, desktopRect.minY), desktopRect.maxY.nextDown)
        let row = Int(
            (clampedY - desktopRect.minY) /
                (desktopRect.height / CGFloat(SnapActivationLayout.desktopRows))
        )
        return SnapActivationLayout.desktopStartRow + min(max(row, 0), SnapActivationLayout.desktopRows - 1)
    }

    private func edgeColumn(for x: CGFloat, in desktopRect: NSRect) -> Int? {
        if x < desktopRect.minX - edgeGap {
            return 0
        }

        if x < desktopRect.minX {
            return nil
        }

        if x >= desktopRect.maxX + edgeGap {
            return SnapActivationLayout.columns - 1
        }

        if x >= desktopRect.maxX {
            return nil
        }

        return desktopColumn(for: x, in: desktopRect)
    }

    private func edgeRow(for y: CGFloat, in desktopRect: NSRect) -> Int? {
        if y < desktopRect.minY - edgeGap {
            return 0
        }

        if y < desktopRect.minY {
            return nil
        }

        if y >= desktopRect.maxY + edgeGap {
            return SnapActivationLayout.rows - 1
        }

        if y >= desktopRect.maxY {
            return nil
        }

        return desktopRow(for: y, in: desktopRect)
    }

    private func cornerFrame(forColumn column: Int, row: Int, in desktopRect: NSRect) -> NSRect? {
        let isLeft = column == 0
        let isRight = column == SnapActivationLayout.columns - 1
        let isTop = row == 0
        let isBottom = row == SnapActivationLayout.rows - 1
        guard (isLeft || isRight), (isTop || isBottom) else { return nil }

        return NSRect(
            x: isLeft ? desktopRect.minX - edgeGap - edgeThickness : desktopRect.maxX + edgeGap,
            y: isTop ? desktopRect.minY - edgeGap - edgeThickness : desktopRect.maxY + edgeGap,
            width: edgeThickness,
            height: edgeThickness
        )
    }

    private func desktopRect(in contentRect: NSRect) -> NSRect {
        let reserved = edgeThickness + edgeGap
        return contentRect.insetBy(dx: reserved, dy: reserved)
    }
}

private enum BorderSide {
    case top
    case bottom
    case left
    case right
}

private extension NSRect {
    func inset(by insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: minX + insets.left,
            y: minY + insets.top,
            width: max(0, width - insets.left - insets.right),
            height: max(0, height - insets.top - insets.bottom)
        )
    }
}
