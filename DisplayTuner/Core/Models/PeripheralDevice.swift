//
//  PeripheralDevice.swift
//  DisplayTuner
//
//  Görev: Ortak cihaz protokolü (Actor).
//  Faz: 2  ·  Kararlar: D-60, 6  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Pil bildiren cihaz sürücüleri. Her sürücü bir actor'dür; istekler sırayla gider (D-60).
protocol BatteryReporting: Actor {
    nonisolated var kind: DeviceKind { get }
    nonisolated var displayName: String { get }
    /// nil: cihaz kapalı / cevap yok.
    func readBattery() async -> BatteryState?
}
