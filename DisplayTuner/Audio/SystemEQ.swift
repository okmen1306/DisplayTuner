//
//  SystemEQ.swift
//  DisplayTuner
//
//  Görev: Bluetooth kulak içi kulaklıklar için sistem geneli yazılımsal EQ.
//  Kararlar: D-158  (bkz. AGENT_BRIEF.md)
//
//  Sıradan Bluetooth kulaklıklarda donanım EQ'su yok. Bu yüzden:
//  1. Core Audio process tap (macOS 14.2+) bütün uygulamaların sesini yakalar ve orijinal çıkışı susturur
//     (kendi sürecimiz hariç, yoksa kendi çıkışımızı tekrar yakalardık).
//  2. Tap + Bluetooth çıkışı özel bir aggregate cihazda birleşir; IOProc yakalanan sesi 10 bant biquad
//     filtreden geçirip kulaklığa yazar.
//  Varsayılan çıkış Bluetooth olunca ve kullanıcı EQ'yu açtıysa kendiliğinden devreye girer.
//  İlk çalışmada macOS bir kez "Sistem sesi kaydı" izni ister (NSAudioCaptureUsageDescription).
//

import AudioToolbox
import CoreAudio
import Foundation
import os

// MARK: - DSP (gerçek zamanlı iş parçacığında çalışır; bellek ayırmaz)

final class EQProcessor: @unchecked Sendable {
    static let maxChannels = 8
    static let bands = 10
    static let frequencies: [Double] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    /// Bant başına b0 b1 b2 a1 a2 (normalize).
    private let coeffs = UnsafeMutablePointer<Double>.allocate(capacity: bands * 5)
    /// Kanal × bant × (x1 x2 y1 y2)
    private let state = UnsafeMutablePointer<Double>.allocate(capacity: maxChannels * bands * 4)
    private var preamp: Float = 1
    private(set) var sampleRate: Double = 48_000
    var bypass = false

    init() {
        state.initialize(repeating: 0, count: Self.maxChannels * Self.bands * 4)
        coeffs.initialize(repeating: 0, count: Self.bands * 5)
        setGains([Int](repeating: 0, count: Self.bands), sampleRate: 48_000)
    }

    deinit {
        coeffs.deallocate()
        state.deallocate()
    }

    /// RBJ peaking EQ, oktav aralıklı bantlar (Q ≈ 1.41). Kırpmayı önlemek için en yüksek artış kadar ön-kısma.
    func setGains(_ gains: [Int], sampleRate: Double) {
        self.sampleRate = sampleRate
        let q = 1.41
        for i in 0..<Self.bands {
            let g = Double(i < gains.count ? gains[i] : 0)
            let f = min(Self.frequencies[i], sampleRate * 0.45)
            let a = pow(10, g / 40)
            let w = 2 * Double.pi * f / sampleRate
            let alpha = sin(w) / (2 * q)
            let a0 = 1 + alpha / a
            coeffs[i * 5 + 0] = (1 + alpha * a) / a0
            coeffs[i * 5 + 1] = (-2 * cos(w)) / a0
            coeffs[i * 5 + 2] = (1 - alpha * a) / a0
            coeffs[i * 5 + 3] = (-2 * cos(w)) / a0
            coeffs[i * 5 + 4] = (1 - alpha / a) / a0
        }
        let maxBoost = Double(gains.max() ?? 0)
        preamp = Float(pow(10, -max(maxBoost, 0) / 20 * 0.85))
    }

    func reset() { state.update(repeating: 0, count: Self.maxChannels * Self.bands * 4) }

    /// Tek bir kanalın örneklerini işler (stride: araya girmiş kanal sayısı).
    @inline(__always)
    func process(_ input: UnsafePointer<Float>, _ output: UnsafeMutablePointer<Float>, frames: Int, stride: Int, channel: Int) {
        guard !bypass else {
            for n in 0..<frames { output[n * stride] = input[n * stride] }
            return
        }
        let st = state + min(channel, Self.maxChannels - 1) * Self.bands * 4
        for n in 0..<frames {
            var x = Double(input[n * stride] * preamp)
            for b in 0..<Self.bands {
                let c = coeffs + b * 5
                let s = st + b * 4
                let y = c[0] * x + c[1] * s[0] + c[2] * s[1] - c[3] * s[2] - c[4] * s[3]
                s[1] = s[0]; s[0] = x
                s[3] = s[2]; s[2] = y
                x = y
            }
            output[n * stride] = Float(max(-1, min(1, x)))
        }
    }
}

// MARK: - Motor

@MainActor
@Observable
final class SystemEQ {
    struct OutputDevice: Equatable {
        let id: AudioDeviceID
        let uid: String
        let name: String
        let isBluetooth: Bool
    }

