//
//  RazerRegisters.swift
//  DisplayTuner
//
//  Görev: Komut ve durum kodları.
//  Faz: 2  ·  Kararlar: 10.6  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum RazerTarget: UInt8, Sendable {
    case dongle = 0x00
    case headset = 0x80
}

/// Okuma komutları; yazma komutu = okuma | 0x80 (EQ eğrisi 0x95 vb.).
enum RazerCommand: UInt8, Sendable {
    case serial = 0x00
    case firmware = 0x02
    case eqPreset = 0x13
    case eqBands = 0x15
    case sidetone = 0x18
    case sidetoneLevel = 0x19
    case audioEnhancement = 0x1D
    case eqEnabled = 0x1E
    case linkStatus = 0x20
    case battery = 0x21
    case doNotDisturb = 0x27
    case charging = 0x2A
    case idleMinutes = 0x2C
    case micMuted = 0x55
    case dongleLED = 0x66

    var write: UInt8 { rawValue | 0x80 }
}

enum RazerStatus: UInt8, Sendable {
    case busy = 0x01
    case ok = 0x02
    case headsetTimedOut = 0x04
    case unsupported = 0x05
    case notOnThisTarget = 0x09
}
