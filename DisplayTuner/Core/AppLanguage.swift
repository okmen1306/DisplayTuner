//
//  AppLanguage.swift
//  DisplayTuner
//
//  Görev: Uygulama dili (Sistem / Türkçe / English). Seçim uygulamaya özel AppleLanguages ile yapılır.
//  Kararlar: D-151  (bkz. AGENT_BRIEF.md)
//

import AppKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, tr, en
    var id: String { rawValue }

    /// Her dil kendi adıyla gösterilir.
    var title: String {
        switch self {
        case .system: String(localized: "Sistem")
        case .tr: "Türkçe"
        case .en: "English"
        }
    }

    static var current: AppLanguage {
        if !UserDefaults.standard.bool(forKey: chosenKey) { return .en }
        guard let list = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String],
              let first = list.first else { return .system }
        return first.hasPrefix("en") ? .en : first.hasPrefix("tr") ? .tr : .system
    }

    private static let chosenKey = "languageChosen"

    /// D-151: Kullanıcı hiç dil seçmediyse uygulama İngilizce açılır.
    static func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: chosenKey) else { return }
        defaults.set(["en"], forKey: "AppleLanguages")
    }

    /// Dili kaydeder ve uygulamayı yeniden başlatır (dil açılışta okunur).
    @MainActor
    static func select(_ language: AppLanguage) {
        UserDefaults.standard.set(true, forKey: chosenKey)
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        let path = Bundle.main.bundlePath
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }
}
