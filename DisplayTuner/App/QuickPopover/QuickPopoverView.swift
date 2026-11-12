//
//  QuickPopoverView.swift
//  DisplayTuner
//
//  Görev: Kontrol Merkezi tarzı hızlı popover (parlaklık, profil, piller).
//  Faz: 1  ·  Kararlar: D-21, 7.1  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct QuickPopoverView: View {
    let brightness: BrightnessModel
    let batteries: BatteryMonitor
    let profiles: ProfileStore
    var onOpenDevice: (SidebarItem) -> Void = { _ in }
    let onOpenSettings: () -> Void
    @State private var rates: [Int] = []
    @State private var currentRate: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if brightness.rows.isEmpty {
                        Text(brightness.isLoading ? "Ekranlar okunuyor…" : "Ekran bulunamadı")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(brightness.rows) { row in
                        BrightnessRow(row: row) { brightness.set(row.id, to: $0) }
                    }
                }
            }
            if profiles.profiles.count > 1 {
                GlassCard { ProfilePicker(profiles: profiles) }
            }
            if !batteries.states.isEmpty {
                GlassCard { BatteryStrip(batteries: batteries, onSelect: onOpenDevice) }
            }
            HStack {
                Spacer()
                Button("Ayarlar…", action: onOpenSettings)
                    .buttonStyle(.borderless)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(width: 320)
        .task {
            refreshRates()
            await brightness.load()
        }
    }

    private func refreshRates() {
        guard let id = ProfileStore.monitorDisplayID else { rates = []; return }
        rates = ModeService.refreshRates(id)
        currentRate = ModeService.currentRefreshRate(id)
    }
}
