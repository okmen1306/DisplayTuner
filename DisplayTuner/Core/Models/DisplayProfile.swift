//
//  DisplayProfile.swift
//  DisplayTuner
//
//  Görev: Profil modeli: LUT, filtre, DDC, bağlantı modu, çözünürlük/Hz.
//  Faz: 5  ·  Kararlar: D-38  (bkz. AGENT_BRIEF.md)
//

import Foundation

struct DisplayProfile: Codable, Identifiable, Equatable, Sendable {
    struct Resolution: Codable, Equatable, Sendable {
        var width: Int, height: Int, pixelWidth: Int, refreshRate: Double
    }

    var id = UUID()
    var name: String
    /// Kayıtlı tablo varsa birebir yüklenir; yoksa `adjustments`'tan hesaplanır (D-38).
    var gammaTable: [[Float]]?          // [red, green, blue]
    var adjustments: ColorAdjustments = .identity
    var saturation: Double = 1, vibrance: Double = 0, hue: Double = 0, sepia: Double = 0   // D-33 filtre hattı
    var ddc: [UInt8: Int] = [:]          // VCP → değer
    var colorMode: String = ConnectionModeService.defaultColorMode
    var bitDepth: Int = ConnectionModeService.defaultBitDepth
    var resolution: Resolution?

    var needsCompositorFilter: Bool { saturation != 1 || vibrance != 0 || hue != 0 || sepia != 0 }  // D-34

    func lut(size: Int) -> LUTMath.Table {
        if let t = gammaTable, t.count == 3, t[0].count == size {
            return LUTMath.Table(red: t[0], green: t[1], blue: t[2])
        }
        return LUTMath.table(adjustments, size: size)
    }
}
