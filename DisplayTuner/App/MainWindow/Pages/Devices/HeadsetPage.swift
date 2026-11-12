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
    @State private var bands: [Int] = []
    @State private var sidetoneOn = false
    @State private var sidetoneLevel = 0
    @State private var idleMinutes = 15
    @State private var dongleLED: UInt8 = 1
    @State private var loaded = false
    @State private var eqWrite: Task<Void, Never>?
    @State private var showingSave = false
    @State private var newPresetName = ""

    private var headset: BlackSharkV2HS? { services.devices.headset }
    private var isOn: Bool { services.batteries.states[.headset] != nil }

    var body: some View {
        Form {
            Section {
                let battery = services.batteries.states[.headset]
                DeviceHero(title: "BlackShark V2 HyperSpeed",
                           subtitle: isOn ? String(localized: "Bağlı") : String(localized: "Kapalı"),
                           detail: firmware.map { String(localized: "Firmware \($0)") },
                           symbol: "headphones", tint: .teal, percent: battery?.percent,
                           isCharging: battery?.isCharging ?? false, connected: isOn)
                    .heroRow()
            }
            if isOn && loaded {
                equalizer
                Section {
                    Toggle("Kendi sesini duy (sidetone)", isOn: Binding(get: { sidetoneOn }, set: { on in
                        sidetoneOn = on
                        Task { await headset?.write(.sidetone, [on ? 1 : 0]) }
                    }))
                    SettingRow(title: "Seviye", symbol: "mic.fill") {
                        Slider(value: Binding(get: { Double(sidetoneLevel) }, set: { sidetoneLevel = Int($0.rounded()) }),
                               in: 0...15, step: 1) { editing in
                            if !editing { Task { await headset?.write(.sidetoneLevel, [UInt8(sidetoneLevel)]) } }
                        }
                        .frame(width: 200)
                        Text(String(localized: "%\(Int((Double(sidetoneLevel) / 15 * 100).rounded()))")).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                    .disabled(!sidetoneOn)
                } header: {
                    Text("Mikrofon")
                } footer: {
                    Text("%100 kulaklığın donanım sınırıdır (Synapse'teki en yüksek seviyeyle aynı).")
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

    private var eq: HeadsetEQStore { services.eq }
    private var selectedPreset: EQPreset? { eq.selected }
    private var isModified: Bool { selectedPreset.map { $0.bands != bands } ?? false }

    @ViewBuilder
    private var equalizer: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(selectedPreset?.name ?? String(localized: "Özel"))
                                .font(.title3.weight(.semibold))
                            if isModified {
                                Text("Değiştirildi").font(.caption.weight(.medium))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.orange.opacity(0.2), in: Capsule()).foregroundStyle(.orange)
                            }
                        }
                        Text(selectedPreset?.detail ?? String(localized: "Bantları sürükleyerek kendi sesini oluştur."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if bands.count == 10 {
                        Button { resetCurve() } label: { Label("Sıfırla", systemImage: "arrow.counterclockwise") }
                            .disabled(!isModified && selectedPreset != nil)
                            .help("Seçili hazır ayarın orijinal eğrisine döner; hazır ayar yoksa düz yapar.")
                        Menu {
                            Button("Yeni ayar olarak kaydet…") { newPresetName = ""; showingSave = true }
                            if let p = selectedPreset, p.isUser {
                                Button("“\(p.name)” ayarını güncelle") { eq.updateUserPreset(p.id, bands: bands) }
                                Divider()
                                Button("“\(p.name)” ayarını sil", role: .destructive) { eq.deleteUserPreset(p.id) }
                            }
                        } label: { Label("Kaydet", systemImage: "square.and.arrow.down") }
                            .fixedSize()
                    }
                }
                if bands.count == 10 {
                    EQCurveView(bands: $bands, onCommit: commitCurve)
                        .padding(.vertical, Theme.Spacing.s)
                    Text("Bantları yukarı-aşağı sürükle. Değişiklik kulaklığın hafızasına yazılır; Synapse olmadan da kalır.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        } header: {
            Text("Ekolayzır")
        }
        .alert("Yeni EQ ayarı", isPresented: $showingSave) {
            TextField("Ad", text: $newPresetName)
            Button("Kaydet") {
                let name = newPresetName.trimmingCharacters(in: .whitespaces)
                _ = eq.saveUserPreset(name: name.isEmpty ? String(localized: "Ayarım") : name, bands: bands)
            }
            Button("Vazgeç", role: .cancel) {}
        }

        ForEach(EQPreset.Category.allCases, id: \.self) { category in
            let presets = eq.all.filter { $0.category == category }
            if !presets.isEmpty {
                Section(category.title) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(presets) { preset in presetCard(preset) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func presetCard(_ preset: EQPreset) -> some View {
        let selected = preset.id == eq.selectedID
        return Button { choose(preset) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .white : Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.15)),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                }
                Text(preset.name).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                EQSparkline(bands: preset.bands, tint: selected ? .accentColor : .secondary)
                    .frame(height: 22)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(preset.detail)
    }

    private func choose(_ preset: EQPreset) {
        eq.select(preset.id)
        bands = preset.bands
        write(preset.bands)
    }

    private func resetCurve() {
        let target = selectedPreset?.bands ?? EQPreset.flatBands
        bands = target
        write(target)
    }

    private func commitCurve() { write(bands) }

    /// D-65: kulaklık hafızasına yazar; 250 ms debounce.
    private func write(_ snapshot: [Int]) {
        eqWrite?.cancel()
        eqWrite = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let headset else { return }
            await eq.apply(snapshot, to: headset)
        }
    }

    private func load() async {
        guard let headset, isOn else { return }
        firmware = await headset.firmware()
        bands = await headset.eqBands() ?? []
        if bands.count == 10 { eq.adopt(bands: bands) }
        sidetoneOn = (await headset.readByte(.sidetone) ?? 0) == 1
        sidetoneLevel = Int(await headset.readByte(.sidetoneLevel) ?? 0)
        idleMinutes = Int(await headset.readByte(.idleMinutes) ?? 15)
        dongleLED = await headset.readByte(.dongleLED, target: .dongle) ?? 1
        loaded = true
    }
}
