//
//  DeviceKind.swift
//  DisplayTuner
//
//  Görev: headset, mouse, keyboard, monitor, dock.
//  Faz: 2  ·  Kararlar: 6  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum DeviceKind: String, Sendable, CaseIterable, Codable {
    case headset, mouse, keyboard, monitor, dock

    var symbol: String {
        switch self {
        case .headset: "headphones"
        case .mouse: "computermouse.fill"
        case .keyboard: "keyboard.fill"
        case .monitor: "display"
        case .dock: "cable.connector"
        }
    }
}
