//
//  AutomationPage.swift
//  DisplayTuner
//
//  Görev: Dock adımları, eski kurulum, kısayollar.
//  Faz: 6  ·  Kararlar: D-91…D-94, D-110, D-131, R9  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

struct AutomationPage: View {
    let services: AppServices
    @State private var legacyLoaded = false
    @State private var legacyMessage: String?

    private static let legacyLabel = "com.muhammed.dockapps"
    private static var legacyPlist: String { NSHomeDirectory() + "/Library/LaunchAgents/\(legacyLabel).plist" }

    var body: some View {
        Form {
            Section {
                Label("Monitörü RGB Full'a al ve aktif profili uygula", systemImage: "display")
                Label("\"Masa Modu\" bildirimi", systemImage: "rectangle.on.rectangle")
                Label("Pil bilgilerini yenile", systemImage: "battery.75percent")
                Label("Şarj limiti %80 — bu Mac'te desteklenmiyor", systemImage: "bolt.slash")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Dock takılınca")
            } footer: {
                Text("Renk adımları Ekran sekmesindeki \"Renk yönetimi\" açıkken çalışır.")
            }

            Section {
                SettingRow(title: "Eski dock script'i (dockapps.sh)", symbol: "terminal") {
                    Text(legacyLoaded ? "Çalışıyor" : "Durduruldu").foregroundStyle(.secondary)
                }
                if legacyLoaded {
                    Button("Durdur") { run(["bootout", "gui/\(getuid())/\(Self.legacyLabel)"]) }
                } else if FileManager.default.fileExists(atPath: Self.legacyPlist) {
                    Button("Yeniden Başlat") { run(["bootstrap", "gui/\(getuid())", Self.legacyPlist]) }
                }
                if let legacyMessage { Text(legacyMessage).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("Eski kurulum")
            } footer: {
                Text("DisplayTuner bu script'in işlerini devraldı. Script silinmez, sadece durdurulur.")
            }

            Section("Kısayollar") {
                SettingRow(title: "Ekran profili 1–4") { Text("⌃⌥1 … ⌃⌥4").font(.body.monospaced()).foregroundStyle(.secondary) }
                SettingRow(title: "Kulaklık EQ hazır ayarı") { Text("⌃⌥E").font(.body.monospaced()).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .task { refresh() }
    }

    private func refresh() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["print", "gui/\(getuid())/\(Self.legacyLabel)"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        legacyLoaded = p.terminationStatus == 0
    }

    private func run(_ arguments: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = arguments
        try? p.run()
        p.waitUntilExit()
        legacyMessage = p.terminationStatus == 0 ? String(localized: "Tamam") : String(localized: "İşlem başarısız (\(p.terminationStatus))")
        refresh()
    }
}
