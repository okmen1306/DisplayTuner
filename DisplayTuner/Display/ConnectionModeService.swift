//
//  ConnectionModeService.swift
//  DisplayTuner
//
//  Görev: CADisplay ile RGB Full / YCbCr / bpc.
//  Faz: 5  ·  Kararlar: D-30…D-32, 10.2, 14  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation
import os

@MainActor
enum ConnectionModeService {
    nonisolated static let monitorName = "PR27R165QC"
    nonisolated static let defaultColorMode = "RGBFullRange"   // D-31
    nonisolated static let defaultBitDepth = 8                 // D-31
    nonisolated static let helperFlag = "--apply-connection-mode"

    /// D-130: Bağlantı modunu taze bir yardımcı süreçte uygular (uygulamanın kendi programı, parametreyle).
    /// Monitör henüz hazır değilse 2 sn arayla 3 kez dener.
    static func applyViaHelper(_ option: Option) async -> Bool {
        guard let executable = Bundle.main.executableURL else { return false }
        for attempt in 1...3 {
            let ok = await Task.detached { () -> Bool in
                let process = Process()
                process.executableURL = executable
                process.arguments = [helperFlag, option.colorMode, String(option.bitDepth)]
                do { try process.run() } catch { return false }
                process.waitUntilExit()
                return process.terminationStatus == 0
            }.value
            logger.info("Yardımcı süreç denemesi \(attempt): \(ok ? "başarılı" : "başarısız", privacy: .public)")
            if ok { return true }
            try? await Task.sleep(for: .seconds(2))
        }
        return false
    }
    private static let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "ConnectionMode")

    struct Option: Hashable, Sendable {
        let colorMode: String
        let bitDepth: Int
    }

    static var current: Option? {
        guard let mode = CADisplayBridge.display(productName: monitorName)?.currentMode else { return nil }
        return Option(colorMode: mode.colorMode, bitDepth: mode.bitDepth)
    }

    /// Mevcut çözünürlük/Hz/HDR için seçilebilecek renk modları.
    static var options: [Option] {
        guard let display = CADisplayBridge.display(productName: monitorName), let current = display.currentMode else { return [] }
        let key = current.geometryKey
        let set = Set(display.availableModes.filter { $0.geometryKey == key }.map { Option(colorMode: $0.colorMode, bitDepth: $0.bitDepth) })
        return set.sorted { ($0.colorMode, $0.bitDepth) < ($1.colorMode, $1.bitDepth) }
    }

    /// D-31: çözünürlük ve Hz korunarak renk modu değiştirilir. Zaten aynıysa dokunulmaz.
    /// `force`: Uzun çalışan süreçte CADisplay'in `currentMode` bilgisi bayat kalır (D-127);
    /// macOS'un modu sıfırladığı olaylarda (dock, uyanma, kilit, ekran değişimi) kontrol etmeden uygulanır.
    @discardableResult
    static func apply(_ option: Option = Option(colorMode: defaultColorMode, bitDepth: defaultBitDepth), force: Bool = false) -> Bool {
        guard let display = CADisplayBridge.display(productName: monitorName), let current = display.currentMode else {
            logger.info("Monitör bulunamadı")
            return false
        }
        if !force && current.colorMode == option.colorMode && current.bitDepth == option.bitDepth { return true }

        let key = current.geometryKey
        guard let target = display.availableModes.first(where: {
            $0.geometryKey == key && $0.colorMode == option.colorMode && $0.bitDepth == option.bitDepth
        }) else {
            logger.error("Uygun mod yok: \(option.colorMode, privacy: .public) \(option.bitDepth)")
            return false
        }

        // Risk (14): mod değişiminden sonra CG çözünürlüğü kayarsa geri yüklenir.
        let cgID = display.displayID.map { CGDirectDisplayID($0) }
        let before = cgID.flatMap { CGDisplayCopyDisplayMode($0) }

        guard display.setCurrentMode(target) else { return false }
        logger.info("Bağlantı modu: \(option.colorMode, privacy: .public) \(option.bitDepth) bpc")

        if let cgID, let before, let after = CGDisplayCopyDisplayMode(cgID),
           after.width != before.width || after.pixelWidth != before.pixelWidth {
            CGDisplaySetDisplayMode(cgID, before, nil)
            logger.info("Çözünürlük kaydı, geri yüklendi")
        }
        return true
    }
}
