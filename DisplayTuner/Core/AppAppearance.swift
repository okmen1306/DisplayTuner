//
//  AppAppearance.swift
//  DisplayTuner
//
//  Görev: Uygulama teması (Sistem / Açık / Koyu).
//  Kararlar: D-151  (bkz. AGENT_BRIEF.md)
//

import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Sistem")
        case .light: String(localized: "Açık")
        case .dark: String(localized: "Koyu")
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    static let key = "appAppearance"

    static var current: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }

    @MainActor
    static func apply(_ value: AppAppearance = current) {
        UserDefaults.standard.set(value.rawValue, forKey: key)
        switch value {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
