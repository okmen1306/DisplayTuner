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
        case .horizontalWave: "Yatay dalga"
        case .pulse: "Nabız"
        case .hurricane: "Kasırga"
        case .breathingColor: "Renkli nefes"
        case .breathing: "Nefes"
        case .fixed: "Sabit"
        case .reactiveSingle: "Tepki (tek tuş)"
        case .reactiveRipple: "Tepki (dalgalanma)"
        case .reactiveHorizontal: "Tepki (yatay)"
        case .waterfall: "Şelale"
        case .swirl: "Girdap"
        case .verticalWave: "Dikey dalga"
        case .sine: "Sinüs"
        case .vortex: "Vorteks"
        case .rain: "Yağmur"
        case .diagonalWave: "Çapraz dalga"
        case .reactiveColor: "Renkli tepki"
        case .ripple: "Dalgalanma"
        case .off: "Kapalı"
        case .custom: "Özel"
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
