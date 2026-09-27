//
//  CarouselLayoutIcon.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import CollectionViewPagingLayout

extension ScaleTransformViewOptions.Layout {
    var icon: ASIcon {
        switch self {
        case .invertedCylinder:
            return .image(R.image.scale_invertedcylinder())
        case .cylinder:
            return .image(R.image.scale_cylinder())
        case .coverFlow:
            return .image(R.image.scale_coverflow())
        case .rotary:
            return .image(R.image.scale_rotary())
        case .linear, .easeIn, .easeOut:
            return .image(R.image.scale_normal())
        case .blur:
            return .image(R.image.scale_blur())
        }
    }
}

extension StackTransformViewOptions.Layout {
    var icon: ASIcon {
        switch self {
        case .transparent:
            return .image(R.image.stack_transparent())
        case .perspective:
            return .image(R.image.stack_prespective())
        case .rotary:
            return .image(R.image.stack_rotary())
        case .vortex:
            return .image(R.image.stack_vortex())
        case .reverse:
            return .image(R.image.stack_reverse())
        case .blur:
            return .image(R.image.stack_blur())
        }
    }
}

extension SnapshotTransformViewOptions.Layout {
    var icon: ASIcon {
        switch self {
        case .grid:
            return .image(R.image.snapshot_grid())
        case .space:
            return .image(R.image.snapshot_space())
        case .chess:
            return .image(R.image.snapshot_chess())
        case .tiles:
            return .image(R.image.snapshot_tiles())
        case .lines:
            return .image(R.image.snapshot_lines())
        case .bars:
            return .image(R.image.snapshot_bars())
        case .puzzle:
            return .image(R.image.snapshot_puzzle())
        case .fade:
            return .image(R.image.snapshot_fade())
        }
    }
}
