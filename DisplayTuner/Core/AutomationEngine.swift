//
//  AutomationEngine.swift
//  DisplayTuner
//
//  Görev: Dock takılınca/çıkınca senaryolar; mikrofon durumu HUD'ı.
//  Faz: 6 (+2 mikrofon)  ·  Kararlar: D-62, D-91…D-94  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os

@MainActor
final class AutomationEngine {
    private let services: AppServices
    private var micTask: Task<Void, Never>?
    private var lastMicMuted: Bool?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Automation")

    init(services: AppServices) {
        self.services = services
    }

    /// D-91 / D-92. Monitör modu ve profil ColorGuard'ın ekran değişimi olayıyla uygulanır (D-130).
    func dockChanged(isDocked: Bool) {
        Task {
            await DDCService.shared.refresh()
            await services.batteries.refresh()
            // D-131: `batt` bu Mac'te şarj kontrolünü desteklemiyor ("charging control is not supported");
            // şarj limiti adımı devre dışı. Destek gelirse: BattCLI.setLimit(isDocked ? 80 : 100).
            if isDocked {
                services.notifier.hud(symbol: "display", text: String(localized: "Masa Modu"))
            }
            logger.info("Dock \(isDocked ? "takıldı" : "çıkarıldı", privacy: .public): otomasyon tamam")
        }
    }

    /// D-62: kulaklık bağlıyken mikrofon durumu 1 sn'de bir sorgulanır; değişince HUD.
    func startMicMonitor() {
        micTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.services.batteries.states[.headset] != nil,
                      let headset = self.services.devices.headset,
                      let muted = await headset.isMicMuted() else {
                    self?.lastMicMuted = nil
                    continue
                }
                if let last = self.lastMicMuted, last != muted {
                    self.services.notifier.hud(symbol: muted ? "mic.slash.fill" : "mic.fill",
                                               text: muted ? String(localized: "Mikrofon Kapalı") : String(localized: "Mikrofon Açık"))
                }
                self.lastMicMuted = muted
            }
        }
    }
}
