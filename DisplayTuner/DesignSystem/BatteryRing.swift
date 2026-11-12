//
//  BatteryRing.swift
//  DisplayTuner
//
//  Görev: iPhone Piller widget'ı tarzı halka.
//  Faz: 1  ·  Kararlar: 9  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct BatteryRing: View {
    let percent: Int?
    let symbol: String
    let label: String
    var isCharging = false
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(percent ?? 0) / 100)
                    .stroke(Theme.batteryColor(percent), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.spring, value: percent)
                Image(systemName: isCharging ? "bolt.fill" : symbol)
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(.primary)
            }
            .frame(width: size, height: size)
            Text(percent.map { String(localized: "%\($0)") } ?? "—")
                .font(.caption.monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percent.map { String(localized: "\(label) pil yüzde \($0)") } ?? String(localized: "\(label) pil bilinmiyor"))
    }
}
