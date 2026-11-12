//
//  ArrangementService.swift
//  DisplayTuner
//
//  Görev: Ana ekran (menü bar ve Dock'un olduğu ekran).
//  Faz: 5  ·  Kararlar: D-41  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation
import os

@MainActor
enum ArrangementService {
    private static let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Arrangement")

    /// Kullanıcı tercihi: monitör bağlanınca ana ekran olsun mu (varsayılan açık, D-41).
    static var monitorShouldBeMain: Bool {
        get { UserDefaults.standard.object(forKey: "monitorIsMain") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "monitorIsMain") }
    }

    static func isMain(_ id: CGDirectDisplayID) -> Bool { CGDisplayIsMain(id) != 0 }

    /// Ana ekran = origin (0,0). Diğer ekranlar aynı göreli yerleşimi koruyacak şekilde kaydırılır.
    @discardableResult
    static func makeMain(_ id: CGDirectDisplayID) -> Bool {
        guard !isMain(id) else { return true }
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return false }
        let shift = CGDisplayBounds(id).origin
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        for display in ids.prefix(Int(count)) {
            let b = CGDisplayBounds(display)
            CGConfigureDisplayOrigin(config, display, Int32(b.origin.x - shift.x), Int32(b.origin.y - shift.y))
        }
        let ok = CGCompleteDisplayConfiguration(config, .permanently) == .success
        logger.info("Ana ekran değişti: \(ok)")
        return ok
    }

    /// Ana ekranı dahili ekrana geri verir.
    static func makeBuiltinMain() {
        if let builtin = BuiltinBrightness.displayID { makeMain(builtin) }
    }
}
