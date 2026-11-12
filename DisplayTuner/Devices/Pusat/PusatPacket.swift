//
//  PusatPacket.swift
//  DisplayTuner
//
//  Görev: Paket yapısı, başlat/bitir.
//  Faz: 2  ·  Kararlar: 10.8  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// PUSAT K3 Pro (Redragon K556 protokolü). Report ID 4, 64 byte.
enum PusatPacket {
    static let reportID: UInt8 = 0x04
    static let size = 64

    /// Profil 1/2/3 için LED ayar bloklarının offset'i.
    static let ledOffsets: [UInt8] = [0x00, 0x2A, 0x54]

    struct LED: Sendable, Equatable {
        let mode: UInt8
        let brightness: Int
        let speed: Int
        let directionLeft: Bool
        let rainbow: Bool
        let red: UInt8, green: UInt8, blue: UInt8
    }

    /// `04 <chk lo> <chk hi> <b3> <b4> <b5> 00…`
    static func make(_ b3: UInt8, _ b4: UInt8, _ b5: UInt8, data: [UInt8: UInt8] = [:]) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: size)
        packet[0] = reportID
        packet[3] = b3; packet[4] = b4; packet[5] = b5
        for (index, value) in data { packet[Int(index)] = value }
        PusatChecksum.apply(to: &packet)
        return packet
    }

    static var readActiveProfile: [UInt8] { make(0x03, 0x2C, 0x00) }
    static func readLED(profile: Int) -> [UInt8] { make(0x05, 0x38, ledOffsets[profile - 1]) }

    /// Cevap `[18]` = profil − 1.
    static func parseActiveProfile(_ reply: [UInt8]) -> Int? {
        guard reply.count > 18, reply[0] == reportID, reply[3] == 0x03, reply[4] == 0x2C else { return nil }
        let profile = Int(reply[18]) + 1
        return (1...3).contains(profile) ? profile : nil
    }

    /// `[8]` mod, `[9]` parlaklık, `[10]` 3−hız, `[11]` yön, `[12]` gökkuşağı, `[13..15]` RGB.
    static func parseLED(_ reply: [UInt8]) -> LED? {
        guard reply.count > 15, reply[0] == reportID, reply[3] == 0x05, reply[4] == 0x38 else { return nil }
        return LED(mode: reply[8], brightness: Int(reply[9]), speed: 3 - Int(min(reply[10], 3)),
                   directionLeft: reply[11] == 0xFF, rainbow: reply[12] == 1,
                   red: reply[13], green: reply[14], blue: reply[15])
    }
}
