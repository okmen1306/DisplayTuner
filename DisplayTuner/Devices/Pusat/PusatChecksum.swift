//
//  PusatChecksum.swift
//  DisplayTuner
//
//  Görev: 16 bit toplam checksum.
//  Faz: 2  ·  Kararlar: 10.8  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum PusatChecksum {
    /// Byte 1 (düşük) ve 2 (yüksek) = byte 3…63 toplamı, 16 bit little endian.
    static func apply(to packet: inout [UInt8]) {
        let sum = packet.dropFirst(3).reduce(UInt16(0)) { $0 &+ UInt16($1) }
        packet[1] = UInt8(sum & 0xFF)
        packet[2] = UInt8(sum >> 8)
    }
}
