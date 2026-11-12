//
//  SidebarItem.swift
//  DisplayTuner
//
//  Görev: Sidebar öğe modeli (sayfa + cihaz kimliği).
//  Faz: 1  ·  Kararlar: D-22  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

/// Ana penceredeki sayfalar (D-22). Cihaz alt öğeleri Faz 2'de `device(id)` ile eklenecek.
enum SidebarItem: Hashable, Identifiable {
    case display
    case mouse
    case devices
    case headset
    case mouseDevice
    case keyboard
    case automation
    case notifications
    case settings

    var id: Self { self }

    static let primary: [SidebarItem] = [.display, .mouse, .devices]
    static let deviceChildren: [SidebarItem] = [.headset, .mouseDevice, .keyboard]
    static let secondary: [SidebarItem] = [.automation, .notifications, .settings]

    var title: LocalizedStringKey {
        switch self {
        case .display: "Ekran"
        case .mouse: "Mouse"
        case .devices: "Bağlı Cihazlar"
        case .headset: "BlackShark V2"
        case .mouseDevice: "ROG Gladius II"
        case .keyboard: "PUSAT K3 Pro"
        case .automation: "Otomasyon"
        case .notifications: "Bildirimler"
        case .settings: "Ayarlar"
        }
    }

    var symbol: String {
        switch self {
        case .display: "display"
        case .mouse: "computermouse.fill"
        case .devices: "cable.connector"
        case .headset: "headphones"
        case .mouseDevice: "computermouse.fill"
        case .keyboard: "keyboard.fill"
        case .automation: "gearshape.2.fill"
        case .notifications: "bell.badge.fill"
        case .settings: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .display: .blue
        case .mouse: .gray
        case .devices: .green
        case .headset, .mouseDevice, .keyboard: .teal
        case .automation: .purple
        case .notifications: .red
        case .settings: .gray
        }
    }

    /// Sayfanın yazılacağı faz (geçici yer tutucu metni için).
    var phase: Int {
        switch self {
        case .display: 5
        case .mouse: 4
        case .devices, .headset, .mouseDevice, .keyboard, .notifications: 2
        case .automation, .settings: 6
        }
    }
}
