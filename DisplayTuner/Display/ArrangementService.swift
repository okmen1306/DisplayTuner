//
//  ArrangementService.swift
//  DisplayTuner
//
//  Görev: Ana ekran (menü bar ve Dock'un olduğu ekran).
//  Faz: 5  ·  Kararlar: D-41  (bkz. AGENT_BRIEF.md)
//

import AppKit
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

    struct Display: Hashable, Identifiable {
        let id: CGDirectDisplayID
        let name: String
        var isBuiltin: Bool { CGDisplayIsBuiltin(id) != 0 }
    }

    /// Bağlı ekranlar (D-150): ana ekran önce, dahili ekran sonra.
    static func displays() -> [Display] {
        NSScreen.screens.compactMap { screen -> Display? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            let name = CGDisplayIsBuiltin(id) != 0 ? String(localized: "MacBook ekranı") : screen.localizedName
            return Display(id: id, name: name)
        }
        .sorted { ($0.isBuiltin ? 1 : 0, $0.name) < ($1.isBuiltin ? 1 : 0, $1.name) }
    }

    /// Seçilen ekranı ana ekran yapar ve tercihi saklar (monitör takılınca hangisi ana olsun, D-41/D-150).
    static func setMain(_ id: CGDirectDisplayID, on: Bool) {
        let monitor = ProfileStore.monitorDisplayID
        if id == monitor {
            monitorShouldBeMain = on
            if on { makeMain(id) } else { makeBuiltinMain() }
        } else if on {
            if monitor != nil { monitorShouldBeMain = false }
            makeMain(id)
        } else if let monitor {
            monitorShouldBeMain = true
            makeMain(monitor)
        } else {
            makeBuiltinMain()
        }
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
