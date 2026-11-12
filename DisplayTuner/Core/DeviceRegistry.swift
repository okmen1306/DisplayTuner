//
//  DeviceRegistry.swift
//  DisplayTuner
//
//  Görev: Bağlı cihazların @Observable listesi.
//  Faz: 2  ·  Kararlar: D-11  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Desteklenen cihazları (Bölüm 3) bulur ve sürücülerini tutar. Sadece bu üç cihaz desteklenir (D-11).
@MainActor
@Observable
final class DeviceRegistry {
    private(set) var headset: BlackSharkV2HS?
    private(set) var mouse: GladiusIIWireless?
    private(set) var keyboard: K3Pro?

    /// Bağlı olmayanları yeniden arar; çıkarılanları bırakır.
    func rescan() {
        if headset == nil || !isPresent(BlackSharkV2HS.vendorID, BlackSharkV2HS.productID) {
            headset = isPresent(BlackSharkV2HS.vendorID, BlackSharkV2HS.productID) ? BlackSharkV2HS() : nil
        }
        if mouse == nil || !isPresent(GladiusIIWireless.vendorID, GladiusIIWireless.productID) {
            mouse = isPresent(GladiusIIWireless.vendorID, GladiusIIWireless.productID) ? GladiusIIWireless() : nil
        }
        if keyboard == nil || !isPresent(K3Pro.vendorID, K3Pro.productID) {
            keyboard = isPresent(K3Pro.vendorID, K3Pro.productID) ? K3Pro() : nil
        }
    }

    var batteryDevices: [any BatteryReporting] {
        [headset as (any BatteryReporting)?, mouse].compactMap { $0 }
    }

    private func isPresent(_ vendorID: Int, _ productID: Int) -> Bool {
        HIDDeviceMatcher.find(vendorID: vendorID, productID: productID) != nil
    }
}
