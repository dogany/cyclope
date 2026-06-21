//
//  SnapLayout.swift
//  Cyclope
//

import CoreGraphics

struct SnapLayout: Codable, Equatable {
    static let columnRange = 2...30
    static let rowRange = 2...30

    var columns: Int
    var rows: Int
    var startColumn: Int
    var startRow: Int
    var columnSpan: Int
    var rowSpan: Int

    var summary: String {
        "\(columnSpan)x\(rowSpan) in \(columns)x\(rows)"
    }

    static let full = SnapLayout(
        columns: 2,
        rows: 2,
        startColumn: 0,
        startRow: 0,
        columnSpan: 2,
        rowSpan: 2
    )

    init(columns: Int, rows: Int, startColumn: Int, startRow: Int, columnSpan: Int, rowSpan: Int) {
        self.columns = columns
        self.rows = rows
        self.startColumn = startColumn
        self.startRow = startRow
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        clamp()
    }

    init(start: SnapGridCell, end: SnapGridCell, columns: Int, rows: Int) {
        let minColumn = min(start.column, end.column)
        let maxColumn = max(start.column, end.column)
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)

        self.init(
            columns: columns,
            rows: rows,
            startColumn: minColumn,
            startRow: minRow,
            columnSpan: maxColumn - minColumn + 1,
            rowSpan: maxRow - minRow + 1
        )
    }

    func contains(column: Int, row: Int) -> Bool {
        column >= startColumn &&
            column < startColumn + columnSpan &&
            row >= startRow &&
            row < startRow + rowSpan
    }

    func snappedFrame(in visibleFrame: CGRect) -> CGRect {
        let cellWidth = visibleFrame.width / CGFloat(columns)
        let cellHeight = visibleFrame.height / CGFloat(rows)
        let originX = visibleFrame.minX + CGFloat(startColumn) * cellWidth
        let originY = visibleFrame.maxY - CGFloat(startRow + rowSpan) * cellHeight

        return CGRect(
            x: originX,
            y: originY,
            width: CGFloat(columnSpan) * cellWidth,
            height: CGFloat(rowSpan) * cellHeight
        )
    }

    func accessibilityFrame(in visibleFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let snappedFrame = snappedFrame(in: visibleFrame)
        return CGRect(
            x: snappedFrame.minX,
            y: screenFrame.maxY - snappedFrame.maxY + screenFrame.minY,
            width: snappedFrame.width,
            height: snappedFrame.height
        )
    }

    mutating func setColumns(_ value: Int) {
        columns = value
        clamp()
    }

    mutating func setRows(_ value: Int) {
        rows = value
        clamp()
    }

    func scaled(toColumns targetColumns: Int, rows targetRows: Int) -> SnapLayout {
        let targetColumns = min(max(targetColumns, Self.columnRange.lowerBound), Self.columnRange.upperBound)
        let targetRows = min(max(targetRows, Self.rowRange.lowerBound), Self.rowRange.upperBound)
        let startColumn = Int((Double(self.startColumn) / Double(columns) * Double(targetColumns)).rounded(.down))
        let endColumn = Int((Double(self.startColumn + columnSpan) / Double(columns) * Double(targetColumns)).rounded(.up))
        let startRow = Int((Double(self.startRow) / Double(rows) * Double(targetRows)).rounded(.down))
        let endRow = Int((Double(self.startRow + rowSpan) / Double(rows) * Double(targetRows)).rounded(.up))

        return SnapLayout(
            columns: targetColumns,
            rows: targetRows,
            startColumn: startColumn,
            startRow: startRow,
            columnSpan: max(1, endColumn - startColumn),
            rowSpan: max(1, endRow - startRow)
        )
    }

    private mutating func clamp() {
        columns = min(max(columns, Self.columnRange.lowerBound), Self.columnRange.upperBound)
        rows = min(max(rows, Self.rowRange.lowerBound), Self.rowRange.upperBound)
        startColumn = min(max(startColumn, 0), columns - 1)
        startRow = min(max(startRow, 0), rows - 1)
        columnSpan = min(max(columnSpan, 1), columns - startColumn)
        rowSpan = min(max(rowSpan, 1), rows - startRow)
    }
}

struct SnapGridCell: Equatable {
    let column: Int
    let row: Int
}

struct SnapActivationLayout: Codable, Equatable {
    static let desktopColumns = 16
    static let desktopRows = 10
    static let desktopStartColumn = 1
    static let desktopStartRow = 1
    static let columns = desktopColumns + 2
    static let rows = desktopRows + 2

    var startColumn: Int
    var startRow: Int
    var columnSpan: Int
    var rowSpan: Int

