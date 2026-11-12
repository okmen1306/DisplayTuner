//
//  AsusPacket.swift
//  DisplayTuner
//
//  Görev: Paketler ve cevap çözme.
//  Faz: 2  ·  Kararlar: 10.7  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// ROG Gladius II Wireless. Report ID yok (0), 64 byte. Cevap ilk iki byte'ta komutu tekrarlar.
enum AsusPacket {
    static let size = 64

    struct Status: Sendable, Equatable {
        let batteryPercent: Int
        let isCharging: Bool
    }

    struct Lighting: Sendable, Equatable {
        let mode: UInt8
        let brightness: Int
        let red: UInt8, green: UInt8, blue: UInt8
    }

    static func request(_ bytes: [UInt8]) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: size)
        packet.replaceSubrange(0..<bytes.count, with: bytes)
        return packet
    }

    static let readStatus: [UInt8] = [0x12, 0x07]
    static func readLighting(zone: UInt8) -> [UInt8] { [0x12, 0x03, zone] }

    static func isError(_ reply: [UInt8]) -> Bool {
        reply.count >= 2 && reply[0] == 0xFF && reply[1] == 0xAA
    }

    /// `12 07` cevabı: `[4]` pil adımı (×25), `[9]` şarj.
    static func parseStatus(_ reply: [UInt8]) -> Status? {
        guard reply.count > 9, reply[0] == 0x12, reply[1] == 0x07 else { return nil }
        return Status(batteryPercent: min(Int(reply[4]) * 25, 100), isCharging: reply[9] > 0)
    }

    /// `12 03` cevabı: `[4]` mod, `[5]` parlaklık, `[6..8]` RGB.
    static func parseLighting(_ reply: [UInt8]) -> Lighting? {
        guard reply.count > 8, reply[0] == 0x12, reply[1] == 0x03 else { return nil }
        return Lighting(mode: reply[4], brightness: Int(reply[5]), red: reply[6], green: reply[7], blue: reply[8])
    }
}
