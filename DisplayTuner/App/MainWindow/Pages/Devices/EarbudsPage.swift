//
//  EarbudsPage.swift
//  DisplayTuner
//
//  Görev: Bluetooth (kulak içi) kulaklık: sistem geneli EQ.
//  Kararlar: D-158  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct EarbudsPage: View {
    @Bindable var eq: SystemEQ
    @State private var bands: [Int] = []
    @State private var showingSave = false
    @State private var newName = ""

    private var connected: Bool { eq.output?.isBluetooth == true }
    private var store: HeadsetEQStore { eq.store }
    private var selected: EQPreset? { store.selected }
    private var isModified: Bool { selected.map { $0.bands != bands } ?? false }

    var body: some View {
        Form {
            Section {
                DeviceHero(title: connected ? eq.output!.name : String(localized: "Kablosuz Kulaklık"),
                           subtitle: connected ? String(localized: "Bağlı") : String(localized: "Bağlı değil"),
                           detail: eq.isRunning ? String(localized: "EQ açık") : nil,
                           symbol: "airpodspro", tint: .pink, connected: connected)
                    .heroRow()
            }
            Section {
                Toggle("Bluetooth kulaklıkta ekolayzırı kullan", isOn: $eq.isEnabled)
                if let error = eq.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            } footer: {
                Text("Varsayılan ses çıkışı bir Bluetooth kulaklık olduğunda kendiliğinden devreye girer. İlk kullanımda macOS bir kez sistem sesi izni ister; ses kaydedilmez, sadece anlık işlenir.")
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(selected?.name ?? String(localized: "Özel")).font(.title3.weight(.semibold))
                                if isModified {
                                    Text("Değiştirildi").font(.caption.weight(.medium))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.orange.opacity(0.2), in: Capsule()).foregroundStyle(.orange)
                                }
                            }
                            Text(selected?.detail ?? String(localized: "Bantları sürükleyerek kendi sesini oluştur."))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { apply(selected?.bands ?? EQPreset.flatBands) } label: {
                            Label("Sıfırla", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(!isModified && selected != nil)
                        Button { newName = ""; showingSave = true } label: { Label("Kaydet", systemImage: "square.and.arrow.down") }
                    }
                    EQCurveView(bands: $bands, tint: .pink) { apply(bands) }
                        .padding(.vertical, Theme.Spacing.s)
                }
                .padding(.vertical, Theme.Spacing.xs)
            } header: {
                Text("Ekolayzır")
            }
            .disabled(!eq.isEnabled)
            .alert("Yeni EQ ayarı", isPresented: $showingSave) {
                TextField("Ad", text: $newName)
                Button("Kaydet") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    _ = store.saveUserPreset(name: name.isEmpty ? String(localized: "Ayarım") : name, bands: bands)
                }
                Button("Vazgeç", role: .cancel) {}
            }

            ForEach(EQPreset.Category.allCases, id: \.self) { category in
                let presets = store.all.filter { $0.category == category && $0.id != "balanced" }
                if !presets.isEmpty {
                    Section(category.title) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(presets) { preset in card(preset) }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!eq.isEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            bands = eq.bands
            store.adopt(bands: eq.bands)
            eq.reconcile()
        }
    }

    private func apply(_ new: [Int]) {
        bands = new
        eq.setBands(new)
    }

    private func card(_ preset: EQPreset) -> some View {
        let on = preset.id == store.selectedID
        return Button {
            store.select(preset.id)
            apply(preset.bands)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? .white : Color.pink)
                        .frame(width: 26, height: 26)
                        .background(on ? AnyShapeStyle(Color.pink) : AnyShapeStyle(Color.pink.opacity(0.15)),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Spacer()
                    if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(.pink) }
                }
                Text(preset.name).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                EQSparkline(bands: preset.bands, tint: on ? .pink : .secondary).frame(height: 22)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Color.pink.opacity(0.12) : Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(on ? Color.pink.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(preset.detail)
    }
}
