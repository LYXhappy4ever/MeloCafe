//
//  ScreenLayout.swift
//  MeloCafe
//
//  Created by Stossy11 on 12/9/2026.
//

import Foundation

enum ScreenLayout: String, CaseIterable {
    case singleScreen
    case bothScreens
    case smallGamePadTopRight

    var string: String {
        switch self {
        case .singleScreen: return "单屏"
        case .bothScreens: return "自适应双屏"
        case .smallGamePadTopRight: return "双屏（GamePad 位于右上角）"
        }
    }

    var description: String {
        switch self {
        case .singleScreen:
            return "仅渲染选中的屏幕。使用切换按钮在电视与 GamePad 之间切换。"
        case .bothScreens:
            return "电视与 GamePad 画面自动调整：竖屏时上下排列，横屏时左右并排。"
        case .smallGamePadTopRight:
            return "小尺寸 GamePad 画面位于右上角，在电视画面旁单独占一列。"
        }
    }
    
    var showsBothScreens: Bool { self != .singleScreen }

    static var initialValue: ScreenLayout {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: "screenLayout"),
           let layout = ScreenLayout(rawValue: stored) {
            return layout
        }
        let layout: ScreenLayout = defaults.bool(forKey: "showBothScreens") ? (defaults.bool(forKey: "smallGamePadTopRight") ? .smallGamePadTopRight : .bothScreens) : .singleScreen
        defaults.set(layout.rawValue, forKey: "screenLayout")
        return layout
    }
}
