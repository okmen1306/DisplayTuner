//
//  NotificationTexts.swift
//  DisplayTuner
//
//  Görev: Bildirim metinleri.
//  Faz: 2  ·  Kararlar: 8.1  (bkz. AGENT_BRIEF.md)
//

import Foundation

enum NotificationTexts {
    static func lowBatteryTitle(_ kind: DeviceKind, critical: Bool) -> String {
        if critical { return "Düşük Pil" }
        return kind == .headset ? "Kulaklık Pili Azalıyor" : "Mouse Pili Azalıyor"
    }

    static func lowBatteryBody(name: String, percent: Int, critical: Bool, kind: DeviceKind) -> String {
        if critical {
            if percent <= 0 { return "\(name)'nin pili bitmek üzere." }
            return "\(name)'de %\(percent) pil kaldı. \(kind == .headset ? "Kulaklığınızı" : "Mouse'unuzu") şarj edin."
        }
        return "\(name)'de %\(percent) pil kaldı."
    }

    static let fullyChargedTitle = "Şarj Tamamlandı"
    static func fullyChargedBody(name: String) -> String { "\(name) tamamen şarj oldu." }
}
