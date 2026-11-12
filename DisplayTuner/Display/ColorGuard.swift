//
//  ColorGuard.swift
//  DisplayTuner
//
//  Görev: Sıfırlanan gamma ve bağlantı modunu yeniden uygulama.
//  Faz: 5  ·  Kararlar: D-36  (bkz. AGENT_BRIEF.md)
//

import AppKit
import CoreGraphics
import os

/// macOS'un sıfırladığı ayarları geri getirir: uyanma, ekran yeniden yapılandırma, kilit açma + 10 sn kontrol (D-36).
@MainActor
final class ColorGuard {
    private let store: ProfileStore
    private var timer: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "ColorGuard")

    init(store: ProfileStore) {
        self.store = store
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule(reason: "uyanma") }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule(reason: "kilit açıldı") }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule(reason: "ekran değişti") }
        }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.checkDrift()
            }
        }
    }

    /// Olaylar art arda gelir; 2 sn bekleyip bir kez uygula.
    private func schedule(reason: String, includeDDC: Bool = true) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let profile = self.store.active else { return }
            self.logger.info("Yeniden uygulanıyor (\(reason, privacy: .public))")
            await self.store.apply(profile, includeDDC: includeDDC)
        }
    }

    private func checkDrift() {
        guard store.isColorManagementEnabled, let profile = store.active, let id = ProfileStore.monitorDisplayID else { return }
        let expected = profile.lut(size: GammaEngine.capacity(of: id))
        let mode = ConnectionModeService.current
        let deviation = GammaEngine.read(id).map {
            LUTMath.maxDeviation(LUTMath.clamped($0), LUTMath.clamped(expected))
        } ?? .infinity
        let hz = CGDisplayCopyDisplayMode(id).map { Int($0.refreshRate.rounded()) } ?? 0
        logger.debug("Kontrol: mod=\(mode?.colorMode ?? "?", privacy: .public) hz=\(hz) sapma=\(deviation)")
        // Hz kullanıcının elle seçimidir; burada zorlanmaz (D-126). Mod bilgisi bayat olabilir (D-127),
        // bu yüzden periyodik kontrol sadece gamma sapmasına bakar; mod olaylarda koşulsuz uygulanır.
        _ = (mode, hz)
        if deviation > 0.002 {
            schedule(reason: "gamma sapması \(deviation)", includeDDC: false)
        }
    }
}
