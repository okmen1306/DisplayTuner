//
//  PusatChecksumTests.swift
//  DisplayTunerTests
//
//  Kapsam: 04 2f 00 03 2c ve 04 09 01 06 01 03 … ff örnekleri.  (bkz. AGENT_BRIEF.md §13)
//

import Testing
@testable import DisplayTuner

struct PusatChecksumTests {
    @Test func readActiveProfilePacket() {
        let p = PusatPacket.readActiveProfile
        #expect(Array(p.prefix(5)) == [0x04, 0x2F, 0x00, 0x03, 0x2C])
    }

    @Test func directionLeftPacket() {
        let p = PusatPacket.make(0x06, 0x01, 0x03, data: [8: 0xFF])
        #expect(p[1] == 0x09)
        #expect(p[2] == 0x01)
    }

    @Test func readLEDPackets() {
        #expect(PusatPacket.readLED(profile: 1)[1] == 0x3D)
        #expect(PusatPacket.readLED(profile: 2)[1] == 0x67)
        #expect(PusatPacket.readLED(profile: 3)[1] == 0x91)
    }

    /// Mac'te alınmış gerçek cevap: profil 1 yatay dalga, parlaklık 5, hız 2, sağa, gökkuşağı.
    @Test func parseLED() {
        var r = [UInt8](repeating: 0, count: 64)
        let head: [UInt8] = [0x04, 0x3D, 0x00, 0x05, 0x38, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x00, 0x01, 0xFF, 0xFF, 0xFF]
        r.replaceSubrange(0..<head.count, with: head)
        let led = PusatPacket.parseLED(r)
        #expect(led?.mode == 0x01)
        #expect(led?.brightness == 5)
        #expect(led?.speed == 2)
        #expect(led?.directionLeft == false)
        #expect(led?.rainbow == true)
    }
}
