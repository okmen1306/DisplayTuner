//
//  CADisplayBridge.swift
//  DisplayTuner
//
//  Görev: CADisplay / CADisplayMode KVC erişimi.
//  Faz: 5  ·  Kararlar: D-30, D-32  (bkz. AGENT_BRIEF.md)
//

import Foundation
import QuartzCore

/// Private QuartzCore `CADisplay`. Her özellik `responds(to:)` kontrolüyle okunur (R8, D-32).
@MainActor
struct CADisplayBridge {
    struct Mode {
        let object: NSObject
        func value(_ key: String) -> Any? {
            object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) : nil
        }
        func string(_ key: String) -> String { String(describing: value(key) ?? "") }
        var colorMode: String { string("colorMode") }
        var bitDepth: Int { (value("bitDepth") as? NSNumber)?.intValue ?? 0 }
        var hdrMode: String { string("hdrMode") }
        /// D-31 eşleştirme anahtarları.
        var geometryKey: String {
            ["width", "height", "refreshRate", "isVRR", "preferredScale", "hdrMode"].map(string).joined(separator: "|")
        }
    }

    let object: NSObject

    static var isAvailable: Bool { NSClassFromString("CADisplay") != nil }

    static func all() -> [CADisplayBridge] {
        guard let cls = NSClassFromString("CADisplay") as? NSObject.Type,
              cls.responds(to: NSSelectorFromString("displays")),
              let list = cls.perform(NSSelectorFromString("displays"))?.takeUnretainedValue() as? [NSObject] else { return [] }
        return list.map(CADisplayBridge.init)
    }

    static func display(productName: String) -> CADisplayBridge? {
        all().first { $0.productName == productName }
    }

    private func value(_ key: String) -> Any? {
        object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) : nil
    }

    var productName: String? { value("productName") as? String }
    var displayID: UInt32? { (value("displayId") as? NSNumber)?.uint32Value }
    var currentMode: Mode? { (value("currentMode") as? NSObject).map(Mode.init) }
    var availableModes: [Mode] { ((value("availableModes") as? [NSObject]) ?? []).map(Mode.init) }

    func setCurrentMode(_ mode: Mode) -> Bool {
        let selector = NSSelectorFromString("setCurrentMode:")
        guard object.responds(to: selector) else { return false }
        object.perform(selector, with: mode.object)
        return true
    }
}
