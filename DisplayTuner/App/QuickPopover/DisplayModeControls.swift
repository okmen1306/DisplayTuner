//
//  DisplayModeControls.swift
//  DisplayTuner
//
//  Görev: Monitör çözünürlüğü/ölçeği, desteklenen bütün Hz değerleri ve ana ekran (popover + Ekran sekmesi).
//  Faz: 5  ·  Kararlar: D-40, D-126, D-142, D-144  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct DisplayModeControls: View {
    let profiles: ProfileStore
    var compact = false
    @State private var resolutions: [ModeService.Resolution] = []
    @State private var current: ModeService.Resolution?
    @State private var rates: [Int] = []
    @State private var currentRate: Int?
    @State private var isMain = false
    @State private var note: String?

    var body: some View {
        Group {
            if resolutions.isEmpty {
                Text("Monitör bağlı değil").foregroundStyle(.secondary)
            } else {
                Picker("Çözünürlük", selection: Binding(get: { current ?? resolutions[0] }, set: { r in
                    note = nil
                    profiles.setResolution(r, hz: currentRate ?? 60)
                    reload()
                })) {
                    ForEach(resolutions, id: \.self) { Text($0.label).tag($0) }
                }
                // D-144: monitörün sunduğu bütün Hz'ler; mevcut ölçekte yoksa uygun moda geçilir.
                Picker("Yenileme hızı", selection: Binding(get: { currentRate ?? rates.first ?? 60 }, set: select)) {
                    ForEach(rates, id: \.self) { Text("\($0) Hz").tag($0) }
                }
                .pickerStyle(.segmented)
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Ana ekran", isOn: Binding(get: { isMain }, set: { on in
                    ArrangementService.monitorShouldBeMain = on
                    if let id = ProfileStore.monitorDisplayID {
                        if on { ArrangementService.makeMain(id) } else { ArrangementService.makeBuiltinMain() }
                    }
                    reload()
                }))
            }
        }
        .onAppear(perform: reload)
    }

    private func select(_ hz: Int) {
        guard let id = ProfileStore.monitorDisplayID, let current,
              let target = ModeService.bestResolution(for: hz, preferring: current, on: id) else { return }
        profiles.setResolution(target, hz: hz)
        note = target == current ? nil : "\(hz) Hz için \(target.label) moduna geçildi."
        reload()
    }

    private func reload() {
        guard let id = ProfileStore.monitorDisplayID else { resolutions = []; return }
        resolutions = ModeService.resolutions(id)
        current = ModeService.currentResolution(id)
        rates = ModeService.allRefreshRates(id)
        currentRate = ModeService.currentRefreshRate(id)
        isMain = ArrangementService.isMain(id)
    }
}
