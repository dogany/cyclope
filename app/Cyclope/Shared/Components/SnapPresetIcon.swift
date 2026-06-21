//
//  SnapPresetIcon.swift
//  Cyclope
//

import SwiftUI

struct SnapPresetIcon: View {
    let layout: SnapLayout
    var position: CustomSnapPosition = .center
    var isPositionOnly = false
    var isSelected = false
    var tint: Color = .accentColor

    init(
        layout: SnapLayout,
        position: CustomSnapPosition = .center,
        isPositionOnly: Bool = false,
        isSelected: Bool = false,
        tint: Color = .accentColor
    ) {
        self.layout = layout
        self.position = position
        self.isPositionOnly = isPositionOnly
        self.isSelected = isSelected
        self.tint = tint
    }

    init(
        preset: CustomSnapPreset,
        isSelected: Bool = false,
        tint: Color = .accentColor
    ) {
        layout = preset.layout
        position = preset.position
        isPositionOnly = preset.isPositionOnly
        self.isSelected = isSelected
        self.tint = tint
    }

    var body: some View {
        if isPositionOnly {
            PositionOnlySnapIcon(
                position: position,
                isSelected: isSelected,
                baseCornerRadius: 4,
                windowCornerRadius: 3,
                tint: tint,
                usesPositionColor: false
            )
        } else {
            SnapLayoutIcon(
                layout: layout,
                isSelected: isSelected,
                baseCornerRadius: 4,
                fillCornerRadius: 2,
                tint: tint
            )
        }
    }
}
