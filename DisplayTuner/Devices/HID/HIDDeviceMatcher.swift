//
//  HIDDeviceMatcher.swift
//  DisplayTuner
//
//  Görev: VID/PID + usage page eşleme.
//  Faz: 2  ·  Kararlar: D-61  (bkz. AGENT_BRIEF.md)
//

import Foundation
import IOKit.hid

enum HIDDeviceMatcher {
    /// Belirtilen VID/PID'e ait, primary usage page'i eşleşen (veya 64 B output report'u olan) ilk HID arayüzü.
    static func find(vendorID: Int, productID: Int, usagePage: Int? = nil, outputReportSize: Int? = nil) -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID] as CFDictionary)
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.first { device in
            if let usagePage, intProperty(device, kIOHIDPrimaryUsagePageKey) != usagePage { return false }
            if let outputReportSize, intProperty(device, kIOHIDMaxOutputReportSizeKey) != outputReportSize { return false }
            return true
        }
    }

    static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }
}
