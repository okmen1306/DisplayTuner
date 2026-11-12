//
//  NotificationsPage.swift
//  DisplayTuner
//
//  Görev: Cihaz başına pil uyarı eşikleri, 'Örnek göster'.
//  Faz: 2  ·  Kararlar: D-71…D-75, D-148  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct NotificationsPage: View {
    let services: AppServices
    @State private var selected: [DeviceKind: Set<Int>] = [:]

    var body: some View {
        Form {
            thresholdSection(.headset, "Kulaklık", "headphones")
            thresholdSection(.mouse, "Mouse", "computermouse.fill")
            Section {
                Button("Örnek Göster") { services.notifier.showSamples() }
            } footer: {
                Text("Bir HUD, bir sistem bildirimi ve bir kritik uyarı gösterir.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            for kind in [DeviceKind.headset, .mouse] {
                selected[kind] = Set(ThresholdTracker.saved(for: kind).map(\.percent))
            }
        }
    }

    private func thresholdSection(_ kind: DeviceKind, _ title: LocalizedStringKey, _ symbol: String) -> some View {
        Section {
            HStack(spacing: 6) {
                ForEach(ThresholdTracker.options(for: kind), id: \.self) { percent in
                    let on = selected[kind, default: []].contains(percent)
                    Button { toggle(kind, percent) } label: {
                        Text("%\(percent)")
                            .font(.callout.monospacedDigit())
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(on ? AnyShapeStyle(percent <= 5 ? Color.red : Color.accentColor) : AnyShapeStyle(.quaternary),
                                        in: Capsule())
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Label(title, systemImage: symbol)
        } footer: {
            Text("Pil seçtiğin seviyelere düşünce uyarır; her seviye bir kez. %5 ve altı (kırmızı) ekranın ortasında kritik uyarıdır.")
        }
    }

    private func toggle(_ kind: DeviceKind, _ percent: Int) {
        var set = selected[kind, default: []]
        if set.contains(percent) { set.remove(percent) } else { set.insert(percent) }
        selected[kind] = set
        ThresholdTracker.save(Array(set), for: kind)
        services.batteries.reloadThresholds()
    }
}
