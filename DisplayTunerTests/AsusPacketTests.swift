//
//  AsusPacketTests.swift
//  DisplayTunerTests
//
//  Kapsam: ASUS 12 07 / 12 03 cevap çözme, FF AA hatası.  (bkz. AGENT_BRIEF.md §13)
//

import Testing
@testable import DisplayTuner

struct AsusPacketTests {
    private func reply(_ head: [UInt8]) -> [UInt8] {
        head + [UInt8](repeating: 0, count: 64 - head.count)
    }

    /// Mac'te alınmış gerçek cevap: pil %75, şarj yok.
    @Test func parseStatus() {
        let status = AsusPacket.parseStatus(reply([0x12, 0x07, 0x00, 0x00, 0x03, 0x02, 0x00, 0x01]))
        #expect(status == AsusPacket.Status(batteryPercent: 75, isCharging: false))
    }

    /// Mac'te alınmış gerçek cevap: sabit, parlaklık 2, #FF00FD.
    @Test func parseLighting() {
        let lighting = AsusPacket.parseLighting(reply([0x12, 0x03, 0x00, 0x00, 0x00, 0x02, 0xFF, 0x00, 0xFD]))
        #expect(lighting == AsusPacket.Lighting(mode: 0, brightness: 2, red: 0xFF, green: 0x00, blue: 0xFD))
    }

    @Test func errorReply() {
        #expect(AsusPacket.isError(reply([0xFF, 0xAA])))
        #expect(AsusPacket.parseStatus(reply([0xFF, 0xAA])) == nil)
    }
}
