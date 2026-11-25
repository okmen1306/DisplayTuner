//
//  GammaEngine.swift
//  DisplayTuner
//
//  Görev: CGSetDisplayTransferByTable uygulama; clamp yok.
//  Faz: 5  ·  Kararlar: D-33, D-35  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation
import os

@MainActor
enum GammaEngine {
    private static let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Gamma")

    static func capacity(of display: CGDirectDisplayID) -> Int {
        Int(CGDisplayGammaTableCapacity(display))
    }

    static func read(_ display: CGDirectDisplayID) -> LUTMath.Table? {
        let cap = capacity(of: display)
        guard cap > 1 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: cap), g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(cap), &r, &g, &b, &count) == .success, count > 1 else { return nil }
        let n = Int(count)
        return LUTMath.Table(red: Array(r.prefix(n)), green: Array(g.prefix(n)), blue: Array(b.prefix(n)))
    }

    /// D-157: göz konforu çarpanı eklenmiş tablo (aktif değilse aynısı).
    static func warmed(_ table: LUTMath.Table, for display: CGDirectDisplayID) -> LUTMath.Table {
        guard let (r, g, b) = EyeComfort.multipliers[display], (r, g, b) != (1, 1, 1) else { return table }
        return LUTMath.Table(red: table.red.map { $0 * Float(r) }, green: table.green.map { $0 * Float(g) },
                             blue: table.blue.map { $0 * Float(b) })
    }

    @discardableResult
    static func apply(_ base: LUTMath.Table, to display: CGDirectDisplayID) -> Bool {
        let table = warmed(base, for: display)
        let result = CGSetDisplayTransferByTable(display, UInt32(table.count), table.red, table.green, table.blue)
        if result != .success { logger.error("Gamma tablosu uygulanamadı: \(result.rawValue)") }
        return result == .success
    }

    /// D-36: tablo beklenenden > 0.002 saptıysa true.
    static func hasDrifted(_ display: CGDirectDisplayID, expected: LUTMath.Table) -> Bool {
        guard let current = read(display) else { return true }
        return LUTMath.maxDeviation(LUTMath.clamped(current), LUTMath.clamped(warmed(expected, for: display))) > 0.002
    }
}
