//
//  DisplayPage.swift
//  DisplayTuner
//
//  Görev: Ekran sekmesi: renk yönetimi, bağlantı modu, Hz, DDC, LUT renk ayarları.
//  Faz: 5  ·  Kararlar: D-30…D-41, D-121, D-126, D-130  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import SwiftUI

struct DisplayPage: View {
    let services: AppServices
    private var profiles: ProfileStore { services.profiles }

    @State private var managementOn = false
    @State private var options: [ConnectionModeService.Option] = []
    @State private var currentOption: ConnectionModeService.Option?
    @State private var rates: [Int] = []
    @State private var currentRate: Int?
    @State private var ddc: [DDCService.VCP: DDCService.Value] = [:]
    @State private var ddcWrite: [DDCService.VCP: Task<Void, Never>] = [:]
    @State private var applying = false
    @State private var displays: [ArrangementService.Display] = []
    @State private var selectedDisplay: CGDirectDisplayID?
    @State private var builtinBrightness = 0.5

    private static let ddcRows: [(DDCService.VCP, LocalizedStringKey, String)] = [
        (.brightness, "Parlaklık", "sun.max.fill"), (.contrast, "Kontrast", "circle.lefthalf.filled"),
        (.redGain, "Kırmızı kazanç", "r.circle"), (.greenGain, "Yeşil kazanç", "g.circle"), (.blueGain, "Mavi kazanç", "b.circle"),
    ]

    /// Seçili ekran PR27R165QC mi (veya seçim yok)?
    private var monitorSelected: Bool {
        guard let selectedDisplay else { return true }
        return selectedDisplay == ProfileStore.monitorDisplayID
    }

