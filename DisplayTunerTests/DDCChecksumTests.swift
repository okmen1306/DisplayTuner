//
//  DDCChecksumTests.swift
//  DisplayTunerTests
//
//  Kapsam: Get/Set VCP checksum.  (bkz. AGENT_BRIEF.md §13)
//

import Testing
@testable import DisplayTuner

struct DDCChecksumTests {
    @Test func getVCPBrightness() {
        #expect(DDCService.packet([0x82, 0x01, 0x10]) == [0x82, 0x01, 0x10, 0xAC])
    }

    @Test func setVCPChecksum() {
        let body: [UInt8] = [0x84, 0x03, 0x10, 0x00, 0x32]
        #expect(DDCService.checksum(body) == body.reduce(0x6E ^ 0x51, ^))
    }
}
