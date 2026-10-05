//
//  ConsoleLanguage.swift
//  MeloCafe
//
//  Created by Stossy11 on 11/4/2026.
//

import Foundation

enum ConsoleLanguage: Int, CaseIterable {
    case japanese = 0
    case english = 1
    case french = 2
    case german = 3
    case italian = 4
    case spanish = 5
    case chinese = 6
    case korean = 7
    case dutch = 8
    case portuguese = 9
    case russian = 10
    case taiwanese = 11

    init(_ config: ObjCCafeConsoleLanguage) {
        self = ConsoleLanguage(rawValue: config.rawValue) ?? .english
    }

    var config: ObjCCafeConsoleLanguage {
        ObjCCafeConsoleLanguage(rawValue: self.rawValue) ?? .EN
    }

    var string: String {
        switch self {
        case .japanese: return "日语"
        case .english: return "英语"
        case .french: return "法语"
        case .german: return "德语"
        case .italian: return "意大利语"
        case .spanish: return "西班牙语"
        case .chinese: return "简体中文"
        case .korean: return "韩语"
        case .dutch: return "荷兰语"
        case .portuguese: return "葡萄牙语"
        case .russian: return "俄语"
        case .taiwanese: return "繁体中文"
        }
    }
}
