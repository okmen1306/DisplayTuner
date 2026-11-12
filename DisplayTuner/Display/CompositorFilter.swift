//
//  CompositorFilter.swift
//  DisplayTuner
//
//  Görev: Overlay pencere + CABackdropLayer + CIFilter zinciri (doygunluk, canlılık, ton, sepya).
//  Faz: 5  ·  Kararlar: D-33, D-34, 10.4  (bkz. AGENT_BRIEF.md)
//

import AppKit
import CoreImage
import os

@MainActor
final class CompositorFilter {
    struct Values: Equatable {
        var saturation = 1.0, vibrance = 0.0, hue = 0.0, sepia = 0.0
        var isDefault: Bool { self == Values() }
    }

    private var window: NSWindow?
    private var backdrop: CALayer?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Filter")

    /// D-34: hepsi varsayılandaysa pencere kaldırılır.
    func update(_ values: Values, on displayID: CGDirectDisplayID?) {
        guard !values.isDefault, let displayID,
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
              }) else {
            remove()
            return
        }
        if window == nil || window?.screen != screen { create(on: screen) }
        window?.setFrame(screen.frame, display: true)
        backdrop?.frame = CGRect(origin: .zero, size: screen.frame.size)
        backdrop?.filters = Self.filters(values)
    }

    func remove() {
        window?.orderOut(nil)
        window = nil
        backdrop = nil
    }

    private func create(on screen: NSScreen) {
        remove()
        guard let layer = CABackdropLayerBridge.make(scale: screen.backingScaleFactor) else {
            logger.error("CABackdropLayer yok; filtre kullanılamıyor")
            return
        }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        // 0 alfa olursa WindowServer pencereyi atlar (10.4).
        window.backgroundColor = NSColor(white: 0, alpha: 0.001)
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        layer.frame = view.bounds
        view.layer?.addSublayer(layer)
        window.contentView = view
        window.orderFrontRegardless()
        self.window = window
        self.backdrop = layer
        logger.info("Filtre katmanı oluşturuldu")
    }

    /// 10.4 sırası: renk kontrolleri → canlılık → ton → sepya.
    private static func filters(_ v: Values) -> [CIFilter] {
        var list: [CIFilter] = []
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(v.saturation, forKey: kCIInputSaturationKey)
            f.setValue(1.0, forKey: kCIInputContrastKey)
            f.setValue(0.0, forKey: kCIInputBrightnessKey)
            list.append(f)
        }
        if v.vibrance != 0, let f = CIFilter(name: "CIVibrance") { f.setValue(v.vibrance, forKey: "inputAmount"); list.append(f) }
        if v.hue != 0, let f = CIFilter(name: "CIHueAdjust") { f.setValue(v.hue, forKey: kCIInputAngleKey); list.append(f) }
        if v.sepia != 0, let f = CIFilter(name: "CISepiaTone") { f.setValue(v.sepia, forKey: kCIInputIntensityKey); list.append(f) }
        return list
    }
}
