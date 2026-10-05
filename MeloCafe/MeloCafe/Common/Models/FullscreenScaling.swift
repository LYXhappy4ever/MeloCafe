//
//  FullscreenScaling.swift
//  MeloCafe
//
//  Created by Stossy11 on 11/4/2026.
//

import Foundation

enum FullscreenScaling: Int, CaseIterable {
    case keepAspectRatio = 0
    case stretch = 1

    init(_ config: ObjCFullscreenScaling) {
        self = FullscreenScaling(rawValue: config.rawValue) ?? .keepAspectRatio
    }

    var config: ObjCFullscreenScaling {
        ObjCFullscreenScaling(rawValue: self.rawValue) ?? .keepAspectRatio
    }

    var string: String {
        switch self {
        case .keepAspectRatio: return "保持宽高比"
        case .stretch: return "拉伸"
        }
    }
}
