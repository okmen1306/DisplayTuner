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
    var earbuds: BluetoothBattery.Earbuds? = nil
    var onSelect: (SidebarItem) -> Void = { _ in }

    var body: some View {
        let items: [(DeviceKind, String, SidebarItem)] = [(.mouse, String(localized: "Mouse"), .mouseDevice), (.headset, String(localized: "Kulaklık"), .headset)]
        HStack(spacing: Theme.Spacing.l) {
            ForEach(items, id: \.0) { kind, label, page in
                if let state = batteries.states[kind] {
                    Button { onSelect(page) } label: {
                        BatteryRing(percent: state.percent, symbol: kind.symbol, label: label, isCharging: state.isCharging)
                            .opacity(state.isStale ? 0.5 : 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "\(label) ayarlarını aç"))
                }
            }
            if let earbuds {
                Button { onSelect(.earbuds) } label: {
                    EarbudsBattery(earbuds: earbuds).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(earbuds.name)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// D-160: AirPods tarzı pil: sol, sağ, kutu (varsa); tek değerli kulaklıkta kulak içi simgesiyle tek halka.
struct EarbudsBattery: View {
    let earbuds: BluetoothBattery.Earbuds

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 10) {
                if earbuds.hasPair {
                    pod(earbuds.left, symbol: "airpodpro.left", tag: "L")
                    pod(earbuds.right, symbol: "airpodpro.right", tag: "R")
                } else {
                    pod(earbuds.main, symbol: "airpodspro", tag: nil)
                }
                if let c = earbuds.caseLevel {
                    pod(c, symbol: "airpodspro.chargingcase.wireless.fill", tag: nil)
                }
            }
            Text(earbuds.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: 150)
        }
        .accessibilityElement(children: .combine)
    }

    private func pod(_ percent: Int?, symbol: String, tag: String?) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: CGFloat(percent ?? 0) / 100)
                    .stroke(Theme.batteryColor(percent), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol).font(.system(size: 14))
                if let tag {
                    Text(tag).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).offset(x: 11, y: 11)
                }
            }
            .frame(width: 38, height: 38)
            Text(percent.map { String(localized: "%\($0)") } ?? "—").font(.caption2.monospacedDigit())
        }
    }
}
