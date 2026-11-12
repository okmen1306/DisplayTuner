//
//  PointerSettings.swift
//  DisplayTuner
//
//  Görev: İmleç hızı ve ivme.
//  Faz: 4  ·  Kararlar: D-52  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Mouse imleç hızı (`HIDMouseAcceleration`, 0…3 × 65536) ve doğrusal (ivmesiz) mod.
/// Değerler sistemde kalıcı değildir; açılışta yeniden uygulanır.
@MainActor
@Observable
final class PointerSettings {
    private let bridge = IOHIDEventSystemBridge.shared
    private let defaults = UserDefaults.standard

    var isAvailable: Bool { bridge.isAvailable }
    /// macOS'un kendi ayarı 3'te biter; HID katmanı daha yüksek değerleri kabul eder (D-138).
    static let maxSpeed = 10.0

    /// 0…3 (macOS Fare ayarındaki ölçek).
    var speed: Double {
        didSet { defaults.set(speed, forKey: "pointerSpeed"); apply() }
    }
    /// Açıkken ivme kapalı (doğrusal hareket; oyun için).
    var linear: Bool {
        didSet { defaults.set(linear, forKey: "pointerLinear"); apply() }
    }

    init() {
        speed = UserDefaults.standard.object(forKey: "pointerSpeed") as? Double
            ?? (IOHIDEventSystemBridge.shared.number("HIDMouseAcceleration").map { $0 / 65536 } ?? 0.6875)
        linear = UserDefaults.standard.bool(forKey: "pointerLinear")
    }

    func apply() {
        bridge.set("HIDMouseAcceleration", NSNumber(value: Int(min(max(speed, 0), Self.maxSpeed) * 65536)))
        bridge.set("HIDUseLinearScalingMouseAcceleration", NSNumber(value: linear ? 1 : 0))
    }
}
