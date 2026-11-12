//
//  BlackSharkV2HS.swift
//  DisplayTuner
//
//  Görev: Razer kulaklık sürücüsü (actor).
//  Faz: 2  ·  Kararlar: D-62, D-63, D-67  (bkz. AGENT_BRIEF.md)
//

import Foundation

actor BlackSharkV2HS: BatteryReporting {
    static let vendorID = 0x1532
    static let productID = 0x0565
    static let usagePage = 0xFF13

    nonisolated let kind: DeviceKind = .headset
    nonisolated let displayName = "BlackShark V2 HyperSpeed"

    private let transport: HIDTransport
    private let requests = HIDRequestQueue()
    private var sequence: UInt8 = 0

    init?() {
        guard let device = HIDDeviceMatcher.find(vendorID: Self.vendorID, productID: Self.productID, usagePage: Self.usagePage),
              let transport = HIDTransport(device: device, label: "razer") else { return nil }
        self.transport = transport
    }

    /// Tek bir okuma/yazma isteği; meşgulse bir kez daha dener. Timeout 800 ms.
    func send(_ command: UInt8, target: RazerTarget, parameters: [UInt8] = []) async -> RazerPacket.Reply? {
        for _ in 0..<2 {
            sequence = (sequence &+ 1) & 0x1F
            let seq = sequence
            let transport = transport
            let reply = await requests.run { () async -> RazerPacket.Reply? in
                transport.clear()
                guard transport.send(reportID: Int(RazerPacket.reportID),
                                     RazerPacket.request(sequence: seq, target: target, command: command, parameters: parameters)) else { return nil }
                guard let report = await transport.waitForReport(timeout: .milliseconds(800), where: {
                    RazerPacket.parse($0, sequence: seq, command: command) != nil
                }) else { return nil }
                return RazerPacket.parse(report, sequence: seq, command: command)
            }
            if reply?.status == RazerStatus.busy.rawValue { continue }
            return reply
        }
        return nil
    }

    /// D-63: önce dongle'a "kulaklık bağlı mı" sorulur.
    func isHeadsetLinked() async -> Bool {
        guard let reply = await send(RazerCommand.linkStatus.rawValue, target: .dongle), reply.isOK else { return false }
        return reply.payload.first == 1
    }

    func readBattery() async -> BatteryState? {
        guard await isHeadsetLinked() else { return nil }
        guard let level = await send(RazerCommand.battery.rawValue, target: .headset),
              level.isOK, let percent = level.payload.first else { return nil }
        let charging = await send(RazerCommand.charging.rawValue, target: .headset)
        return BatteryState(percent: min(Int(percent), 100),
                            isCharging: (charging?.isOK ?? false) && (charging?.payload.first ?? 0) > 0)
    }

    func firmware() async -> String? {
        guard let reply = await send(RazerCommand.firmware.rawValue, target: .dongle), reply.isOK, reply.payload.count >= 2 else { return nil }
        return "\(reply.payload[0]).\(reply.payload[1])"
    }

    func isMicMuted() async -> Bool? {
        guard let reply = await send(RazerCommand.micMuted.rawValue, target: .headset), reply.isOK else { return nil }
        return reply.payload.first == 1
    }

    // MARK: - Ayarlar (Faz 3)

    /// Tek byte okuma.
    func readByte(_ command: RazerCommand, target: RazerTarget = .headset) async -> UInt8? {
        guard let reply = await send(command.rawValue, target: target), reply.isOK else { return nil }
        return reply.payload.first
    }

    /// Yazma: kabul edildiyse cevap verisi `00`.
    @discardableResult
    func write(_ command: RazerCommand, _ parameters: [UInt8], target: RazerTarget = .headset) async -> Bool {
        guard let reply = await send(command.write, target: target, parameters: parameters), reply.isOK else { return false }
        return reply.payload.first == 0
    }

    /// 10 bant, dB (okuma işaretli byte).
    func eqBands() async -> [Int]? {
        guard let reply = await send(RazerCommand.eqBands.rawValue, target: .headset), reply.isOK, reply.payload.count == 10 else { return nil }
        return reply.payload.map(RazerPacket.decodeEQ)
    }

    /// D-65/D-67: flash'a yazar; çağıran taraf debounce uygular.
    @discardableResult
    func setEQBands(_ decibels: [Int]) async -> Bool {
        guard decibels.count == 10 else { return false }
        return await write(.eqBands, decibels.map(RazerPacket.encodeEQ))
    }
}

/// Kulaklık EQ hazır ayarları (D-67).
enum RazerEQPreset: UInt8, CaseIterable, Identifiable {
    case flat = 0x00, game = 0x07, music = 0x08, movie = 0x09, custom = 0xFF
    var id: UInt8 { rawValue }
    var title: String {
        switch self {
        case .flat: "Düz"
        case .game: "Oyun"
        case .music: "Müzik"
        case .movie: "Film"
        case .custom: "Özel"
        }
    }
    static let frequencies = ["31", "63", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
}
