//
//  DockWatcher.swift
//  DisplayTuner
//
//  Görev: IOServiceAddMatchingNotification ile DL-Dock algılama.
//  Faz: 1  ·  Kararlar: D-90  (bkz. AGENT_BRIEF.md)
//

import Foundation
import IOKit
import IOKit.usb
import os

/// Dock'u USB ürün adı "DL-Dock" (DisplayLink 17E9:6000) ile algılar. Polling yok (D-90).
@MainActor
@Observable
final class DockWatcher {
    private(set) var isDocked = false
    /// Dock durumu değişince çağrılır (Faz 6'da AutomationEngine bağlanacak).
    var onChange: ((Bool) -> Void)?

    private static let productName = "DL-Dock"
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Dock")
    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var count = 0

    func start() {
        guard port == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, Self.matching(), { context, iterator in
            guard let context else { return }
            let watcher = Unmanaged<DockWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.drain(iterator, added: true) }
        }, context, &addedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, Self.matching(), { context, iterator in
            guard let context else { return }
            let watcher = Unmanaged<DockWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.drain(iterator, added: false) }
        }, context, &removedIterator)

        // Iterator'ları boşaltmak bildirimleri "kurar" ve mevcut durumu verir.
        drain(addedIterator, added: true)
        drain(removedIterator, added: false)
    }

    private func drain(_ iterator: io_iterator_t, added: Bool) {
        var changed = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            changed += 1
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        guard changed > 0 else { return }
        count = max(0, count + (added ? changed : -changed))
        let docked = count > 0
        guard docked != isDocked else { return }
        isDocked = docked
        logger.info("Dock \(docked ? "takıldı" : "çıkarıldı", privacy: .public)")
        onChange?(docked)
    }

    private static func matching() -> CFDictionary {
        let dict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        dict["IOPropertyMatch"] = ["USB Product Name": productName]
        return dict
    }
}
