//
//  BuiltinBrightness.swift
//  DisplayTuner
//
//  Görev: Dahili ekran parlaklığı (DisplayServices).
//  Faz: 1  ·  Kararlar: 7.1  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation

enum BuiltinBrightness {
    static var displayID: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var value: Double? {
        guard let id = displayID, let v = DisplayServicesBridge.shared.brightness(of: id) else { return nil }
        return Double(v)
    }

    static func set(_ value: Double) {
        guard let id = displayID else { return }
        DisplayServicesBridge.shared.setBrightness(Float(value), of: id)
    }
}
