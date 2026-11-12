//
//  BatteryMonitor.swift
//  DisplayTuner
//
//  Görev: Sorgu zamanlaması (60/30 sn).
//  Faz: 2  ·  Kararlar: D-62  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os

@MainActor
@Observable
final class BatteryMonitor {
    private(set) var states: [DeviceKind: BatteryState] = [:]
    /// Eşik tetiklenince (Notifier bağlanır).
    var onThreshold: ((DeviceKind, String, Int, ThresholdTracker.Threshold) -> Void)?
    /// Şarj tamamlanınca (D-74).
    var onFullyCharged: ((DeviceKind, String) -> Void)?
    /// Cihaz cevap vermeye başlayınca/kesince (kulaklık aç/kapa → ses çıkışı, D-80).
    var onPresenceChange: ((DeviceKind, Bool) -> Void)?

    private let registry: DeviceRegistry
    private var trackers: [DeviceKind: ThresholdTracker] = [
        .headset: ThresholdTracker(thresholds: ThresholdTracker.saved(for: .headset)),
        .mouse: ThresholdTracker(thresholds: ThresholdTracker.saved(for: .mouse)),
    ]

    /// Bildirimler sekmesinde eşik değişince (D-148).
    func reloadThresholds() {
        for kind in [DeviceKind.headset, .mouse] {
            trackers[kind] = ThresholdTracker(thresholds: ThresholdTracker.saved(for: kind))
        }
    }
    private var loop: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Battery")

    init(registry: DeviceRegistry) {
        self.registry = registry
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: self.interval)
            }
        }
    }

    /// D-62: 60 sn; kulaklık %10 altındaysa 30 sn.
    private var interval: Duration {
        if let headset = states[.headset], headset.percent < 10, !headset.isCharging { return .seconds(30) }
        return .seconds(60)
    }

    func refresh() async {
        registry.rescan()
        logger.info("Pil cihazları: \(self.registry.batteryDevices.map(\.displayName).joined(separator: ", "), privacy: .public)")
        for device in registry.batteryDevices {
            let kind = device.kind
            if let state = await device.readBattery() {
                if states[kind] == nil { onPresenceChange?(kind, true) }
                handle(state, kind: kind, name: device.displayName)
            } else if kind == .headset, states[kind] != nil {
                // D-63: kulaklık kapalı → "Kapalı" (durum kaldırılır).
                states[kind] = nil
                onPresenceChange?(kind, false)
            } else if var last = states[kind] {
                logger.info("\(device.displayName, privacy: .public): cevap yok")
                last.isStale = true          // D-64
                states[kind] = last
            }
        }
        // Çıkarılan cihazların durumunu temizle.
        let present = Set(registry.batteryDevices.map(\.kind))
        states = states.filter { present.contains($0.key) }
    }

    private func handle(_ state: BatteryState, kind: DeviceKind, name: String) {
        let previous = states[kind]
        states[kind] = state
        logger.info("\(name, privacy: .public): %\(state.percent) şarj=\(state.isCharging)")

        if let previous, previous.isCharging, state.percent >= 100 && previous.percent < 100 {
            onFullyCharged?(kind, name)
        }
        if let threshold = trackers[kind]?.update(percent: state.percent, isCharging: state.isCharging) {
            onThreshold?(kind, name, state.percent, threshold)
        }
    }
}
