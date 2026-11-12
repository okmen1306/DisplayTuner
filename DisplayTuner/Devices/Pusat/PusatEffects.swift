//
//  PusatEffects.swift
//  DisplayTuner
//
//  Görev: 20 efekt kodu, yön desteği.
//  Faz: 2  ·  Kararlar: 10.8  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum PusatEffect: UInt8, CaseIterable, Sendable, Identifiable {
    case horizontalWave = 0x01, pulse, hurricane, breathingColor, breathing, fixed
    case reactiveSingle, reactiveRipple, reactiveHorizontal, waterfall, swirl, verticalWave
    case sine, vortex, rain, diagonalWave, reactiveColor, ripple, off, custom

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .horizontalWave: String(localized: "Yatay dalga")
        case .pulse: String(localized: "Nabız")
        case .hurricane: String(localized: "Kasırga")
        case .breathingColor: String(localized: "Renkli nefes")
        case .breathing: String(localized: "Nefes")
        case .fixed: String(localized: "Sabit")
        case .reactiveSingle: String(localized: "Tepki (tek tuş)")
        case .reactiveRipple: String(localized: "Tepki (dalgalanma)")
        case .reactiveHorizontal: String(localized: "Tepki (yatay)")
        case .waterfall: String(localized: "Şelale")
        case .swirl: String(localized: "Girdap")
        case .verticalWave: String(localized: "Dikey dalga")
        case .sine: String(localized: "Sinüs")
        case .vortex: String(localized: "Vorteks")
        case .rain: String(localized: "Yağmur")
        case .diagonalWave: String(localized: "Çapraz dalga")
        case .reactiveColor: String(localized: "Renkli tepki")
        case .ripple: String(localized: "Dalgalanma")
        case .off: String(localized: "Kapalı")
        case .custom: String(localized: "Özel")
        }
    }

    /// Yön seçimi sadece hareketli efektlerde gösterilir (tahmin; donanımda doğrulanacak).
    var supportsDirection: Bool {
        switch self {
        case .horizontalWave, .hurricane, .reactiveRipple, .reactiveHorizontal, .waterfall,
             .swirl, .verticalWave, .sine, .vortex, .diagonalWave, .ripple: true
        default: false
        }
    }
}
