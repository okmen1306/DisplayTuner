//
//  OutputSwitcher.swift
//  DisplayTuner
//
//  Görev: Kulaklık bağlanınca ses çıkışı geçişi (CoreAudio).
//  Faz: 2  ·  Kararlar: D-80, D-81  (bkz. AGENT_BRIEF.md)
//

import CoreAudio
import Foundation
import os

/// Kulaklık açılınca varsayılan çıkışı ona alır, kapanınca önceki çıkışa döner (D-80).
@MainActor
final class OutputSwitcher {
    var isEnabled = true
    private var previousOutput: AudioDeviceID?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Audio")

    /// D-81: cihaz adı yerine model UID içindeki VID:PID (1532:0565) ile eşleştirilir.
    private static let headsetIDs = ["1532:0565", "1532:565"]

    /// Geçiş yapıldıysa yeni çıkışın adını döndürür (HUD için).
    func headsetLinkChanged(isLinked: Bool) -> String? {
        guard isEnabled else { return nil }
        if isLinked {
            guard let headset = Self.outputDevices().first(where: { device in
                let uid = Self.string(device, kAudioDevicePropertyModelUID)?.lowercased() ?? ""
                return Self.headsetIDs.contains { uid.contains($0) }
            }) else {
                logger.info("Kulaklığın ses cihazı bulunamadı")
                return nil
            }
            let current = Self.defaultOutput()
            guard current != headset else { return nil }
            previousOutput = current
            return Self.setDefaultOutput(headset) ? Self.string(headset, kAudioObjectPropertyName) : nil
        } else {
            guard let previous = previousOutput, Self.outputDevices().contains(previous) else { return nil }
            previousOutput = nil
            return Self.setDefaultOutput(previous) ? Self.string(previous, kAudioObjectPropertyName) : nil
        }
    }

    // MARK: - CoreAudio

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func outputDevices() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { id in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
            var streamSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr && streamSize > 0
        }
    }

    private static func defaultOutput() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr else { return nil }
        return id
    }

    private static func setDefaultOutput(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = id
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                          UInt32(MemoryLayout<AudioDeviceID>.size), &device) == noErr
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
