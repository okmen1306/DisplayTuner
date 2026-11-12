//
//  K3Pro.swift
//  DisplayTuner
//
//  Görev: Pusat klavye sürücüsü (actor).
//  Faz: 2  ·  Kararlar: 10.8  (bkz. AGENT_BRIEF.md)
//

import Foundation

actor K3Pro {
    static let vendorID = 0x0C45
    static let productID = 0x5004

    nonisolated let kind: DeviceKind = .keyboard
    nonisolated let displayName = "PUSAT K3 Pro"

    private let transport: HIDTransport
    private let requests = HIDRequestQueue()

    init?() {
        // Vendor arayüzü: 64 byte output report'u olan koleksiyon (usage page 0xFF1C).
        guard let device = HIDDeviceMatcher.find(vendorID: Self.vendorID, productID: Self.productID, outputReportSize: 64),
              let transport = HIDTransport(device: device, label: "pusat") else { return nil }
        self.transport = transport
    }

    private func query(_ packet: [UInt8]) async -> [UInt8]? {
        let transport = transport
        return await requests.run {
            transport.clear()
            guard transport.send(reportID: Int(PusatPacket.reportID), packet) else { return nil }
            return await transport.waitForReport(timeout: .milliseconds(800)) {
                $0.count > 5 && $0[0] == PusatPacket.reportID && $0[3] == packet[3] && $0[4] == packet[4] && $0[5] == packet[5]
            }
        }
    }

    func activeProfile() async -> Int? {
        guard let reply = await query(PusatPacket.readActiveProfile) else { return nil }
        return PusatPacket.parseActiveProfile(reply)
    }

    func led(profile: Int) async -> PusatPacket.LED? {
        guard (1...3).contains(profile), let reply = await query(PusatPacket.readLED(profile: profile)) else { return nil }
        return PusatPacket.parseLED(reply)
    }

    // MARK: - Ayarlar (Faz 3)

    enum Setting: UInt8 {
        case mode = 0x00, brightness = 0x01, speedRaw = 0x02, direction = 0x03
    }

    /// `04 chk 00 06 01 <offset> 00 00 <değer>`; offset = ayar + 0x2A × (profil − 1). Başlat/bitir paketleri arasında gönderilir.
    @discardableResult
    func set(_ setting: Setting, _ value: UInt8, profile: Int) async -> Bool {
        guard (1...3).contains(profile) else { return false }
        let offset = setting.rawValue + 0x2A * UInt8(profile - 1)
        let transport = transport
        return await requests.run {
            let start = PusatPacket.make(0x01, 0x00, 0x00)   // 04 01 00 01 (checksum = 01)
            let packet = PusatPacket.make(0x06, 0x01, offset, data: [8: value])
            let end = PusatPacket.make(0x02, 0x00, 0x00)     // 04 02 00 02
            var ok = true
            for p in [start, packet, end] {
                ok = ok && transport.send(reportID: Int(PusatPacket.reportID), p)
                try? await Task.sleep(for: .milliseconds(30))
            }
            transport.clear()
            return ok
        }
    }
}
