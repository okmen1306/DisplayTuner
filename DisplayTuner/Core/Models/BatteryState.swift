//
//  BatteryState.swift
//  DisplayTuner
//
//  Görev: percent, isCharging, updatedAt, isStale.
//  Faz: 2  ·  Kararlar: D-64  (bkz. AGENT_BRIEF.md)
//

import Foundation

struct BatteryState: Sendable, Equatable {
    var percent: Int
    var isCharging: Bool
    var updatedAt: Date = .now
    /// Cihaz son sorguya cevap vermediyse true; son bilinen değer gösterilir (D-64).
    var isStale = false
}
