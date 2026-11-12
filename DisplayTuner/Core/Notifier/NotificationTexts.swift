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
        if critical { return String(localized: "Düşük Pil") }
        return kind == .headset ? String(localized: "Kulaklık Pili Azalıyor") : String(localized: "Mouse Pili Azalıyor")
    }

    static func lowBatteryBody(name: String, percent: Int, critical: Bool, kind: DeviceKind) -> String {
        if critical {
            if percent <= 0 { return String(localized: "\(name)'nin pili bitmek üzere.") }
            return kind == .headset
                ? String(localized: "\(name)'de %\(percent) pil kaldı. Kulaklığınızı şarj edin.")
                : String(localized: "\(name)'de %\(percent) pil kaldı. Mouse'unuzu şarj edin.")
        }
        return String(localized: "\(name)'de %\(percent) pil kaldı.")
    }

    static var fullyChargedTitle: String { String(localized: "Şarj Tamamlandı") }
    static func fullyChargedBody(name: String) -> String { String(localized: "\(name) tamamen şarj oldu.") }
}
