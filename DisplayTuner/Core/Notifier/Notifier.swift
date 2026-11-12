//
//  Notifier.swift
//  DisplayTuner
//
//  Görev: Bildirim katmanlarının giriş noktası.
//  Faz: 2  ·  Kararlar: D-70…D-74  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Üç katman: sistem bildirimi, kritik uyarı, HUD (D-70).
@MainActor
final class Notifier {
    private let system = SystemNotificationService()
    private let critical = CriticalAlertPanel()
    private let hud = HUDPanel()

    func start() {
        system.requestAuthorization()
    }

    /// D-71: kritik seviyeler hem sistem bildirimi hem kritik uyarı olarak gider (8.4).
    func batteryThreshold(kind: DeviceKind, name: String, percent: Int, threshold: ThresholdTracker.Threshold) {
        let title = NotificationTexts.lowBatteryTitle(kind, critical: threshold.isCritical)
        let body = NotificationTexts.lowBatteryBody(name: name, percent: percent, critical: threshold.isCritical, kind: kind)
        let playSound = threshold.isCritical && kind == .headset && threshold.percent <= 3
        system.post(title: title, body: body, thread: kind.rawValue, sound: playSound)
        if threshold.isCritical {
            critical.show(title: title, message: body)
        }
        // D-73 (mouse LED'i kırmızı nefes) Faz 3'te LowBatteryLEDAlert ile eklenecek.
    }

    func fullyCharged(kind: DeviceKind, name: String) {
        system.post(title: NotificationTexts.fullyChargedTitle, body: NotificationTexts.fullyChargedBody(name: name), thread: kind.rawValue)
    }

    func hud(symbol: String, text: String) {
        hud.show(symbol: symbol, text: text)
    }

    /// Bildirimler sayfasındaki "Örnek göster" (Faz 2 kabul kriteri).
    func showSamples() {
        hud(symbol: "headphones", text: "BlackShark V2 HyperSpeed")
        batteryThreshold(kind: .headset, name: "BlackShark V2", percent: 5,
                         threshold: .init(percent: 5, isCritical: true))
    }
}
