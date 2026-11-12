//
//  KeyboardPage.swift
//  DisplayTuner
//
//  Görev: Klavye: profil, efekt, yön, parlaklık, hız.
//  Faz: 2–3 (tuş başına renk Faz 7)  ·  Kararlar: D-68, D-120, 7.4  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

struct KeyboardPage: View {
    let services: AppServices
    @State private var activeProfile = 1
    @State private var leds: [Int: PusatPacket.LED] = [:]

    private var keyboard: K3Pro? { services.devices.keyboard }

    var body: some View {
        Form {
            if keyboard == nil {
                Section {
                    Label("Klavyeye erişmek için Giriş İzleme izni gerekiyor.", systemImage: "lock.fill")
                    Button("Sistem Ayarları'nı Aç") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                } footer: {
                    Text("İzni verdikten sonra DisplayTuner'ı yeniden başlatın.")
                }
            } else {
                Section("Profiller") {
                    ForEach(1...3, id: \.self) { p in
                        SettingRow(title: "Profil \(p)", symbol: p == activeProfile ? "checkmark.circle.fill" : "circle") {
                            if let led = leds[p] {
                                Text("\(PusatEffect(rawValue: led.mode)?.title ?? "?")").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Aktif profil klavyedeki profil tuşuyla değiştirilir.").font(.caption).foregroundStyle(.secondary)
                }
                if let led = leds[activeProfile] {
                    Section("Profil \(activeProfile) aydınlatma") {
                        Picker("Efekt", selection: Binding(get: { led.mode }, set: { write(.mode, $0) })) {
                            ForEach(PusatEffect.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        SettingRow(title: "Parlaklık") {
                            Picker("", selection: Binding(get: { led.brightness }, set: { write(.brightness, UInt8($0)) })) {
                                ForEach(0...5, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                        }
                        SettingRow(title: "Hız") {
                            // Hız = 3 − ham değer (okuma ile tutarlı, D-134).
                            Picker("", selection: Binding(get: { led.speed }, set: { write(.speedRaw, UInt8(3 - $0)) })) {
                                ForEach(0...3, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                        }
                        if PusatEffect(rawValue: led.mode)?.supportsDirection == true {
                            Picker("Yön", selection: Binding(get: { led.directionLeft }, set: { write(.direction, $0 ? 0xFF : 0x00) })) {
                                Text("Soldan sağa").tag(false)
                                Text("Sağdan sola").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                Section {
                    Text("Renk ve tuş başına renk sonraki sürümde.").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await load() }
    }

    private func write(_ setting: K3Pro.Setting, _ value: UInt8) {
        let profile = activeProfile
        Task {
            await keyboard?.set(setting, value, profile: profile)
            try? await Task.sleep(for: .milliseconds(150))
            if let led = await keyboard?.led(profile: profile) { leds[profile] = led }
        }
    }

    private func load() async {
        guard let keyboard else { return }
        activeProfile = await keyboard.activeProfile() ?? 1
        for p in 1...3 {
            if let led = await keyboard.led(profile: p) { leds[p] = led }
        }
    }
}
