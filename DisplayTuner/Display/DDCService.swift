//
//  DDCService.swift
//  DisplayTuner
//
//  Görev: VCP okuma/yazma, 50 ms bekleme, 3 deneme.
//  Faz: 1  ·  Kararlar: D-37, 10.1  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os

/// DDC/CI üzerinden harici monitörle konuşur. Tek harici monitör varsayılır (D-11).
actor DDCService {
    static let shared = DDCService()

    /// Kullanılan VCP kodları (10.1).
    enum VCP: UInt8, Sendable {
        case brightness = 0x10
        case contrast = 0x12
        case colorPreset = 0x14
        case redGain = 0x16
        case greenGain = 0x18
        case blueGain = 0x1A
        case inputSource = 0x60
        case volume = 0x62
        case blackLevelRed = 0x6C
        case pictureMode = 0xDC
    }

    struct Value: Sendable, Equatable {
        let current: Int
        let maximum: Int
        var fraction: Double { maximum > 0 ? Double(current) / Double(maximum) : 0 }
    }

    private let bridge = IOAVServiceBridge.shared
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "DDC")
    private var service: AnyObject?

    private static let hostAddress: UInt8 = 0x51
    private static let displayAddress: UInt8 = 0x6E
    private static let replyDelay: useconds_t = 50_000   // D-37
    private static let attempts = 3                      // D-37

    /// Servisi yeniden bulur (dock takılınca/çıkınca çağrılır).
    func refresh() {
        service = bridge.externalServices().first
        logger.info("DDC servisi \(self.service == nil ? "bulunamadı" : "bulundu", privacy: .public)")
    }

    var hasExternalDisplay: Bool {
        if service == nil { refresh() }
        return service != nil
    }

    /// Get VCP: `82 01 <vcp> <chk>`; cevap `[2]=02 [3]=sonuç [4]=vcp [6..7]=max [8..9]=mevcut`.
    func read(_ vcp: VCP) -> Value? {
        if service == nil { refresh() }
        guard let service else { return nil }

        let request = Self.packet([0x82, 0x01, vcp.rawValue])
        for attempt in 1...Self.attempts {
            guard bridge.write(service, request) else { continue }
            usleep(Self.replyDelay)
            if let reply = bridge.read(service, count: 12), reply[2] == 0x02, reply[4] == vcp.rawValue {
                guard reply[3] == 0 else { return nil } // desteklenmiyor
                return Value(current: Int(reply[8]) << 8 | Int(reply[9]),
                             maximum: Int(reply[6]) << 8 | Int(reply[7]))
            }
            logger.debug("VCP \(vcp.rawValue) okuma denemesi \(attempt) başarısız")
            usleep(Self.replyDelay)
        }
        return nil
    }

    /// Set VCP: `84 03 <vcp> <hi> <lo> <chk>`.
    @discardableResult
    func write(_ vcp: VCP, value: Int) -> Bool {
        if service == nil { refresh() }
        guard let service else { return false }
        let clamped = UInt16(clamping: max(0, value))
        let request = Self.packet([0x84, 0x03, vcp.rawValue, UInt8(clamped >> 8), UInt8(clamped & 0xFF)])
        let ok = bridge.write(service, request)
        usleep(Self.replyDelay)
        if !ok { logger.error("VCP \(vcp.rawValue) yazılamadı") }
        return ok
    }

    /// Checksum: `0x6E ^ 0x51 ^ (tüm byte'ların XOR'u)`.
    nonisolated static func packet(_ body: [UInt8]) -> [UInt8] {
        body + [checksum(body)]
    }

    nonisolated static func checksum(_ body: [UInt8]) -> UInt8 {
        body.reduce(displayAddress ^ hostAddress) { $0 ^ $1 }
    }
}
