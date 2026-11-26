//
//  GladiusIIWireless.swift
//  DisplayTuner
//
//  Görev: ASUS mouse sürücüsü (actor).
//  Faz: 2  ·  Kararlar: D-64  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os

actor GladiusIIWireless: BatteryReporting {
    static let vendorID = 0x0B05
    static let productID = 0x18A0
    static let usagePage = 0xFF01

    nonisolated let kind: DeviceKind = .mouse
    nonisolated let displayName = "ROG Gladius II"

    private let transport: HIDTransport
    private let requests = HIDRequestQueue()

    init?() {
        guard let device = HIDDeviceMatcher.find(vendorID: Self.vendorID, productID: Self.productID, usagePage: Self.usagePage),
              let transport = HIDTransport(device: device, label: "asus") else { return nil }
        self.transport = transport
    }

    /// Komutu gönderir; aynı iki byte ile başlayan cevabı ya da `FF AA` hatasını bekler.
    func send(_ bytes: [UInt8]) async -> [UInt8]? {
        let transport = transport
        let reply = await requests.run {
            transport.clear()
            guard transport.send(reportID: 0, AsusPacket.request(bytes)) else { return nil as [UInt8]? }
            return await transport.waitForReport(timeout: .milliseconds(800)) {
                AsusPacket.isError($0) || ($0.count >= 2 && $0[0] == bytes[0] && $0[1] == bytes[1])
            }
        }
        guard let reply, !AsusPacket.isError(reply) else { return nil } // D-64: uyku / desteklenmiyor
        return reply
    }

    func readBattery() async -> BatteryState? {
        guard let reply = await send(AsusPacket.readStatus), let status = AsusPacket.parseStatus(reply) else { return nil }
        return BatteryState(percent: status.batteryPercent, isCharging: status.isCharging)
    }

    func readLighting(zone: UInt8) async -> AsusPacket.Lighting? {
        guard let reply = await send(AsusPacket.readLighting(zone: zone)) else { return nil }
        return AsusPacket.parseLighting(reply)
    }

    // MARK: - Ayarlar (Faz 3)

    /// `51 28 <bölge> 00 <mod> <parlaklık> <R> <G> <B> <yön> <rastgele> <hız>` — canlı uygular, kaydetmez.
    @discardableResult
    func setLighting(zone: UInt8, _ lighting: AsusPacket.Lighting) async -> Bool {
        await send([0x51, 0x28, zone, 0x00, lighting.mode, UInt8(clamping: lighting.brightness),
                    lighting.red, lighting.green, lighting.blue, 0x00, 0x00, 0x00]) != nil
    }

    /// `50 03` — ayarları mouse hafızasına kaydeder (D-65: debounce ile çağrılır).
    @discardableResult
    /// D-162: tuş atamaları (okuma). Cevap: [4+2i]=eylem kodu, [5+2i]=tür (0 tuş, 1 mouse tuşu), 8 tuş.
    func readButtonBindings() async -> [(code: UInt8, type: UInt8)]? {
        var request = [UInt8](repeating: 0, count: 64)
        request[0] = 0x12; request[1] = 0x05
        guard let reply = await send(request), reply.count >= 20 else { return nil }
        return (0..<8).map { (reply[4 + 2 * $0], reply[5 + 2 * $0]) }
    }

    func saveToFlash() async -> Bool {
        await send([0x50, 0x03]) != nil
    }
}
