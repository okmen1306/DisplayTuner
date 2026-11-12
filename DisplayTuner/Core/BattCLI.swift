//
//  BattCLI.swift
//  DisplayTuner
//
//  Görev: /usr/local/bin/batt sarmalayıcı (limit 80/100).
//  Faz: 6  ·  Kararlar: D-93  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os

enum BattCLI {
    static let path = "/usr/local/bin/batt"
    private static let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Batt")

    /// D-93: `batt` yoksa adım atlanır ve loglanır.
    @discardableResult
    static func setLimit(_ percent: Int) async -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            logger.error("batt bulunamadı; şarj limiti atlandı")
            return false
        }
        let ok = await Task.detached { () -> Bool in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["limit", String(percent)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return false }
            process.waitUntilExit()
            return process.terminationStatus == 0
        }.value
        logger.info("Şarj limiti %\(percent): \(ok ? "ayarlandı" : "başarısız", privacy: .public)")
        return ok
    }
}
