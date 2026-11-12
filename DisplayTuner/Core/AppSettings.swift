//
//  AppSettings.swift
//  DisplayTuner
//
//  Görev: Kullanıcı tercihleri (UserDefaults + JSON).
//  Faz: 1  ·  Kararlar: D-08, D-100  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Settings")

    /// Açılışta başlatma (D-08, varsayılan açık).
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                logger.error("Açılışta başlatma değiştirilemedi: \(error.localizedDescription)")
            }
        }
    }

    /// İlk açılışta açılışta başlatmayı etkinleştirir (D-08).
    /// D-08: varsayılan açık. Kayıt her açılışta yenilenir; uygulama /Applications'a taşınınca yeni konum kaydedilir.
    func applyDefaultsOnFirstLaunch() {
        let key = "launchAtLoginWanted"
        if UserDefaults.standard.object(forKey: key) == nil { UserDefaults.standard.set(true, forKey: key) }
        guard UserDefaults.standard.bool(forKey: key),
              Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        try? SMAppService.mainApp.register()
    }
}
