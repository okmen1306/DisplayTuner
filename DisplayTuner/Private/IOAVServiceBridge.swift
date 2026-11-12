//
//  IOAVServiceBridge.swift
//  DisplayTuner
//
//  Görev: IOAVServiceCreateWithService / ReadI2C / WriteI2C.
//  Faz: 1  ·  Kararlar: D-37  (bkz. AGENT_BRIEF.md)
//

import Foundation
import IOKit

/// Apple Silicon'da DDC/CI için private IOAVService köprüsü.
final class IOAVServiceBridge: @unchecked Sendable {
    typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<AnyObject>?
    typealias I2CFn = @convention(c) (AnyObject, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

    static let shared = IOAVServiceBridge()

    private let create: CreateFn?
    private let readI2C: I2CFn?
    private let writeI2C: I2CFn?

    private init() {
        create = PrivateSymbols.function("IOAVServiceCreateWithService", as: CreateFn.self)
        readI2C = PrivateSymbols.function("IOAVServiceReadI2C", as: I2CFn.self)
        writeI2C = PrivateSymbols.function("IOAVServiceWriteI2C", as: I2CFn.self)
    }

    var isAvailable: Bool { create != nil && readI2C != nil && writeI2C != nil }

    /// Harici ekranlara ait AV servisleri (`DCPAVServiceProxy`, Location == External).
    func externalServices() -> [AnyObject] {
        guard let create else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var result: [AnyObject] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let location = IORegistryEntryCreateCFProperty(service, "Location" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            if location == "External", let av = create(kCFAllocatorDefault, service)?.takeRetainedValue() {
                result.append(av)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    func write(_ service: AnyObject, _ bytes: [UInt8]) -> Bool {
        guard let writeI2C else { return false }
        var buffer = bytes
        return writeI2C(service, 0x37, 0x51, &buffer, UInt32(buffer.count)) == kIOReturnSuccess
    }

    func read(_ service: AnyObject, count: Int) -> [UInt8]? {
        guard let readI2C else { return nil }
        var buffer = [UInt8](repeating: 0, count: count)
        guard readI2C(service, 0x37, 0x51, &buffer, UInt32(count)) == kIOReturnSuccess else { return nil }
        return buffer
    }
}
