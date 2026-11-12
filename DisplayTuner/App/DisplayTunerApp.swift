//
//  DisplayTunerApp.swift
//  DisplayTuner
//
//  Görev: Uygulama girişi (@main). AppDelegate'i bağlar, sahne yok (LSUIElement).
//  Faz: 1  ·  Kararlar: D-03, D-07  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

@main
struct DisplayTunerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppLanguage.applyDefaultIfNeeded()   // D-151: ilk açılış İngilizce; kullanıcı seçimi kalıcı.
        // D-130: Yardımcı süreç modu. `DisplayTuner --apply-connection-mode <colorMode> <bitDepth>`
        // Taze süreçte CADisplay güncel olduğu için bağlantı modu burada değiştirilir, sonra çıkılır.
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: ConnectionModeService.helperFlag), args.count > index + 2,
           let bitDepth = Int(args[index + 2]) {
            let ok = ConnectionModeService.apply(.init(colorMode: args[index + 1], bitDepth: bitDepth))
            exit(ok ? 0 : 1)
        }
    }

    var body: some Scene {
        Settings { EmptyView() }
    }
}