    var summary: String {
        "\(columnSpan)x\(rowSpan) at \(startColumn),\(startRow)"
    }

    init(startColumn: Int, startRow: Int, columnSpan: Int, rowSpan: Int) {
        self.startColumn = startColumn
        self.startRow = startRow
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        clamp()
    }

    enum CodingKeys: String, CodingKey {
        case startColumn
        case startRow
        case columnSpan
        case rowSpan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            startColumn: try container.decode(Int.self, forKey: .startColumn),
            startRow: try container.decode(Int.self, forKey: .startRow),
            columnSpan: try container.decode(Int.self, forKey: .columnSpan),
            rowSpan: try container.decode(Int.self, forKey: .rowSpan)
        )
    }

    init(start: SnapGridCell, end: SnapGridCell) {
        let minColumn = min(start.column, end.column)
        let maxColumn = max(start.column, end.column)
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)

        self.init(
            startColumn: minColumn,
            startRow: minRow,
            columnSpan: maxColumn - minColumn + 1,
            rowSpan: maxRow - minRow + 1
        )
    }

    static func defaultLayout(for snapLayout: SnapLayout) -> SnapActivationLayout {
        let coversFullWidth = snapLayout.startColumn == 0 && snapLayout.columnSpan == snapLayout.columns
        let coversFullHeight = snapLayout.startRow == 0 && snapLayout.rowSpan == snapLayout.rows
        let horizontalCenter = max(desktopStartColumn, columns / 2 - 2)
        let verticalCenter = max(desktopStartRow, rows / 2 - 2)

        if coversFullWidth && coversFullHeight {
            return SnapActivationLayout(startColumn: horizontalCenter, startRow: 0, columnSpan: 4, rowSpan: 1)
        }

        if snapLayout.startColumn == 0 && !coversFullWidth {
            return SnapActivationLayout(
                startColumn: 0,
                startRow: desktopStartRow,
                columnSpan: 1,
                rowSpan: desktopRows
            )
        }

        if snapLayout.startColumn + snapLayout.columnSpan == snapLayout.columns && !coversFullWidth {
            return SnapActivationLayout(
                startColumn: columns - 1,
                startRow: desktopStartRow,
                columnSpan: 1,
                rowSpan: desktopRows
            )
        }

        if snapLayout.startRow == 0 && !coversFullHeight {
            return SnapActivationLayout(
                startColumn: desktopStartColumn,
                startRow: 0,
                columnSpan: desktopColumns,
                rowSpan: 1
            )
        }

        if snapLayout.startRow + snapLayout.rowSpan == snapLayout.rows && !coversFullHeight {
            return SnapActivationLayout(
                startColumn: desktopStartColumn,
                startRow: rows - 1,
                columnSpan: desktopColumns,
                rowSpan: 1
            )
        }

        return SnapActivationLayout(startColumn: horizontalCenter, startRow: verticalCenter, columnSpan: 4, rowSpan: 4)
    }

    func contains(column: Int, row: Int) -> Bool {
        column >= startColumn &&
            column < startColumn + columnSpan &&
            row >= startRow &&
            row < startRow + rowSpan
    }

    func intersects(_ other: SnapActivationLayout) -> Bool {
        startColumn < other.startColumn + other.columnSpan &&
            startColumn + columnSpan > other.startColumn &&
            startRow < other.startRow + other.rowSpan &&
            startRow + rowSpan > other.startRow
    }

    func contains(point: CGPoint, in visibleFrame: CGRect, screenFrame: CGRect) -> Bool {
        guard let cell = Self.cell(containing: point, in: visibleFrame, screenFrame: screenFrame) else {
            return false
        }

        return contains(column: cell.column, row: cell.row)
    }

    func contains(point: CGPoint, in visibleFrame: CGRect) -> Bool {
        contains(point: point, in: visibleFrame, screenFrame: visibleFrame)
    }

    func frame(in screenFrame: CGRect) -> CGRect {
        let cellWidth = screenFrame.width / CGFloat(Self.columns)
        let cellHeight = screenFrame.height / CGFloat(Self.rows)

        return CGRect(
            x: screenFrame.minX + CGFloat(startColumn) * cellWidth,
            y: screenFrame.maxY - CGFloat(startRow + rowSpan) * cellHeight,
            width: CGFloat(columnSpan) * cellWidth,
            height: CGFloat(rowSpan) * cellHeight
        )
    }

    private static func cell(containing point: CGPoint, in visibleFrame: CGRect, screenFrame: CGRect) -> SnapGridCell? {
        // CGRect.contains excludes the max edges; use a boundary-inclusive test so a
        // cursor at the very top or right edge of the screen still resolves a cell.
        let isWithinScreen = point.x >= screenFrame.minX && point.x <= screenFrame.maxX &&
            point.y >= screenFrame.minY && point.y <= screenFrame.maxY
        guard visibleFrame.width > 0,
              visibleFrame.height > 0,
              screenFrame.width > 0,
              screenFrame.height > 0,
              isWithinScreen else {
            return nil
        }

        let edgeThickness = edgeActivationThickness(in: visibleFrame)
        let isLeftEdge = point.x < visibleFrame.minX || point.x <= visibleFrame.minX + edgeThickness
        let isRightEdge = point.x > visibleFrame.maxX || point.x >= visibleFrame.maxX - edgeThickness
        let isTopEdge = point.y > visibleFrame.maxY || point.y >= visibleFrame.maxY - edgeThickness
        let isBottomEdge = point.y < visibleFrame.minY || point.y <= visibleFrame.minY + edgeThickness

        let edgeColumn: Int?
        if isLeftEdge {
            edgeColumn = 0
        } else if isRightEdge {
            edgeColumn = columns - 1
        } else {
            edgeColumn = nil
        }

        let edgeRow: Int?
        if isTopEdge {
            edgeRow = 0
        } else if isBottomEdge {
            edgeRow = rows - 1
        } else {
            edgeRow = nil
        }

        if let edgeColumn, let edgeRow {
            return SnapGridCell(column: edgeColumn, row: edgeRow)
        }

        if let edgeRow {
            return SnapGridCell(column: desktopColumn(for: point.x, in: visibleFrame), row: edgeRow)
        }

        if let edgeColumn {
            return SnapGridCell(column: edgeColumn, row: desktopRow(for: point.y, in: visibleFrame))
        }

        guard visibleFrame.contains(point) else { return nil }
        return SnapGridCell(
            column: desktopColumn(for: point.x, in: visibleFrame),
            row: desktopRow(for: point.y, in: visibleFrame)
        )
    }

    private static func desktopColumn(for x: CGFloat, in visibleFrame: CGRect) -> Int {
        let clampedX = min(max(x, visibleFrame.minX), visibleFrame.maxX.nextDown)
        let column = Int((clampedX - visibleFrame.minX) / (visibleFrame.width / CGFloat(desktopColumns)))
        return desktopStartColumn + min(max(column, 0), desktopColumns - 1)
    }

    private static func desktopRow(for y: CGFloat, in visibleFrame: CGRect) -> Int {
        let clampedY = min(max(y, visibleFrame.minY), visibleFrame.maxY.nextDown)
        let row = Int((visibleFrame.maxY - clampedY) / (visibleFrame.height / CGFloat(desktopRows)))
        return desktopStartRow + min(max(row, 0), desktopRows - 1)
    }

    private static func edgeActivationThickness(in visibleFrame: CGRect) -> CGFloat {
        let cellSize = min(
            visibleFrame.width / CGFloat(desktopColumns),
            visibleFrame.height / CGFloat(desktopRows)
        )
        return min(max(cellSize * 0.55, 28), 72)
    }

    private mutating func clamp() {
        startColumn = min(max(startColumn, 0), Self.columns - 1)
        startRow = min(max(startRow, 0), Self.rows - 1)
        columnSpan = min(max(columnSpan, 1), Self.columns - startColumn)
        rowSpan = min(max(rowSpan, 1), Self.rows - startRow)
    }
}

struct SnapActivationPreference: Codable, Equatable {
    var layouts: [SnapActivationLayout]
    var isEnabled: Bool

    var layout: SnapActivationLayout {
        get { layouts.first ?? SnapActivationLayout.defaultLayout(for: .full) }
        set { layouts = [newValue] }
    }

    init(layout: SnapActivationLayout, isEnabled: Bool) {
        self.layouts = [layout]
        self.isEnabled = isEnabled
    }

    init(layouts: [SnapActivationLayout], isEnabled: Bool) {
        self.layouts = layouts
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case layout
        case layouts
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedLayouts = try container.decodeIfPresent([SnapActivationLayout].self, forKey: .layouts)
        let legacyLayout = try container.decodeIfPresent(SnapActivationLayout.self, forKey: .layout)
        layouts = decodedLayouts ?? legacyLayout.map { [$0] } ?? []
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layouts, forKey: .layouts)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    static func defaultPreference(for snapLayout: SnapLayout) -> SnapActivationPreference {
        SnapActivationPreference(
            layout: .defaultLayout(for: snapLayout),
            isEnabled: true
        )
    }
}
