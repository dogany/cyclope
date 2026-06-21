//
//  CustomSnapPreset.swift
//  Cyclope
//

import Foundation

struct CustomSnapPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var layout: SnapLayout
    var mode: CustomSnapPresetMode
    var position: CustomSnapPosition
    var snapActivationLayouts: [SnapActivationLayout]
    var isSnapActivationEnabled: Bool

    var isPositionOnly: Bool {
        mode == .positionOnly
    }

    var snapActivationLayout: SnapActivationLayout {
        get { snapActivationLayouts.first ?? SnapActivationLayout.defaultLayout(for: layout) }
        set { snapActivationLayouts = [newValue] }
    }

    init(
        id: UUID = UUID(),
        name: String,
        layout: SnapLayout,
        mode: CustomSnapPresetMode = .sizeAndPosition,
        position: CustomSnapPosition? = nil,
        snapActivationLayout: SnapActivationLayout? = nil,
        snapActivationLayouts: [SnapActivationLayout]? = nil,
        isSnapActivationEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.layout = layout
        self.mode = mode
        self.position = position ?? CustomSnapPosition(layout: layout)
        self.snapActivationLayouts = snapActivationLayouts ??
            snapActivationLayout.map { [$0] } ??
            [SnapActivationLayout.defaultLayout(for: layout)]
        self.isSnapActivationEnabled = isSnapActivationEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layout
        case mode
        case position
        case snapActivationLayout
        case snapActivationLayouts
        case isSnapActivationEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        layout = try container.decode(SnapLayout.self, forKey: .layout)
        mode = try container.decodeIfPresent(
            CustomSnapPresetMode.self,
            forKey: .mode
        ) ?? .sizeAndPosition
        position = try container.decodeIfPresent(
            CustomSnapPosition.self,
            forKey: .position
        ) ?? CustomSnapPosition(layout: layout)
        let decodedLayouts = try container.decodeIfPresent(
            [SnapActivationLayout].self,
            forKey: .snapActivationLayouts
        )
        let legacyLayout = try container.decodeIfPresent(
            SnapActivationLayout.self,
            forKey: .snapActivationLayout
        )
        snapActivationLayouts = decodedLayouts ??
            legacyLayout.map { [$0] } ??
            [SnapActivationLayout.defaultLayout(for: layout)]
        isSnapActivationEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isSnapActivationEnabled
        ) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(layout, forKey: .layout)
        try container.encode(mode, forKey: .mode)
        try container.encode(position, forKey: .position)
        try container.encode(snapActivationLayouts, forKey: .snapActivationLayouts)
        try container.encode(isSnapActivationEnabled, forKey: .isSnapActivationEnabled)
    }

    static var defaults: [CustomSnapPreset] {
        ShortcutCommand.defaultCustomSnapPresets
    }
}

enum CustomSnapPresetMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case sizeAndPosition
    case positionOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sizeAndPosition:
            return String(localized: "Size & Position")
        case .positionOnly:
            return String(localized: "Position")
        }
    }
}

enum CustomSnapPosition: String, Codable, CaseIterable, Identifiable, Hashable {
    case topLeft
    case top
    case topRight
    case left
    case center
    case right
    case bottomLeft
    case bottom
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft:
            return String(localized: "Top Left")
        case .top:
            return String(localized: "Top")
        case .topRight:
            return String(localized: "Top Right")
        case .left:
            return String(localized: "Left")
        case .center:
            return String(localized: "Center")
        case .right:
            return String(localized: "Right")
        case .bottomLeft:
            return String(localized: "Bottom Left")
        case .bottom:
            return String(localized: "Bottom")
        case .bottomRight:
            return String(localized: "Bottom Right")
        }
    }

    var layout: SnapLayout {
        SnapLayout(
            columns: 3,
            rows: 3,
            startColumn: column,
            startRow: row,
            columnSpan: 1,
            rowSpan: 1
        )
    }

    var column: Int {
        switch self {
        case .topLeft, .left, .bottomLeft:
            return 0
        case .top, .center, .bottom:
            return 1
        case .topRight, .right, .bottomRight:
            return 2
        }
    }

    var row: Int {
        switch self {
        case .topLeft, .top, .topRight:
            return 0
        case .left, .center, .right:
            return 1
        case .bottomLeft, .bottom, .bottomRight:
            return 2
        }
    }

    static let rows: [[CustomSnapPosition]] = [
        [.topLeft, .top, .topRight],
        [.left, .center, .right],
        [.bottomLeft, .bottom, .bottomRight]
    ]

    init(layout: SnapLayout) {
        let column = Self.positionColumn(for: layout)
        let row = Self.positionRow(for: layout)

        switch (column, row) {
        case (0, 0):
            self = .topLeft
        case (1, 0):
            self = .top
        case (2, 0):
            self = .topRight
        case (0, 1):
            self = .left
        case (1, 1):
            self = .center
        case (2, 1):
            self = .right
        case (0, 2):
            self = .bottomLeft
        case (1, 2):
            self = .bottom
        default:
            self = .bottomRight
        }
    }

    private static func positionColumn(for layout: SnapLayout) -> Int {
        if layout.columnSpan >= layout.columns {
            return 1
        }

        if layout.startColumn <= 0 {
            return 0
        }

        if layout.startColumn + layout.columnSpan >= layout.columns {
            return 2
        }

        let midpoint = Double(layout.startColumn) + Double(layout.columnSpan) / 2
        let ratio = midpoint / Double(layout.columns)
        if ratio < 1.0 / 3.0 {
            return 0
        }

        if ratio > 2.0 / 3.0 {
            return 2
        }

        return 1
    }

    private static func positionRow(for layout: SnapLayout) -> Int {
        if layout.rowSpan >= layout.rows {
            return 1
        }

        if layout.startRow <= 0 {
            return 0
        }

        if layout.startRow + layout.rowSpan >= layout.rows {
            return 2
        }

        let midpoint = Double(layout.startRow) + Double(layout.rowSpan) / 2
        let ratio = midpoint / Double(layout.rows)
        if ratio < 1.0 / 3.0 {
            return 0
        }

        if ratio > 2.0 / 3.0 {
            return 2
        }

        return 1
    }
}