    /// Kullanıcı tercihi: Bluetooth çıkışta EQ uygula.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "btEQ.enabled"); reconcile() }
    }
    private(set) var bands: [Int]
    private(set) var output: OutputDevice?
    private(set) var isRunning = false
    private(set) var lastError: String?

    let store = HeadsetEQStore(prefix: "btEQ")
    private let processor = EQProcessor()
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "SystemEQ")
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "com.muhammed.DisplayTuner.systemEQ", qos: .userInteractive)
    private var listenerInstalled = false

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "btEQ.enabled") as? Bool ?? true
        bands = (UserDefaults.standard.array(forKey: "btEQ.bands") as? [Int]) ?? EQPreset.flatBands
    }

    func start() {
        installListener()
        reconcile()
    }

    func setBands(_ new: [Int]) {
        bands = new
        UserDefaults.standard.set(new, forKey: "btEQ.bands")
        processor.setGains(new, sampleRate: processor.sampleRate)
    }

    /// Varsayılan çıkış değişince: Bluetooth + açık → başlat; değilse durdur.
    func reconcile() {
        let current = Self.defaultOutput()
        if current?.uid != output?.uid || !isEnabled || current?.isBluetooth != true { stopEngine() }
        output = current
        guard isEnabled, let current, current.isBluetooth, !isRunning else { return }
        startEngine(for: current)
    }

    // MARK: Başlat / durdur

    private func startEngine(for device: OutputDevice) {
        lastError = nil
        guard #available(macOS 14.2, *) else { lastError = "macOS 14.2+"; return }
        // 1) Tap: bütün sistem sesi, kendi sürecimiz hariç; orijinal çıkış susturulur.
        var excluded: [AudioObjectID] = []
        if let me = Self.processObject(pid: getpid()) { excluded.append(me) }
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.uuid = UUID()
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true
        description.name = "DisplayTuner EQ"
        var tap = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &tap)
        guard status == noErr else { fail("Tap oluşturulamadı (\(status))"); return }
        tapID = tap

        // 2) Aggregate: Bluetooth çıkışı + tap.
        let aggregateUID = "com.muhammed.DisplayTuner.eq.\(UUID().uuidString)"
        let config: [String: Any] = [
            kAudioAggregateDeviceNameKey: "DisplayTuner EQ",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: device.uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: device.uid]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregate)
        guard status == noErr else { fail("Aggregate cihaz oluşturulamadı (\(status))"); return }
        aggregateID = aggregate

        let rate = Self.nominalRate(aggregate) ?? 48_000
        processor.setGains(bands, sampleRate: rate)
        processor.reset()

        // 3) IOProc: giriş (tap) → EQ → çıkış (kulaklık).
        let processor = self.processor
        var proc: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&proc, aggregate, ioQueue) { _, inData, _, outData, _ in
            let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
            let outs = UnsafeMutableAudioBufferListPointer(outData)
            var channelBase = 0
            for (index, outBuffer) in outs.enumerated() {
                guard let outRaw = outBuffer.mData else { continue }
                let outChannels = max(Int(outBuffer.mNumberChannels), 1)
                let outFrames = Int(outBuffer.mDataByteSize) / (MemoryLayout<Float>.size * outChannels)
                let out = outRaw.assumingMemoryBound(to: Float.self)
                guard index < ins.count, let inRaw = ins[index].mData else {
                    out.update(repeating: 0, count: outFrames * outChannels)
                    continue
                }
                let inChannels = max(Int(ins[index].mNumberChannels), 1)
                let inFrames = Int(ins[index].mDataByteSize) / (MemoryLayout<Float>.size * inChannels)
                let frames = min(inFrames, outFrames)
                let input = UnsafePointer(inRaw.assumingMemoryBound(to: Float.self))
                for ch in 0..<outChannels {
                    let srcCh = min(ch, inChannels - 1)
                    processor.process(input + srcCh, out + ch, frames: frames, stride: outChannels == inChannels ? outChannels : 1,
                                      channel: channelBase + ch)
                }
                if frames < outFrames {
                    (out + frames * outChannels).update(repeating: 0, count: (outFrames - frames) * outChannels)
                }
                channelBase += outChannels
            }
        }
        guard status == noErr, let proc else { fail("IOProc oluşturulamadı (\(status))"); return }
        procID = proc
        status = AudioDeviceStart(aggregate, proc)
        guard status == noErr else { fail("Ses başlatılamadı (\(status))"); return }
        isRunning = true
        logger.info("Sistem EQ açık: \(device.name, privacy: .public) @ \(Int(rate)) Hz")
    }

    private func fail(_ message: String) {
        lastError = message
        logger.error("\(message, privacy: .public)")
        stopEngine()
    }

    func stopEngine() {
        if aggregateID != kAudioObjectUnknown, let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        if tapID != kAudioObjectUnknown, #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tapID) }
        tapID = AudioObjectID(kAudioObjectUnknown)
        if isRunning { logger.info("Sistem EQ kapalı") }
        isRunning = false
    }

    // MARK: Core Audio yardımcıları

    private func installListener() {
        guard !listenerInstalled else { return }
        listenerInstalled = true
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                // Çıkış değişince: önce durdur (eski cihaz), kısa gecikmeyle yeniden kur.
                self?.stopEngine()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    self?.reconcile()
                }
            }
        }
    }

    static func defaultOutput() -> OutputDevice? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr, id != 0,
              let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
        let name = string(id, kAudioObjectPropertyName) ?? uid
        var transport: UInt32 = 0
        var tAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                               mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var tSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &tAddr, 0, nil, &tSize, &transport)
        let bt = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        return OutputDevice(id: id, uid: uid, name: name, isBluetooth: bt)
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func nominalRate(_ id: AudioObjectID) -> Double? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &rate) == noErr, rate > 0 else { return nil }
        return rate
    }

    private static func processObject(pid: pid_t) -> AudioObjectID? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var pidValue = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr,
                                                UInt32(MemoryLayout<pid_t>.size), &pidValue, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }
}
