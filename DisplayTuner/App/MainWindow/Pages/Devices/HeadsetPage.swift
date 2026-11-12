//
//  HeadsetPage.swift
//  DisplayTuner
//
//  Görev: Kulaklık: pil, EQ, sidetone, güç, LED.
//  Faz: 2–3  ·  Kararlar: D-63, D-65, D-67, 7.4  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct HeadsetPage: View {
    let services: AppServices
    @State private var firmware: String?
    @State private var preset: UInt8?
    @State private var bands: [Int] = []
    @State private var sidetoneOn = false
    @State private var sidetoneLevel = 0
    @State private var idleMinutes = 15
    @State private var dongleLED: UInt8 = 1
    @State private var loaded = false
    @State private var eqWrite: Task<Void, Never>?

    private var headset: BlackSharkV2HS? { services.devices.headset }
    private var isOn: Bool { services.batteries.states[.headset] != nil }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Spacing.l) {
                    BatteryRing(percent: services.batteries.states[.headset]?.percent, symbol: "headphones",
                                label: "Pil", isCharging: services.batteries.states[.headset]?.isCharging ?? false, size: 64)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("BlackShark V2 HyperSpeed").font(.title3.weight(.semibold))
                        Text(isOn ? "Bağlı" : "Kapalı").foregroundStyle(.secondary)
                        if let firmware { Text("Firmware \(firmware)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .padding(.vertical, Theme.Spacing.s)
            }
            if isOn && loaded {
                equalizer
                Section("Mikrofon") {
                    Toggle("Kendi sesini duy (sidetone)", isOn: Binding(get: { sidetoneOn }, set: { on in
                        sidetoneOn = on
                        Task { await headset?.write(.sidetone, [on ? 1 : 0]) }
                    }))
                    SettingRow(title: "Seviye") {
                        Slider(value: Binding(get: { Double(sidetoneLevel) }, set: { sidetoneLevel = Int($0.rounded()) }),
                               in: 0...15, step: 1) { editing in
                            if !editing { Task { await headset?.write(.sidetoneLevel, [UInt8(sidetoneLevel)]) } }
                        }
                        .frame(width: 200)
                        Text("\(sidetoneLevel)").monospacedDigit().frame(width: 24)
                    }
                    .disabled(!sidetoneOn)
                }
                Section("Güç ve ışık") {
                    Picker("Otomatik kapanma", selection: Binding(get: { idleMinutes }, set: { m in
                        idleMinutes = m
                        Task { await headset?.write(.idleMinutes, [UInt8(m)]) }
                    })) {
                        Text("Kapalı").tag(0)
                        ForEach([5, 10, 15, 30, 60], id: \.self) { Text("\($0) dk").tag($0) }
                        if ![0, 5, 10, 15, 30, 60].contains(idleMinutes) { Text("\(idleMinutes) dk").tag(idleMinutes) }
                    }
                    Picker("Dongle ışığı", selection: Binding(get: { dongleLED }, set: { v in
                        dongleLED = v
                        Task { await headset?.write(.dongleLED, [v], target: .dongle) }
                    })) {
                        Text("Kapalı").tag(UInt8(0))
                        Text("Bağlantı durumu").tag(UInt8(1))
                        Text("Pil durumu").tag(UInt8(2))
                        Text("Sadece düşük pil").tag(UInt8(3))
                    }
                }
            } else if !isOn {
                Section { Text("Ayarlar için kulaklığı açın.").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .task(id: isOn) { await load() }
    }

    private var equalizer: some View {
        Section("Ekolayzır") {
            Picker("Hazır ayar", selection: Binding(get: { preset ?? 0 }, set: { p in
                preset = p
                Task {
                    await headset?.write(.eqPreset, [p])
                    bands = await headset?.eqBands() ?? bands
                }
            })) {
                ForEach(RazerEQPreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            if bands.count == 10 {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        VStack(spacing: Theme.Spacing.xs) {
                            Text("\(bands[i] > 0 ? "+" : "")\(bands[i])").font(.caption2.monospacedDigit())
                            Slider(value: Binding(get: { Double(bands[i]) }, set: { setBand(i, Int($0.rounded())) }), in: -9...6, step: 1)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 120, height: 24)
                                .frame(width: 34, height: 120)
                            Text(RazerEQPreset.frequencies[i]).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .disabled(preset != RazerEQPreset.custom.rawValue)
                if preset != RazerEQPreset.custom.rawValue {
                    Text("Bantları değiştirmek için \"Özel\"i seçin.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// D-65: kulaklık hafızasına yazar; 250 ms debounce.
    private func setBand(_ index: Int, _ value: Int) {
        guard bands[index] != value else { return }
        bands[index] = value
        let snapshot = bands
        eqWrite?.cancel()
        eqWrite = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await headset?.setEQBands(snapshot)
        }
    }

    private func load() async {
        guard let headset, isOn else { return }
        firmware = await headset.firmware()
        preset = await headset.readByte(.eqPreset)
        bands = await headset.eqBands() ?? []
        sidetoneOn = (await headset.readByte(.sidetone) ?? 0) == 1
        sidetoneLevel = Int(await headset.readByte(.sidetoneLevel) ?? 0)
        idleMinutes = Int(await headset.readByte(.idleMinutes) ?? 15)
        dongleLED = await headset.readByte(.dongleLED, target: .dongle) ?? 1
        loaded = true
    }
}
