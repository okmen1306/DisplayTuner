//
//  HIDTransport.swift
//  DisplayTuner
//
//  Görev: IOHIDDevice sarmalayıcı: aç, rapor gönder, input callback, timeout.
//  Faz: 2  ·  Kararlar: D-61  (bkz. AGENT_BRIEF.md)
//

import Foundation
import IOKit.hid
import os

/// Bir HID arayüzüyle istek/cevap haberleşmesi. Gelen input report'lar (report ID dahil) tampona alınır.
final class HIDTransport: @unchecked Sendable {
    private let device: IOHIDDevice
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var reports: [[UInt8]] = []
    private let buffer: UnsafeMutablePointer<UInt8>
    private let bufferSize = 256
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "HID")
    private var isActive = false

    init?(device: IOHIDDevice, label: String) {
        self.device = device
        self.queue = DispatchQueue(label: "com.muhammed.DisplayTuner.hid.\(label)")
        self.buffer = .allocate(capacity: bufferSize)

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            // Klavye arayüzleri Giriş İzleme izni ister (kIOReturnNotPermitted).
            logger.error("\(label, privacy: .public) açılamadı: \(openResult)")
            return nil
        }
        isActive = true
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, bufferSize, { context, _, _, _, _, report, length in
            guard let context else { return }
            let transport = Unmanaged<HIDTransport>.fromOpaque(context).takeUnretainedValue()
            transport.append(Array(UnsafeBufferPointer(start: report, count: length)))
        }, context)
        IOHIDDeviceSetDispatchQueue(device, queue)
        IOHIDDeviceSetCancelHandler(device) { }
        IOHIDDeviceActivate(device)
    }

    deinit {
        if isActive {
            IOHIDDeviceCancel(device)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        buffer.deallocate()
    }

    private func append(_ report: [UInt8]) {
        lock.withLock {
            reports.append(report)
            if reports.count > 32 { reports.removeFirst(reports.count - 32) }
        }
    }

    func clear() {
        lock.withLock { reports.removeAll() }
    }

    /// Output report gönderir. `bytes` numaralı raporlarda report ID ile başlar.
    func send(reportID: Int, _ bytes: [UInt8]) -> Bool {
        var data = bytes
        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(reportID), &data, data.count)
        if result != kIOReturnSuccess { logger.error("SetReport başarısız: \(result)") }
        return result == kIOReturnSuccess
    }

    /// `matches` koşulunu sağlayan ilk raporu bekler.
    func waitForReport(timeout: Duration, where matches: ([UInt8]) -> Bool) async -> [UInt8]? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let found: [UInt8]? = lock.withLock {
                guard let index = reports.firstIndex(where: matches) else { return nil }
                return reports.remove(at: index)
            }
            if let found { return found }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }
}
