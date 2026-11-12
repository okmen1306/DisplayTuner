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

    @discardableResult
    static func apply(_ table: LUTMath.Table, to display: CGDirectDisplayID) -> Bool {
        let result = CGSetDisplayTransferByTable(display, UInt32(table.count), table.red, table.green, table.blue)
        if result != .success { logger.error("Gamma tablosu uygulanamadı: \(result.rawValue)") }
        return result == .success
    }

    /// D-36: tablo beklenenden > 0.002 saptıysa true.
    static func hasDrifted(_ display: CGDirectDisplayID, expected: LUTMath.Table) -> Bool {
        guard let current = read(display) else { return true }
        return LUTMath.maxDeviation(LUTMath.clamped(current), LUTMath.clamped(expected)) > 0.002
    }
}
