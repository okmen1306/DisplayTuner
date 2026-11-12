//
//  MouseDevicePage.swift
//  DisplayTuner
//
//  Görev: Mouse donanımı: pil, RGB.
//  Faz: 2–3  ·  Kararlar: D-23, D-64, D-65, 7.4  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct MouseDevicePage: View {
    let services: AppServices
    let openMouseSettings: () -> Void
    @State private var zones: [UInt8: AsusPacket.Lighting] = [:]
    @State private var save: Task<Void, Never>?

    private static let zoneNames: [(UInt8, LocalizedStringKey)] = [(0, "Logo"), (1, "Tekerlek")]
    private static let modes: [(UInt8, String)] = [(0x00, "Sabit"), (0x01, "Nefes"), (0x02, "Renk döngüsü"),
                                                  (0x04, "Tepki"), (0x06, "Pil durumu"), (0xF0, "Kapalı")]

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Spacing.l) {
                    let state = services.batteries.states[.mouse]
                    BatteryRing(percent: state?.percent, symbol: "computermouse.fill", label: "Pil",
                                isCharging: state?.isCharging ?? false, size: 64)
                        .opacity(state?.isStale == true ? 0.5 : 1)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("ROG Gladius II Wireless").font(.title3.weight(.semibold))
                        Text("Pil %25'lik adımlarla raporlanır").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Theme.Spacing.s)
            }
            ForEach(Self.zoneNames, id: \.0) { zone, name in
                if let lighting = zones[zone] {
                    Section(name) {
                        Picker("Efekt", selection: Binding(get: { lighting.mode }, set: { update(zone) { l, m in l = .init(mode: m, brightness: l.brightness, red: l.red, green: l.green, blue: l.blue) }($0) })) {
                            ForEach(Self.modes, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        InlineColorPicker(title: "Renk", color: Binding(get: {
                            Color(red: Double(lighting.red) / 255, green: Double(lighting.green) / 255, blue: Double(lighting.blue) / 255)
                        }, set: { color in
                            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                            update(zone) { l, _ in
                                l = .init(mode: l.mode, brightness: l.brightness, red: UInt8(c.redComponent * 255),
                                          green: UInt8(c.greenComponent * 255), blue: UInt8(c.blueComponent * 255))
                            }(0)
                        }))
                        SettingRow(title: "Parlaklık") {
                            Picker("", selection: Binding(get: { lighting.brightness }, set: { b in
                                update(zone) { l, _ in l = .init(mode: l.mode, brightness: b, red: l.red, green: l.green, blue: l.blue) }(0)
                            })) {
                                ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                        }
                    }
                }
            }
            Section {
                Button("macOS mouse ayarları", action: openMouseSettings)
            } footer: {
                Text("DPI ve polling ayarları sonraki sürümde.")
            }
        }
        .formStyle(.grouped)
        .task {
            guard let mouse = services.devices.mouse else { return }
            for (zone, _) in Self.zoneNames {
                if let l = await mouse.readLighting(zone: zone) { zones[zone] = l }
            }
        }
    }

    /// Canlı uygular; 500 ms sonra hafızaya kaydeder (D-65).
    private func update(_ zone: UInt8, _ change: @escaping (inout AsusPacket.Lighting, UInt8) -> Void) -> (UInt8) -> Void {
        { value in
            guard var lighting = zones[zone] else { return }
            change(&lighting, value)
            zones[zone] = lighting
            let mouse = services.devices.mouse
            Task { await mouse?.setLighting(zone: zone, lighting) }
            save?.cancel()
            save = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await mouse?.saveToFlash()
            }
        }
    }
}
