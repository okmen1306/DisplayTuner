//
//  BaselineImporter.swift
//  DisplayTuner
//
//  Görev: BaselineProfile.json → 'Masa (Kayıtlı)' profili.
//  Faz: 5  ·  Kararlar: D-38, 4  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum BaselineImporter {
    static let profileName = "Masa (Kayıtlı)"

    private struct File: Decodable {
        struct Monitor: Decodable {
            struct Connection: Decodable { let colorMode: String; let bitDepth: Int }
            struct Mode: Decodable { let width: Int; let height: Int; let pixelWidth: Int; let refreshRate: Double }
            struct Gamma: Decodable { let red: [Float]; let green: [Float]; let blue: [Float] }
            let connectionMode: Connection
            let displayMode: Mode
            let ddc: [String: String]
            let gammaTable: Gamma
            let betterDisplayValues: [String: Double]?
        }
        let monitor: Monitor
    }

    /// VCP adı (JSON) → kod. Sadece yazılabilir olanlar (4. bölüm, adım 3).
    private static let vcpNames: [String: DDCService.VCP] = [
        "brightness": .brightness, "contrast": .contrast, "colorPreset": .colorPreset,
        "redGain": .redGain, "greenGain": .greenGain, "blueGain": .blueGain, "blackLevelRed": .blackLevelRed,
    ]

    static func load(bundle: Bundle = .main) -> DisplayProfile? {
        guard let url = bundle.url(forResource: "BaselineProfile", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> DisplayProfile? {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        let m = file.monitor
        var ddc: [UInt8: Int] = [:]
        for (name, value) in m.ddc {
            // "100/100" → 100; "unsupported" atlanır.
            if let vcp = vcpNames[name], let current = value.split(separator: "/").first.flatMap({ Int($0) }) {
                ddc[vcp.rawValue] = current
            }
        }
        var adjustments = ColorAdjustments.identity
        adjustments.contrast = m.betterDisplayValues?["ColorController.contrast"] ?? 0
        return DisplayProfile(
            name: profileName,
            gammaTable: [m.gammaTable.red, m.gammaTable.green, m.gammaTable.blue],
            adjustments: adjustments,
            ddc: ddc,
            colorMode: m.connectionMode.colorMode,
            bitDepth: m.connectionMode.bitDepth,
            resolution: .init(width: m.displayMode.width, height: m.displayMode.height,
                              pixelWidth: m.displayMode.pixelWidth, refreshRate: m.displayMode.refreshRate)
        )
    }
}
