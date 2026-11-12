//
//  LUTMathTests.swift
//  DisplayTunerTests
//
//  Kapsam: Kimlik, kontrast (baseline ile <0.001), kuantizasyon.  (bkz. AGENT_BRIEF.md §13)
//

import Foundation
import Testing
@testable import DisplayTuner

struct LUTMathTests {
    @Test func identity() {
        let t = LUTMath.table(.identity, size: 1024)
        #expect(t.red.first == 0)
        #expect(abs(t.red.last! - 1) < 1e-6)
        #expect(abs(t.green[512] - Float(512.0 / 1023.0)) < 1e-6)
    }

    @Test func contrastEndpoints() {
        var a = ColorAdjustments.identity
        a.contrast = 0.15708
        let t = LUTMath.table(a, size: 1024)
        #expect(abs(t.red[0] - (-0.07854)) < 1e-4)          // clamp yok (D-35)
        #expect(abs(t.red[1023] - 1.07854) < 1e-4)
    }

    /// Kayıtlı ayardaki 1024 değerlik tablo, formülle < 0.001 sapmayla üretilebiliyor.
    @Test func baselineMatchesFormula() throws {
        let profile = try #require(BaselineImporter.load())
        let saved = profile.lut(size: 1024)
        let computed = LUTMath.table(profile.adjustments, size: 1024)
        #expect(LUTMath.maxDeviation(saved, computed) < 0.001)
        #expect(profile.colorMode == "RGBFullRange")
        #expect(profile.ddc[DDCService.VCP.redGain.rawValue] == 50)
        #expect(profile.resolution?.width == 2048)
    }

    @Test func quantizationOffIsIdentity() {
        #expect(LUTMath.quantize(0.37, 1) == 0.37)
        #expect(LUTMath.quantize(0.6, 0) == 1)               // 2 seviye
    }

    @Test func temperatureWarm() {
        var a = ColorAdjustments.identity
        a.temperature = 1                                     // sıcak: R=1, G=0.5, B=0
        let t = LUTMath.table(a, size: 256)
        #expect(abs(t.red.last! - 1) < 1e-6)
        #expect(abs(t.green.last! - 0.5) < 1e-6)
        #expect(abs(t.blue.last!) < 1e-6)
    }
}
