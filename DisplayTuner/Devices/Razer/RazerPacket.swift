//
//  RazerPacket.swift
//  DisplayTuner
//
//  Görev: İstek kodlama (XOR) ve cevap eşleme.
//  Faz: 2  ·  Kararlar: 10.6  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// BlackShark V2 HyperSpeed (MediaTek) çerçevesi. Rapor ID 2, 64 byte.
enum RazerPacket {
    static let reportID: UInt8 = 0x02
    static let size = 64

    struct Reply: Sendable, Equatable {
        let status: UInt8
        let target: UInt8
        let command: UInt8
        let payload: [UInt8]
        var isOK: Bool { status == RazerStatus.ok.rawValue }
    }

    /// `[0]=02 [2]=0x60|seq [6]=4+n [9]=hedef [10]=komut [12]=n [13…]=parametre [62]=XOR(0…61)`.
    static func request(sequence: UInt8, target: RazerTarget, command: UInt8, parameters: [UInt8] = []) -> [UInt8] {
        precondition(parameters.count <= 48)
        var report = [UInt8](repeating: 0, count: size)
        report[0] = reportID
        report[2] = 0x60 | (sequence & 0x1F)
        report[6] = UInt8(4 + parameters.count)
        report[9] = target.rawValue
        report[10] = command
        report[12] = UInt8(parameters.count)
        report.replaceSubrange(13..<(13 + parameters.count), with: parameters)
        report[62] = report[0..<62].reduce(0, ^)
        return report
    }

    /// Cevap `[1]=durum [2]=seq [8]=0x80 [9]=hedef [10]=komut [12]=n [13…]=veri`.
    static func parse(_ report: [UInt8], sequence: UInt8, command: UInt8) -> Reply? {
        guard report.count >= 14, report[0] == reportID, report[8] == 0x80,
              report[10] == command, report[2] & 0x1F == sequence & 0x1F else { return nil }
        let count = min(Int(report[12]), report.count - 13)
        return Reply(status: report[1], target: report[9], command: report[10],
                     payload: Array(report[13..<(13 + count)]))
    }

    /// Kulaklığın sakladığı EQ değeri: yazarken `dB + 5` (D-67).
    static func encodeEQ(_ decibels: Int) -> UInt8 {
        UInt8(bitPattern: Int8(min(max(decibels, -9), 6) + 5))   // -9 → 0xFC (iki tümleyen)
    }

    /// Okumada değer dB olarak, işaretli byte.
    static func decodeEQ(_ byte: UInt8) -> Int {
        Int(Int8(bitPattern: byte))
    }
}