    var body: some View {
        Form {
            if displays.count > 1 {
                Section {
                    Picker("Ekran", selection: $selectedDisplay) {
                        ForEach(displays) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if monitorSelected { monitorContent } else if let selectedDisplay { otherDisplay(selectedDisplay) }
        }
        .formStyle(.grouped)
        .task { await reload() }
    }

    // MARK: Diğer ekran (MacBook ekranı vb., D-150)

    @ViewBuilder
    private func otherDisplay(_ id: CGDirectDisplayID) -> some View {
        Section(displays.first { $0.id == id }?.name ?? "") {
            if CGDisplayIsBuiltin(id) != 0 {
                SettingRow(title: "Parlaklık", symbol: "sun.max.fill") {
                    Slider(value: Binding(get: { builtinBrightness }, set: {
                        builtinBrightness = $0
                        BuiltinBrightness.set($0)
                    }), in: 0...1)
                    .frame(width: 220)
                }
            }
            DisplayModeControls(profiles: profiles, displayID: id)
        }
    }

    // MARK: Monitör

    @ViewBuilder
    private var monitorContent: some View {
            Section {
                Toggle("Renk yönetimi", isOn: Binding(get: { managementOn }, set: {
                    managementOn = $0
                    profiles.isColorManagementEnabled = $0
                }))
            } footer: {
                Text("Açıkken monitör her bağlandığında RGB Full'a alınır ve aktif profil (\(profiles.active?.displayName ?? "—")) uygulanır.")
            }

            ProfilesSection(profiles: profiles)
            if ProfileStore.monitorDisplayID == nil {
                Section { Label("PR27R165QC bağlı değil", systemImage: "display.trianglebadge.exclamationmark") }
            } else {
                connectionSection
                hardwareSection
                colorSection
            }
    }

    // MARK: Bağlantı

    private var connectionSection: some View {
        Section("Bağlantı") {
            Picker("Renk modu", selection: Binding(get: { currentOption ?? options.first }, set: { option in
                guard let option else { return }
                currentOption = option
                Task {
                    applying = true
                    _ = await ConnectionModeService.applyViaHelper(option)
                    profiles.updateActive(applyGamma: true) { $0.colorMode = option.colorMode; $0.bitDepth = option.bitDepth }
                    applying = false
                }
            })) {
                ForEach(options, id: \.self) { o in
                    Text("\(Self.label(o.colorMode)) · \(o.bitDepth) bit").tag(Optional(o))
                }
            }
            .disabled(applying)
            DisplayModeControls(profiles: profiles)
        }
    }

    // MARK: Donanım (DDC)

    private var hardwareSection: some View {
        Section("Monitör (donanım)") {
            ForEach(Self.ddcRows, id: \.0) { vcp, title, symbol in
                if let value = ddc[vcp] {
                    SettingRow(title: title, symbol: symbol) {
                        Slider(value: Binding(get: { Double(value.current) }, set: { set(vcp, Int($0.rounded())) }),
                               in: 0...Double(max(value.maximum, 1)))
                            .frame(width: 220)
                        Text("\(value.current)").monospacedDigit().frame(width: 32, alignment: .trailing)
                    }
                }
            }
            if ddc.isEmpty { Text("Okunuyor…").foregroundStyle(.secondary) }
        }
    }

    private func set(_ vcp: DDCService.VCP, _ value: Int) {
        guard let old = ddc[vcp], old.current != value else { return }
        ddc[vcp] = .init(current: value, maximum: old.maximum)
        ddcWrite[vcp]?.cancel()
        ddcWrite[vcp] = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await DDCService.shared.write(vcp, value: value)
            profiles.updateActive(applyGamma: false) { $0.ddc[vcp.rawValue] = value }
        }
    }

    // MARK: Renk (LUT)

    @ViewBuilder
    private var colorSection: some View {
        Section {
            lutRow("Kontrast", \.contrast, -1...1)
            lutRow("Gama", \.gamma, -1...1)
            lutRow("Kazanç", \.gain, -0.5...0.5)
            lutRow("Parlak alanlar", \.highlights, -1...1)
            lutRow("Gölge", \.shadows, -1...1)
            lutRow("Renk sıcaklığı", \.temperature, -1...1)
            lutRow("Kazanç (kırmızı)", \.redGain, -0.5...0.5)
            lutRow("Kazanç (yeşil)", \.greenGain, -0.5...0.5)
            lutRow("Kazanç (mavi)", \.blueGain, -0.5...0.5)
        } header: {
            Text("Renk (yazılım)")
        } footer: {
            Text("Renk sıcaklığı: sağa sıcak, sola soğuk.")
        }
        .disabled(!managementOn)
        filterSection
    }

    private var filterSection: some View {
        Section {
            filterRow("Doygunluk", \.saturation, 0...2, neutral: 1)
            filterRow("Canlılık", \.vibrance, -1...1, neutral: 0)
            filterRow("Ton", \.hue, -Double.pi...Double.pi, neutral: 0)
            filterRow("Sepya", \.sepia, 0...1, neutral: 0)
        } header: {
            Text("Renk (filtre)")
        } footer: {
            Text("Bu ayarlar ekranın üstünde saydam bir katmanla uygulanır; hepsi varsayılandayken katman kapalıdır.")
        }
        .disabled(!managementOn)
    }

    private func filterRow(_ title: LocalizedStringKey, _ key: WritableKeyPath<DisplayProfile, Double>,
                           _ range: ClosedRange<Double>, neutral: Double) -> some View {
        let value = profiles.active?[keyPath: key] ?? neutral
        return SettingRow(title: title, onReset: value == neutral ? nil : { profiles.updateActive(applyGamma: false) { $0[keyPath: key] = neutral } }) {
            Slider(value: Binding(get: { value }, set: { v in profiles.updateActive(applyGamma: false) { $0[keyPath: key] = v } }), in: range)
                .frame(width: 220)
            Text(value, format: .number.precision(.fractionLength(2))).monospacedDigit().frame(width: 40, alignment: .trailing)
        }
    }

    private func lutRow(_ title: LocalizedStringKey, _ key: WritableKeyPath<ColorAdjustments, Double>, _ range: ClosedRange<Double>) -> some View {
        let value = profiles.active?.adjustments[keyPath: key] ?? 0
        return SettingRow(title: title, onReset: value == 0 ? nil : { setLUT(key, 0) }) {
            Slider(value: Binding(get: { value }, set: { setLUT(key, $0) }), in: range)
                .frame(width: 220)
            Text(value, format: .number.precision(.fractionLength(2))).monospacedDigit().frame(width: 40, alignment: .trailing)
        }
    }

    /// Slider değişince kayıtlı tablo bırakılır ve tablo formülden üretilir (D-38: başlangıç değerleri aynı sonucu verir).
    private func setLUT(_ key: WritableKeyPath<ColorAdjustments, Double>, _ value: Double) {
        profiles.updateActive { $0.gammaTable = nil; $0.adjustments[keyPath: key] = value }
    }

    // MARK: Yükleme

    private func reload() async {
        managementOn = profiles.isColorManagementEnabled
        displays = ArrangementService.displays()
        if selectedDisplay == nil || !displays.contains(where: { $0.id == selectedDisplay }) {
            selectedDisplay = ProfileStore.monitorDisplayID ?? displays.first?.id
        }
        builtinBrightness = BuiltinBrightness.value ?? 0.5
        if let id = ProfileStore.monitorDisplayID {
            rates = ModeService.refreshRates(id)
            currentRate = ModeService.currentRefreshRate(id)
        }
        options = ConnectionModeService.options
        if let active = profiles.active {
            currentOption = .init(colorMode: active.colorMode, bitDepth: active.bitDepth)
        }
        var values: [DDCService.VCP: DDCService.Value] = [:]
        for (vcp, _, _) in Self.ddcRows {
            if let v = await DDCService.shared.read(vcp) { values[vcp] = v }
        }
        ddc = values
    }

    private static func label(_ colorMode: String) -> String {
        switch colorMode {
        case "RGBFullRange": "RGB Full"
        case "RGBLimitedRange": "RGB Limited"
        case "YCbCr444LimitedRange": "YCbCr 4:4:4 Limited"
        case "YCbCr444FullRange": "YCbCr 4:4:4 Full"
        default: colorMode.replacingOccurrences(of: "_", with: " ")
        }
    }
}
