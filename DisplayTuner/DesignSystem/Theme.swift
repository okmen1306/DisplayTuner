//
//  Theme.swift
//  DisplayTuner
//
//  Görev: Boşluklar, köşe yarıçapları, animasyonlar, pil renkleri.
//  Faz: 1  ·  Kararlar: 9  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

enum Theme {
    /// 8 pt ızgara.
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum Radius {
        static let sidebarIcon: CGFloat = 5
        static let card: CGFloat = 14
        static let popover: CGFloat = 18
    }

    static let spring = Animation.spring(duration: 0.35)

    /// Pil rengi: >%20 yeşil, %10–20 sarı, <%10 kırmızı.
    static func batteryColor(_ percent: Int?) -> Color {
        guard let percent else { return .secondary }
        switch percent {
        case ..<10: return .red
        case ..<21: return .yellow
        default: return .green
        }
    }
}
