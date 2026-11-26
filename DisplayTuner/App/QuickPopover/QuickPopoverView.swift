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
    let eyeComfort: EyeComfort
    var bluetooth: BluetoothBattery? = nil
    var onOpenDevice: (SidebarItem) -> Void = { _ in }
    let onOpenSettings: () -> Void
    @State private var rates: [Int] = []
    @State private var currentRate: Int?

    private var layout: PopoverLayout { PopoverLayout.shared }

    /// D-161: Ayarlar'daki sıra, görünürlük ve özel adlar.
    private var visibleRows: [BrightnessModel.Row] {
        layout.sorted(brightness.rows.map(\.key))
            .filter(layout.isVisible)
            .compactMap { key in brightness.rows.first { $0.key == key } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if brightness.rows.isEmpty || !visibleRows.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        if brightness.rows.isEmpty {
                            Text(brightness.isLoading ? "Ekranlar okunuyor…" : "Ekran bulunamadı")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(visibleRows) { row in
                            BrightnessRow(row: row, title: layout.name(row.key)) { brightness.set(row.id, to: $0) }
                        }
                    }
                }
            }
            // D-157: Kontrol Merkezi tarzı göz konforu düğmesi.
            if layout.showEyeComfort {
            Button { eyeComfort.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: eyeComfort.isActive ? "moon.stars.fill" : "moon.stars")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(eyeComfort.isActive ? .white : .primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(eyeComfort.isActive ? Color.orange : Color.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Göz konforu").font(.callout.weight(.semibold))
                        Text(eyeComfort.isActive ? "Açık" : "Kapalı").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.s + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassBackground(cornerRadius: Theme.Radius.card)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            }
            if profiles.profiles.count > 1 {
                GlassCard { ProfilePicker(profiles: profiles) }
            }
            if layout.showBatteries, !batteries.states.isEmpty || bluetooth?.earbuds != nil {
                GlassCard { BatteryStrip(batteries: batteries, earbuds: bluetooth?.earbuds, onSelect: onOpenDevice) }
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
