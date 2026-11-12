//
//  ScrollReverser.swift
//  DisplayTuner
//
//  Görev: CGEventTap; sadece tekerlek olaylarını ters çevirir.
//  Faz: 4  ·  Kararlar: D-50, D-51  (bkz. AGENT_BRIEF.md)
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os

/// Kesintili (tekerlek) scroll olaylarını ters çevirir; trackpad (continuous) olaylarına dokunmaz (D-50).
/// Erişilebilirlik izni gerekir. LinearMouse açıkken açılmamalı (çift ters çevirme).
@MainActor
@Observable
final class ScrollReverser {
    private(set) var isRunning = false
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "scrollReverseEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "scrollReverseEnabled")
            if newValue {
                NSRunningApplication.runningApplications(withBundleIdentifier: Self.linearMouseID).forEach { $0.terminate() }
                start()
            } else {
                stop()
            }
        }
    }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Scroll")

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        // kAXTrustedCheckOptionPrompt'un değeri; global değişkene erişim Swift 6'da güvensiz sayılıyor.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static let linearMouseID = "com.lujjjh.LinearMouse"
    private var watchdog: Task<Void, Never>?

    /// Açıkken: LinearMouse'u kapatır (çift ters çevirmeyi önler) ve izin gelir gelmez dinleyiciyi başlatır.
    /// Bekçi 3 sn'de bir kontrol eder; LinearMouse girişte yeniden açılsa da kapatılır (D-136).
    func startIfEnabled() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isEnabled {
                    NSRunningApplication.runningApplications(withBundleIdentifier: Self.linearMouseID).forEach { $0.terminate() }
                    if !self.isRunning && Self.hasAccessibility { self.start() }
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func start() {
        guard tap == nil else { return }
        guard Self.hasAccessibility else {
            Self.requestAccessibility()
            logger.info("Erişilebilirlik izni yok")
            return
        }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let refcon {
                let reverser = Unmanaged<ScrollReverser>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { reverser.reenable() }
                return Unmanaged.passUnretained(event)
            }
            // Trackpad / Magic Mouse: continuous = 1 → dokunma.
            guard type == .scrollWheel, event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else {
                return Unmanaged.passUnretained(event)
            }
            // D-140: Önce hepsini oku, sonra yaz. DeltaAxis yazılınca CG piksel/fixed değerleri yeniden hesaplıyor;
            // tek tek okuyup yazmak onları iki kez çevirip eski haline döndürüyordu (uygulamalar piksel değerini kullanır).
            let d1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let d2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let p1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let p2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
            let f1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let f2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -d1)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -d2)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -f1)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -f2)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -p1)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -p2)
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            logger.error("Event tap oluşturulamadı")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        isRunning = true
        logger.info("Scroll ters çevirme açık")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isRunning = false
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}
