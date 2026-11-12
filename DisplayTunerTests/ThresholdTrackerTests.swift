//
//  ThresholdTrackerTests.swift
//  DisplayTunerTests
//
//  Kapsam: Eşik bir kez, şarjda sıfırlama, +5 histerezis.  (bkz. AGENT_BRIEF.md §13)
//

import Testing
@testable import DisplayTuner

struct ThresholdTrackerTests {
    @Test func headsetSequence() {
        var t = ThresholdTracker(thresholds: ThresholdTracker.headset)
        #expect(t.update(percent: 25, isCharging: false) == nil)
        #expect(t.update(percent: 19, isCharging: false)?.percent == 20)
        #expect(t.update(percent: 18, isCharging: false) == nil)      // bir kez
        #expect(t.update(percent: 8, isCharging: false)?.percent == 10)
        let critical = t.update(percent: 4, isCharging: false)
        #expect(critical?.percent == 5)
        #expect(critical?.isCritical == true)
        #expect(t.update(percent: 2, isCharging: false)?.percent == 3)
    }

    @Test func onlyLowestWhenSkipping() {
        var t = ThresholdTracker(thresholds: ThresholdTracker.headset)
        #expect(t.update(percent: 8, isCharging: false)?.percent == 10)
        #expect(t.update(percent: 7, isCharging: false) == nil)       // 20 de işaretlendi
    }

    @Test func resetOnCharging() {
        var t = ThresholdTracker(thresholds: ThresholdTracker.headset)
        _ = t.update(percent: 19, isCharging: false)
        _ = t.update(percent: 19, isCharging: true)
        #expect(t.update(percent: 19, isCharging: false)?.percent == 20)
    }

    @Test func hysteresis() {
        var t = ThresholdTracker(thresholds: ThresholdTracker.headset)
        _ = t.update(percent: 19, isCharging: false)
        _ = t.update(percent: 23, isCharging: false)                  // 25'in altı: sıfırlanmaz
        #expect(t.update(percent: 19, isCharging: false) == nil)
        _ = t.update(percent: 26, isCharging: false)                  // +5: sıfırlanır
        #expect(t.update(percent: 19, isCharging: false)?.percent == 20)
    }

    @Test func mouseSteps() {
        var t = ThresholdTracker(thresholds: ThresholdTracker.mouse)
        #expect(t.update(percent: 50, isCharging: false) == nil)
        #expect(t.update(percent: 25, isCharging: false)?.percent == 25)
        #expect(t.update(percent: 0, isCharging: false)?.isCritical == true)
    }
}
