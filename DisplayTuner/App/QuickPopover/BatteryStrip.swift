//
//  BatteryStrip.swift
//  DisplayTuner
//
//  Görev: Popover altındaki cihaz pil halkaları; tıklayınca cihazın sekmesi açılır.
//  Faz: 2  ·  Kararlar: 7.1, D-145  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct BatteryStrip: View {
    let batteries: BatteryMonitor
    var onSelect: (SidebarItem) -> Void = { _ in }

    var body: some View {
        let items: [(DeviceKind, String, SidebarItem)] = [(.mouse, "Mouse", .mouseDevice), (.headset, "Kulaklık", .headset)]
        HStack(spacing: Theme.Spacing.l) {
            ForEach(items, id: \.0) { kind, label, page in
                if let state = batteries.states[kind] {
                    Button { onSelect(page) } label: {
                        BatteryRing(percent: state.percent, symbol: kind.symbol, label: label, isCharging: state.isCharging)
                            .opacity(state.isStale ? 0.5 : 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(label) ayarlarını aç")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
