//
//  RazerPacketTests.swift
//  DisplayTunerTests
//
//  Kapsam: Razer istek kodlama, XOR, cevap eşleme (seq/hedef/komut).  (bkz. AGENT_BRIEF.md §13)
//

import Testing
@testable import DisplayTuner

struct RazerPacketTests {
    @Test func requestLayout() {
        let p = RazerPacket.request(sequence: 1, target: .dongle, command: 0x20)
        #expect(p.count == 64)
        #expect(p[0] == 0x02)
        #expect(p[2] == 0x61)
        #expect(p[6] == 4)
        #expect(p[9] == 0x00)
        #expect(p[10] == 0x20)
        #expect(p[12] == 0)
        #expect(p[62] == p[0..<62].reduce(0, ^))
    }

    @Test func requestWithParameters() {
        let p = RazerPacket.request(sequence: 3, target: .headset, command: 0x99, parameters: [7])
        #expect(p[6] == 5)
        #expect(p[9] == 0x80)
        #expect(p[12] == 1)
        #expect(p[13] == 7)
    }

    /// Mac'te alınmış gerçek firmware cevabı (1.7).
    @Test func parseRealFirmwareReply() {
        var report = [UInt8](repeating: 0, count: 64)
        let head: [UInt8] = [0x02, 0x02, 0x64, 0, 0, 0, 0x08, 0, 0x80, 0x00, 0x02, 0x01, 0x04, 0x01, 0x07, 0, 0]
        report.replaceSubrange(0..<head.count, with: head)
        let reply = RazerPacket.parse(report, sequence: 4, command: 0x02)
        #expect(reply?.isOK == true)
        #expect(reply?.payload == [0x01, 0x07, 0x00, 0x00])
        #expect(RazerPacket.parse(report, sequence: 5, command: 0x02) == nil)
        #expect(RazerPacket.parse(report, sequence: 4, command: 0x21) == nil)
    }
}
