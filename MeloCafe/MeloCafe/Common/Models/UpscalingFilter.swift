//
//  UpscalingFilter.swift
//  MeloCafe
//
//  Created by Stossy11 on 11/4/2026.
//

import Foundation

enum UpscalingFilter: Int, CaseIterable {
    case linear = 0
    case bicubic = 1
    case bicubicHermite = 2
    case nearestNeighbor = 3

    init(_ config: ObjCUpscalingFilter) {
        self = UpscalingFilter(rawValue: config.rawValue) ?? .linear
    }

    var config: ObjCUpscalingFilter {
        ObjCUpscalingFilter(rawValue: self.rawValue) ?? .linear
    }

    var string: String {
        switch self {
        case .linear: return "线性"
        case .bicubic: return "双三次"
        case .bicubicHermite: return "双三次 Hermite"
        case .nearestNeighbor: return "最近邻"
        }
    }
}
